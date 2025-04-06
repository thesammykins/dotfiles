# ~/.bashrc: executed by bash(1) for non-login shells.

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# Set PATH so it includes user's private bin if it exists
if [ -d "$HOME/bin" ] ; then
    PATH="$HOME/bin:$PATH"
fi

# Set PATH for Homebrew
if [ -d "/usr/local/bin" ] ; then
    PATH="/usr/local/bin:$PATH"
fi

# Set PATH for MacPorts
if [ -d "/opt/local/bin" ] ; then
    PATH="/opt/local/bin:$PATH"
fi

# Alias definitions
alias ll='ls -lah'
alias la='ls -A'
alias l='ls -CF'

# Enable color support for ls and grep
export CLICOLOR=1
export LSCOLORS=GxFxCxDxBxegedabagaced

# Custom prompt
export PS1="\[\e[32m\]\u@\h \[\e[33m\]\w\[\e[0m\] $ "

# Load bash completions if available
if [ -f /usr/local/etc/bash_completion ]; then
    . /usr/local/etc/bash_completion
elif [ -f /opt/local/etc/bash_completion ]; then
    . /opt/local/etc/bash_completion
fi

# Add user-specific aliases and functions
if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

# Add user-specific environment variables
if [ -f ~/.bash_profile ]; then
    . ~/.bash_profile
fi

# History settings
HISTSIZE=1000
HISTFILESIZE=2000
HISTCONTROL=ignoredups:erasedups
shopt -s histappend

# Enable programmable completion features
if [ -f /usr/local/etc/bash_completion ]; then
    . /usr/local/etc/bash_completion
fi