#!/bin/bash
# Dotfiles Bootstrap Script - MCRN Tactical
# One-command setup for Ghostty + zsh + modern CLI stack

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================
DOTFILES_REPO="https://github.com/sammykins/dotfiles.git"
SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_WORKTREE="${DOTFILES_WORKTREE:-$(cd -- "$SCRIPT_DIR/.." && pwd)}"
DOTFILES_CLOUD_BACKUP="${DOTFILES_CLOUD_BACKUP:-0}"
DOTFILES_BACKUP_DIR="${DOTFILES_BACKUP_DIR:-}"
BACKUP_DIR="${DOTFILES_BACKUP_DIR:-$HOME/.dotfiles.backup/$(date +%Y%m%d_%H%M%S)}"
DOTFILES_LINK_MODE="${DOTFILES_LINK_MODE:-migrate}"
DOTFILES_ROOT="${DOTFILES_ROOT:-$DOTFILES_WORKTREE}"
DOTFILES_DRY_RUN="${DOTFILES_DRY_RUN:-0}"
DOTFILES_INSTALL_DEV="${DOTFILES_INSTALL_DEV:-0}"
DOTFILES_INSTALL_WORKSTATION="${DOTFILES_INSTALL_WORKSTATION:-0}"
DOTFILES_APPLY_MACOS_DEFAULTS="${DOTFILES_APPLY_MACOS_DEFAULTS:-0}"
DOTFILES_APPLY_DOCK="${DOTFILES_APPLY_DOCK:-0}"
BREW_BIN=""

# Colors
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

apply_macos_defaults_enabled() {
    [[ "$DOTFILES_APPLY_MACOS_DEFAULTS" == "1" ]]
}

apply_dock_enabled() {
    [[ "$DOTFILES_APPLY_DOCK" == "1" ]]
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

run_shell() {
    local command="$1"

    if dry_run_enabled; then
        printf '[DRY-RUN] %s\n' "$command"
        return 0
    fi

    bash -lc "$command"
}

ensure_mcrn_ai_dependencies() {
    local plugin_dir="$DOTFILES_ROOT/zsh/plugins/mcrn-ai"
    local package_json="$plugin_dir/package.json"
    local package_lock="$plugin_dir/package-lock.json"

    if [[ ! -f "$package_json" || ! -f "$package_lock" ]]; then
        log_warn "Skipping MCRN AI dependency install; package manifest missing."
        return 0
    fi

    log_step "Installing MCRN AI dependencies..."

    if dry_run_enabled; then
        if command -v npm &>/dev/null; then
            run_shell "cd \"$plugin_dir\" && npm ci --dry-run --no-audit --no-fund --loglevel=error"
        else
            log_info "Would run npm ci in $plugin_dir after Node/npm are available."
        fi
        return 0
    fi

    command -v npm &>/dev/null || fail "npm not found after tool initialization. Node/npm is required for the MCRN AI widget."
    (cd "$plugin_dir" && npm ci --no-audit --no-fund --loglevel=error)
    (cd "$plugin_dir" && node ./patch-copilot-sdk.mjs)
    log_info "MCRN AI dependencies installed"

    if command -v copilot &>/dev/null; then
        log_info "GitHub Copilot CLI detected"
    else
        log_warn "GitHub Copilot CLI not found. Install the dev bundle or run: brew install copilot-cli"
    fi
}

validate_link_mode() {
    case "$DOTFILES_LINK_MODE" in
        safe|force|migrate) return 0 ;;
        *)
            log_warn "Unknown DOTFILES_LINK_MODE=$DOTFILES_LINK_MODE. Defaulting to migrate."
            DOTFILES_LINK_MODE="migrate"
            ;;
    esac
}

# ============================================================================
# PREFLIGHT CHECKS
# ============================================================================
check_prerequisites() {
    log_step "Checking prerequisites..."
    
    # Check macOS
    if [[ "$(uname)" != "Darwin" ]]; then
        log_error "This script is for macOS only."
        exit 1
    fi
    
    # Check architecture
    ARCH=$(uname -m)
    if [[ "$ARCH" == "arm64" ]]; then
        HOMEBREW_PREFIX="/opt/homebrew"
        log_info "Detected Apple Silicon (arm64)"
    else
        HOMEBREW_PREFIX="/usr/local"
        log_info "Detected Intel (x86_64)"
    fi
    
    # Check for existing backup
    if [[ -d "$HOME/.dotfiles.backup" ]]; then
        log_warn "Existing backup directory found."
    fi

    validate_link_mode

    if dry_run_enabled; then
        log_warn "Dry-run mode enabled. No file system or package manager changes will be applied."
    fi
    
    log_info "Prerequisites OK"
}

