#!/bin/bash
# Refresh Quotes Script - Weekly AI-generated quote refresh
# Uses opencode + GPT-5 mini via copilot provider

set -euo pipefail

DOTFILES="${DOTFILES:-$HOME/.dotfiles}"
QUOTES_FILE="$DOTFILES/quotes/tech-quotes.json"
CACHE_FILE="$DOTFILES/.quote_refresh_cache"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

# Check prerequisites
check_prerequisites() {
    if ! command -v opencode &>/dev/null; then
        log_error "opencode not found. Please install opencode first."
        exit 1
    fi
    
    if ! command -v jq &>/dev/null; then
        log_error "jq not found. Run: brew install jq"
        exit 1
    fi
    
    if [[ ! -f "$QUOTES_FILE" ]]; then
        log_error "Quotes file not found at $QUOTES_FILE"
        exit 1
    fi
}

# Rate limiting - max once per hour
check_rate_limit() {
    if [[ -f "$CACHE_FILE" ]]; then
        local last_run=$(cat "$CACHE_FILE" 2>/dev/null || echo "0")
        local now=$(date +%s)
        local diff=$((now - last_run))
        
        if [[ $diff -lt 3600 ]]; then
            local wait_minutes=$(( (3600 - diff) / 60 ))
            log_warn "Rate limited. Please wait ${wait_minutes} minutes before refreshing again."
            log_info "Using existing quotes from cache."
            exit 0
        fi
    fi
}

# Generate AI quotes using opencode
generate_quotes() {
    log_info "Generating 5 new AI quotes using GPT-5 mini..."
    
    local prompt="Generate 5 unique quotes about technology, programming, and innovation. 
Format as JSON array with fields: quote (string) and author (string).
Mix styles: serious insights from tech figures, witty observations, and creative perspectives.
Example authors to emulate: Alan Turing, Grace Hopper, Dennis Ritchie, Steve Jobs, Linus Torvalds.
Keep quotes 1-2 sentences max. Make them inspiring or thought-provoking."

    local temp_file=$(mktemp)
    
    # Try to generate with opencode, timeout after 30 seconds
    if timeout 30 opencode generate --model "copilot/gpt-5-mini" --prompt "$prompt" > "$temp_file" 2>/dev/null; then
        # Validate JSON
        if jq empty "$temp_file" 2>/dev/null; then
            log_info "Successfully generated new quotes"
            cat "$temp_file"
            rm "$temp_file"
            return 0
        fi
    fi
    
    rm -f "$temp_file"
    return 1
}

# Append and deduplicate quotes
update_quotes() {
    local new_quotes="$1"
    
    log_info "Adding new quotes to cache..."
    
    # Combine existing and new quotes
    local combined=$(jq -s '.[0] + .[1] | unique_by(.quote)' "$QUOTES_FILE" - <<< "$new_quotes")
    
    # Validate result
    if ! jq empty <<< "$combined" 2>/dev/null; then
        log_error "Failed to merge quotes"
        return 1
    fi
    
    # Write back
    echo "$combined" | jq '.' > "$QUOTES_FILE"
    
    local total=$(jq 'length' "$QUOTES_FILE")
    log_info "Quote cache updated! Total quotes: $total"
}

# Main
main() {
    log_info "Quote Refresh Script - 2026"
    log_info "Using opencode + GPT-5 mini via copilot"
    
    check_prerequisites
    check_rate_limit
    
    log_info "Fetching fresh AI-generated quotes..."
    
    if new_quotes=$(generate_quotes); then
        update_quotes "$new_quotes"
        date +%s > "$CACHE_FILE"
        log_info "Done! New quotes will appear in tomorrow's MOTD."
    else
        log_warn "Failed to generate new quotes (API issue or timeout)"
        log_info "Keeping existing quotes from cache."
        exit 0
    fi
}

main