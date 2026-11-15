#!/bin/zsh
# ~/.zprofile - Login shell configuration
# Runs once per login session; keep login-only environment here.

# Homebrew on PATH for every login shell, including non-interactive ones
# (ssh host cmd, agent runners) that never read ~/.zshrc.
for _brew in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    [[ -x "$_brew" ]] && eval "$("$_brew" shellenv)" && break
done
unset _brew

# Added by OrbStack: command-line tools and integration
# This won't be added again if you remove it.
source ~/.orbstack/shell/init.zsh 2>/dev/null || :
