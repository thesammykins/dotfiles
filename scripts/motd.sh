#!/bin/bash
# MOTD Script - Displayed once per day
# Shows system info and tactical directives

set -e

DOTFILES="${DOTFILES:-$HOME/.dotfiles}"
MOTD_FLAG="$DOTFILES/.last_motd"
SHELL_OPEN_FLAG="$DOTFILES/.last_shell_open"
MOTD_INTERVAL_SECONDS="${MOTD_INTERVAL_SECONDS:-86400}"
MOTD_IDLE_SECONDS="${MOTD_IDLE_SECONDS:-21600}"

# MCRN Hex Palette (24-bit ANSI RGB)
PDC_AMBER="\033[38;2;255;211;78m"
ALERT_RED="\033[38;2;255;41;41m"
RUST_ORANGE="\033[38;2;176;76;42m"
HOLOMAP="\033[38;2;196;122;64m"
STARLIGHT="\033[38;2;234;234;234m"
RESET="\033[0m"
BOLD="\033[1m"
FALLBACK_QUOTE="Technology is best when it brings people together. — Matt Mullenweg"

# Check if we should show MOTD (once per 24 hours, or after shell idle gap)
show_motd() {
	local now
	local last_shown=0
	local last_shell_open=0
	local since_shown
	local since_shell_open

	if [[ "${MOTD_FORCE:-0}" == "1" ]]; then
		return 0
	fi

	now=$(date +%s)

	if [[ -f "$MOTD_FLAG" ]]; then
		last_shown=$(cat "$MOTD_FLAG" 2>/dev/null || printf '0')
	fi

	if [[ -f "$SHELL_OPEN_FLAG" ]]; then
		last_shell_open=$(cat "$SHELL_OPEN_FLAG" 2>/dev/null || printf '0')
	fi

	if ! [[ "$last_shown" =~ ^[0-9]+$ ]]; then
		last_shown=0
	fi

	if ! [[ "$last_shell_open" =~ ^[0-9]+$ ]]; then
		last_shell_open=0
	fi

	if ((last_shown == 0)); then
		return 0
	fi

	since_shown=$((now - last_shown))
	since_shell_open=$((now - last_shell_open))

	if ((since_shown >= MOTD_INTERVAL_SECONDS)); then
		return 0
	fi

	if ((last_shell_open == 0)) || ((since_shell_open >= MOTD_IDLE_SECONDS)); then
		return 0
	fi

	return 1
}

record_shell_open() {
	mkdir -p "$(dirname "$SHELL_OPEN_FLAG")"
	date +%s >"$SHELL_OPEN_FLAG"
}

repeat_char() {
	local char="$1"
	local count="$2"
	local result=""

	while ((count-- > 0)); do
		result+="$char"
	done

	printf '%s' "$result"
}

get_terminal_width() {
	local cols=80

	if command -v tput &>/dev/null; then
		cols=$(tput cols 2>/dev/null || printf '80')
	fi

	if ! [[ "$cols" =~ ^[0-9]+$ ]] || ((cols < 60)); then
		cols=80
	fi

	printf '%s' "$cols"
}

get_quote() {
	if [[ -x "$DOTFILES/scripts/random-quote.sh" ]]; then
		"$DOTFILES/scripts/random-quote.sh"
		return 0
	fi

	printf '%s\n' "$FALLBACK_QUOTE"
}

wrap_quote() {
	local width="$1"
	local quote
	quote=$(get_quote)

	if command -v python3 &>/dev/null; then
		python3 - "$width" "$quote" <<'PY'
import sys
import textwrap

width = int(sys.argv[1])
text = sys.argv[2].strip()

for line in textwrap.wrap(
    text,
    width=width,
    break_long_words=False,
    break_on_hyphens=False,
):
    print(line)
PY
		return 0
	fi

	printf '%s\n' "$quote" | fold -s -w "$width"
}

