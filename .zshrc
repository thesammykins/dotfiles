#!/bin/zsh

# Keep startup predictable. Machine-specific exports, paths, and aliases belong
# in ~/.zshrc.local.

export DOTFILES="${DOTFILES:-$HOME/repos/dotfiles}"
export EDITOR="${EDITOR:-vim}"
typeset -U path PATH

# Login shells get Homebrew from ~/.zprofile; this covers interactive shells
# started without one.
if [[ -z "${HOMEBREW_PREFIX:-}" ]]; then
    for _brew in /opt/homebrew/bin/brew /usr/local/bin/brew; do
        [[ -x "$_brew" ]] && eval "$("$_brew" shellenv)" && break
    done
    unset _brew
fi

# Homebrew first, then ~/.local/bin, then the system.
path=(${HOMEBREW_PREFIX:+$HOMEBREW_PREFIX/bin} ${HOMEBREW_PREFIX:+$HOMEBREW_PREFIX/sbin} $HOME/.local/bin(N/) $path)

# Point ssh, ssh-add and git at the 1Password agent. Inside an SSH session,
# keep any forwarded agent instead.
_op_agent="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
if [[ -z "${SSH_CONNECTION:-}" && -S "$_op_agent" ]]; then
    export SSH_AUTH_SOCK="$_op_agent"
fi
unset _op_agent

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

if [[ -n "${HOMEBREW_PREFIX:-}" && -d "$HOMEBREW_PREFIX/share/zsh-completions" ]]; then
    fpath=("$HOMEBREW_PREFIX/share/zsh-completions" $fpath)
fi

# Rex ships its own completion script. Cache it, regenerating when rex is
# upgraded, instead of running rex on every shell start.
if (( $+commands[rex] )); then
    _rex_comp_dir="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/completions"
    if [[ ! -s "$_rex_comp_dir/_rex" || "$_rex_comp_dir/_rex" -ot "${commands[rex]:A}" ]]; then
        mkdir -p "$_rex_comp_dir" && rex completion zsh >| "$_rex_comp_dir/_rex"
        rm -f "$HOME/.zcompdump" # compinit -C would otherwise never see the new function
    fi
    fpath=("$_rex_comp_dir" $fpath)
    unset _rex_comp_dir
fi

# Run the full compinit security check at most once a day. The (#q) glob
# qualifier needs extended_glob; without it the test is always true.
autoload -Uz compinit
() {
    setopt local_options extended_glob
    if [[ ! -e "$HOME/.zcompdump" || -n $HOME/.zcompdump(#qN.mh+24) ]]; then
        compinit
    else
        compinit -C
    fi
}

zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

if [[ -n "${HOMEBREW_PREFIX:-}" ]]; then
    [[ -f "$HOMEBREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]] &&
        source "$HOMEBREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
fi

if command -v mise >/dev/null 2>&1; then
    eval "$(mise activate zsh)"
fi

if command -v direnv >/dev/null 2>&1; then
    eval "$(direnv hook zsh)"
fi

if command -v fzf >/dev/null 2>&1; then
    # Atuin owns history search when installed; fzf owns files and directories.
    command -v atuin >/dev/null 2>&1 && export FZF_CTRL_R_COMMAND=''
    command -v bat >/dev/null 2>&1 &&
        export FZF_CTRL_T_OPTS="--walker=file,follow,hidden --preview 'bat --theme=base16 --color=always --style=numbers --line-range=:200 -- {}'"
    command -v eza >/dev/null 2>&1 &&
        export FZF_ALT_C_OPTS="--preview 'eza --tree --level=2 --color=always -- {}'"
    eval "$(fzf --zsh)"
fi

if command -v atuin >/dev/null 2>&1; then
    eval "$(atuin init zsh --disable-up-arrow --disable-ai)"
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
alias ssh-device-add='bash "$DOTFILES/scripts/ssh-enroll-device.sh"'
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
    printf '%s\n' \
        'Ctrl-R            Search history (Atuin)' \
        'Ctrl-T            Find a file and insert its path' \
        'Esc, then c       Pick a directory and change into it' \
        'Right arrow       Accept a suggestion at end of line' \
        '# DESCRIPTION     Enter swaps it for a suggested command' \
        'ask QUESTION      One-shot answer from an agent, read-only' \
        'z NAME / zi       Jump to / pick a visited directory' \
        'll / lt           Detailed listing / two-level tree' \
        'gs / gd / gl      Git status / diff / history' \
        'fresh / yazi      Editor with file tree / file browser' \
        'btop              System monitor' \
        'vrun CMD          Run CMD with secrets from varlock'
    [[ "$TERM_PROGRAM" == rex ]] && printf '%s\n' \
        'ax TASK           Hand a task to an agent in a split below' \
        'Ctrl-Shift-R      Saved commands (Ctrl-A add, Ctrl-D delete, Ctrl-E edit)' \
        'Ctrl-X Ctrl-A     Save the typed line as a saved command' \
        'Ctrl-X Ctrl-E     Edit the command line in $EDITOR' \
        'Cmd-Up / Cmd-Down Jump to previous / next prompt' \
        'Cmd-B             Files in fresh beside this pane' \
        'Cmd-Shift-B       Pick a file or directory with yazi'
    return 0
}

[[ -r "$HOME/.config/zsh/ask.zsh" ]] && source "$HOME/.config/zsh/ask.zsh"

# Tab title: the directory at the prompt, the running command while it executes.
autoload -Uz add-zsh-hook
_title_precmd() { print -Pn '\e]0;%~\a' }
_title_preexec() { print -rn -- $'\e]0;'"${1[(w)1]} · ${PWD/#$HOME/~}"$'\a' }
add-zsh-hook precmd _title_precmd
add-zsh-hook preexec _title_preexec

if command -v starship >/dev/null 2>&1; then
    eval "$(starship init zsh)"
fi

# Rex prompt marks, long-command status and saved-command keys. After starship,
# because it appends the prompt-end mark to starship's prompt.
if [[ "$TERM_PROGRAM" == rex && -r "$HOME/.config/rex/shell/rex.zsh" ]]; then
    source "$HOME/.config/rex/shell/rex.zsh"
fi

[[ -f "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"

# Load after integrations and local overrides have registered their widgets.
if [[ -n "${HOMEBREW_PREFIX:-}" ]]; then
    [[ -f "$HOMEBREW_PREFIX/share/zsh-fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh" ]] &&
        source "$HOMEBREW_PREFIX/share/zsh-fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh"
fi
