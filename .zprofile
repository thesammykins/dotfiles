#!/bin/zsh
# ~/.zprofile - Login shell configuration
# Runs once per login session (not for every shell)

# Source .zshrc for consistency
if [[ -f "$HOME/.zshrc" ]]; then
    source "$HOME/.zshrc"
fi