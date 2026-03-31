# ~/.dotfiles/zsh/plugins/mcrn-ai.zsh (repo path: ~/.dotfiles/zsh/plugins/mcrn-ai.zsh)
# MCRN Tactical Display - Real-Time AI ZLE Widget
# Generates shell commands from natural language without leaving the prompt.
# Engine: Copilot SDK
# Model: gpt-5-mini

# ── Configuration ────────────────────────────────────────────────────
export MCRN_AI_TIMEOUT_MS="${MCRN_AI_TIMEOUT_MS:-30000}"
export MCRN_COPILOT_MODEL="${MCRN_COPILOT_MODEL:-gpt-5-mini}"
export MCRN_AI_PLUGIN_PATH="${MCRN_AI_PLUGIN_PATH:-${(%):-%x}}"
export MCRN_AI_DEBUG_LOG="${MCRN_AI_DEBUG_LOG:-/tmp/mcrn-ai-debug.log}"

# ── State Variables (SAM-39/40/41/42/45) ─────────────────────────────
typeset -g  _MCRN_LAST_AI_QUERY=""
typeset -g  _MCRN_LAST_AI_PROMPT=""
typeset -g  _MCRN_LAST_AI_COMMAND=""
typeset -g  _MCRN_LAST_EXECUTED_COMMAND=""
typeset -g  _MCRN_LAST_EXIT_CODE="0"
typeset -g  _MCRN_AI_GENERATED_BUFFER=""
# Async state (SAM-45)
typeset -gi _MCRN_AI_ASYNC_ACTIVE=0
typeset -g  _MCRN_AI_ASYNC_MODE=""
typeset -g  _MCRN_AI_RESULT_FD=""
typeset -g  _MCRN_AI_SPINNER_FD=""
# Pending result (written by zle -F handler, consumed by apply widget)
typeset -g  _MCRN_AI_PENDING_CMD=""
typeset -g  _MCRN_AI_PENDING_EC=""
typeset -g  _MCRN_AI_PENDING_ERR=""
# Cached UI config (read once at load, avoids forking jq inside zle -F handlers)
typeset -g  _MCRN_AI_CFG_HIGHLIGHT_ENABLED=""
typeset -g  _MCRN_AI_CFG_HIGHLIGHT_STYLE=""
typeset -gi _MCRN_AI_SPINNER_IDX=0
typeset -ga _MCRN_AI_SPINNER_FRAMES=(
  "TARGETING."
  "TARGETING.."
  "TARGETING..."
  "TARGETING...."
)

# ── Hooks: track last command and exit code (SAM-40) ─────────────────
autoload -Uz add-zsh-hook

_mcrn_ai_preexec() {
  _MCRN_LAST_EXECUTED_COMMAND="$1"
}

_mcrn_ai_precmd() {
  _MCRN_LAST_EXIT_CODE="$?"
}

add-zsh-hook preexec _mcrn_ai_preexec
add-zsh-hook precmd  _mcrn_ai_precmd

# ── Highlight clear hook (SAM-42) ────────────────────────────────────
_mcrn_ai_clear_highlight() {
  if [[ -n "$_MCRN_AI_GENERATED_BUFFER" && "$BUFFER" != "$_MCRN_AI_GENERATED_BUFFER" ]]; then
    region_highlight=()
    _MCRN_AI_GENERATED_BUFFER=""
  fi
}

if autoload -Uz add-zle-hook-widget 2>/dev/null; then
  add-zle-hook-widget line-pre-redraw _mcrn_ai_clear_highlight 2>/dev/null || true
fi

# ── Config Reader (SAM-44) ───────────────────────────────────────────
typeset -g _MCRN_AI_CONFIG_CACHE=""
typeset -g _MCRN_AI_CONFIG_PATH=""

