#!/bin/zsh
# ~/.zshrc - 2026 Ready Terminal Configuration
# Optimized load order for performance

# ============================================================================
# PATH AND ENVIRONMENT
# ============================================================================
# OpenCode (must be early in PATH)
export PATH="$HOME/.opencode/bin:$PATH"
export OPENCODE_EXPERIMENTAL_LSP_TOOL=true

# Homebrew (Apple Silicon vs Intel)
if [[ -d "/opt/homebrew/bin" ]]; then
    export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:$PATH"
    export HOMEBREW_PREFIX="/opt/homebrew"
elif [[ -d "/usr/local/bin" ]]; then
    export PATH="/usr/local/bin:/usr/local/sbin:$PATH"
    export HOMEBREW_PREFIX="/usr/local"
fi

# Editor
export EDITOR="vim"
if command -v nvim &>/dev/null; then
    export EDITOR="nvim"
fi

# Dotfiles location
export DOTFILES="$HOME/.dotfiles"

# Bat theme (matches MCRN warm palette)
export BAT_THEME="ansi"

# ============================================================================
# HISTORY CONFIGURATION
# ============================================================================
HISTSIZE=100000
SAVEHIST=100000
HISTFILE="$HOME/.zsh_history"

setopt EXTENDED_HISTORY
setopt SHARE_HISTORY
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_FIND_NO_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_SAVE_NO_DUPS
setopt HIST_VERIFY
setopt HIST_REDUCE_BLANKS

# ============================================================================
# COMPLETIONS
# ============================================================================
fpath=("$HOMEBREW_PREFIX/share/zsh/site-functions" $fpath)
fpath=("$HOME/.zsh/plugins" $fpath)

# Load completions
autoload -Uz compinit

