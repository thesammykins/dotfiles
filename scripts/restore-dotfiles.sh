#!/usr/bin/env bash
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

    [[ -d "$root" ]] || return 1

    if [[ -e "$root/.zshrc" || -e "$root/.zshrc.symlink" ]]; then
        return 0
    fi

    local latest
    latest="$(find "$root" -mindepth 1 -maxdepth 1 -type d -print 2>/dev/null | sort -r | head -n 1)"
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
    local link_target

    if [[ -f "${source}.symlink" ]]; then
        link_target="$(cat "${source}.symlink")"
        mkdir -p "$(dirname "$target")"
        rm -rf "$target"
        ln -s "$link_target" "$target"
        log_info "Restored symlink: $relative"
        return 0
    fi

    [[ -e "$source" ]] || return 0

    mkdir -p "$(dirname "$target")"
    rm -rf "$target"
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
    restore_item ".config/starship.toml"
    restore_item ".config/mise/config.toml"
    restore_item ".config/atuin/config.toml"
    restore_item ".config/varlock/.env.schema"
    restore_item ".agents/AGENTS.md"
    restore_item ".agents/GEMINI.md"

    log_info "Restore complete."
}

main "$@"
