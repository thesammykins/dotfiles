#!/bin/bash
# MOTD Script - Displayed once per day
# Shows system info and a random quote

set -e

DOTFILES="${DOTFILES:-$HOME/dotfiles-staging/.dotfiles}"
MOTD_FLAG="$DOTFILES/.last_motd"
QUOTES_FILE="$DOTFILES/quotes/tech-quotes.json"

# Check if we should show MOTD (once per 24 hours)
show_motd() {
    if [[ ! -f "$MOTD_FLAG" ]]; then
        return 0
    fi
    
    local last_run=$(cat "$MOTD_FLAG")
    local now=$(date +%s)
    local diff=$((now - last_run))
    
    # Show if more than 24 hours (86400 seconds)
    if [[ $diff -gt 86400 ]]; then
        return 0
    fi
    
    return 1
}

# Get random quote from local cache
get_quote() {
    if [[ -x "$DOTFILES/scripts/random-quote.sh" ]]; then
        "$DOTFILES/scripts/random-quote.sh"
    else
        echo "Technology is best when it brings people together. — Matt Mullenweg"
    fi
}

# Main MOTD display
main() {
    if ! show_motd; then
        return 0
    fi

    # MCRN Tactical OS Boot Header
    echo -e "\033[38;2;255;211;78m[MCRN TACHI / ROCINANTE - TACTICAL TERMINAL v9.0.4]\033[0m"
    echo -e "\033[38;2;176;76;42m[BOOT SEQUENCE COMPLETE]\033[0m"
    echo ""

    # System info with fastfetch (includes quote module)
    if command -v fastfetch &>/dev/null; then
        fastfetch --config ~/.config/fastfetch/config.jsonc 2>/dev/null || true
    else
        local quote
        quote=$(get_quote)
        echo "💬 $quote"
    fi

    echo ""
    echo "💡 Run \`~/dotfiles-staging/.dotfiles/scripts/refresh-quotes.sh\` weekly for fresh AI-generated quotes"
    echo ""

    # Update timestamp
    date +%s > "$MOTD_FLAG"
}

main
