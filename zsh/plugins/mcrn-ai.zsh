# ~/.dotfiles/zsh/plugins/mcrn-ai.zsh (repo path: ~/.dotfiles/zsh/plugins/mcrn-ai.zsh)
# MCRN Tactical Display - Real-Time AI ZLE Widget
# Generates shell commands from natural language without leaving the prompt.
# Engine: Copilot SDK
# Model: gpt-5-mini

# Model configuration variables
export MCRN_AI_TIMEOUT_MS="${MCRN_AI_TIMEOUT_MS:-12000}"
export MCRN_COPILOT_MODEL="${MCRN_COPILOT_MODEL:-gpt-5-mini}"
export MCRN_AI_PLUGIN_PATH="${MCRN_AI_PLUGIN_PATH:-${(%):-%x}}"
export MCRN_AI_DEBUG_LOG="${MCRN_AI_DEBUG_LOG:-/tmp/mcrn-ai-debug.log}"

# Global variable to store the last generated command for quick retry
typeset -g _MCRN_LAST_AI_QUERY=""

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
  local node_major
  node_major="$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0)"
  if (( node_major < 20 )); then
    zle -M "[MCRN ERROR] NODE 20+ REQUIRED FOR COPILOT SDK."
    return 1
  fi
  local in_git_repo="0"
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    in_git_repo="1"
  fi
  _mcrn_ai_debug_log "copilot: invoking helper"
  printf '%s' "$1" | MCRN_AI_IN_GIT_REPO="$in_git_repo" NODE_NO_WARNINGS=1 node "$helper" 2>>"$MCRN_AI_DEBUG_LOG"
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
  local error
  local error_code
  result="$(_mcrn_ai_call_copilot "$user_input")"

  _mcrn_ai_debug_log "raw result: $result"

  command="$(printf '%s' "$result" | jq -r '.command // empty' 2>/dev/null)"
  error="$(printf '%s' "$result" | jq -r '.error // empty' 2>/dev/null)"
  error_code="$(printf '%s' "$result" | jq -r '.error_code // empty' 2>/dev/null)"

  if [[ -z "$command" ]]; then
    case "$error_code" in
      copilot_cli_missing)
        zle -M "[MCRN ERROR] COPILOT CLI MISSING."
        ;;
      copilot_auth_required)
        zle -M "[MCRN ERROR] COPILOT AUTH REQUIRED."
        ;;
      copilot_model_rejected)
        zle -M "[MCRN ERROR] MODEL REJECTED: $MCRN_COPILOT_MODEL"
        ;;
      copilot_timeout)
        zle -M "[MCRN ERROR] COPILOT TIMEOUT."
        ;;
      copilot_sdk_missing)
        zle -M "[MCRN ERROR] COPILOT SDK NOT INSTALLED."
        ;;
      copilot_node_required)
        zle -M "[MCRN ERROR] NODE 20+ REQUIRED FOR COPILOT SDK."
        ;;
      *)
        if [[ -n "$error" ]]; then
          zle -M "[MCRN ERROR] COPILOT FAILED. CHECK /tmp/mcrn-ai-debug.log"
        else
          zle -M "[MCRN ERROR] NO COMMAND RETURNED."
        fi
        ;;
    esac
    zle redisplay
    return
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
