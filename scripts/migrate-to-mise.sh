#!/bin/bash
# Migrate runtime/toolchain management from Homebrew to mise.
# This script keeps Homebrew for system tooling and GUI apps, while moving dev runtimes to mise.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="${DOTFILES_DIR:-$(cd -- "$SCRIPT_DIR/.." && pwd)}"
MISE_CONFIG="${MISE_CONFIG:-$DOTFILES_DIR/.config/mise/config.toml}"
AUTO_UNINSTALL="${MISE_AUTO_UNINSTALL_BREW_RUNTIMES:-0}"
DOTFILES_DRY_RUN="${DOTFILES_DRY_RUN:-0}"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

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

load_runtime_formulas() {
  local formulas_file="$DOTFILES_DIR/scripts/runtime-formulas.txt"
  local line

  if [[ ! -f "$formulas_file" ]]; then
    log_error "runtime formulas file not found at: $formulas_file"
    exit 1
  fi

  RUNTIME_FORMULAS=()
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" =~ ^[[:space:]]*$ ]] && continue
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    RUNTIME_FORMULAS+=("$line")
  done < "$formulas_file"
}

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

   if dry_run_enabled; then
     log_warn "Dry-run mode enabled. Runtime changes will be reported but not applied."
   fi

  if [[ ! -f "$MISE_CONFIG" ]]; then
    log_error "mise config not found at: $MISE_CONFIG"
    exit 1
  fi

  log_step "Installing runtimes declared in mise config..."
  if dry_run_enabled; then
    run_cmd env MISE_GLOBAL_CONFIG_FILE="$MISE_CONFIG" mise install
  else
    MISE_GLOBAL_CONFIG_FILE="$MISE_CONFIG" mise install
  fi

  load_runtime_formulas

  if ! command -v brew &>/dev/null; then
    log_info "Homebrew not installed; runtime migration complete (mise-only environment)."
    return 0
  fi

  log_step "Checking for Homebrew runtime overlap with mise..."
  local installed installed_families
  installed="$(brew list --formula 2>/dev/null || true)"
  installed_families="$(printf '%s\n' "$installed" | sed 's/@.*$//' | sort -u)"

  local overlaps=()
  local formula
  for formula in "${RUNTIME_FORMULAS[@]}"; do
    if printf '%s\n' "$installed_families" | grep -Fxq "${formula%@*}"; then
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
    if run_cmd brew uninstall "${overlaps[@]}"; then
      log_info "Requested Homebrew runtime uninstall complete."
    else
      log_warn "Some formulas may remain if Homebrew reports dependency conflicts. Resolve manually with 'brew uninstall --ignore-dependencies ...' if needed."
    fi
  else
    log_warn "No changes made. To uninstall overlaps automatically, rerun with:"
    echo "  MISE_AUTO_UNINSTALL_BREW_RUNTIMES=1 DOTFILES_DRY_RUN=$DOTFILES_DRY_RUN $DOTFILES_DIR/scripts/migrate-to-mise.sh"
  fi

  log_step "Runtime migration check complete."
}

main "$@"
