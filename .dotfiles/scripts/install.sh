#!/bin/bash
# Dotfiles Bootstrap Script - MCRN Tactical
# One-command setup for Ghostty + zsh + modern CLI stack

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================
DOTFILES_REPO="https://github.com/sammykins/dotfiles.git"
DOTFILES_WORKTREE="${DOTFILES_WORKTREE:-$HOME/Development/dotfiles}"
DOTFILES_CLOUD_BACKUP="${DOTFILES_CLOUD_BACKUP:-0}"
BACKUP_DIR="$HOME/.dotfiles.backup/$(date +%Y%m%d_%H%M%S)"
SKIP_MODEL_DOWNLOAD="${SKIP_MODEL_DOWNLOAD:-0}"
DOTFILES_LINK_MODE="${DOTFILES_LINK_MODE:-safe}"
DOTFILES_ROOT="${DOTFILES_ROOT:-$HOME/.dotfiles}"

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
    
    log_info "Prerequisites OK"
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

# ============================================================================
# RESOLVE DOTFILES ROOT
# ============================================================================
resolve_dotfiles_root() {
    if [[ -f "$HOME/.dotfiles/Brewfile" ]]; then
        DOTFILES_ROOT="$HOME/.dotfiles"
        return 0
    fi

    if [[ -f "$DOTFILES_WORKTREE/.dotfiles/Brewfile" ]]; then
        DOTFILES_ROOT="$DOTFILES_WORKTREE/.dotfiles"
        log_warn "Using repo dotfiles root at $DOTFILES_ROOT"
        return 0
    fi

    DOTFILES_ROOT="$HOME/.dotfiles"
    log_warn "Unable to locate Brewfile; using $DOTFILES_ROOT"
}

# ============================================================================
# BACKUP EXISTING CONFIGS
# ============================================================================
backup_configs() {
    log_step "Backing up existing configurations..."
    
    mkdir -p "$BACKUP_DIR"
    
    # Files to backup
    local files=(
        ".zshrc"
        ".zprofile"
        ".tmux.conf"
        ".zsh_aliases"
        "Library/Application Support/com.mitchellh.ghostty/config"
        ".config/ghostty/config"
        ".config/starship.toml"
        ".config/mise/config.toml"
        ".config/fastfetch/config.jsonc"
        ".config/fastfetch/mcrn_logo.txt"
        ".config/opencode"
    )
    
    for file in "${files[@]}"; do
        local src="$HOME/$file"
        if [[ -e "$src" && ! -L "$src" ]]; then
            local dest="$BACKUP_DIR/$file"
            mkdir -p "$(dirname "$dest")"
            cp -R "$src" "$dest"
            log_info "Backed up: $file"
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
            cp -R "$BACKUP_DIR" "$cloud_target" 2>/dev/null || true
            log_info "iCloud backup saved to: $cloud_target"
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

    if [[ ! -e "$source" ]]; then
        log_warn "Source missing: $source"
        return 0
    fi

    mkdir -p "$(dirname "$target")"

    if [[ -L "$target" ]]; then
        local current
        current="$(readlink "$target")"
        if [[ "$current" == "$source" ]]; then
            log_info "Link already set: $target"
            return 0
        fi
        if [[ "$DOTFILES_LINK_MODE" != "force" ]]; then
            log_warn "Link differs, skipping: $target"
            return 0
        fi
        rm -f "$target"
    elif [[ -e "$target" ]]; then
        if [[ "$DOTFILES_LINK_MODE" != "force" ]]; then
            log_warn "Target exists, skipping: $target"
            return 0
        fi
        rm -rf "$target"
    fi

    ln -s "$source" "$target"
    log_info "Linked: $target -> $source"
}

link_dotfiles() {
    log_step "Linking dotfiles (mode: $DOTFILES_LINK_MODE)..."

    link_item "$DOTFILES_WORKTREE/.dotfiles" "$HOME/.dotfiles"
    link_item "$DOTFILES_WORKTREE/.zshrc" "$HOME/.zshrc"
    link_item "$DOTFILES_WORKTREE/.zprofile" "$HOME/.zprofile"
    link_item "$DOTFILES_WORKTREE/.tmux.conf" "$HOME/.tmux.conf"
    link_item "$DOTFILES_WORKTREE/.config/starship.toml" "$HOME/.config/starship.toml"
    link_item "$DOTFILES_WORKTREE/.config/mise/config.toml" "$HOME/.config/mise/config.toml"
    link_item "$DOTFILES_WORKTREE/.config/ghostty/config" "$HOME/.config/ghostty/config"
    link_item "$DOTFILES_WORKTREE/.config/fastfetch/config.jsonc" "$HOME/.config/fastfetch/config.jsonc"
    link_item "$DOTFILES_WORKTREE/.config/fastfetch/mcrn_logo.txt" "$HOME/.config/fastfetch/mcrn_logo.txt"
    link_item "$DOTFILES_WORKTREE/.config/ghostty/config" "$HOME/Library/Application Support/com.mitchellh.ghostty/config"
}

