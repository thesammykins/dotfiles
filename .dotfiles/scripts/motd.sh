#!/bin/bash
# MOTD Script - Displayed once per day
# Shows system info and a random quote

set -e

DOTFILES="${DOTFILES:-$HOME/.dotfiles}"
MOTD_FLAG="$DOTFILES/.last_motd"

# MCRN Hex Palette (24-bit ANSI RGB)
PDC_AMBER="\033[38;2;255;211;78m"
ALERT_RED="\033[38;2;255;41;41m"
RUST_ORANGE="\033[38;2;176;76;42m"
HOLOMAP="\033[38;2;117;51;26m"
STARLIGHT="\033[38;2;234;234;234m"
RESET="\033[0m"
BOLD="\033[1m"

# Check if we should show MOTD (once per 24 hours)
show_motd() {
    if [[ ! -f "$MOTD_FLAG" ]]; then
        return 0
    fi
    
    local last_run
    local now
    last_run=$(cat "$MOTD_FLAG")
    now=$(date +%s)
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

    # MCRN Boot Sequence Handshake
    echo -e "${HOLOMAP}┌──────────────────────────────────────────────────────────────┐${RESET}"
    echo -e "${HOLOMAP}│${RESET} ${ALERT_RED}>> MCRN FLEET COMMAND SECURE LINK ESTABLISHED${RESET}            ${HOLOMAP}│${RESET}"
    echo -e "${HOLOMAP}│${RESET} ${RUST_ORANGE}>> HANDSHAKE PROTOCOL: AUTHENTICATED${RESET}                     ${HOLOMAP}│${RESET}"
    echo -e "${HOLOMAP}│${RESET} ${PDC_AMBER}>> INITIALIZING TACTICAL TERMINAL v9.0.4...${RESET}              ${HOLOMAP}│${RESET}"
    echo -e "${HOLOMAP}└──────────────────────────────────────────────────────────────┘${RESET}\n"

    # System info with fastfetch (includes quote module)
    if command -v fastfetch &>/dev/null; then
        fastfetch --config ~/.config/fastfetch/config.jsonc 2>/dev/null || true
    fi

    # System Advisories
    local quote
    quote=$(get_quote)
    echo -e "\n${HOLOMAP}▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰${RESET}"
    echo -e "${ALERT_RED}[TACTICAL ADVISORY]${RESET} ${PDC_AMBER}${quote}${RESET}"
    echo -e "${RUST_ORANGE}[SYSTEM DIRECTIVE]${RESET}  ${STARLIGHT}Run ${BOLD}dotfiles-refresh${RESET}${STARLIGHT} to sync orbital telemetry.${RESET}"
    echo -e "${HOLOMAP}▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰${RESET}\n"

    # Update timestamp
    mkdir -p "$(dirname "$MOTD_FLAG")"
    date +%s > "$MOTD_FLAG"
}

main