ensure_parent_dir() {
    local target="$1"
    local parent
    parent=$(dirname "$target")
    if [[ ! -d "$parent" ]]; then
        mkdir -p "$parent"
    fi
}

resolve_brew_bin() {
    if command -v brew &>/dev/null; then
        BREW_BIN=$(command -v brew)
        return 0
    fi

    local arch
    arch=$(uname -m)
    if [[ "$arch" == "arm64" ]]; then
        if [[ -x "/opt/homebrew/bin/brew" ]]; then
            BREW_BIN="/opt/homebrew/bin/brew"
            return 0
        fi
    else
        if [[ -x "/usr/local/bin/brew" ]]; then
            BREW_BIN="/usr/local/bin/brew"
            return 0
        fi
    fi

    BREW_BIN=""
    return 1
}

ensure_dockutil() {
    if ! apply_dock_enabled; then
        return 0
    fi

    if command -v dockutil &>/dev/null; then
        return 0
    fi

    log_step "Installing dockutil for Dock automation..."
    if ! resolve_brew_bin; then
        fail "Homebrew is required to install dockutil"
    fi

    run_cmd "$BREW_BIN" install dockutil
}

# ============================================================================
# MIGRATION NOTICE
# ============================================================================
show_migration_notice() {
    if [[ -d "$HOME/Library/Application Support/Warp" ]]; then
        log_warn "Warp data detected at ~/Library/Application Support/Warp"
        log_info "Ghostty install will not remove Warp. Migration is manual."
    fi
}

