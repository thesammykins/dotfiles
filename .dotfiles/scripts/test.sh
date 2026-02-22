#!/bin/bash
# test.sh - Test Dotfiles configuration

set -euo pipefail

log_step() { echo -e "\033[0;34m[STEP]\033[0m $1"; }
log_info() { echo -e "\033[0;32m[INFO]\033[0m $1"; }

log_step "Running ShellCheck on bash scripts..."
if command -v shellcheck &>/dev/null; then
    shellcheck "$HOME/.dotfiles/scripts/"*.sh
    log_info "ShellCheck passed."
else
    echo "ShellCheck not found, skipping."
fi

log_step "Running Bats functional tests..."
if command -v bats &>/dev/null; then
    bats "$HOME/Development/dotfiles/test/"*.bats
    log_info "Bats tests passed."
else
    echo "Bats not found, skipping."
fi