_mcrn_ai_read_config() {
  local key="$1" default="$2"
  if [[ -z "$_MCRN_AI_CONFIG_PATH" ]]; then
    local dir
    dir="$(_mcrn_ai_helpers_dir)"
    _MCRN_AI_CONFIG_PATH="${MCRN_AI_CONFIG_FILE:-$dir/config.json}"
  fi
  if [[ ! -f "$_MCRN_AI_CONFIG_PATH" ]]; then
    echo "$default"
    return
  fi
  local val
  val="$(jq -r "$key // empty" "$_MCRN_AI_CONFIG_PATH" 2>/dev/null)"
  if [[ -n "$val" ]]; then
    echo "$val"
  else
    echo "$default"
  fi
}

# ── Internals ────────────────────────────────────────────────────────
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

# Cache UI config at load time (safe to fork jq here, outside ZLE context)
_MCRN_AI_CFG_HIGHLIGHT_ENABLED="$(_mcrn_ai_read_config '.ui.highlightAiBuffer' 'true')"
_MCRN_AI_CFG_HIGHLIGHT_STYLE="$(_mcrn_ai_read_config '.ui.highlightStyle' 'underline')"

# ── Mode Detection (SAM-39/40/41) ───────────────────────────────────
_mcrn_ai_detect_mode() {
  local buffer="$1"
  if [[ -z "$buffer" && "$_MCRN_LAST_EXIT_CODE" != "0" && -n "$_MCRN_LAST_EXECUTED_COMMAND" ]]; then
    echo "fix"
    return
  fi
  if [[ -n "$buffer" && -n "$_MCRN_LAST_AI_COMMAND" ]]; then
    local lower="${(L)buffer}"
    case "$lower" in
      but*|also*|instead*|actually*|change*|make\ it*|add*|remove*|use*|with*|without*|try*|now*|and\ also*)
        echo "refine"
        return
        ;;
    esac
  fi
  echo "generate"
}

# ── Payload Builder (SAM-39/44) ─────────────────────────────────────
_mcrn_ai_build_payload() {
  local prompt="$1"
  local mode="$2"

  local history_count
  history_count="$(_mcrn_ai_read_config '.context.recentHistoryCount' '5')"
  local include_git
  include_git="$(_mcrn_ai_read_config '.context.includeGitSummary' 'true')"
  local include_failure
  include_failure="$(_mcrn_ai_read_config '.context.includeLastFailure' 'true')"

  local recent_history=""
  if (( history_count > 0 )); then
    if (( $+commands[fc] )) || whence -w fc >/dev/null 2>&1; then
      recent_history="$(fc -l -${history_count} 2>/dev/null | sed 's/^[[:space:]]*[0-9]*[[:space:]]*//' || echo "")"
    fi
  fi

  local git_summary=""
  if [[ "$include_git" == "true" ]]; then
    if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      local branch dirty=""
      branch="$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null || echo "detached")"
      if ! git diff --quiet HEAD 2>/dev/null; then
        dirty=" [dirty]"
      fi
      git_summary="${branch}${dirty}"
    fi
  fi

  local last_failure=""
  if [[ "$mode" == "fix" && "$include_failure" == "true" ]]; then
    last_failure="$_MCRN_LAST_EXECUTED_COMMAND (exit $_MCRN_LAST_EXIT_CODE)"
  fi

  local prior_prompt="" prior_command=""
  if [[ "$mode" == "refine" ]]; then
    prior_prompt="$_MCRN_LAST_AI_PROMPT"
    prior_command="$_MCRN_LAST_AI_COMMAND"
  fi

  jq -n -c \
    --arg prompt "$prompt" \
    --arg mode "$mode" \
    --arg recent_history "$recent_history" \
    --arg git_summary "$git_summary" \
    --arg last_failure "$last_failure" \
    --arg prior_prompt "$prior_prompt" \
    --arg prior_command "$prior_command" \
    '{
      prompt: $prompt,
      mode: $mode,
      recentHistory: $recent_history,
      gitSummary: $git_summary,
      lastFailure: $last_failure,
      priorAi: {
        prompt: $prior_prompt,
        command: $prior_command
      }
    }'
}

