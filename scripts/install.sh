#!/usr/bin/env bash
set -euo pipefail

DOTFILES_REPO="https://github.com/thesammykins/dotfiles.git"
SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_WORKTREE="${DOTFILES_WORKTREE:-$(cd -- "$SCRIPT_DIR/.." && pwd)}"
DOTFILES_ROOT="${DOTFILES_ROOT:-$DOTFILES_WORKTREE}"
DOTFILES_DRY_RUN="${DOTFILES_DRY_RUN:-0}"
DOTFILES_LINK_MODE="${DOTFILES_LINK_MODE:-migrate}"
DOTFILES_INSTALL_BREW="${DOTFILES_INSTALL_BREW:-1}"
DOTFILES_INSTALL_DEV="${DOTFILES_INSTALL_DEV:-0}"
DOTFILES_INSTALL_WORKSTATION="${DOTFILES_INSTALL_WORKSTATION:-0}"
# Comma-separated tiers (core, workstation, dev, ci). Unset: ask in an
# interactive terminal, otherwise core plus the legacy DEV/WORKSTATION flags.
DOTFILES_TIERS="${DOTFILES_TIERS:-}"
# Commit signing is linked only where this signer exists (not on CI runners).
DOTFILES_GIT_SIGNER="${DOTFILES_GIT_SIGNER:-/Applications/1Password.app/Contents/MacOS/op-ssh-sign}"
DOTFILES_APPLY_MACOS_DEFAULTS="${DOTFILES_APPLY_MACOS_DEFAULTS:-0}"
DOTFILES_CLOUD_BACKUP="${DOTFILES_CLOUD_BACKUP:-0}"
DOTFILES_BACKUP_DIR="${DOTFILES_BACKUP_DIR:-}"
DOTFILES_STATUS_FILE="${DOTFILES_STATUS_FILE:-}"
BACKUP_DIR="${DOTFILES_BACKUP_DIR:-$HOME/.dotfiles.backup/$(date +%Y%m%d_%H%M%S)}"
MANAGED_PATHS_FILE="$SCRIPT_DIR/managed-paths.txt"
BREW_BIN=""
STATUS_WRITTEN=0

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

status_event() {
    # A dry run reports what it would do but records nothing as done.
    [[ -n "$DOTFILES_STATUS_FILE" ]] && ! dry_run_enabled || return 0
    python3 - "$DOTFILES_STATUS_FILE.events" "$1" "$2" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
path.parent.mkdir(parents=True, exist_ok=True)
with path.open("a", encoding="utf-8") as handle:
    handle.write(json.dumps({"status": sys.argv[2], "item": sys.argv[3]}) + "\n")
PY
}

write_status() {
    [[ -n "$DOTFILES_STATUS_FILE" ]] || return 0
    python3 - "$DOTFILES_STATUS_FILE.events" "$DOTFILES_STATUS_FILE" "$1" "$BACKUP_DIR" <<'PY'
import json
import sys
from pathlib import Path

events_path = Path(sys.argv[1])
output_path = Path(sys.argv[2])
payload = {key: [] for key in ("linked", "installed", "skipped", "outdated", "failed")}
if events_path.exists():
    for line in events_path.read_text(encoding="utf-8").splitlines():
        event = json.loads(line)
        payload[event["status"]].append(event["item"])
payload["result"] = sys.argv[3]
payload["backup"] = sys.argv[4]
output_path.parent.mkdir(parents=True, exist_ok=True)
output_path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
events_path.unlink(missing_ok=True)
PY
    STATUS_WRITTEN=1
}

write_failed_status() {
    local exit_status=$?
    if [[ "$STATUS_WRITTEN" != "1" && -n "$DOTFILES_STATUS_FILE" ]]; then
        status_event failed "dotfiles installer exited with status $exit_status"
        write_status failed
    fi
    return "$exit_status"
}

fail() {
    log_error "$1"
    exit 1
}

dry_run_enabled() {
    [[ "$DOTFILES_DRY_RUN" == "1" ]]
}

run_cmd() {
    if dry_run_enabled; then
        printf '[DRY-RUN] '
        printf '%q ' "$@"
        printf '\n'
        return 0
    fi

    "$@"
}

validate_link_mode() {
    case "$DOTFILES_LINK_MODE" in
        migrate|safe|force) ;;
        *) fail "Invalid DOTFILES_LINK_MODE=$DOTFILES_LINK_MODE; expected migrate, safe, or force." ;;
    esac
}

