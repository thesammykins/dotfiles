#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
VARLOCK_PATH="${VARLOCK_PATH:-$DOTFILES_ROOT/.config/varlock}"

exec varlock run --no-redact-stdout --path "$VARLOCK_PATH" -- opencode "$@"
