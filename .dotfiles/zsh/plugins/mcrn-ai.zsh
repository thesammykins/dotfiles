# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154,SC2168
# ~/.dotfiles/zsh/plugins/mcrn-ai.zsh
# MCRN Tactical Display - Real-Time AI ZLE Widget
# Generates shell commands from natural language without leaving the prompt.
# Engine: Copilot SDK (primary) + llama-server (fallback)
# Model: gpt-5-mini (Copilot), qwen3-codersmall-q8_0.gguf (local)

# Model configuration variables
export MCRN_AI_PROVIDER="${MCRN_AI_PROVIDER:-copilot}"
export MCRN_AI_TIMEOUT_MS="${MCRN_AI_TIMEOUT_MS:-12000}"
export MCRN_AI_CONFIDENCE_MIN="${MCRN_AI_CONFIDENCE_MIN:-0.55}"
export MCRN_COPILOT_MODEL="gpt-5-mini"
export MCRN_LLM_DIR="${MCRN_LLM_DIR:-$HOME/.cache/llm-models}"
export MCRN_LLM_FILE="${MCRN_LLM_FILE:-qwen3-codersmall-q8_0.gguf}"
export MCRN_LLM_MODEL="$MCRN_LLM_DIR/$MCRN_LLM_FILE"
export MCRN_LLM_PORT="${MCRN_LLM_PORT:-8080}"
export MCRN_LLM_LOG="${MCRN_LLM_LOG:-/tmp/mcrn-llama-server.log}"
export MCRN_AI_PLUGIN_PATH="${MCRN_AI_PLUGIN_PATH:-${(%):-%x}}"
export MCRN_AI_DEBUG_LOG="${MCRN_AI_DEBUG_LOG:-/tmp/mcrn-ai-debug.log}"

# Global variable to store the last generated command for quick retry
typeset -g _MCRN_LAST_AI_QUERY=""

# Auto-start llama-server if it's not running
_mcrn_ensure_server() {
  if ! pgrep -f "llama-server.*$MCRN_LLM_FILE" >/dev/null; then
    zle -M "[MCRN UPLINK] INITIALIZING LOCAL SERVER..."
    # Start server in background with max GPU offload
    llama-server \
      --model "$MCRN_LLM_MODEL" \
      --port "$MCRN_LLM_PORT" \
      -ngl 99 \
      --threads "$(sysctl -n hw.ncpu 2>/dev/null || echo 4)" \
      > "$MCRN_LLM_LOG" 2>&1 &
    
    # Wait for server to become healthy
    local retries=0
    while ! curl -s "http://127.0.0.1:$MCRN_LLM_PORT/health" | grep -q '"status":"ok"'; do
      sleep 0.5
      ((retries++))
      if ((retries > 10)); then
        zle -M "[MCRN ERROR] LOCAL SERVER INIT FAILED. CHECK $MCRN_LLM_LOG"
        return 1
      fi
    done
    zle -M "[MCRN UPLINK] LOCAL SERVER ONLINE."
  fi
  return 0
}

_mcrn_ai_helpers_dir() {
  local script_path
  script_path="$MCRN_AI_PLUGIN_PATH"
  if [[ -z "$script_path" ]]; then
    script_path="${(%):-%x}"
  fi
  if [[ -z "$script_path" ]]; then
    script_path="$0"
  fi
  echo "${script_path:A:h}/mcrn-ai"
}

_mcrn_ai_debug_log() {
  if [[ -n "${MCRN_AI_DEBUG:-}" ]]; then
    printf '%s\n' "$1" >> "$MCRN_AI_DEBUG_LOG"
  fi
}

_mcrn_ai_call_copilot() {
  local helpers_dir
  helpers_dir="$(_mcrn_ai_helpers_dir)"
  local helper="$helpers_dir/copilot-helper.mjs"
  local sdk_dir="$helpers_dir/node_modules/@github/copilot-sdk"
  if [[ ! -f "$helper" ]]; then
    zle -M "[MCRN ERROR] COPILOT HELPER MISSING."
    return 1
  fi
  if [[ ! -d "$sdk_dir" ]]; then
    zle -M "[MCRN ERROR] COPILOT SDK NOT INSTALLED."
    return 1
  fi
  if [[ ! -x "$(command -v node)" ]]; then
    zle -M "[MCRN ERROR] NODE NOT FOUND."
    return 1
  fi
  if [[ ! -x "$(command -v copilot)" ]]; then
    zle -M "[MCRN ERROR] COPILOT CLI NOT FOUND."
    return 1
  fi
  _mcrn_ai_debug_log "copilot: invoking helper"
  NODE_NO_WARNINGS=1 printf '%s' "$1" | node "$helper" 2>>"$MCRN_AI_DEBUG_LOG"
}