# ============================================================================
# INSTALL HOMEBREW
# ============================================================================
install_homebrew() {
    log_step "Checking Homebrew..."
    
    if command -v brew &>/dev/null; then
        log_info "Homebrew already installed"
        eval "$(brew shellenv)"
        return 0
    fi
    
    log_info "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # Add to PATH for current session
    eval "$(brew shellenv)"
    
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
        log_info "Cloning repository into $DOTFILES_WORKTREE"
        git clone "$DOTFILES_REPO" "$DOTFILES_WORKTREE"
    fi

    if ! git config --global alias.dotfiles &>/dev/null; then
        git config --global alias.dotfiles "!git -C \"$DOTFILES_WORKTREE\""
        log_info "Created 'dotfiles' alias"
    fi

    log_info "Repository ready"
}

# ============================================================================
# INSTALL DEPENDENCIES
# ============================================================================
install_dependencies() {
    log_step "Installing Homebrew dependencies..."
    
    local brewfile="$DOTFILES_ROOT/Brewfile"
    
    if [[ ! -f "$brewfile" ]]; then
        log_warn "Brewfile not found at $brewfile"
        return 0
    fi
    
    log_info "Running brew bundle..."
    brew bundle install --file="$brewfile"
    
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
        mise install
    fi
    
    # Initialize zoxide
    if command -v zoxide &>/dev/null; then
        log_info "zoxide ready"
    fi
    
    # Initialize fzf
    if [[ -f "$HOMEBREW_PREFIX/opt/fzf/install" ]]; then
        log_info "Setting up fzf..."
        "$HOMEBREW_PREFIX/opt/fzf/install" --all --no-bash --no-fish --no-update-rc 2>/dev/null || true
    fi
    
    # Make scripts executable
    chmod +x "$DOTFILES_ROOT/scripts/"*.sh 2>/dev/null || true
    
    log_info "Tools initialized"
}

# ============================================================================
# SETUP MCRN TACTICAL AI (Local LLM)
# ============================================================================
setup_mcrn_ai() {
    log_step "Setting up MCRN Tactical AI (Local LLM)..."

    local llm_dir="$HOME/.cache/llm-models"
    local llm_file="qwen3-codersmall-q8_0.gguf"
    local llm_url="https://huggingface.co/echos-keeper/Qwen3-CoderSmall-Q8_0-GGUF/resolve/main/qwen3-codersmall-q8_0.gguf"

    mkdir -p "$llm_dir"

    if [[ ! -f "$llm_dir/$llm_file" ]]; then
        if [[ "$SKIP_MODEL_DOWNLOAD" == "1" ]]; then
            log_warn "Skipping model download (SKIP_MODEL_DOWNLOAD=1)"
            if command -v llama-server &>/dev/null; then
                log_info "llama-server is ready."
            else
                log_warn "llama-server not found. Ensure llama.cpp was installed via Brewfile."
            fi
            return 0
        fi
        log_info "Downloading Qwen3-CoderSmall model (approx 767MB)..."
        curl -L -o "$llm_dir/$llm_file" "$llm_url"
        log_info "Model downloaded successfully."
    else
        log_info "Model already exists at $llm_dir/$llm_file"
    fi

    if command -v llama-server &>/dev/null; then
        log_info "llama-server is ready."
    else
        log_warn "llama-server not found. Ensure llama.cpp was installed via Brewfile."
    fi
}

# ============================================================================
# CREATE LOCAL CONFIG TEMPLATE
# ============================================================================
create_local_config() {
    log_step "Creating local configuration template..."
    
    if [[ ! -f "$HOME/.zshrc.local" ]]; then
        cat > "$HOME/.zshrc.local" << 'EOF'
# ~/.zshrc.local - Local overrides (not tracked in git)
# Add your machine-specific settings here

# Example: API keys (use 1Password instead when possible)
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

# ============================================================================
# CHECK 1PASSWORD
# ============================================================================
check_1password() {
    log_step "Checking 1Password CLI..."
    
    if ! command -v op &>/dev/null; then
        log_warn "1Password CLI not found"
        return 0
    fi
    
    # Check if configured (with timeout)
    if timeout 5 op account list &>/dev/null 2>&1; then
        log_info "1Password CLI configured"
    else
        echo ""
        log_warn "1Password CLI installed but not configured"
        echo ""
        echo "To set up 1Password, run:"
        echo "  op account add"
        echo ""
    fi
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
    echo "3. Set up 1Password (optional):"
    echo "   op account add"
    echo ""
    echo "4. Refresh quotes weekly:"
    echo "   $HOME/.dotfiles/scripts/refresh-quotes.sh"
    echo ""
    echo "5. Test your setup:"
    echo "   - Press Ctrl+G and type a command description"
    echo "   - Press Ctrl+R for fuzzy history search"
    echo "   - Type 'z <directory>' to jump around"
    echo "   - Type 'ls' to see eza in action"
    echo ""
    echo "Backups saved to: $BACKUP_DIR"
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
    resolve_dotfiles_root
    install_dependencies
    setup_mcrn_ai
    initialize_tools
    create_local_config
    check_1password
    print_post_install
}

main
