#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
VARLOCK_PATH="${VARLOCK_PATH:-$DOTFILES_ROOT/.config/varlock}"

if [[ $# -eq 0 ]]; then
    echo "Usage: $0 <command> [args...]" >&2
    exit 1
fi

exec varlock run --path "$VARLOCK_PATH" -- "$@"