# BACKUP EXISTING CONFIGS
# ============================================================================
backup_configs() {
    log_step "Backing up existing configurations..."

    if dry_run_enabled; then
        log_info "Would create backup directory: $BACKUP_DIR"
    else
        mkdir -p "$BACKUP_DIR"
    fi
     
    # Files to backup
    local files=(
        ".zshrc"
        ".zprofile"
        ".zsh_aliases"
        "Library/Application Support/com.mitchellh.ghostty/config"
        ".config/ghostty/config"
        ".config/starship.toml"
        ".config/mise/config.toml"
        ".config/fastfetch/config.jsonc"
        ".config/fastfetch/mcrn_logo.txt"
        ".config/opencode"
        "Library/Application Support/Dia/User Data"
    )
    
    for file in "${files[@]}"; do
        local src="$HOME/$file"
        if [[ -e "$src" ]]; then
            local dest="$BACKUP_DIR/$file"
            if dry_run_enabled; then
                log_info "Would back up: $src -> $dest"
                continue
            fi

            mkdir -p "$(dirname "$dest")"
            if [[ -L "$src" ]]; then
                local link_target
                link_target=$(readlink "$src")
                printf '%s\n' "$link_target" > "${dest}.symlink"
                log_info "Backed up symlink: $file"
            else
                cp -R "$src" "$dest"
                log_info "Backed up: $file"
            fi
        fi
    done
    
    if [[ -d "$BACKUP_DIR" && -n "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]]; then
        log_info "Backups saved to: $BACKUP_DIR"
    fi

    if [[ "$DOTFILES_CLOUD_BACKUP" == "1" ]]; then
        local cloud_dir="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Dotfiles Backup"
        if [[ -d "$cloud_dir" ]]; then
            local cloud_target
            cloud_target="$cloud_dir/$(basename "$BACKUP_DIR")"
            if dry_run_enabled; then
                log_info "Would copy backup to iCloud: $cloud_target"
            else
                cp -R "$BACKUP_DIR" "$cloud_target" 2>/dev/null || true
                log_info "iCloud backup saved to: $cloud_target"
            fi
        else
            log_warn "iCloud Drive not found. Skipping cloud backup."
        fi
    fi
}

# ============================================================================
# LINK DOTFILES
# ============================================================================
link_item() {
    local source="$1"
    local target="$2"
    local label="$3"

    if [[ ! -e "$source" ]]; then
        log_warn "Source missing: $source"
        return 0
    fi

    if dry_run_enabled; then
        log_info "Would link $target -> $source"
    else
        mkdir -p "$(dirname "$target")"
    fi

    if [[ -L "$target" ]]; then
        local current
        current="$(readlink "$target")"
        if [[ "$current" == "$source" ]]; then
            log_info "Link already set: $target"
            return 0
        fi
        if [[ "$DOTFILES_LINK_MODE" == "safe" ]]; then
            log_warn "Link differs, skipping: $target"
            return 0
        fi
        if [[ "$DOTFILES_LINK_MODE" == "migrate" ]]; then
            local backup_target="$BACKUP_DIR/${label}.symlink"
            if dry_run_enabled; then
                log_info "Would back up existing symlink: $target -> $backup_target"
            else
                mkdir -p "$(dirname "$backup_target")"
                printf '%s\n' "$current" > "$backup_target"
                log_info "Backed up existing symlink: $target"
            fi
        fi
        run_cmd rm -f "$target"
    elif [[ -e "$target" ]]; then
        if [[ "$DOTFILES_LINK_MODE" == "safe" ]]; then
            log_warn "Target exists, skipping: $target"
            return 0
        fi
        if [[ "$DOTFILES_LINK_MODE" == "migrate" ]]; then
            local backup_target="$BACKUP_DIR/$label"
            if dry_run_enabled; then
                log_info "Would back up existing target: $target -> $backup_target"
            else
                mkdir -p "$(dirname "$backup_target")"
                cp -R "$target" "$backup_target"
                log_info "Backed up existing target: $target"
            fi
        fi
        run_cmd rm -rf "$target"
    fi

    run_cmd ln -s "$source" "$target"
    log_info "Linked: $target -> $source"
}

link_dotfiles() {
    log_step "Linking dotfiles (mode: $DOTFILES_LINK_MODE)..."

    link_item "$DOTFILES_WORKTREE/.zshrc" "$HOME/.zshrc" ".zshrc"
    link_item "$DOTFILES_WORKTREE/.zprofile" "$HOME/.zprofile" ".zprofile"
    link_item "$DOTFILES_WORKTREE/.config/starship.toml" "$HOME/.config/starship.toml" ".config/starship.toml"
    link_item "$DOTFILES_WORKTREE/.config/mise/config.toml" "$HOME/.config/mise/config.toml" ".config/mise/config.toml"
    link_item "$DOTFILES_WORKTREE/.config/ghostty/config" "$HOME/.config/ghostty/config" ".config/ghostty/config"
    link_item "$DOTFILES_WORKTREE/.config/fastfetch/config.jsonc" "$HOME/.config/fastfetch/config.jsonc" ".config/fastfetch/config.jsonc"
    link_item "$DOTFILES_WORKTREE/.config/fastfetch/mcrn_logo.txt" "$HOME/.config/fastfetch/mcrn_logo.txt" ".config/fastfetch/mcrn_logo.txt"
    link_item "$DOTFILES_WORKTREE/.config/ghostty/config" "$HOME/Library/Application Support/com.mitchellh.ghostty/config" "Library/Application Support/com.mitchellh.ghostty/config"
}

# ============================================================================
# INSTALL HOMEBREW
# ============================================================================
install_homebrew() {
    log_step "Checking Homebrew..."
    
    if resolve_brew_bin; then
        log_info "Homebrew already installed"
        eval "$("$BREW_BIN" shellenv)"
        return 0
    fi
    
    log_info "Installing Homebrew..."
    if dry_run_enabled; then
        log_info "Would install Homebrew from official installer"
        return 0
    fi

    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    if ! resolve_brew_bin; then
        log_error "Homebrew installed but brew not found on PATH. Open a new shell and re-run."
        exit 1
    fi

    # Add to PATH for current session
    eval "$("$BREW_BIN" shellenv)"
    
    log_info "Homebrew installed successfully"
}

# ============================================================================
# SETUP BARE REPO
# ============================================================================
setup_bare_repo() {
    log_step "Setting up dotfiles repository..."

    if [[ -d "$DOTFILES_WORKTREE/.git" ]]; then
        log_info "Repo already exists at $DOTFILES_WORKTREE"
    else
        ensure_parent_dir "$DOTFILES_WORKTREE"
        log_info "Cloning repository into $DOTFILES_WORKTREE"
        run_cmd git clone "$DOTFILES_REPO" "$DOTFILES_WORKTREE"
    fi

    if ! git config --global alias.dotfiles &>/dev/null; then
        run_cmd git config --global alias.dotfiles "!git -C \"$DOTFILES_WORKTREE\""
        log_info "Created 'dotfiles' alias"
    fi

    log_info "Repository ready"
}

# ============================================================================
# INSTALL DEPENDENCIES
# ============================================================================
install_dependencies() {
    log_step "Installing Homebrew dependencies..."

    log_info "Running brew bundle..."
    if ! resolve_brew_bin; then
        log_error "Homebrew not available. Aborting dependency install."
        exit 1
    fi

    local brewfiles=("$DOTFILES_ROOT/Brewfile")
    if [[ "$DOTFILES_INSTALL_DEV" == "1" && -f "$DOTFILES_ROOT/Brewfile.dev" ]]; then
        brewfiles+=("$DOTFILES_ROOT/Brewfile.dev")
    fi
    if [[ "$DOTFILES_INSTALL_WORKSTATION" == "1" && -f "$DOTFILES_ROOT/Brewfile.workstation" ]]; then
        brewfiles+=("$DOTFILES_ROOT/Brewfile.workstation")
    fi

    local brewfile
    for brewfile in "${brewfiles[@]}"; do
        if [[ ! -f "$brewfile" ]]; then
            log_warn "Brewfile not found at $brewfile"
            continue
        fi

        if dry_run_enabled; then
            run_cmd "$BREW_BIN" bundle install --file="$brewfile"
        else
            "$BREW_BIN" bundle install --file="$brewfile"
        fi
    done

    log_info "Dependencies installed"
}

# ============================================================================
# INITIALIZE TOOLS
# ============================================================================
initialize_tools() {
    log_step "Initializing tools..."
    
    # Initialize mise (Toolchain manager)
    if command -v mise &>/dev/null; then
        log_info "Setting up mise global toolchain..."
        if [[ -f "$DOTFILES_ROOT/scripts/migrate-to-mise.sh" ]]; then
            log_info "Reconciling Homebrew runtime overlap with mise..."
            DOTFILES_DIR="$DOTFILES_WORKTREE" DOTFILES_DRY_RUN="$DOTFILES_DRY_RUN" \
                bash "$DOTFILES_ROOT/scripts/migrate-to-mise.sh"
        else
            if dry_run_enabled; then
                DOTFILES_DIR="$DOTFILES_WORKTREE" DOTFILES_DRY_RUN=1 run_cmd mise install
            else
                DOTFILES_DIR="$DOTFILES_WORKTREE" mise install
            fi
        fi
    fi
    
    # Initialize zoxide
    if command -v zoxide &>/dev/null; then
        log_info "zoxide ready"
    fi
    
    # Initialize fzf
    if [[ -f "$HOMEBREW_PREFIX/opt/fzf/install" ]]; then
        log_info "Setting up fzf..."
        if dry_run_enabled; then
            run_cmd "$HOMEBREW_PREFIX/opt/fzf/install" --all --no-bash --no-fish --no-update-rc
        else
            "$HOMEBREW_PREFIX/opt/fzf/install" --all --no-bash --no-fish --no-update-rc 2>/dev/null || true
        fi
    fi
    
    # Make scripts executable
    if dry_run_enabled; then
        run_shell "chmod +x \"$DOTFILES_ROOT/scripts/\"*.sh"
    else
        chmod +x "$DOTFILES_ROOT/scripts/"*.sh 2>/dev/null || true
    fi
    
    log_info "Tools initialized"
}

# ============================================================================
# CREATE LOCAL CONFIG TEMPLATE
# ============================================================================
create_local_config() {
    log_step "Creating local configuration template..."
    
    if [[ ! -f "$HOME/.zshrc.local" ]]; then
        if dry_run_enabled; then
            log_info "Would create ~/.zshrc.local template"
            return 0
        fi

        cat > "$HOME/.zshrc.local" << 'EOF'
# ~/.zshrc.local - Local overrides (not tracked in git)
# Add your machine-specific settings here

# Example: env overrides that should stay local
# export MCRN_COPILOT_MODEL="gpt-5-mini"

# Example: varlock fallback values (prefer 1Password ENV + varlock first)
# export MY_API_KEY="..."

# Example: Custom PATH additions
# export PATH="$HOME/custom/bin:$PATH"

# Example: Aliases specific to this machine
# alias work-project="cd ~/Work/some-project"

# Example: Set default browser
# export BROWSER="arc"
EOF
        log_info "Created ~/.zshrc.local template"
    fi
}

apply_macos_defaults() {
    if ! apply_macos_defaults_enabled; then
        return 0
    fi

    log_step "Applying macOS defaults..."

    local screenshot_dir="$HOME/Pictures/Screenshots"
    run_cmd mkdir -p "$screenshot_dir"
    run_cmd defaults write NSGlobalDomain AppleShowAllExtensions -bool true
    run_cmd defaults write com.apple.finder ShowPathbar -bool true
    run_cmd defaults write com.apple.finder ShowStatusBar -bool true
    run_cmd defaults write com.apple.finder FXPreferredViewStyle -string Nlsv
    run_cmd defaults write com.apple.finder _FXSortFoldersFirst -bool true
    run_cmd defaults write com.apple.dock show-recents -bool false
    run_cmd defaults write com.apple.screencapture type -string png
    run_cmd defaults write com.apple.screencapture location -string "$screenshot_dir"

    if dry_run_enabled; then
        log_info "Would restart Finder, Dock, and SystemUIServer"
        return 0
    fi

    killall Finder >/dev/null 2>&1 || true
    killall Dock >/dev/null 2>&1 || true
    killall SystemUIServer >/dev/null 2>&1 || true
    log_info "macOS defaults applied"
}

apply_dock_layout() {
    if ! apply_dock_enabled; then
        return 0
    fi

    log_step "Applying Dock layout..."
    ensure_dockutil

    local dock_apps=(
        "/System/Applications/Calendar.app"
        "/Applications/1Password.app"
        "/Applications/Dia.app"
        "/Applications/Ghostty.app"
        "/Applications/Zed.app"
    )
    local app_path

    run_cmd dockutil --no-restart --remove all
    for app_path in "${dock_apps[@]}"; do
        if [[ -e "$app_path" ]]; then
            run_cmd dockutil --no-restart --add "$app_path"
        else
            log_warn "Dock app missing, skipping: $app_path"
        fi
    done

    if dry_run_enabled; then
        log_info "Would restart Dock"
        return 0
    fi

    killall Dock >/dev/null 2>&1 || true
    log_info "Dock layout applied"
}

# ============================================================================
# CHECK 1PASSWORD
# ============================================================================
check_1password() {
    log_step "Checking 1Password CLI..."
    
    if ! command -v op &>/dev/null; then
        log_warn "1Password CLI not found"
        return 0
    fi
    
    # Check if configured (macOS doesn't ship GNU timeout; use perl alarm fallback)
    if perl -e 'alarm shift; exec @ARGV' 5 op account list &>/dev/null; then
        log_info "1Password CLI configured"
        return 0
    fi

    echo ""
    log_warn "1Password CLI installed but not configured"
    echo ""
    echo "To set up 1Password, run:"
    echo "  op account add"
    echo ""
}

check_varlock() {
    log_step "Checking varlock..."

    if command -v varlock &>/dev/null; then
        log_info "varlock installed"
        return 0
    fi

    log_warn "varlock not found"
    echo "Install the developer bundle to get varlock:"
    echo "  DOTFILES_INSTALL_DEV=1 $HOME/.dotfiles/scripts/install.sh"
    echo ""
}

# ============================================================================
# PRINT POST-INSTALL CHECKLIST
# ============================================================================
print_post_install() {
    echo ""
    echo "========================================"
    echo "  Installation Complete!"
    echo "========================================"
    echo ""
    echo "Next steps:"
    echo ""
    echo "1. Restart your terminal or run:"
    echo "   exec zsh"
    echo ""
    echo "2. Configure Git (if not already done):"
    echo "   gh auth login"
    echo "   $HOME/.dotfiles/scripts/setup-git.sh"
    echo ""
    echo "3. Verify GitHub Copilot access in your terminal session."
    echo ""
    echo "4. Set up 1Password (optional):"
    echo "   op account add"
    echo ""
    echo "5. Set up ENV-backed varlock secrets (optional):"
    echo "   op vault get ENV >/dev/null 2>&1 || op vault create ENV"
    echo "   vopencode"
    echo ""
    echo "6. Refresh quotes weekly:"
    echo "   $HOME/.dotfiles/scripts/refresh-quotes.sh"
    echo ""
    echo "7. Test your setup:"
    echo "   - Press Ctrl+G and type a command description"
    echo "   - Press Ctrl+R for fuzzy history search"
    echo "   - Type 'z <directory>' to jump around"
    echo "   - Type 'ls' to see eza in action"
    echo ""
    if dry_run_enabled; then
        echo "Dry-run mode: no changes were applied."
        echo "Planned backup location: $BACKUP_DIR"
    else
        echo "Backups saved to: $BACKUP_DIR"
    fi
    echo ""
    echo "Happy hacking."
    echo ""
}

# ============================================================================
# MAIN
# ============================================================================
main() {
    echo "========================================"
    echo "  Dotfiles Bootstrap - MCRN Tactical"
    echo "========================================"
    echo ""
    
    check_prerequisites
    show_migration_notice
    backup_configs
    install_homebrew
    setup_bare_repo
    link_dotfiles
    install_dependencies
    initialize_tools
    ensure_mcrn_ai_dependencies
    create_local_config
    apply_macos_defaults
    apply_dock_layout
    check_1password
    check_varlock
    print_post_install
}

main