print_hermes_profiles() {
	local total_width
	local panel_width
	local inner_width
	local top_border
	local bottom_border
	local header_fill
	local line
	local padding
	local profiles=(
		"sentinel   :: SRE / observability / production health"
		"forge      :: builder / implementation engineer"
		"scout      :: research / QA / reconnaissance"
		"prospector :: automation opportunity discovery"
	)

	total_width=$(get_terminal_width)
	panel_width=$((total_width - 2))
	if ((panel_width > 92)); then
		panel_width=92
	fi
	if ((panel_width < 56)); then
		panel_width=56
	fi

	inner_width=$((panel_width - 2))
	top_border="┌$(repeat_char "─" $((panel_width - 2)))┐"
	bottom_border="└$(repeat_char "─" $((panel_width - 2)))┘"
	header_fill=$(repeat_char "═" $((inner_width - 26)))

	echo -e "${HOLOMAP}${top_border}${RESET}"
	echo -e "${HOLOMAP}│${RESET}${BOLD}${PDC_AMBER}[HERMES PROFILE ROSTER]${RESET}${HOLOMAP}${header_fill}│${RESET}"
	echo -e "${HOLOMAP}├$(repeat_char "─" $((panel_width - 2)))┤${RESET}"
	for line in "${profiles[@]}"; do
		padding=$((inner_width - 3 - ${#line}))
		if ((padding < 0)); then
			padding=0
		fi
		echo -e "${HOLOMAP}│${RESET} ${RUST_ORANGE}› ${line}$(repeat_char " " "$padding")${RESET}${HOLOMAP}│${RESET}"
	done
	line="quick launch: sentinel | forge | scout | prospector"
	padding=$((inner_width - 3 - ${#line}))
	if ((padding < 0)); then
		padding=0
	fi
	echo -e "${HOLOMAP}├$(repeat_char "─" $((panel_width - 2)))┤${RESET}"
	echo -e "${HOLOMAP}│${RESET} ${STARLIGHT}» ${line}$(repeat_char " " "$padding")${RESET}${HOLOMAP}│${RESET}"
	echo -e "${HOLOMAP}${bottom_border}${RESET}\n"
}

print_quote_banner() {
	local total_width
	local panel_width
	local inner_width
	local top_border
	local bottom_border
	local header_fill
	local directive_line
	local directive_text
	local line
	local padding

	total_width=$(get_terminal_width)
	panel_width=$((total_width - 2))
	if ((panel_width > 92)); then
		panel_width=92
	fi
	if ((panel_width < 56)); then
		panel_width=56
	fi

	inner_width=$((panel_width - 2))
	top_border="┌$(repeat_char "─" $((panel_width - 2)))┐"
	bottom_border="└$(repeat_char "─" $((panel_width - 2)))┘"
	header_fill=$(repeat_char "═" $((inner_width - 19)))

	directive_text="[SYSTEM DIRECTIVE] Run dotfiles-refresh to sync orbital telemetry."
	padding=$((inner_width - ${#directive_text}))
	if ((padding < 0)); then
		padding=0
	fi
	directive_line="${directive_text}$(repeat_char " " "$padding")"

	echo -e "\n${HOLOMAP}${top_border}${RESET}"
	echo -e "${HOLOMAP}│${RESET}${ALERT_RED}[TACTICAL ADVISORY]${HOLOMAP}${header_fill}│${RESET}"
	echo -e "${HOLOMAP}├$(repeat_char "─" $((panel_width - 2)))┤${RESET}"
	while IFS= read -r line; do
		padding=$((inner_width - 3 - ${#line}))
		if ((padding < 0)); then
			padding=0
		fi
		echo -e "${HOLOMAP}│${RESET} ${PDC_AMBER}» ${line}$(repeat_char " " "$padding")${RESET}${HOLOMAP}│${RESET}"
	done < <(wrap_quote $((inner_width - 3)))
	echo -e "${HOLOMAP}├$(repeat_char "─" $((panel_width - 2)))┤${RESET}"
	echo -e "${HOLOMAP}│${RESET}${RUST_ORANGE}${directive_line}${RESET}${HOLOMAP}│${RESET}"
	echo -e "${HOLOMAP}${bottom_border}${RESET}\n"
}

# Main MOTD display
main() {
	record_shell_open

	if ! show_motd; then
		return 0
	fi

	# MCRN Boot Sequence Handshake
	echo -e "${HOLOMAP}┌──────────────────────────────────────────────────────────────┐${RESET}"
	echo -e "${HOLOMAP}│${RESET} ${ALERT_RED}>> MCRN FLEET COMMAND SECURE LINK ESTABLISHED${RESET}            ${HOLOMAP}│${RESET}"
	echo -e "${HOLOMAP}│${RESET} ${RUST_ORANGE}>> HANDSHAKE PROTOCOL: AUTHENTICATED${RESET}                     ${HOLOMAP}│${RESET}"
	echo -e "${HOLOMAP}│${RESET} ${PDC_AMBER}>> INITIALIZING TACTICAL TERMINAL v9.0.4...${RESET}              ${HOLOMAP}│${RESET}"
	echo -e "${HOLOMAP}└──────────────────────────────────────────────────────────────┘${RESET}\n"

	# System info with fastfetch
	if command -v fastfetch &>/dev/null; then
		fastfetch --config ~/.config/fastfetch/config.jsonc 2>/dev/null || true
	fi

	print_hermes_profiles
	print_quote_banner

	# Update display timestamp
	mkdir -p "$(dirname "$MOTD_FLAG")"
	date +%s >"$MOTD_FLAG"
}

main
