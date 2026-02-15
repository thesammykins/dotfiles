#!/bin/bash
# Print a random quote from the quotes cache
set -euo pipefail

DOTFILES="${DOTFILES:-$HOME/dotfiles-staging/.dotfiles}"
QUOTES_FILE="$DOTFILES/quotes/tech-quotes.json"
FALLBACK="Technology is best when it brings people together. — Matt Mullenweg"

if [[ ! -f "$QUOTES_FILE" ]] || ! command -v jq &>/dev/null; then
    echo "$FALLBACK"
    exit 0
fi

jq -r '.[] | .quote + " — " + .author' "$QUOTES_FILE" | awk 'BEGIN{srand()} {a[NR]=$0} END{print a[int(rand()*NR)+1]}'