# Only regenerate completion cache once per day
if [[ -n "$HOME/.zcompdump"(#qN.mh+24) ]]; then
    compinit
else
    compinit -C
fi

# Completion styling
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

# ============================================================================
# ZSH PLUGINS (Performance Order)
# ============================================================================
# 1. Autosuggestions (async by default)
if [[ -f "$HOMEBREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]; then
    source "$HOMEBREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
fi

# 2. Fast syntax highlighting (drop-in replacement, faster than zsh-syntax-highlighting)
if [[ -f "$HOMEBREW_PREFIX/share/zsh-fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh" ]]; then
    source "$HOMEBREW_PREFIX/share/zsh-fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh"
fi

# 3. fzf-tab - Warp-style inline completion dropdown (must load after compinit, before other plugins that wrap widgets)
if [[ -f "$HOMEBREW_PREFIX/share/fzf-tab/fzf-tab.plugin.zsh" ]]; then
    source "$HOMEBREW_PREFIX/share/fzf-tab/fzf-tab.plugin.zsh"
    zstyle ':fzf-tab:*' fzf-flags --color=bg+:#3c180f,bg:#1a0b0c,fg:#ffd34e,fg+:#eaeaea,hl:#ff2929,hl+:#ff5a5a,info:#b04c2a,marker:#ff2929,prompt:#ffd34e,spinner:#b04c2a,pointer:#ffd34e,header:#c47a40,border:#c47a40
fi

# 4. Autopair - IDE-like bracket/quote auto-pairing
if [[ -f "$HOMEBREW_PREFIX/share/zsh-autopair/autopair.zsh" ]]; then
    source "$HOMEBREW_PREFIX/share/zsh-autopair/autopair.zsh"
fi

# 5. You-should-use - Alias discovery (MCRN tactical voice)
if [[ -f "$HOMEBREW_PREFIX/share/zsh-you-should-use/you-should-use.plugin.zsh" ]]; then
    export YSU_MESSAGE_FORMAT="TACTICAL NOTICE: Found alias for \"%command\" → \"%alias\""
    export YSU_MESSAGE_POSITION="after"
    source "$HOMEBREW_PREFIX/share/zsh-you-should-use/you-should-use.plugin.zsh"
fi

# ============================================================================
# TOOL INITIALIZATION
# ============================================================================
# FZF - Fuzzy finder
if command -v fzf &>/dev/null; then
    eval "$(fzf --zsh)" 2>/dev/null || { [[ -f "$HOME/.fzf.zsh" ]] && source "$HOME/.fzf.zsh"; }
fi

# FZF MCRN theme
export FZF_DEFAULT_OPTS="--color=bg+:#3c180f,bg:#1a0b0c,fg:#ffd34e,fg+:#eaeaea,hl:#ff2929,hl+:#ff5a5a,info:#b04c2a,marker:#ff2929,prompt:#ffd34e,spinner:#b04c2a,pointer:#ffd34e,header:#c47a40,border:#c47a40"

# Atuin - Synced shell history TUI (replaces fzf Ctrl+R)
if command -v atuin &>/dev/null; then
    eval "$(atuin init zsh --disable-up-arrow)"
fi

# Zoxide - Smarter cd command
if command -v zoxide &>/dev/null; then
    eval "$(zoxide init --cmd cd zsh)"
fi

# Direnv - Directory-specific environment variables
if command -v direnv &>/dev/null; then
    eval "$(direnv hook zsh)"
fi

# Mise - Global toolchain manager (Must be early)
if command -v mise &>/dev/null; then
    eval "$(mise activate zsh)"
fi

# UV - Python package manager
if command -v uv &>/dev/null; then
    eval "$(uv generate-shell-completion zsh)"
fi

# 1Password CLI completions
if command -v op &>/dev/null; then
    eval "$(op completion zsh)" 2>/dev/null || true
fi

# Carapace - Universal shell completions (hundreds of CLI tools)
if command -v carapace &>/dev/null; then
    export CARAPACE_BRIDGES='zsh,fish,bash,inshellisense'
    zstyle ':completion:*' format $'%{\e[2;37;41m%}completing %d%{\e[0m%}'
    source <(carapace _carapace)
fi

# ============================================================================
# ALIASES
# ============================================================================
# Modern CLI replacements
alias ls='eza --icons --group-directories-first --hyperlink'
alias ll='eza --icons --group-directories-first --hyperlink -la'
alias la='eza --icons --group-directories-first --hyperlink -a'
alias lt='eza --icons --hyperlink --tree'

alias cat='bat --paging=never --style=plain'
alias grep='rg'
alias find='fd'
alias top='btop'
alias du='dust'
alias ps='procs'
alias diff='delta'

# Yazi - Terminal file manager (cd to last dir on exit)
y() {
    local tmp
    tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
    yazi "$@" --cwd-file="$tmp"
    if cwd="$(command cat -- "$tmp")" && [[ -n "$cwd" ]] && [[ "$cwd" != "$PWD" ]]; then
        builtin cd -- "$cwd" || return
    fi
    rm -f -- "$tmp"
}

# Git aliases
alias g='git'
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline --graph'
alias gd='git diff'

# Navigation aliases
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
# ============================================================================
# WARP-LIKE HELPERS (yy, cdj, ts, bookmarks, fzf theme)
# ============================================================================
if [[ -f "$DOTFILES/zsh/plugins/warp-helpers.zsh" ]]; then
    source "$DOTFILES/zsh/plugins/warp-helpers.zsh"
fi


vrun() {
    command varlock run --path "$DOTFILES/.config/varlock" -- "$@"
}

vopencode() {
    command varlock run --no-redact-stdout --path "$DOTFILES/.config/varlock" -- opencode "$@"
}

# ============================================================================
# PROMPT - Starship (MUST be last)
# ============================================================================
if command -v starship &>/dev/null; then
    eval "$(starship init zsh)"
fi

# ============================================================================
# AI INTEGRATION - MCRN Tactical Widget (Load last to avoid conflicts)
# ============================================================================
if [[ -f "$DOTFILES/zsh/plugins/mcrn-ai.zsh" ]]; then
    source "$DOTFILES/zsh/plugins/mcrn-ai.zsh"
fi

# ============================================================================
# MOTD - Rocinante Bridge Boot Sequence
# ============================================================================
if [[ -o login ]]; then
    "$DOTFILES/scripts/motd.sh" 2>/dev/null || true
fi

# ============================================================================
# LOCAL OVERRIDES
# ============================================================================
[[ -f "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"

# ============================================================================
# DOTFILES ALIAS
# ============================================================================
alias dotfiles='git -C "$DOTFILES"'
# peon-ping quick controls
alias peon="bash $HOME/.claude/hooks/peon-ping/peon.sh"
[[ -f "$HOME/.claude/hooks/peon-ping/completions.bash" ]] && source "$HOME/.claude/hooks/peon-ping/completions.bash"
