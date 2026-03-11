#!/bin/bash
# Restore dotfiles from a backup directory

set -euo pipefail

BACKUP_DIR="${1:-$HOME/.dotfiles.backup}"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

usage() {
    echo "Usage: $0 /path/to/backup"
    echo "If omitted, uses the most recent backup under ~/.dotfiles.backup."
}

resolve_backup_dir() {
    local root="$BACKUP_DIR"
    if [[ ! -d "$root" ]]; then
        return 1
    fi

    if [[ -e "$root/.zshrc" || -e "$root/.zshrc.symlink" ]]; then
        return 0
    fi

    local latest
    latest=$(ls -1dt "$root"/* 2>/dev/null | head -n 1)
    if [[ -n "$latest" && -d "$latest" ]]; then
        BACKUP_DIR="$latest"
        return 0
    fi

    return 1
}

restore_item() {
    local relative="$1"
    local source="$BACKUP_DIR/$relative"
    local target="$HOME/$relative"

    if [[ -f "${source}.symlink" ]]; then
        local link_target
        link_target=$(cat "${source}.symlink")
        mkdir -p "$(dirname "$target")"
        if [[ -e "$target" || -L "$target" ]]; then
            rm -rf "$target"
        fi
        ln -s "$link_target" "$target"
        log_info "Restored symlink: $relative"
        return 0
    fi

    if [[ ! -e "$source" ]]; then
        return 0
    fi

    mkdir -p "$(dirname "$target")"
    if [[ -e "$target" || -L "$target" ]]; then
        rm -rf "$target"
    fi
    cp -R "$source" "$target"
    log_info "Restored: $relative"
}

main() {
    if [[ -z "$BACKUP_DIR" ]]; then
        log_error "Backup directory required."
        usage
        exit 1
    fi

    if ! resolve_backup_dir; then
        log_error "Backup directory not found or empty: $BACKUP_DIR"
        exit 1
    fi

    log_step "Restoring dotfiles from $BACKUP_DIR"

    restore_item ".zshrc"
    restore_item ".zprofile"
    restore_item ".tmux.conf"
    restore_item ".zsh_aliases"
    restore_item "Library/Application Support/com.mitchellh.ghostty/config"
    restore_item ".config/ghostty/config"
    restore_item ".config/starship.toml"
    restore_item ".config/mise/config.toml"
    restore_item ".config/fastfetch/config.jsonc"
    restore_item ".config/fastfetch/mcrn_logo.txt"
    restore_item ".config/opencode"

    log_info "Restore complete."
}

main
