#!/bin/zsh

# Keep startup predictable. Machine-specific exports, paths, and aliases belong
# in ~/.zshrc.local.

export DOTFILES="${DOTFILES:-$HOME/Development/dotfiles}"
export EDITOR="${EDITOR:-vim}"

if [[ -d "$HOME/.local/bin" ]]; then
    export PATH="$HOME/.local/bin:$PATH"
fi

if [[ -d /opt/homebrew/bin ]]; then
    export HOMEBREW_PREFIX="/opt/homebrew"
    export PATH="$HOMEBREW_PREFIX/bin:$HOMEBREW_PREFIX/sbin:$PATH"
elif [[ -d /usr/local/bin ]]; then
    export HOMEBREW_PREFIX="/usr/local"
    export PATH="$HOMEBREW_PREFIX/bin:$HOMEBREW_PREFIX/sbin:$PATH"
fi

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

if [[ -n "${HOMEBREW_PREFIX:-}" ]]; then
    [[ -f "$HOMEBREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]] &&
        source "$HOMEBREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh"

    [[ -f "$HOMEBREW_PREFIX/share/zsh-fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh" ]] &&
        source "$HOMEBREW_PREFIX/share/zsh-fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh"
fi

if command -v mise >/dev/null 2>&1; then
    eval "$(mise activate zsh)"
fi

if command -v direnv >/dev/null 2>&1; then
    eval "$(direnv hook zsh)"
fi

if command -v fzf >/dev/null 2>&1; then
    eval "$(fzf --zsh)" 2>/dev/null || true
fi

if command -v atuin >/dev/null 2>&1; then
    eval "$(atuin init zsh --disable-up-arrow)"
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
    alias ll='eza --group-directories-first -la'
    alias la='eza --group-directories-first -a'
else
    alias ll='ls -la'
    alias la='ls -A'
fi

if command -v bat >/dev/null 2>&1; then
    alias cat='bat --paging=never --style=plain'
fi

vrun() {
    command varlock run --path "$DOTFILES/.config/varlock" -- "$@"
}

if command -v starship >/dev/null 2>&1; then
    eval "$(starship init zsh)"
fi

[[ -f "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"
