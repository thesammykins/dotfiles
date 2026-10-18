#!/bin/bash
set -euo pipefail
export HOMEBREW_NO_AUTO_UPDATE=1

SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${DOTFILES_REPO_ROOT:-$(cd -- "$SCRIPT_DIR/.." && pwd)}"

warn() { echo "[WARN] $*"; }
info() { echo "[INFO] $*"; }
WORK_DIR=""

cleanup() {
  if [[ -n "$WORK_DIR" && -d "$WORK_DIR" ]]; then
    rm -rf "$WORK_DIR"
  fi
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    warn "Missing required command: $1"
    exit 1
  }
}

parse_brewfile_entries() {
  local file="$1"

  awk '
    /^[[:space:]]*(tap|brew|cask|mas)[[:space:]]+"/ {
      line = $0
      sub(/[[:space:]]*#.*/, "", line)
      kind = $1

      if (kind == "mas") {
        name = line
        sub(/^[^"]*"/, "", name)
        sub(/".*$/, "", name)
        id = line
        sub(/^.*id:[[:space:]]*/, "", id)
        sub(/[^0-9].*$/, "", id)
        if (id != "") {
          printf "mas:%s\t%s\n", id, name
        }
        next
      }

      name = line
      sub(/^[^"]*"/, "", name)
      sub(/".*$/, "", name)
      if (kind == "brew" || kind == "cask") {
        sub(/^.*\//, "", name)
      }
      if (name != "") {
        printf "%s:%s\n", kind, name
      }
    }
  ' "$file"
}

tracked_entries() {
  local file

  for file in "$REPO_ROOT/Brewfile" "$REPO_ROOT/Brewfile.dev" "$REPO_ROOT/Brewfile.workstation" "$REPO_ROOT/Brewfile.ci"; do
    [[ -f "$file" ]] || continue
    parse_brewfile_entries "$file"
  done | sort -u
}

current_brew_entries() {
  local dump_file="$1"
  parse_brewfile_entries "$dump_file" | sort -u
}

installed_brew_entries() {
  {
    brew list --formula | awk '{sub(/^.*\//, "", $0); print "brew:" $0}'
    brew list --cask | awk '{sub(/^.*\//, "", $0); print "cask:" $0}'
    brew tap | awk '{print "tap:" $0}'
  } | sort -u
}

current_mas_entries() {
  mas list | awk '
    /^[[:space:]]*[0-9]+[[:space:]]+/ {
      id = $1
      $1 = ""
      sub(/^[[:space:]]+/, "", $0)
      sub(/[[:space:]]+\([^)]+\)$/, "", $0)
      printf "mas:%s\t%s\n", id, $0
    }
  ' | sort -u
}

print_section() {
  local title="$1"
  local file="$2"

  echo
  echo "== $title =="
  if [[ -s "$file" ]]; then
    cat "$file"
  else
    echo "None."
  fi
}

main() {
  require_cmd brew
  require_cmd comm
  require_cmd mktemp
  require_cmd sort

  local tracked_file dump_file current_file installed_file current_mas_file
  local untracked_brew_file untracked_mas_file tracked_missing_file tracked_outdated_file outdated_file
  WORK_DIR="$(mktemp -d)"
  trap cleanup EXIT

  tracked_file="$WORK_DIR/tracked.txt"
  dump_file="$WORK_DIR/current.Brewfile"
  current_file="$WORK_DIR/current.txt"
  installed_file="$WORK_DIR/installed.txt"
  current_mas_file="$WORK_DIR/current-mas.txt"
  untracked_brew_file="$WORK_DIR/untracked-brew.txt"
  untracked_mas_file="$WORK_DIR/untracked-mas.txt"
  tracked_missing_file="$WORK_DIR/tracked-missing.txt"
  tracked_outdated_file="$WORK_DIR/tracked-outdated.txt"
  outdated_file="$WORK_DIR/outdated.txt"

  tracked_entries > "$tracked_file"
  # dump probes go and cargo for packages; mise shims print errors for them in
  # directories with no version set. Show stderr only when the dump fails.
  if ! brew bundle dump --force --file="$dump_file" >/dev/null 2>"$WORK_DIR/dump.err"; then
    cat "$WORK_DIR/dump.err" >&2
    exit 1
  fi
  current_brew_entries "$dump_file" > "$current_file"
  installed_brew_entries > "$installed_file"

  if command -v mas >/dev/null 2>&1; then
    current_mas_entries > "$current_mas_file"
    sort -u "$installed_file" "$current_mas_file" -o "$installed_file"
  else
    : > "$current_mas_file"
    warn "mas not installed; skipping live App Store comparison"
  fi

  comm -23 "$current_file" "$tracked_file" > "$untracked_brew_file"
  comm -23 "$current_mas_file" "$tracked_file" > "$untracked_mas_file"
  comm -23 "$tracked_file" "$installed_file" > "$tracked_missing_file"
  { brew outdated --formula; brew outdated --cask; } | awk '{name = $1; sub(/^.*\//, "", name); print name}' | sort -u > "$outdated_file"
  awk -F: '/^(brew|cask):/ {print $2}' "$tracked_file" | sort -u | comm -12 - "$outdated_file" > "$tracked_outdated_file"

  info "Tracked source files:"
  info "  $REPO_ROOT/Brewfile"
  if [[ -f "$REPO_ROOT/Brewfile.dev" ]]; then
    info "  $REPO_ROOT/Brewfile.dev"
  fi
  if [[ -f "$REPO_ROOT/Brewfile.workstation" ]]; then
    info "  $REPO_ROOT/Brewfile.workstation"
  fi
  if [[ -f "$REPO_ROOT/Brewfile.ci" ]]; then
    info "  $REPO_ROOT/Brewfile.ci"
  fi

  print_section "Installed via Homebrew bundle dump but not tracked" "$untracked_brew_file"
  print_section "Installed via mas list but not tracked" "$untracked_mas_file"
  print_section "Tracked but missing from current machine" "$tracked_missing_file"
  print_section "Tracked and installed but outdated" "$tracked_outdated_file"
  uncovered_apps > "$WORK_DIR/uncovered-apps.txt"
  print_section "Apps in no Brewfile and not in manual-installs.txt" "$WORK_DIR/uncovered-apps.txt"
}

# Apps installed outside Homebrew and the App Store that manual-installs.txt
# doesn't list. Games and Xcode copies are skipped: Steam and xcodes own them.
uncovered_apps() {
  python3 - "$REPO_ROOT/manual-installs.txt" <<'PY'
import json, pathlib, plistlib, re, subprocess, sys
listed = set()
for line in pathlib.Path(sys.argv[1]).read_text().splitlines():
    if line and not line.startswith("#"):
        listed.add(line.split("\t")[1])
brewfiles = [pathlib.Path(sys.argv[1]).parent / name for name in ("Brewfile", "Brewfile.workstation", "Brewfile.dev", "Brewfile.ci")]
tracked = [m.group(1) for f in brewfiles if f.exists() for m in re.finditer(r'^cask "([^"]+)"', f.read_text(), re.M)]
installed = json.loads(subprocess.run(["brew", "info", "--json=v2", "--installed"], capture_output=True, text=True, check=True).stdout)["casks"]
listed_casks = json.loads(subprocess.run(["brew", "info", "--json=v2", "--cask", *tracked], capture_output=True, text=True).stdout or '{"casks": []}')["casks"]

def cask_apps(cask):
    # App artifacts, plus apps a pkg-based cask deletes on uninstall.
    for artifact in cask["artifacts"]:
        if not isinstance(artifact, dict):
            continue
        for app in artifact.get("app", []):
            if isinstance(app, str):
                yield pathlib.Path(app).name
        for step in artifact.get("uninstall", []):
            if isinstance(step, dict):
                deletes = step.get("delete", [])
                for path in [deletes] if isinstance(deletes, str) else deletes:
                    if str(path).startswith("/Applications/") and str(path).endswith(".app"):
                        yield pathlib.Path(path).name

def cask_bundle_ids(cask):
    # pkg-based casks name their app only by bundle id (quit/pkgutil).
    for artifact in cask["artifacts"]:
        for step in (artifact.get("uninstall", []) if isinstance(artifact, dict) else []):
            if isinstance(step, dict):
                for key in ("quit", "pkgutil"):
                    value = step.get(key, [])
                    yield from [value] if isinstance(value, str) else value

casks = [*installed, *listed_casks]
from_casks = {app for cask in casks for app in cask_apps(cask)}
cask_ids = {bundle_id for cask in casks for bundle_id in cask_bundle_ids(cask)}

def bundle_id(app):
    try:
        return plistlib.loads((app / "Contents/Info.plist").read_bytes()).get("CFBundleIdentifier")
    except (OSError, plistlib.InvalidFileException):
        return None
apps = sorted(p for p in pathlib.Path("/Applications").glob("*.app"))
for app in apps:
    name = app.stem
    if app.name in from_casks or name in listed or (app / "Contents/_MASReceipt").exists() or bundle_id(app) in cask_ids:
        continue
    if name.startswith("Xcode") or (app / "Contents/MacOS/steam_appid.txt").exists():
        continue
    if re.search(r"steamapps|Steam", str(app.resolve())):
        continue
    print(name)
PY
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
