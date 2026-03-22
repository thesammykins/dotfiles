#!/bin/bash

set -euo pipefail

DIA_ROOT="${DIA_ROOT:-$HOME/Library/Application Support/Dia}"
DIA_USER_DATA="${DIA_USER_DATA:-$DIA_ROOT/User Data}"
DIA_BACKUP_ROOT="${DOTFILES_BROWSER_BACKUP_DIR:-$HOME/.dotfiles.backup/browser-profiles}"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP_DIR="$DIA_BACKUP_ROOT/dia-$TIMESTAMP"

log() {
    printf '[INFO] %s\n' "$1"
}

warn() {
    printf '[WARN] %s\n' "$1" >&2
}

if [[ ! -d "$DIA_USER_DATA" ]]; then
    warn "Dia profile not found at: $DIA_USER_DATA"
    exit 1
fi

mkdir -p "$BACKUP_DIR"

log "Backing up Dia profile to $BACKUP_DIR"

rsync -a \
    --delete \
    --exclude '*/Cache/***' \
    --exclude '*/Code Cache/***' \
    --exclude '*/GPUCache/***' \
    --exclude '*/ShaderCache/***' \
    --exclude '*/Service Worker/CacheStorage/***' \
    --exclude 'Crashpad/***' \
    --exclude 'Singleton*' \
    "$DIA_USER_DATA/" "$BACKUP_DIR/User Data/"

if [[ -f "$DIA_ROOT/StorableProfileContainers.json" ]]; then
    cp "$DIA_ROOT/StorableProfileContainers.json" "$BACKUP_DIR/"
fi

if [[ -f "$DIA_ROOT/StorableAutoArchive.json" ]]; then
    cp "$DIA_ROOT/StorableAutoArchive.json" "$BACKUP_DIR/"
fi

log "Dia backup complete"
printf '%s\n' "$BACKUP_DIR"
