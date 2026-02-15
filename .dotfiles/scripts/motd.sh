#!/bin/bash
# MOTD Script - Displayed once per day
# Shows system info and a random quote

set -e

DOTFILES="${DOTFILES:-$HOME/.dotfiles}"
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
    if [[ ! -f "$QUOTES_FILE" ]]; then
        echo "Technology is best when it brings people together. — Matt Mullenweg"
        return
    fi
    
    if command -v jq &>/dev/null; then
        jq -r '.[] | .quote + " — " + .author' "$QUOTES_FILE" | shuf -n 1
    else
        # Fallback if jq not available
        echo "Technology is best when it brings people together. — Matt Mullenweg"
    fi
}

# Main MOTD display
main() {
    if ! show_motd; then
        return 0
    fi
    
    echo ""
    
    # System info with fastfetch
    if command -v fastfetch &>/dev/null; then
        fastfetch --logo none --separator " : " 2>/dev/null || true
    fi
    
    echo ""
    
    # Random quote
    local quote=$(get_quote)
    echo "💬 $quote"
    
    echo ""
    echo "💡 Run \`~/.dotfiles/scripts/refresh-quotes.sh\` weekly for fresh AI-generated quotes"
    echo ""
    
    # Update timestamp
    date +%s > "$MOTD_FLAG"
}

main