# ── Copilot Preflight Checks ────────────────────────────────────────
# Returns 0 if all prerequisites are met, 1 otherwise.
_mcrn_ai_preflight() {
  local helpers_dir
  helpers_dir="$(_mcrn_ai_helpers_dir)"
  if [[ ! -f "$helpers_dir/copilot-helper.mjs" ]]; then
    zle -M "[MCRN ERROR] COPILOT HELPER MISSING."
    return 1
  fi
  if [[ ! -d "$helpers_dir/node_modules/@github/copilot-sdk" ]]; then
    zle -M "[MCRN ERROR] COPILOT SDK NOT INSTALLED. RUN NPM CI IN ~/.DOTFILES/ZSH/PLUGINS/MCRN-AI"
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
  return 0
}

# ── Async Spinner Handler (SAM-45) ──────────────────────────────────
_mcrn_ai_spinner_handler() {
  local fd="$1"
  local line=""
  if ! read -r -u "$fd" line 2>/dev/null; then
    # Spinner process ended (SIGPIPE from fd close or natural exit)
    zle -F "$fd" 2>/dev/null
    builtin exec {fd}<&- 2>/dev/null
    _MCRN_AI_SPINNER_FD=""
    return
  fi
  if (( _MCRN_AI_ASYNC_ACTIVE )); then
    _MCRN_AI_SPINNER_IDX=$(( (_MCRN_AI_SPINNER_IDX % ${#_MCRN_AI_SPINNER_FRAMES[@]}) + 1 ))
    zle -M "[MCRN UPLINK] ${_MCRN_AI_SPINNER_FRAMES[$_MCRN_AI_SPINNER_IDX]}"
    zle -R
  fi
}

# ── Async Result Handler (SAM-45) ───────────────────────────────────
# Pattern from zsh-autosuggestions: zle -F handlers CANNOT modify BUFFER
# directly — changes are discarded when the handler returns. Instead, store
# the result in globals and invoke a proper ZLE widget with `zle <name>`.
_mcrn_ai_result_handler() {
  emulate -L zsh
  local fd=$1

  # Stop spinner
  _MCRN_AI_ASYNC_ACTIVE=0
  if [[ -n "$_MCRN_AI_SPINNER_FD" ]]; then
    zle -F "$_MCRN_AI_SPINNER_FD" 2>/dev/null
    builtin exec {_MCRN_AI_SPINNER_FD}<&- 2>/dev/null
    _MCRN_AI_SPINNER_FD=""
  fi

  if [[ -z "$2" || "$2" == "hup" ]]; then
    # Read pre-extracted fields directly from the pipe (builtins only).
    # Format: line 1 = error_code, line 2 = error, rest = command.
    read -r -u $fd _MCRN_AI_PENDING_EC 2>/dev/null
    read -r -u $fd _MCRN_AI_PENDING_ERR 2>/dev/null
    IFS='' read -rd '' -u $fd _MCRN_AI_PENDING_CMD 2>/dev/null

    _mcrn_ai_debug_log "pipe read: cmd='${_MCRN_AI_PENDING_CMD}' ec='${_MCRN_AI_PENDING_EC}' err='${_MCRN_AI_PENDING_ERR}'"

    # Apply result via proper ZLE widget — only way BUFFER changes persist
    zle _mcrn_ai_apply_result
  fi

  # Clean up fd (after widget call so pipe stays open during read)
  builtin exec {fd}<&- 2>/dev/null
  zle -F "$fd" 2>/dev/null
  _MCRN_AI_RESULT_FD=""
}

# ── Apply Result Widget ─────────────────────────────────────────────
# Registered as a ZLE widget so BUFFER modifications persist (the correct
# async pattern, matching zsh-autosuggestions).
_mcrn_ai_apply_result() {
  local command="$_MCRN_AI_PENDING_CMD"
  local error="$_MCRN_AI_PENDING_ERR"
  local error_code="$_MCRN_AI_PENDING_EC"
  local mode="$_MCRN_AI_ASYNC_MODE"

  _MCRN_AI_PENDING_CMD=""
  _MCRN_AI_PENDING_ERR=""
  _MCRN_AI_PENDING_EC=""

  _mcrn_ai_debug_log "apply_result widget: cmd_len=${#command} ec='$error_code' mode=$mode"

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
        zle -M "[MCRN ERROR] COPILOT SDK NOT INSTALLED. RUN NPM CI IN ~/.DOTFILES/ZSH/PLUGINS/MCRN-AI"
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
    zle -R
    return
  fi

  # Store AI state for future refinement (SAM-41)
  _MCRN_LAST_AI_PROMPT="$_MCRN_AI_ASYNC_EFFECTIVE_PROMPT"
  _MCRN_LAST_AI_COMMAND="$command"

  # Set buffer and cursor
  BUFFER="$command"
  CURSOR=${#BUFFER}

  _mcrn_ai_debug_log "BUFFER set: len=${#BUFFER}"

  # Apply visual highlight using cached config (SAM-42/44)
  if [[ "$_MCRN_AI_CFG_HIGHLIGHT_ENABLED" == "true" && "$_MCRN_AI_CFG_HIGHLIGHT_STYLE" != "none" ]]; then
    _MCRN_AI_GENERATED_BUFFER="$BUFFER"
    region_highlight=("0 ${#BUFFER} ${_MCRN_AI_CFG_HIGHLIGHT_STYLE}")
  fi

  case "$mode" in
    fix)
      zle -M "[MCRN UPLINK] FIX APPLIED. REVIEW BEFORE EXECUTION."
      ;;
    refine)
      zle -M "[MCRN UPLINK] COMMAND REFINED. REVIEW BEFORE EXECUTION."
      ;;
    *)
      zle -M "[MCRN UPLINK] COMMAND RECEIVED. REVIEW BEFORE EXECUTION."
      ;;
  esac
  zle -R
}
zle -N _mcrn_ai_apply_result

# ── Cancel In-Flight Request ────────────────────────────────────────
_mcrn_ai_cancel_async() {
  if (( ! _MCRN_AI_ASYNC_ACTIVE )); then
    return
  fi
  _MCRN_AI_ASYNC_ACTIVE=0
  if [[ -n "$_MCRN_AI_RESULT_FD" ]]; then
    zle -F "$_MCRN_AI_RESULT_FD" 2>/dev/null
    builtin exec {_MCRN_AI_RESULT_FD}<&- 2>/dev/null
    _MCRN_AI_RESULT_FD=""
  fi
  if [[ -n "$_MCRN_AI_SPINNER_FD" ]]; then
    zle -F "$_MCRN_AI_SPINNER_FD" 2>/dev/null
    builtin exec {_MCRN_AI_SPINNER_FD}<&- 2>/dev/null
    _MCRN_AI_SPINNER_FD=""
  fi
  zle -M "[MCRN UPLINK] REQUEST CANCELLED."
  zle -R
}

# ── Main ZLE Widget ─────────────────────────────────────────────────
typeset -g _MCRN_AI_ASYNC_EFFECTIVE_PROMPT=""

mcrn_ai_generate() {
  # If a request is already in flight, cancel it first
  if (( _MCRN_AI_ASYNC_ACTIVE )); then
    _mcrn_ai_cancel_async
    return
  fi

  local user_input="${BUFFER}"

  _mcrn_ai_debug_log "widget fired: BUFFER='$user_input'"

  if [[ ! -x "$(command -v jq)" ]]; then
    zle -M "[MCRN ERROR] JQ NOT FOUND."
    return
  fi

  # Preflight checks
  _mcrn_ai_preflight || return

  _mcrn_ai_debug_log "preflight passed"

  # Detect mode (SAM-39/40/41)
  local mode
  mode="$(_mcrn_ai_detect_mode "$user_input")"

  _mcrn_ai_debug_log "mode=$mode"

  # Determine the effective prompt
  local effective_prompt=""
  case "$mode" in
    fix)
      effective_prompt="fix the last command that failed"
      zle -M "[MCRN UPLINK] FIX MODE: ANALYZING FAILED COMMAND..."
      ;;
    refine)
      effective_prompt="$user_input"
      zle -M "[MCRN UPLINK] REFINE MODE: ADJUSTING PRIOR COMMAND..."
      ;;
    generate)
      if [[ -z "$user_input" ]]; then
        if [[ -n "$_MCRN_LAST_AI_QUERY" ]]; then
          user_input="$_MCRN_LAST_AI_QUERY"
          effective_prompt="$user_input"
          zle -M "[MCRN UPLINK] RETRYING LAST QUERY: $user_input"
        else
          return
        fi
      else
        effective_prompt="$user_input"
        _MCRN_LAST_AI_QUERY="$user_input"
        zle -M "[MCRN UPLINK] TARGETING..."
      fi
      ;;
  esac

  # Store for result handler
  _MCRN_AI_ASYNC_EFFECTIVE_PROMPT="$effective_prompt"

  # Build structured payload (SAM-39)
  local payload
  payload="$(_mcrn_ai_build_payload "$effective_prompt" "$mode")"
  _mcrn_ai_debug_log "payload: $payload"

  if [[ -z "$payload" ]]; then
    zle -M "[MCRN ERROR] PAYLOAD BUILD FAILED."
    return
  fi

  # Launch async (SAM-45)
  local helpers_dir
  helpers_dir="$(_mcrn_ai_helpers_dir)"
  local helper="$helpers_dir/copilot-helper.mjs"
  _MCRN_AI_ASYNC_MODE="$mode"
  _MCRN_AI_ASYNC_ACTIVE=1
  _MCRN_AI_SPINNER_IDX=0

  _mcrn_ai_debug_log "async setup: helper=$helper"

  # Spinner subprocess: writes a line every 300ms for zle -F to pick up
  builtin exec {_MCRN_AI_SPINNER_FD}< <(
    while true; do
      sleep 0.3
      printf 'tick\n'
    done
  )
  zle -F "$_MCRN_AI_SPINNER_FD" _mcrn_ai_spinner_handler

  _mcrn_ai_debug_log "spinner fd=$_MCRN_AI_SPINNER_FD"

  # Copilot subprocess: pipe pre-extracted fields directly to stdout.
  # Format: line 1 = error_code, line 2 = error, remaining = command.
  # The zle -F handler reads these with builtins and delegates to the
  # _mcrn_ai_apply_result widget (the only way BUFFER changes persist).
  local stderr_target="/dev/null"
  if [[ -n "${MCRN_AI_DEBUG:-}" ]]; then
    stderr_target="$MCRN_AI_DEBUG_LOG"
  fi
  builtin exec {_MCRN_AI_RESULT_FD}< <(
    local raw
    raw="$(printf '%s' "$payload" | MCRN_AI_DEBUG="${MCRN_AI_DEBUG:-}" NODE_NO_WARNINGS=1 node "$helper" 2>>"$stderr_target")"
    local ec err cmd
    ec="$(printf '%s' "$raw" | jq -r '.error_code // empty' 2>/dev/null)"
    err="$(printf '%s' "$raw" | jq -r '.error // empty' 2>/dev/null)"
    cmd="$(printf '%s' "$raw" | jq -r '.command // empty' 2>/dev/null)"
    # Write structured output: one field per protocol line
    printf '%s\n' "$ec"
    printf '%s\n' "$err"
    printf '%s' "$cmd"
  )
  zle -F "$_MCRN_AI_RESULT_FD" _mcrn_ai_result_handler

  _mcrn_ai_debug_log "result fd=$_MCRN_AI_RESULT_FD launched"

  zle -R
}

# ── Key Bindings ─────────────────────────────────────────────────────
zle -N mcrn_ai_generate
bindkey '^g' mcrn_ai_generate
bindkey -M viins '^g' mcrn_ai_generate 2>/dev/null || true
bindkey -M vicmd '^g' mcrn_ai_generate 2>/dev/null || true
