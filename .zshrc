#!/bin/zsh

# Keep startup predictable. Machine-specific exports, paths, and aliases belong
# in ~/.zshrc.local.

export DOTFILES="${DOTFILES:-$HOME/Development/dotfiles}"
export EDITOR="${EDITOR:-vim}"
typeset -U path PATH

if [[ -d "$HOME/.local/bin" ]]; then
    path=("$HOME/.local/bin" $path)
fi

if [[ -d /opt/homebrew/bin ]]; then
    export HOMEBREW_PREFIX="/opt/homebrew"
    path=("$HOMEBREW_PREFIX/bin" "$HOMEBREW_PREFIX/sbin" $path)
elif [[ -d /usr/local/bin ]]; then
    export HOMEBREW_PREFIX="/usr/local"
    path=("$HOMEBREW_PREFIX/bin" "$HOMEBREW_PREFIX/sbin" $path)
fi

# ~/.ssh/config already routes ssh through 1Password; this also points ssh-add
# and other tools that read SSH_AUTH_SOCK at the same agent. Inside an SSH
# session, keep any forwarded agent instead.
_op_agent="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
if [[ -z "${SSH_CONNECTION:-}" && -S "$_op_agent" ]]; then
    export SSH_AUTH_SOCK="$_op_agent"
fi
unset _op_agent

if command -v nvim >/dev/null 2>&1; then
    export EDITOR="nvim"
fi

HISTFILE="$HOME/.zsh_history"
HISTSIZE=100000
SAVEHIST=100000

setopt EXTENDED_HISTORY
setopt SHARE_HISTORY
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_SAVE_NO_DUPS
setopt HIST_VERIFY
setopt HIST_REDUCE_BLANKS
setopt AUTO_CD

if [[ -n "${HOMEBREW_PREFIX:-}" && -d "$HOMEBREW_PREFIX/share/zsh/site-functions" ]]; then
    fpath=("$HOMEBREW_PREFIX/share/zsh/site-functions" $fpath)
fi

autoload -Uz compinit
if [[ -n "$HOME/.zcompdump"(#qN.mh+24) ]]; then
    compinit
else
    compinit -C
fi

zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

# Warp owns input rendering; ordinary terminals use Zsh's line editor.
if [[ "$TERM_PROGRAM" != WarpTerminal && -n "${HOMEBREW_PREFIX:-}" ]]; then
    [[ -f "$HOMEBREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]] &&
        source "$HOMEBREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
fi

if command -v mise >/dev/null 2>&1; then
    eval "$(mise activate zsh)"
fi

if command -v direnv >/dev/null 2>&1; then
    eval "$(direnv hook zsh)"
fi

if [[ "$TERM_PROGRAM" != WarpTerminal ]] && command -v fzf >/dev/null 2>&1; then
    # Atuin owns history search when installed; fzf owns files and directories.
    command -v atuin >/dev/null 2>&1 && export FZF_CTRL_R_COMMAND=''
    command -v bat >/dev/null 2>&1 &&
        export FZF_CTRL_T_OPTS="--walker=file,follow,hidden --preview 'bat --theme=base16 --color=always --style=numbers --line-range=:200 -- {}'"
    command -v eza >/dev/null 2>&1 &&
        export FZF_ALT_C_OPTS="--preview 'eza --tree --level=2 --color=always -- {}'"
    eval "$(fzf --zsh)"
fi

if command -v atuin >/dev/null 2>&1; then
    if [[ "$TERM_PROGRAM" == WarpTerminal ]]; then
        eval "$(atuin init zsh --disable-up-arrow --disable-ctrl-r --disable-ai)"
    else
        eval "$(atuin init zsh --disable-up-arrow --disable-ai)"
    fi
fi

if command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init zsh)"
fi

if command -v carapace >/dev/null 2>&1; then
    export CARAPACE_BRIDGES='zsh,fish,bash,inshellisense'
    source <(carapace _carapace)
fi

if command -v op >/dev/null 2>&1; then
    eval "$(op completion zsh)" 2>/dev/null || true
fi

alias dotfiles='git -C "$DOTFILES"'
alias g='git'
alias gs='git status --short --branch'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gd='git diff'
alias gl='git log --oneline --graph --decorate'

if command -v eza >/dev/null 2>&1; then
    alias ls='eza --group-directories-first'
    alias ll='eza --group-directories-first --icons=auto --git -la'
    alias la='eza --group-directories-first -a'
    alias lt='eza --tree --level=2 --group-directories-first --icons=auto'
else
    alias ll='ls -la'
    alias la='ls -A'
fi

vrun() {
    command varlock run --path "$DOTFILES/.config/varlock" -- "$@"
}

keys() {
    if [[ "$TERM_PROGRAM" == WarpTerminal ]]; then
        printf '%s\n' \
            'WARP SHORTCUTS (defaults; remappable in Settings)' \
            '  Cmd-P             Search actions and keyboard shortcuts' \
            '  Ctrl-R            Search command history' \
            '  Cmd-O             Search files' \
            '  Cmd-D             Split pane right' \
            '  Cmd-,             Settings > Keyboard shortcuts'
    else
        printf '%s\n' \
            'ZSH SHORTCUTS (this dotfiles setup)' \
            '  Ctrl-R            Search history with Atuin' \
            '  Ctrl-T            Find a file and insert its path' \
            '  Esc, then c       Pick a directory and change into it' \
            '  Option-C          Same, if Option is configured as Meta' \
            '  Right arrow       Accept a suggestion at end of line'
    fi
    printf '%s\n' \
        '' \
        'COMMANDS TO TYPE' \
        '  z project         Jump to a previously visited directory' \
        '  zi                Pick a previously visited directory' \
        '  ll / lt           Detailed listing / two-level file tree' \
        '  bat FILE          Read a file with highlighting' \
        '  yazi              Browse files (press ~ for help, q to quit)' \
        '  btop              CPU, memory and processes (q to quit)' \
        '  gs / gd / gl      Git status / diff / history' \
        '  open .            Open this directory in Finder' \
        '  COMMAND | pbcopy  Copy command output to the clipboard' \
        '  caffeinate CMD    Keep the Mac awake while CMD runs' \
        '  man COMMAND       Read the full manual (q to quit)' \
        '' \
        'Type keys or shortcuts to show this again. Nothing here is executed.'
}
alias shortcuts='keys'

if [[ "$TERM_PROGRAM" != WarpTerminal ]] && command -v starship >/dev/null 2>&1; then
    eval "$(starship init zsh)"
fi

[[ -f "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"

# Load after integrations and local overrides have registered their widgets.
if [[ "$TERM_PROGRAM" != WarpTerminal && -n "${HOMEBREW_PREFIX:-}" ]]; then
    [[ -f "$HOMEBREW_PREFIX/share/zsh-fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh" ]] &&
        source "$HOMEBREW_PREFIX/share/zsh-fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh"
fi

if [[ -o interactive && -o login && -t 1 ]]; then
    print -r -- 'Shell shortcuts: type keys (or shortcuts).'
fi
