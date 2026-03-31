#!/bin/bash

set -euo pipefail

SOURCE_DIR="${1:-}"
DIA_ROOT="${DIA_ROOT:-$HOME/Library/Application Support/Dia}"
DIA_USER_DATA="${DIA_USER_DATA:-$DIA_ROOT/User Data}"

log() {
    printf '[INFO] %s\n' "$1"
}

warn() {
    printf '[WARN] %s\n' "$1" >&2
}

usage() {
    printf 'Usage: %s /path/to/dia-backup\n' "$0"
}

if [[ -z "$SOURCE_DIR" ]]; then
    usage
    exit 1
fi

if [[ ! -d "$SOURCE_DIR/User Data" ]]; then
    warn "Expected Dia backup at $SOURCE_DIR/User Data"
    exit 1
fi

mkdir -p "$DIA_ROOT"
rm -rf "$DIA_USER_DATA"

log "Restoring Dia profile from $SOURCE_DIR"
rsync -a "$SOURCE_DIR/User Data/" "$DIA_USER_DATA/"

if [[ -f "$SOURCE_DIR/StorableProfileContainers.json" ]]; then
    cp "$SOURCE_DIR/StorableProfileContainers.json" "$DIA_ROOT/"
fi

if [[ -f "$SOURCE_DIR/StorableAutoArchive.json" ]]; then
    cp "$SOURCE_DIR/StorableAutoArchive.json" "$DIA_ROOT/"
fi

log "Dia restore complete"
