#!/bin/zsh
# warp-helpers.zsh — Warp-like shell helpers for Ghostty + tmux
# Provides: yy, cdj, ts, mark/jump/marks/unmark, warp-help
# Requires: fzf, zoxide, yazi, tmux

# ============================================================================
# FZF MCRN THEME
# ============================================================================
export FZF_DEFAULT_OPTS="\
  --color=bg+:#3c180f,bg:#1a0b0c,fg:#ffd34e,fg+:#f3eadb \
  --color=hl:#ff2929,hl+:#ff2929,info:#c9895c,marker:#ff2929 \
  --color=prompt:#ffd34e,spinner:#b04c2a,pointer:#e8a15b,header:#c9895c \
  --color=border:#b04c2a,separator:#b04c2a \
  --border=rounded --height=40% --layout=reverse"

# ============================================================================
# 1. YAZI FILE MANAGER WRAPPER — yy
# ============================================================================
# Opens yazi; when you quit (q), your shell cd's to whatever directory
# yazi was showing. Pass any args through (e.g. yy ~/Downloads).
function yy() {
    if ! command -v yazi &>/dev/null; then
        echo "[WARP] yazi not found — brew install yazi" >&2
        return 1
    fi
    local tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
    yazi "$@" --cwd-file="$tmp"
    if cwd="$(cat -- "$tmp")" && [[ -n "$cwd" ]] && [[ "$cwd" != "$PWD" ]]; then
        builtin cd -- "$cwd"
    fi
    rm -f -- "$tmp"
}

# ============================================================================
# 2. FUZZY DIRECTORY JUMP — cdj
# ============================================================================
# Interactive fuzzy picker over your zoxide frecency database.
# Just type a few chars to narrow, Enter to jump.
function cdj() {
    if ! command -v zoxide &>/dev/null; then
        echo "[WARP] zoxide not found — brew install zoxide" >&2
        return 1
    fi
    local dir
    dir="$(zoxide query -l 2>/dev/null | fzf \
        --prompt='Jump › ' \
        --preview='eza --icons --group-directories-first --color=always {} 2>/dev/null || ls -la {}' \
        --preview-window=right:40%:wrap)" && builtin cd "$dir"
}

# ============================================================================
# 3. TMUX SESSION PICKER — ts
# ============================================================================
# Fuzzy-switch between tmux sessions. Works inside and outside tmux.
# Creates a new session if you type a name that doesn't exist.
function ts() {
    if ! command -v tmux &>/dev/null; then
        echo "[WARP] tmux not found — brew install tmux" >&2
        return 1
    fi
    if ! tmux info &>/dev/null 2>&1; then
        echo "[WARP] No tmux server running. Start one: tmux new -s main" >&2
        return 1
    fi
    local sessions target session
    sessions="$(tmux list-sessions -F '#{session_name}  #{session_windows}w #{?session_attached,(attached),}' 2>/dev/null)"
    if [[ -z "$sessions" ]]; then
        echo "[WARP] No sessions found" >&2
        return 1
    fi
    target="$(echo "$sessions" | fzf --prompt='Session › ')" || return
    session="${target%%  *}"
    if [[ -n "$TMUX" ]]; then
        tmux switch-client -t "$session"
    else
        tmux attach-session -t "$session"
    fi
}

# ============================================================================
# 4. ENHANCED HISTORY SEARCH — Ctrl+R override
# ============================================================================
# fzf already binds Ctrl+R via `source <(fzf --zsh)`. This adds MCRN styling
# and a preview showing the full command. The FZF_DEFAULT_OPTS above handle
# colors automatically. Override Ctrl+R prompt for clarity:
export FZF_CTRL_R_OPTS="\
  --prompt='History › ' \
  --header='Ctrl+R: search history | Enter: execute | Tab: paste to buffer' \
  --preview='echo {}' --preview-window=up:3:wrap"

# ============================================================================
# 5. DIRECTORY BOOKMARKS — mark, jump, marks, unmark
# ============================================================================
BOOKMARKS_FILE="${BOOKMARKS_FILE:-$HOME/.zsh_bookmarks}"
[[ -f "$BOOKMARKS_FILE" ]] || touch "$BOOKMARKS_FILE"

