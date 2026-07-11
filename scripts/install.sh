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
DOTFILES_APPLY_MACOS_DEFAULTS="${DOTFILES_APPLY_MACOS_DEFAULTS:-0}"
DOTFILES_CLOUD_BACKUP="${DOTFILES_CLOUD_BACKUP:-0}"
DOTFILES_BACKUP_DIR="${DOTFILES_BACKUP_DIR:-}"
BACKUP_DIR="${DOTFILES_BACKUP_DIR:-$HOME/.dotfiles.backup/$(date +%Y%m%d_%H%M%S)}"
BREW_BIN=""

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

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
        *)
            log_warn "Unknown DOTFILES_LINK_MODE=$DOTFILES_LINK_MODE; using migrate."
            DOTFILES_LINK_MODE="migrate"
            ;;
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

resolve_brew_bin() {
    if command -v brew >/dev/null 2>&1; then
        BREW_BIN="$(command -v brew)"
        return 0
    fi

    if [[ -x /opt/homebrew/bin/brew ]]; then
        BREW_BIN="/opt/homebrew/bin/brew"
        return 0
    fi

    if [[ -x /usr/local/bin/brew ]]; then
        BREW_BIN="/usr/local/bin/brew"
        return 0
    fi

    BREW_BIN=""
    return 1
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

    if [[ -d "$DOTFILES_WORKTREE/.git" ]]; then
        log_info "Repo already exists at $DOTFILES_WORKTREE"
    else
        ensure_parent_dir "$DOTFILES_WORKTREE"
        run_cmd git clone "$DOTFILES_REPO" "$DOTFILES_WORKTREE"
    fi

    if ! git config --global alias.dotfiles >/dev/null 2>&1; then
        run_cmd git config --global alias.dotfiles "!git -C \"$DOTFILES_WORKTREE\""
    fi
}

backup_existing() {
    log_step "Backing up existing config..."

    local paths=(
        ".zshrc"
        ".zprofile"
        ".config/starship.toml"
        ".config/mise/config.toml"
        ".config/atuin/config.toml"
        ".config/varlock/.env.schema"
        ".agents/AGENTS.md"
        ".agents/GEMINI.md"
    )

    if dry_run_enabled; then
        log_info "Would create backup directory: $BACKUP_DIR"
    else
        mkdir -p "$BACKUP_DIR"
    fi

    local relative source target link_target
    for relative in "${paths[@]}"; do
        source="$HOME/$relative"
        target="$BACKUP_DIR/$relative"

        [[ -e "$source" || -L "$source" ]] || continue

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
    done

    if [[ "$DOTFILES_CLOUD_BACKUP" == "1" ]]; then
        local cloud_dir="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Dotfiles Backup"
        local cloud_target
        cloud_target="$cloud_dir/$(basename "$BACKUP_DIR")"

        if [[ -d "$cloud_dir" ]]; then
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
        return 0
    fi

    ensure_parent_dir "$target"

    if [[ -L "$target" ]]; then
        current="$(readlink "$target")"
        if [[ "$current" == "$source" ]]; then
            log_info "Already linked: $target"
            return 0
        fi

        if [[ "$DOTFILES_LINK_MODE" == "safe" ]]; then
            log_warn "Link differs, skipping: $target"
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
}

link_dotfiles() {
    log_step "Linking tracked config..."

    link_item "$DOTFILES_WORKTREE/.zshrc" "$HOME/.zshrc" ".zshrc"
    link_item "$DOTFILES_WORKTREE/.zprofile" "$HOME/.zprofile" ".zprofile"
    link_item "$DOTFILES_WORKTREE/.config/starship.toml" "$HOME/.config/starship.toml" ".config/starship.toml"
    link_item "$DOTFILES_WORKTREE/.config/mise/config.toml" "$HOME/.config/mise/config.toml" ".config/mise/config.toml"
    link_item "$DOTFILES_WORKTREE/.config/atuin/config.toml" "$HOME/.config/atuin/config.toml" ".config/atuin/config.toml"
    link_item "$DOTFILES_WORKTREE/.config/varlock/.env.schema" "$HOME/.config/varlock/.env.schema" ".config/varlock/.env.schema"
    link_item "$DOTFILES_WORKTREE/.agents/AGENTS.md" "$HOME/.agents/AGENTS.md" ".agents/AGENTS.md"
    link_item "$DOTFILES_WORKTREE/.agents/GEMINI.md" "$HOME/.agents/GEMINI.md" ".agents/GEMINI.md"
}

install_brew_bundles() {
    if [[ "$DOTFILES_INSTALL_BREW" != "1" ]]; then
        log_info "Skipping Homebrew bundles because DOTFILES_INSTALL_BREW=$DOTFILES_INSTALL_BREW"
        return 0
    fi

    log_step "Installing Homebrew bundles..."
    resolve_brew_bin || fail "Homebrew is required before installing Brewfile tiers."

    local brewfiles=("$DOTFILES_ROOT/Brewfile")
    local brewfile

    if [[ "$DOTFILES_INSTALL_DEV" == "1" ]]; then
        brewfiles+=("$DOTFILES_ROOT/Brewfile.dev")
    fi

    if [[ "$DOTFILES_INSTALL_WORKSTATION" == "1" ]]; then
        brewfiles+=("$DOTFILES_ROOT/Brewfile.workstation")
    fi

    for brewfile in "${brewfiles[@]}"; do
        [[ -f "$brewfile" ]] || {
            log_warn "Missing Brewfile: $brewfile"
            continue
        }
        run_cmd "$BREW_BIN" bundle install --no-upgrade --file="$brewfile"
    done
}

install_mise_tools() {
    log_step "Checking mise tools..."

    if ! command -v mise >/dev/null 2>&1; then
        log_warn "mise not installed; skipping runtime install."
        return 0
    fi

    run_cmd env MISE_GLOBAL_CONFIG_FILE="$DOTFILES_WORKTREE/.config/mise/config.toml" mise install
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
    echo "  $DOTFILES_WORKTREE/scripts/setup-git.sh"
    echo ""

    if dry_run_enabled; then
        echo "Dry-run mode: no changes were applied."
        echo "Planned backup location: $BACKUP_DIR"
    else
        echo "Backups saved to: $BACKUP_DIR"
    fi
}

main() {
    echo "== Dotfiles Bootstrap =="

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
    install_mise_tools
    create_local_config
    apply_macos_defaults
    check_optional_tools
    print_post_install
}

main "$@"
