#!/bin/bash
# test.sh - Test Dotfiles configuration

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"

log_step() { echo -e "\033[0;34m[STEP]\033[0m $1"; }
log_info() { echo -e "\033[0;32m[INFO]\033[0m $1"; }

log_step "Running ShellCheck on bash scripts..."
if command -v shellcheck &>/dev/null; then
    shellcheck "$REPO_ROOT"/bootstrap "$REPO_ROOT"/scripts/*.sh
    log_info "ShellCheck passed."
else
    echo "ShellCheck not found, skipping."
fi

log_step "Running zsh syntax checks..."
if command -v zsh &>/dev/null; then
    zsh -n "$REPO_ROOT/.zshrc" "$REPO_ROOT/.zprofile" "$REPO_ROOT/zsh/plugins/mcrn-ai.zsh"
    log_info "zsh syntax checks passed."
else
    echo "zsh not found, skipping."
fi

log_step "Checking MCRN AI npm dependency health..."
if command -v npm &>/dev/null; then
    (
        cd "$REPO_ROOT/zsh/plugins/mcrn-ai"
        npm ci --dry-run --no-audit --no-fund --loglevel=error >/dev/null
        # shellcheck disable=SC2016
        node -e 'const fs=require("node:fs"); const lock=JSON.parse(fs.readFileSync("package-lock.json","utf8")); const expected=lock.packages["node_modules/@github/copilot-sdk"].version; const actual=require("./node_modules/@github/copilot-sdk/package.json").version; if(actual!==expected){console.error(`copilot-sdk mismatch: expected ${expected}, got ${actual}`); process.exit(1);} '
    )
    log_info "MCRN AI dependency checks passed."
else
    echo "npm not found, skipping."
fi

log_step "Running Bats functional tests..."
if command -v bats &>/dev/null; then
    bats "$REPO_ROOT"/test/*.bats
    log_info "Bats tests passed."
else
    echo "Bats not found, skipping."
fi