_mcrn_ai_call_local() {
  local helpers_dir
  helpers_dir="$(_mcrn_ai_helpers_dir)"
  local helper="$helpers_dir/local-helper.sh"
  if [[ ! -f "$helper" ]]; then
    zle -M "[MCRN ERROR] LOCAL HELPER MISSING."
    return 1
  fi
  if [[ ! -x "$(command -v jq)" ]]; then
    zle -M "[MCRN ERROR] JQ NOT FOUND."
    return 1
  fi
  if [[ ! -f "$MCRN_LLM_MODEL" ]]; then
    zle -M "[MCRN ERROR] MODEL MISSING AT $MCRN_LLM_MODEL"
    return 1
  fi
  _mcrn_ensure_server || return 1
  _mcrn_ai_debug_log "local: invoking helper"
  printf '%s' "$1" | bash "$helper" 2>>"$MCRN_AI_DEBUG_LOG"
}

mcrn_ai_generate() {
  # If buffer is empty, try to retry the last query
  local user_input="${BUFFER}"
  if [[ -z "$user_input" ]]; then
    if [[ -n "$_MCRN_LAST_AI_QUERY" ]]; then
      user_input="$_MCRN_LAST_AI_QUERY"
      zle -M "[MCRN UPLINK] Retrying last query: $user_input"
    else
      return
    fi
  else
    # Store current input for future retries
    _MCRN_LAST_AI_QUERY="$user_input"
  fi

  if [[ ! -x "$(command -v jq)" ]]; then
    zle -M "[MCRN ERROR] JQ NOT FOUND."
    return
  fi

  # Show visual indicator that generation has started
  zle -M "[MCRN UPLINK] ACQUIRING COPILOT SIGNAL..."
  zle redisplay
  local result
  local command
  local confidence
  local provider
  if [[ "$MCRN_AI_PROVIDER" == "local" ]]; then
    result="$(_mcrn_ai_call_local "$user_input")"
  else
    result="$(_mcrn_ai_call_copilot "$user_input")"
  fi

  _mcrn_ai_debug_log "raw result: $result"

  command="$(printf '%s' "$result" | jq -r '.command // empty' 2>/dev/null)"
  confidence="$(printf '%s' "$result" | jq -r '.confidence // 0' 2>/dev/null)"
  provider="$(printf '%s' "$result" | jq -r '.provider // empty' 2>/dev/null)"

  if [[ -z "$command" && "$MCRN_AI_PROVIDER" != "local" ]]; then
    zle -M "[MCRN UPLINK] COPILOT SIGNAL LOST - FALLING BACK TO LOCAL..."
    zle redisplay
    result="$(_mcrn_ai_call_local "$user_input")"
    command="$(printf '%s' "$result" | jq -r '.command // empty' 2>/dev/null)"
    confidence="$(printf '%s' "$result" | jq -r '.confidence // 0' 2>/dev/null)"
    provider="$(printf '%s' "$result" | jq -r '.provider // empty' 2>/dev/null)"
    _mcrn_ai_debug_log "fallback result: $result"
  fi

  if [[ -z "$command" ]]; then
    if [[ "$MCRN_AI_PROVIDER" == "local" ]]; then
      zle -M "[MCRN ERROR] LOCAL UPLINK FAILED."
    else
      zle -M "[MCRN ERROR] UPLINK FAILED. CHECK COPILOT LOGIN."
    fi
    zle redisplay
    return
  fi

  if [[ "$provider" == "local" ]]; then
    local threshold
    threshold="$MCRN_AI_CONFIDENCE_MIN"
    if awk -v a="$confidence" -v b="$threshold" 'BEGIN { exit (a < b) ? 0 : 1 }'; then
      zle -M "[MCRN ERROR] LOCAL CONFIDENCE LOW. ABORTING."
      zle redisplay
      return
    fi
  fi

  BUFFER="$command"
  CURSOR=${#BUFFER}
  zle -M "[MCRN UPLINK] COMMAND RECEIVED. REVIEW BEFORE EXECUTION."
  zle redisplay
}

# Bind to Ctrl+G for generation
zle -N mcrn_ai_generate
bindkey '^g' mcrn_ai_generate

# Bind Ctrl+R to retry if you clear the buffer
# (Ctrl+R is usually history search, so we'll leave it as Ctrl+G, 
# since mcrn_ai_generate already retries when buffer is empty)
