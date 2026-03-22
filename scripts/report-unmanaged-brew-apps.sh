#!/bin/bash
set -euo pipefail

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
      if (name != "") {
        printf "%s:%s\n", kind, name
      }
    }
  ' "$file"
}

tracked_entries() {
  local file

  for file in "$REPO_ROOT/Brewfile" "$REPO_ROOT/Brewfile.dev" "$REPO_ROOT/Brewfile.workstation"; do
    [[ -f "$file" ]] || continue
    parse_brewfile_entries "$file"
  done | sort -u
}

current_brew_entries() {
  local dump_file="$1"
  parse_brewfile_entries "$dump_file" | sort -u
}

current_mas_entries() {
  mas list | awk '
    /^[0-9]+[[:space:]]+/ {
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

  local tracked_file dump_file current_file current_mas_file
  local untracked_brew_file untracked_mas_file tracked_missing_file
  WORK_DIR="$(mktemp -d)"
  trap cleanup EXIT

  tracked_file="$WORK_DIR/tracked.txt"
  dump_file="$WORK_DIR/current.Brewfile"
  current_file="$WORK_DIR/current.txt"
  current_mas_file="$WORK_DIR/current-mas.txt"
  untracked_brew_file="$WORK_DIR/untracked-brew.txt"
  untracked_mas_file="$WORK_DIR/untracked-mas.txt"
  tracked_missing_file="$WORK_DIR/tracked-missing.txt"

  tracked_entries > "$tracked_file"
  brew bundle dump --describe --force --file="$dump_file" >/dev/null
  current_brew_entries "$dump_file" > "$current_file"

  if command -v mas >/dev/null 2>&1; then
    current_mas_entries > "$current_mas_file"
  else
    : > "$current_mas_file"
    warn "mas not installed; skipping live App Store comparison"
  fi

  comm -23 "$current_file" "$tracked_file" > "$untracked_brew_file"
  comm -23 "$current_mas_file" "$tracked_file" > "$untracked_mas_file"
  comm -23 "$tracked_file" "$current_file" > "$tracked_missing_file"

  info "Tracked source files:"
  info "  $REPO_ROOT/Brewfile"
  if [[ -f "$REPO_ROOT/Brewfile.dev" ]]; then
    info "  $REPO_ROOT/Brewfile.dev"
  fi
  if [[ -f "$REPO_ROOT/Brewfile.workstation" ]]; then
    info "  $REPO_ROOT/Brewfile.workstation"
  fi

  print_section "Installed via Homebrew bundle dump but not tracked" "$untracked_brew_file"
  print_section "Installed via mas list but not tracked" "$untracked_mas_file"
  print_section "Tracked but missing from current machine" "$tracked_missing_file"
}

main "$@"
