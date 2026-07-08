#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"

log_step() { echo -e "\033[0;34m[STEP]\033[0m $1"; }
log_info() { echo -e "\033[0;32m[INFO]\033[0m $1"; }

log_step "Running ShellCheck on scripts..."
if command -v shellcheck >/dev/null 2>&1; then
    shellcheck "$REPO_ROOT"/scripts/*.sh
    log_info "ShellCheck passed."
else
    echo "ShellCheck not found, skipping."
fi

log_step "Running zsh syntax checks..."
if command -v zsh >/dev/null 2>&1; then
    zsh -n "$REPO_ROOT/.zshrc" "$REPO_ROOT/.zprofile"
    log_info "zsh syntax checks passed."
else
    echo "zsh not found, skipping."
fi

log_step "Running Bats tests..."
if command -v bats >/dev/null 2>&1; then
    bats "$REPO_ROOT"/test/*.bats
    log_info "Bats tests passed."
else
    echo "Bats not found, skipping."
fi
