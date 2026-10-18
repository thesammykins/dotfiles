#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"

log_step() { echo -e "\033[0;34m[STEP]\033[0m $1"; }
log_info() { echo -e "\033[0;32m[INFO]\033[0m $1"; }

# A check that skips its tools would pass while testing nothing. Set
# DOTFILES_ALLOW_MISSING_TOOLS=1 only on machines that lack the dev tier.
missing_tool() {
    if [[ "${DOTFILES_ALLOW_MISSING_TOOLS:-0}" == "1" ]]; then
        echo "$1 not found; skipped because DOTFILES_ALLOW_MISSING_TOOLS=1."
    else
        echo "$1 not found. Install the dev Brewfile tier, or set DOTFILES_ALLOW_MISSING_TOOLS=1." >&2
        exit 1
    fi
}

# A fresh Mac runs these scripts with /bin/bash 3.2, not Homebrew's bash.
log_step "Checking scripts parse under /bin/bash..."
for script in "$REPO_ROOT"/scripts/*.sh; do
    /bin/bash -n "$script"
done
log_info "All scripts parse under $(/bin/bash -c 'echo "$BASH_VERSION"')."

log_step "Running ShellCheck on scripts..."
if command -v shellcheck >/dev/null 2>&1; then
    shellcheck "$REPO_ROOT"/scripts/*.sh
    log_info "ShellCheck passed."
else
    missing_tool shellcheck
fi

log_step "Running zsh syntax checks..."
if command -v zsh >/dev/null 2>&1; then
    zsh -n "$REPO_ROOT/.zshrc" "$REPO_ROOT/.zprofile"
    log_info "zsh syntax checks passed."
else
    echo "zsh not found, skipping."
fi

# The bats tests search files with ripgrep.
command -v rg >/dev/null 2>&1 || missing_tool rg

log_step "Running Bats tests..."
if command -v bats >/dev/null 2>&1; then
    bats "$REPO_ROOT"/test/*.bats
    log_info "Bats tests passed."
else
    missing_tool bats
fi