check_prerequisites() {
    log_step "Checking prerequisites..."

    [[ "$(uname)" == "Darwin" ]] || fail "This installer currently supports macOS only."
    validate_link_mode

    if dry_run_enabled; then
        log_warn "Dry-run mode enabled. No filesystem or package-manager changes will be applied."
    fi

    log_info "Prerequisites OK"
}

ensure_parent_dir() {
    local target="$1"
    local parent
    parent="$(dirname "$target")"

    if [[ ! -d "$parent" ]]; then
        run_cmd mkdir -p "$parent"
    fi
}

# Where Homebrew installs on Apple silicon and Intel Macs.
DOTFILES_HOMEBREW_PREFIXES="${DOTFILES_HOMEBREW_PREFIXES:-/opt/homebrew /usr/local}"

resolve_brew_bin() {
    if command -v brew >/dev/null 2>&1; then
        BREW_BIN="$(command -v brew)"
        return 0
    fi

    local prefix
    for prefix in $DOTFILES_HOMEBREW_PREFIXES; do
        if [[ -x "$prefix/bin/brew" ]]; then
            BREW_BIN="$prefix/bin/brew"
            return 0
        fi
    done

    BREW_BIN=""
    return 1
}

# Resolve symlinked directories so a checkout reached through a link compares
# equal to its real location. A path whose directory doesn't exist is
# returned unchanged.
physical_path() {
    local dir
    if dir="$(cd -P -- "$(dirname -- "$1")" 2>/dev/null && pwd -P)"; then
        printf '%s/%s\n' "$dir" "$(basename -- "$1")"
    else
        printf '%s\n' "$1"
    fi
}