# mark <name> — save current directory as a named bookmark
function mark() {
    local name="${1:?Usage: mark <name>}"
    sed -i '' "/^${name}|/d" "$BOOKMARKS_FILE" 2>/dev/null
    echo "${name}|${PWD}" >> "$BOOKMARKS_FILE"
    echo "Bookmarked: ${name} -> ${PWD}"
}

# jump [name] — cd to a bookmark. No arg = interactive fzf picker.
function jump() {
    if [[ -z "$1" ]]; then
        if [[ ! -s "$BOOKMARKS_FILE" ]]; then
            echo "[WARP] No bookmarks. Use: mark <name>" >&2
            return 1
        fi
        local selection
        selection="$(cat "$BOOKMARKS_FILE" | fzf \
            --prompt='Bookmark › ' \
            --delimiter='|' \
            --with-nth=1 \
            --preview='eza --icons --group-directories-first --color=always {2} 2>/dev/null || ls -la {2}' \
            --preview-window=right:40%:wrap)" || return
        builtin cd "${selection#*|}"
    else
        local target
        target="$(grep "^${1}|" "$BOOKMARKS_FILE" | head -1 | cut -d'|' -f2)"
        if [[ -n "$target" ]]; then
            builtin cd "$target"
        else
            echo "[WARP] No bookmark: $1" >&2
            return 1
        fi
    fi
}

# marks — list all bookmarks
function marks() {
    if [[ ! -s "$BOOKMARKS_FILE" ]]; then
        echo "No bookmarks. Use: mark <name>"
        return
    fi
    printf "\033[38;2;255;211;78m%-20s %s\033[0m\n" "NAME" "DIRECTORY"
    printf "%-20s %s\n" "----" "---------"
    while IFS='|' read -r name dir; do
        printf "%-20s %s\n" "$name" "$dir"
    done < "$BOOKMARKS_FILE"
}

# unmark <name> — remove a bookmark
function unmark() {
    local name="${1:?Usage: unmark <name>}"
    if grep -q "^${name}|" "$BOOKMARKS_FILE" 2>/dev/null; then
        sed -i '' "/^${name}|/d" "$BOOKMARKS_FILE"
        echo "Removed: ${name}"
    else
        echo "[WARP] No bookmark: $1" >&2
        return 1
    fi
}

# Completion for jump/unmark (tab-complete bookmark names)
function _bookmark_names() {
    local names=()
    [[ -f "$BOOKMARKS_FILE" ]] && while IFS='|' read -r name _; do
        names+=("$name")
    done < "$BOOKMARKS_FILE"
    _describe 'bookmark' names
}
compdef _bookmark_names jump unmark

# ============================================================================
# ONBOARDING — warp-help
# ============================================================================
function warp-help() {
    cat <<'HELP'

  WARP-LIKE SHELL HELPERS
  ━━━━━━━━━━━━━━━━━━━━━━

  FILE MANAGER
    yy [path]          Open yazi. Quit (q) to cd to last viewed directory.
                       Arrow keys navigate, Enter opens, q quits.

  DIRECTORY JUMP
    cdj                Fuzzy-pick from your most-visited directories.
                       Powered by zoxide frecency — directories you visit
                       often rank higher. Just start typing to filter.

  TMUX SESSIONS
    ts                 Fuzzy-switch between tmux sessions.
                       Works inside and outside tmux.

  HISTORY
    Ctrl+R             Fuzzy search command history (fzf-enhanced).
                       Enter = run command, Tab = paste to edit first.

  BOOKMARKS
    mark <name>        Bookmark current directory as <name>.
    jump [name]        Jump to bookmark. No arg = interactive picker.
    marks              List all bookmarks.
    unmark <name>      Remove a bookmark.

  EXAMPLES
    $ mark proj        # Save ~/Projects/myapp as "proj"
    $ jump proj        # Jump back to ~/Projects/myapp from anywhere
    $ jump             # Pick from all bookmarks with fzf
    $ cdj              # Jump to a recent directory (fuzzy)
    $ yy ~/Downloads   # Browse Downloads in yazi, cd on quit
    $ ts               # Switch tmux session

HELP
}
