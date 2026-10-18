#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${DOTFILES_REPO_ROOT:-$(cd -- "$SCRIPT_DIR/.." && pwd)}"
MANAGED_PATHS_FILE="$SCRIPT_DIR/managed-paths.txt"

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
    check_file "scripts/managed-paths.txt"

    if [[ -f "$MANAGED_PATHS_FILE" ]]; then
        local relative
        while IFS= read -r relative || [[ -n "$relative" ]]; do
            [[ -n "$relative" ]] || continue
            check_file "$relative"
        done < "$MANAGED_PATHS_FILE"
    fi

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

    # Claude Code is the one allowed global tool; runtimes belong in projects.
    local global_tools
    global_tools="$(awk '/^\[/ { section = $0; next }
        section == "[tools]" && NF && $0 !~ /^[[:space:]]*#/ { print $1 }' \
        "$REPO_ROOT/.config/mise/config.toml" | grep -vx 'claude' || true)"
    if [[ -n "$global_tools" ]]; then
        warn "global mise config declares tools other than claude: ${global_tools//$'\n'/ }"
    else
        ok "global mise config contains settings and claude only"
    fi
}

pathway() {
    cat <<'TXT'

== Setup pathway ==
1. Clone thesammykins/new-mac on a fresh Mac.
2. Run ./setup.sh and choose the guided profile.
3. Keep machine-only edits in ~/.zshrc.local.
TXT
}

check_shell_contract
check_brewfiles
check_mise
pathway
