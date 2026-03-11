#!/bin/bash
# Migrate runtime/toolchain management from Homebrew to mise.
# This script keeps Homebrew for system tooling and GUI apps, while moving dev runtimes to mise.

set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/Development/dotfiles}"
MISE_CONFIG="${MISE_CONFIG:-$DOTFILES_DIR/.config/mise/config.toml}"
AUTO_UNINSTALL="${MISE_AUTO_UNINSTALL_BREW_RUNTIMES:-0}"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" &>/dev/null; then
    log_error "Required command not found: $cmd"
    exit 1
  fi
}

main() {
  log_step "Validating runtime migration prerequisites..."
  require_cmd mise

  if [[ ! -f "$MISE_CONFIG" ]]; then
    log_error "mise config not found at: $MISE_CONFIG"
    exit 1
  fi

  log_step "Installing runtimes declared in mise config..."
  mise install

  # Runtime formulas to migrate away from Homebrew.
  # Keep Homebrew for system tools/casks; use mise for runtimes.
  local runtime_formulas=(
    node
    python
    python@3
    go
    openjdk
    temurin
    terraform
    gradle
    dotnet
    asdf
    fnm
    pyenv
    rbenv
  )

  if ! command -v brew &>/dev/null; then
    log_info "Homebrew not installed; runtime migration complete (mise-only environment)."
    return 0
  fi

  log_step "Checking for Homebrew runtime overlap with mise..."
  local installed
  installed="$(brew list --formula 2>/dev/null || true)"

  local overlaps=()
  local formula
  for formula in "${runtime_formulas[@]}"; do
    if echo "$installed" | grep -Fxq "$formula"; then
      overlaps+=("$formula")
    fi
  done

  if [[ "${#overlaps[@]}" -eq 0 ]]; then
    log_info "No overlapping Homebrew-managed runtimes detected."
    return 0
  fi

  log_warn "Detected Homebrew runtime formulas that should be managed by mise: ${overlaps[*]}"

  if [[ "$AUTO_UNINSTALL" == "1" ]]; then
    log_step "Uninstalling overlapping runtime formulas from Homebrew..."
    brew uninstall "${overlaps[@]}" || true
    log_info "Requested Homebrew runtime uninstall complete."
  else
    log_warn "No changes made. To uninstall overlaps automatically, rerun with:"
    echo "  MISE_AUTO_UNINSTALL_BREW_RUNTIMES=1 $DOTFILES_DIR/.dotfiles/scripts/migrate-to-mise.sh"
  fi

  log_step "Runtime migration check complete."
}

main "$@"