# True when link points at source, however either path was spelled. A
# relative link target is resolved from the link's own folder.
links_to() {
    local link="$1" source="$2" target
    [[ -L "$link" ]] || return 1
    target="$(readlink "$link")"
    [[ "$target" == /* ]] || target="$(dirname -- "$link")/$target"
    [[ "$(physical_path "$target")" == "$(physical_path "$source")" ]]
}

install_homebrew() {
    log_step "Checking Homebrew..."

    if resolve_brew_bin; then
        log_info "Homebrew already installed"
        eval "$("$BREW_BIN" shellenv)"
        return 0
    fi

    if dry_run_enabled; then
        log_info "Would install Homebrew with the official installer"
        return 0
    fi

    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    resolve_brew_bin || fail "Homebrew installed but brew was not found on PATH."
    eval "$("$BREW_BIN" shellenv)"
}

setup_repo() {
    log_step "Checking dotfiles repository..."

    if [[ -d "$DOTFILES_WORKTREE/.git" || -f "$DOTFILES_WORKTREE/.git" ]]; then
        log_info "Repo already exists at $DOTFILES_WORKTREE"
    elif [[ -e "$DOTFILES_WORKTREE" ]] && [[ -n "$(find "$DOTFILES_WORKTREE" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]; then
        fail "Dotfiles target exists but is not a Git checkout: $DOTFILES_WORKTREE"
    else
        ensure_parent_dir "$DOTFILES_WORKTREE"
        run_cmd git clone "$DOTFILES_REPO" "$DOTFILES_WORKTREE"
    fi

    # --global would write to ~/.config/git/config, a link into this repo,
    # when ~/.gitconfig doesn't exist yet; machine settings belong in ~/.gitconfig.
    if ! git config --global alias.dotfiles >/dev/null 2>&1; then
        run_cmd git config --file "$HOME/.gitconfig" alias.dotfiles "!git -C \"$DOTFILES_WORKTREE\""
    fi
}

backup_existing() {
    log_step "Backing up existing config..."
    [[ -f "$MANAGED_PATHS_FILE" ]] || fail "Managed paths file is missing: $MANAGED_PATHS_FILE"

    # The backup folder is created on first use, so a run with nothing to
    # back up leaves no empty folder (or iCloud copy) behind.
    local relative source target link_target backed_up=0
    while IFS= read -r relative || [[ -n "$relative" ]]; do
        [[ -n "$relative" ]] || continue
        source="$HOME/$relative"
        target="$BACKUP_DIR/$relative"

        [[ -e "$source" || -L "$source" ]] || continue
        # A link to this repo's own copy holds nothing to keep, and backing it
        # up would make the newest backup useless for restore.
        if links_to "$source" "$DOTFILES_WORKTREE/$relative"; then
            continue
        fi

        backed_up=1
        if dry_run_enabled; then
            log_info "Would back up: $source -> $target"
            continue
        fi

        mkdir -p "$(dirname "$target")"
        if [[ -L "$source" ]]; then
            link_target="$(readlink "$source")"
            printf '%s\n' "$link_target" > "${target}.symlink"
        else
            cp -R "$source" "$target"
        fi
    done < "$MANAGED_PATHS_FILE"

    if [[ "$DOTFILES_CLOUD_BACKUP" == "1" ]]; then
        local cloud_dir="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Dotfiles Backup"
        local cloud_target
        cloud_target="$cloud_dir/$(basename "$BACKUP_DIR")"

        if [[ "$backed_up" == 0 ]]; then
            log_info "Nothing was backed up, so nothing to copy to iCloud."
        elif [[ -d "$cloud_dir" ]]; then
            run_cmd cp -R "$BACKUP_DIR" "$cloud_target"
        else
            log_warn "iCloud backup directory not found; skipping cloud backup."
        fi
    fi
}

link_item() {
    local source="$1"
    local target="$2"
    local label="$3"
    local current backup_target

    if [[ ! -e "$source" ]]; then
        log_warn "Source missing: $source"
        status_event skipped "$target (source missing)"
        return 0
    fi

    ensure_parent_dir "$target"

    if [[ -L "$target" ]]; then
        current="$(readlink "$target")"
        if links_to "$target" "$source"; then
            log_info "Already linked: $target"
            status_event skipped "$target (already linked)"
            return 0
        fi

        if [[ "$DOTFILES_LINK_MODE" == "safe" ]]; then
            log_warn "Link differs, skipping: $target"
            status_event skipped "$target (safe mode)"
            return 0
        fi

        if [[ "$DOTFILES_LINK_MODE" == "migrate" ]]; then
            backup_target="$BACKUP_DIR/${label}.symlink"
            run_cmd mkdir -p "$(dirname "$backup_target")"
            if dry_run_enabled; then
                log_info "Would save symlink target: $target -> $backup_target"
            else
                printf '%s\n' "$current" > "$backup_target"
            fi
        fi

        run_cmd rm -f "$target"
    elif [[ -e "$target" ]]; then
        if [[ "$DOTFILES_LINK_MODE" == "safe" ]]; then
            log_warn "Target exists, skipping: $target"
            status_event skipped "$target (safe mode)"
            return 0
        fi

        if [[ "$DOTFILES_LINK_MODE" == "migrate" ]]; then
            backup_target="$BACKUP_DIR/$label"
            run_cmd mkdir -p "$(dirname "$backup_target")"
            run_cmd cp -R "$target" "$backup_target"
        fi

        run_cmd rm -rf "$target"
    fi

    run_cmd ln -s "$source" "$target"
    log_info "Linked: $target"
    status_event linked "$target"
}

link_dotfiles() {
    log_step "Linking tracked config..."

    local relative
    while IFS= read -r relative || [[ -n "$relative" ]]; do
        [[ -n "$relative" ]] || continue
        if [[ "$relative" == .config/git/signing.gitconfig ]]; then
            link_signing_config
            continue
        fi
        link_item "$DOTFILES_WORKTREE/$relative" "$HOME/$relative" "$relative"
    done < "$MANAGED_PATHS_FILE"
}

# The shared git config includes signing.gitconfig. Link it only where the
# 1Password signer exists, and unlink our own link if the signer is gone,
# since every commit would fail otherwise. Git skips a missing include.
link_signing_config() {
    local relative=".config/git/signing.gitconfig"
    local source="$DOTFILES_WORKTREE/$relative" target="$HOME/$relative"
    if [[ -x "$DOTFILES_GIT_SIGNER" ]]; then
        link_item "$source" "$target" "$relative"
    elif links_to "$target" "$source"; then
        log_warn "Unlinking commit signing: $DOTFILES_GIT_SIGNER is missing"
        run_cmd rm -f "$target"
        status_event skipped "$target (signer missing; unlinked)"
    else
        log_info "Commit signing not linked: $DOTFILES_GIT_SIGNER is missing"
        status_event skipped "$target (signer missing)"
    fi
}

install_brew_bundles() {
    if [[ "$DOTFILES_INSTALL_BREW" != "1" ]]; then
        log_info "Skipping Homebrew bundles because DOTFILES_INSTALL_BREW=$DOTFILES_INSTALL_BREW"
        return 0
    fi

    log_step "Installing Homebrew bundles..."
    if ! resolve_brew_bin; then
        dry_run_enabled || fail "Homebrew is required before installing Brewfile tiers."
        log_warn "Homebrew is not installed; a real run would stop here."
        return 0
    fi
    # brew-tiers.sh calls brew by name.
    PATH="$(dirname "$BREW_BIN"):$PATH"

    local tiers_list="$DOTFILES_TIERS"
    if [[ -z "$tiers_list" ]]; then
        if [[ -t 0 && -t 2 ]] && ! dry_run_enabled; then
            tiers_list="$(bash "$SCRIPT_DIR/brew-tiers.sh" choose | paste -sd, -)"
        else
            tiers_list="core"
            [[ "$DOTFILES_INSTALL_WORKSTATION" == "1" ]] && tiers_list+=",workstation"
            [[ "$DOTFILES_INSTALL_DEV" == "1" ]] && tiers_list+=",dev"
        fi
    fi
    [[ -n "$tiers_list" ]] || { log_info "No Brewfile tiers selected."; return 0; }

    local -a tiers
    IFS=',' read -r -a tiers <<< "$tiers_list"
    local -a flags=()
    dry_run_enabled && flags+=(--dry-run)
    bash "$SCRIPT_DIR/brew-tiers.sh" install "${flags[@]+"${flags[@]}"}" "${tiers[@]}"
    status_event installed "Brewfile tiers: $tiers_list"
}

create_local_config() {
    log_step "Checking local override file..."

    if [[ -f "$HOME/.zshrc.local" ]]; then
        log_info "$HOME/.zshrc.local already exists"
        return 0
    fi

    if dry_run_enabled; then
        log_info "Would create ~/.zshrc.local"
        return 0
    fi

    cat > "$HOME/.zshrc.local" <<'EOF'
# ~/.zshrc.local
# Machine-specific exports, paths, and aliases.

# export PATH="$HOME/bin:$PATH"
# export BROWSER="safari"
EOF
}

apply_macos_defaults() {
    [[ "$DOTFILES_APPLY_MACOS_DEFAULTS" == "1" ]] || return 0

    log_step "Applying macOS defaults..."

    local screenshot_dir="$HOME/Pictures/Screenshots"
    run_cmd mkdir -p "$screenshot_dir"
    run_cmd defaults write NSGlobalDomain AppleShowAllExtensions -bool true
    run_cmd defaults write com.apple.finder ShowPathbar -bool true
    run_cmd defaults write com.apple.finder ShowStatusBar -bool true
    run_cmd defaults write com.apple.finder _FXSortFoldersFirst -bool true
    run_cmd defaults write com.apple.dock show-recents -bool false
    run_cmd defaults write com.apple.screencapture type -string png
    run_cmd defaults write com.apple.screencapture location -string "$screenshot_dir"

    if ! dry_run_enabled; then
        killall Finder >/dev/null 2>&1 || true
        killall Dock >/dev/null 2>&1 || true
        killall SystemUIServer >/dev/null 2>&1 || true
    fi
}

check_optional_tools() {
    log_step "Checking optional auth tools..."

    if command -v op >/dev/null 2>&1; then
        if perl -e 'alarm shift; exec @ARGV' 5 op account list >/dev/null 2>&1; then
            log_info "1Password CLI configured"
        else
            log_warn "1Password CLI installed but not signed in. Run: op account add"
        fi
    else
        log_warn "1Password CLI not installed"
    fi

    command -v varlock >/dev/null 2>&1 || log_warn "varlock not installed; install the dev Brewfile tier if needed."
}

print_post_install() {
    echo ""
    echo "Dotfiles install complete."
    echo ""
    echo "Next:"
    echo "  exec zsh"
    echo "  gh auth login"
    echo ""

    if dry_run_enabled; then
        echo "Dry-run mode: no changes were applied."
        echo "Planned backup location: $BACKUP_DIR"
    elif [[ -d "$BACKUP_DIR" ]]; then
        echo "Backups saved to: $BACKUP_DIR"
    else
        echo "No existing files needed a backup."
    fi
}

main() {
    echo "== Dotfiles Bootstrap =="
    trap write_failed_status EXIT
    if [[ -n "$DOTFILES_STATUS_FILE" ]]; then
        rm -f "$DOTFILES_STATUS_FILE.events"
    fi

    check_prerequisites
    backup_existing
    if [[ "$DOTFILES_INSTALL_BREW" == "1" ]]; then
        install_homebrew
    else
        resolve_brew_bin >/dev/null 2>&1 || true
    fi
    setup_repo
    link_dotfiles
    install_brew_bundles
    create_local_config
    apply_macos_defaults
    check_optional_tools
    print_post_install
    if dry_run_enabled; then
        write_status dry-run
    else
        write_status success
    fi
}

main "$@"
