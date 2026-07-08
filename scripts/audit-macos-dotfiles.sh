#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${DOTFILES_REPO_ROOT:-$(cd -- "$SCRIPT_DIR/.." && pwd)}"

warn() { echo "[WARN] $*"; }
ok() { echo "[OK]   $*"; }

check_file() {
    local file="$1"
    if [[ -f "$REPO_ROOT/$file" ]]; then
        ok "$file exists"
    else
        warn "$file is missing"
    fi
}

check_shell_contract() {
    printf '\n== Shell contract ==\n'

    check_file ".zshrc"
    check_file ".zprofile"
    check_file ".config/starship.toml"
    check_file ".config/mise/config.toml"

    if rg -n 'source ".*\.zshrc"' "$REPO_ROOT/.zprofile" >/dev/null 2>&1; then
        warn ".zprofile sources .zshrc; login shells may double-load shell init"
    else
        ok ".zprofile does not source .zshrc"
    fi

    if rg -n '\$HOME/Development/dotfiles' "$REPO_ROOT/.zshrc" >/dev/null 2>&1; then
        ok ".zshrc uses canonical dotfiles path"
    else
        warn ".zshrc does not mention canonical dotfiles path"
    fi
}

check_brewfiles() {
    printf '\n== Brewfiles ==\n'

    check_file "Brewfile"
    check_file "Brewfile.dev"
    check_file "Brewfile.workstation"
}

check_mise() {
    printf '\n== mise ==\n'

    if rg -n '=[[:space:]]*"(latest|lts)"' "$REPO_ROOT/.config/mise/config.toml" >/dev/null 2>&1; then
        warn "mise config uses floating versions"
    else
        ok "mise config appears pinned"
    fi
}

pathway() {
    cat <<'TXT'

== Setup pathway ==
1. Clone thesammykins/new-mac on a fresh Mac.
2. Run mise run plan -- --profile personal --dry-run.
3. Let new-mac install Homebrew tiers, dotfiles, skills, and plugins.
4. Keep machine-only edits in ~/.zshrc.local.
TXT
}

check_shell_contract
check_brewfiles
check_mise
pathway
