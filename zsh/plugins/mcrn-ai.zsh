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
# Daemon state
typeset -gi _MCRN_AI_DAEMON_PORT=0
typeset -gi _MCRN_AI_DAEMON_PID=0
typeset -gi _MCRN_AI_USING_DAEMON=0
typeset -g  _MCRN_AI_CFG_DAEMON_ENABLED=""
# Ghost-text suggest state
typeset -g  _MCRN_AI_GHOST_TEXT=""
typeset -g  _MCRN_AI_GHOST_FD=""
typeset -gi _MCRN_AI_LAST_SUGGEST_TS=0
typeset -g  _MCRN_AI_CFG_SUGGEST_ENABLED=""
typeset -g  _MCRN_AI_CFG_SUGGEST_GHOST_STYLE=""
typeset -g  _MCRN_AI_CFG_SUGGEST_RATE_LIMIT_MS=""
typeset -g  _MCRN_AI_CFG_SUGGEST_SKIP_CMDS=""
# NL detection state
typeset -g  _MCRN_AI_CFG_NL_ENABLED=""
typeset -g  _MCRN_AI_CFG_NL_MIN_WORDS=""
typeset -g  _MCRN_AI_CFG_NL_INDICATOR=""
# Autofix state
typeset -g  _MCRN_AI_CFG_AUTOFIX_ENABLED=""
typeset -g  _MCRN_AI_CFG_AUTOFIX_MODE=""
# Stderr capture state
typeset -g  _MCRN_AI_LAST_STDERR=""
typeset -g  _MCRN_AI_STDERR_FILE="/tmp/mcrn-ai-stderr-$$.log"
# Candidate cycling state
typeset -ga _MCRN_AI_CANDIDATES=()
typeset -gi _MCRN_AI_CANDIDATE_IDX=0

# ── Hooks: track last command, exit code, and stderr (SAM-40) ────────
autoload -Uz add-zsh-hook

_mcrn_ai_preexec() {
  _MCRN_LAST_EXECUTED_COMMAND="$1"
  # Reset stderr capture file for next command
  if [[ -n "$_MCRN_AI_STDERR_FILE" ]]; then
    : > "$_MCRN_AI_STDERR_FILE" 2>/dev/null
  fi
}

_mcrn_ai_precmd() {
  _MCRN_LAST_EXIT_CODE="$?"
  # Read captured stderr (populated by wrapper, if enabled)
  if [[ -s "$_MCRN_AI_STDERR_FILE" ]]; then
    _MCRN_AI_LAST_STDERR="$(tail -50 "$_MCRN_AI_STDERR_FILE" 2>/dev/null)"
  else
    _MCRN_AI_LAST_STDERR=""
  fi
}

add-zsh-hook preexec _mcrn_ai_preexec
add-zsh-hook precmd  _mcrn_ai_precmd

# ── Highlight + ghost-text clear hook ─────────────────────────────────
if autoload -Uz add-zle-hook-widget 2>/dev/null; then
  add-zle-hook-widget line-pre-redraw _mcrn_ai_ghost_line_changed 2>/dev/null || true
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
_MCRN_AI_CFG_DAEMON_ENABLED="$(_mcrn_ai_read_config '.daemon.enabled' 'true')"
_MCRN_AI_CFG_SUGGEST_ENABLED="$(_mcrn_ai_read_config '.suggest.enabled' 'false')"
_MCRN_AI_CFG_SUGGEST_GHOST_STYLE="$(_mcrn_ai_read_config '.suggest.ghostStyle' 'fg=240')"
_MCRN_AI_CFG_SUGGEST_RATE_LIMIT_MS="$(_mcrn_ai_read_config '.suggest.rateLimitMs' '2000')"
_MCRN_AI_CFG_SUGGEST_SKIP_CMDS="$(_mcrn_ai_read_config '.suggest.skipCommands | join(",")' 'cd,ls,clear,pwd,exit,true,false')"
_MCRN_AI_CFG_NL_ENABLED="$(_mcrn_ai_read_config '.nlDetection.enabled' 'false')"
_MCRN_AI_CFG_NL_MIN_WORDS="$(_mcrn_ai_read_config '.nlDetection.minWords' '3')"
_MCRN_AI_CFG_NL_INDICATOR="$(_mcrn_ai_read_config '.nlDetection.indicator' '[MCRN NL]')"
_MCRN_AI_CFG_AUTOFIX_ENABLED="$(_mcrn_ai_read_config '.autofix.enabled' 'false')"
_MCRN_AI_CFG_AUTOFIX_MODE="$(_mcrn_ai_read_config '.autofix.displayMode' 'banner')"

# ── Daemon Lifecycle ─────────────────────────────────────────────────
_mcrn_ai_daemon_state_file() {
  echo "/tmp/mcrn-ai-daemon-${UID}.json"
}

_mcrn_ai_daemon_is_running() {
  local state_file
  state_file="$(_mcrn_ai_daemon_state_file)"
  [[ -f "$state_file" ]] || return 1

  local pid
  pid="$(jq -r '.pid // empty' "$state_file" 2>/dev/null)"
  [[ -n "$pid" ]] || return 1

  kill -0 "$pid" 2>/dev/null || {
    rm -f "$state_file" 2>/dev/null
    return 1
  }
  return 0
}

_mcrn_ai_daemon_read_state() {
  local state_file
  state_file="$(_mcrn_ai_daemon_state_file)"
  _MCRN_AI_DAEMON_PORT="$(jq -r '.port // empty' "$state_file" 2>/dev/null)"
  _MCRN_AI_DAEMON_PID="$(jq -r '.pid // empty' "$state_file" 2>/dev/null)"
}

_mcrn_ai_daemon_start() {
  local helpers_dir
  helpers_dir="$(_mcrn_ai_helpers_dir)"
  local state_file
  state_file="$(_mcrn_ai_daemon_state_file)"

  rm -f "$state_file" 2>/dev/null

  local stderr_target="/dev/null"
  if [[ -n "${MCRN_AI_DEBUG:-}" ]]; then
    stderr_target="$MCRN_AI_DEBUG_LOG"
  fi

  NODE_NO_WARNINGS=1 node "$helpers_dir/copilot-daemon.mjs" --tcp \
    2>>"$stderr_target" &!

  local attempts=0
  while (( attempts < 50 )) && [[ ! -f "$state_file" ]]; do
    sleep 0.1
    (( attempts++ ))
  done

  if [[ ! -f "$state_file" ]]; then
    _mcrn_ai_debug_log "daemon start failed: state file not created"
    return 1
  fi

  _mcrn_ai_daemon_read_state
  _mcrn_ai_debug_log "daemon started: pid=$_MCRN_AI_DAEMON_PID port=$_MCRN_AI_DAEMON_PORT"
  return 0
}

_mcrn_ai_daemon_ensure() {
  [[ "$_MCRN_AI_CFG_DAEMON_ENABLED" == "true" ]] || return 1

  if _mcrn_ai_daemon_is_running; then
    if (( _MCRN_AI_DAEMON_PORT == 0 )); then
      _mcrn_ai_daemon_read_state
      _mcrn_ai_debug_log "daemon reconnected: pid=$_MCRN_AI_DAEMON_PID port=$_MCRN_AI_DAEMON_PORT"
    fi
    return 0
  fi

  _mcrn_ai_debug_log "daemon not running, starting..."
  _mcrn_ai_daemon_start
}

# ── Ghost-Text Suggestions ───────────────────────────────────────────
_mcrn_ai_ghost_clear() {
  if [[ -n "$_MCRN_AI_GHOST_TEXT" ]]; then
    _MCRN_AI_GHOST_TEXT=""
    POSTDISPLAY=""
    region_highlight=("${(@)region_highlight:#*postdisplay*}")
  fi
}

_mcrn_ai_ghost_render() {
  local suggestion="$1"
  if [[ -z "$suggestion" ]]; then
    _mcrn_ai_ghost_clear
    return
  fi
  _MCRN_AI_GHOST_TEXT="$suggestion"
  POSTDISPLAY="$suggestion"
  _mcrn_ai_debug_log "ghost render: '${suggestion:0:80}'"
}

_mcrn_ai_ghost_accept_full() {
  if [[ -z "$_MCRN_AI_GHOST_TEXT" ]]; then
    # No ghost text — pass through to default right-arrow behavior
    zle forward-char
    return
  fi
  _mcrn_ai_debug_log "ghost accept full: '${_MCRN_AI_GHOST_TEXT:0:80}'"
  BUFFER="${BUFFER}${_MCRN_AI_GHOST_TEXT}"
  CURSOR=${#BUFFER}
  _mcrn_ai_ghost_clear
}

_mcrn_ai_ghost_accept_word() {
  if [[ -z "$_MCRN_AI_GHOST_TEXT" ]]; then
    zle forward-word
    return
  fi
  local ghost="$_MCRN_AI_GHOST_TEXT"
  # Extract next word (up to whitespace boundary)
  local word="${ghost%%[[:space:]]*}"
  local rest="${ghost#"$word"}"
  # Include trailing whitespace with the word
  if [[ "$rest" == [[:space:]]* ]]; then
    word="${word}${rest%%[^[:space:]]*}"
    rest="${rest#${rest%%[^[:space:]]*}}"
  fi
  BUFFER="${BUFFER}${word}"
  CURSOR=${#BUFFER}
  if [[ -n "$rest" ]]; then
    _MCRN_AI_GHOST_TEXT="$rest"
    POSTDISPLAY="$rest"
  else
    _mcrn_ai_ghost_clear
  fi
}

# Clear ghost text on any buffer change
_mcrn_ai_ghost_line_changed() {
  if [[ -n "$_MCRN_AI_GHOST_TEXT" && -n "$BUFFER" ]]; then
    # If user started typing, clear ghost
    _mcrn_ai_ghost_clear
  fi
  # Also handle AI highlight clearing
  if [[ -n "$_MCRN_AI_GENERATED_BUFFER" && "$BUFFER" != "$_MCRN_AI_GENERATED_BUFFER" ]]; then
    region_highlight=()
    _MCRN_AI_GENERATED_BUFFER=""
  fi
}

# Suggest result handler (async, lightweight)
_mcrn_ai_suggest_result_handler() {
  local fd=$1
  local line=""

  if [[ -z "$2" || "$2" == "hup" ]]; then
    read -r -u $fd line 2>/dev/null
    read -r -u $fd line 2>/dev/null  # skip error line
    local cmd=""
    IFS='' read -rd '' -u $fd cmd 2>/dev/null
    _mcrn_ai_debug_log "suggest result: '$cmd'"

    # Only show if buffer is still empty (user hasn't started typing)
    if [[ -z "$BUFFER" && -n "$cmd" ]]; then
      _mcrn_ai_ghost_render "$cmd"
      zle -R
    fi
  fi

  if (( _MCRN_AI_USING_DAEMON )); then
    ztcp -c "$fd" 2>/dev/null
  else
    builtin exec {fd}<&- 2>/dev/null
  fi
  zle -F "$fd" 2>/dev/null
  _MCRN_AI_GHOST_FD=""
}

_mcrn_ai_request_suggest() {
  [[ "$_MCRN_AI_CFG_SUGGEST_ENABLED" == "true" ]] || return

  # Rate limit
  local now_ms
  now_ms=$(( $(date +%s) * 1000 ))
  local elapsed=$(( now_ms - _MCRN_AI_LAST_SUGGEST_TS ))
  if (( elapsed < _MCRN_AI_CFG_SUGGEST_RATE_LIMIT_MS )); then
    return
  fi
  _MCRN_AI_LAST_SUGGEST_TS=$now_ms

  # Skip trivial commands
  local cmd_name="${_MCRN_LAST_EXECUTED_COMMAND%% *}"
  if [[ ",$_MCRN_AI_CFG_SUGGEST_SKIP_CMDS," == *",$cmd_name,"* ]]; then
    return
  fi

  # Need daemon for suggestions
  _mcrn_ai_daemon_ensure 2>/dev/null || return

  zmodload -e zsh/net/tcp || zmodload zsh/net/tcp 2>/dev/null || return

  _mcrn_ai_debug_log "suggest: requesting for '$_MCRN_LAST_EXECUTED_COMMAND' (exit $_MCRN_LAST_EXIT_CODE)"

  # Cancel any in-flight suggest
  if [[ -n "$_MCRN_AI_GHOST_FD" ]]; then
    ztcp -c "$_MCRN_AI_GHOST_FD" 2>/dev/null
    zle -F "$_MCRN_AI_GHOST_FD" 2>/dev/null
    _MCRN_AI_GHOST_FD=""
  fi

  ztcp 127.0.0.1 "$_MCRN_AI_DAEMON_PORT" 2>/dev/null || return
  local tcp_fd=$REPLY

  local history_snippet=""
  if whence -w fc >/dev/null 2>&1; then
    history_snippet="$(fc -l -5 2>/dev/null | sed 's/^[[:space:]]*[0-9]*[[:space:]]*//' || echo "")"
  fi

  # JSON-escape the history
  local escaped_history
  escaped_history="$(printf '%s' "$history_snippet" | jq -Rs '.' 2>/dev/null || echo '""')"
  local escaped_cmd
  escaped_cmd="$(printf '%s' "$_MCRN_LAST_EXECUTED_COMMAND" | jq -Rs '.' 2>/dev/null || echo '""')"

  local request="{\"id\":${RANDOM},\"type\":\"suggest\",\"format\":\"zle\",\"payload\":{\"lastCommand\":${escaped_cmd},\"exitCode\":${_MCRN_LAST_EXIT_CODE:-0},\"cwd\":\"${PWD}\",\"home\":\"${HOME}\",\"recentHistory\":${escaped_history}}}"

  print -u "$tcp_fd" "$request"

  _MCRN_AI_GHOST_FD=$tcp_fd
  _MCRN_AI_USING_DAEMON=1
  zle -F "$tcp_fd" _mcrn_ai_suggest_result_handler
}

# Hook into precmd for passive suggestions
_mcrn_ai_suggest_precmd() {
  [[ "$_MCRN_AI_CFG_SUGGEST_ENABLED" == "true" ]] || return
  # Only suggest if we actually ran a command (not just pressing Enter)
  [[ -n "$_MCRN_LAST_EXECUTED_COMMAND" ]] || return
  # Schedule suggestion (will be picked up by ZLE event loop)
  # Use sched for debounce, or just request directly
  _mcrn_ai_request_suggest 2>/dev/null
}

add-zsh-hook precmd _mcrn_ai_suggest_precmd

# Register ghost-text widgets
zle -N _mcrn_ai_ghost_accept_full
zle -N _mcrn_ai_ghost_accept_word
zle -N _mcrn_ai_suggest_result_handler

# ── Natural Language Auto-Detection ──────────────────────────────────
# Pure-ZSH heuristic: if input starts with a word that is NOT a known command
# and contains >= minWords, classify as natural language.
_mcrn_ai_is_natural_language() {
  local input="$1"
  [[ -n "$input" ]] || return 1

  # Count words
  local -a words=( ${(z)input} )
  (( ${#words} >= _MCRN_AI_CFG_NL_MIN_WORDS )) || return 1

  local first_word="${words[1]}"

  # Skip if starts with path, variable, or special chars
  case "$first_word" in
    /*|~*|./*|../*|'$'*|'!'*|'#'*) return 1 ;;
  esac

  # Check if first word is a known command, alias, function, or builtin
  if (( $+commands[$first_word] )) || \
     (( $+aliases[$first_word] )) || \
     (( $+functions[$first_word] )) || \
     whence -w "$first_word" >/dev/null 2>&1; then
    return 1
  fi

  return 0
}

# Custom accept-line that intercepts NL input
_mcrn_ai_accept_line() {
  if [[ "$_MCRN_AI_CFG_NL_ENABLED" == "true" ]] && \
     _mcrn_ai_is_natural_language "$BUFFER"; then
    _mcrn_ai_debug_log "NL detected: '$BUFFER'"
    # Route to AI generation instead of shell execution
    mcrn_ai_generate
    return
  fi
  # Clear ghost text before executing
  _mcrn_ai_ghost_clear
  _mcrn_ai_debug_log "accept-line: executing shell command"
  zle .accept-line
}
zle -N accept-line _mcrn_ai_accept_line

# Escape key bypasses NL detection (forces shell execution)
_mcrn_ai_force_execute() {
  _mcrn_ai_ghost_clear
  zle .accept-line
}
zle -N _mcrn_ai_force_execute
bindkey '^[^M' _mcrn_ai_force_execute 2>/dev/null || true  # Esc+Enter

# ── Candidate Cycling ────────────────────────────────────────────────
_mcrn_ai_cycle_next() {
  (( ${#_MCRN_AI_CANDIDATES} > 1 )) || return
  _MCRN_AI_CANDIDATE_IDX=$(( (_MCRN_AI_CANDIDATE_IDX % ${#_MCRN_AI_CANDIDATES}) + 1 ))
  local candidate="${_MCRN_AI_CANDIDATES[$_MCRN_AI_CANDIDATE_IDX]}"
  BUFFER="$candidate"
  CURSOR=${#BUFFER}
  _MCRN_LAST_AI_COMMAND="$candidate"
  zle -M "[MCRN UPLINK] CANDIDATE ${_MCRN_AI_CANDIDATE_IDX}/${#_MCRN_AI_CANDIDATES}"
  zle -R
}

_mcrn_ai_cycle_prev() {
  (( ${#_MCRN_AI_CANDIDATES} > 1 )) || return
  _MCRN_AI_CANDIDATE_IDX=$(( _MCRN_AI_CANDIDATE_IDX - 1 ))
  (( _MCRN_AI_CANDIDATE_IDX < 1 )) && _MCRN_AI_CANDIDATE_IDX=${#_MCRN_AI_CANDIDATES}
  local candidate="${_MCRN_AI_CANDIDATES[$_MCRN_AI_CANDIDATE_IDX]}"
  BUFFER="$candidate"
  CURSOR=${#BUFFER}
  _MCRN_LAST_AI_COMMAND="$candidate"
  zle -M "[MCRN UPLINK] CANDIDATE ${_MCRN_AI_CANDIDATE_IDX}/${#_MCRN_AI_CANDIDATES}"
  zle -R
}

zle -N _mcrn_ai_cycle_next
zle -N _mcrn_ai_cycle_prev
bindkey '^[]' _mcrn_ai_cycle_next 2>/dev/null || true    # Alt+]
bindkey '^[[' _mcrn_ai_cycle_prev 2>/dev/null || true    # Alt+[

# ── Proactive Autofix ────────────────────────────────────────────────
_mcrn_ai_autofix_precmd() {
  [[ "$_MCRN_AI_CFG_AUTOFIX_ENABLED" == "true" ]] || return
  # Only trigger on non-zero exit
  [[ "$_MCRN_LAST_EXIT_CODE" != "0" ]] || return
  [[ -n "$_MCRN_LAST_EXECUTED_COMMAND" ]] || return

  _mcrn_ai_debug_log "autofix: command='$_MCRN_LAST_EXECUTED_COMMAND' exit=$_MCRN_LAST_EXIT_CODE"

  # Need daemon for autofix
  _mcrn_ai_daemon_ensure 2>/dev/null || return
  zmodload -e zsh/net/tcp || zmodload zsh/net/tcp 2>/dev/null || return

  ztcp 127.0.0.1 "$_MCRN_AI_DAEMON_PORT" 2>/dev/null || return
  local tcp_fd=$REPLY

  local escaped_cmd
  escaped_cmd="$(printf '%s' "$_MCRN_LAST_EXECUTED_COMMAND" | jq -Rs '.' 2>/dev/null || echo '""')"
  local escaped_stderr
  escaped_stderr="$(printf '%s' "$_MCRN_AI_LAST_STDERR" | jq -Rs '.' 2>/dev/null || echo '""')"

  local payload="{\"prompt\":\"fix the last command that failed\",\"mode\":\"fix\",\"recentHistory\":\"\",\"gitSummary\":\"\",\"lastFailure\":${escaped_cmd},\"lastStderr\":${escaped_stderr},\"priorAi\":{\"prompt\":\"\",\"command\":\"\"}}"
  local request="{\"id\":${RANDOM},\"type\":\"generate\",\"format\":\"zle\",\"payload\":${payload}}"

  print -u "$tcp_fd" "$request"

  _MCRN_AI_USING_DAEMON=1
  zle -F "$tcp_fd" _mcrn_ai_autofix_result_handler
}

_mcrn_ai_autofix_result_handler() {
  local fd=$1

  if [[ -z "$2" || "$2" == "hup" ]]; then
    local ec="" err="" cmd=""
    read -r -u $fd ec 2>/dev/null
    read -r -u $fd err 2>/dev/null
    IFS='' read -rd '' -u $fd cmd 2>/dev/null

    if [[ -n "$cmd" ]]; then
      if [[ "$_MCRN_AI_CFG_AUTOFIX_MODE" == "ghost" ]]; then
        _mcrn_ai_ghost_render "$cmd"
      else
        zle -M "[MCRN FIX] $_MCRN_LAST_EXECUTED_COMMAND → $cmd  (Ctrl+G to apply)"
        _MCRN_LAST_AI_COMMAND="$cmd"
        _MCRN_LAST_AI_PROMPT="fix the last command that failed"
      fi
      zle -R
    fi
  fi

  ztcp -c "$fd" 2>/dev/null
  zle -F "$fd" 2>/dev/null
}
zle -N _mcrn_ai_autofix_result_handler

add-zsh-hook precmd _mcrn_ai_autofix_precmd

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

  local last_stderr=""
  if [[ "$mode" == "fix" && -n "$_MCRN_AI_LAST_STDERR" ]]; then
    last_stderr="$_MCRN_AI_LAST_STDERR"
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
    --arg last_stderr "$last_stderr" \
    --arg prior_prompt "$prior_prompt" \
    --arg prior_command "$prior_command" \
    '{
      prompt: $prompt,
      mode: $mode,
      recentHistory: $recent_history,
      gitSummary: $git_summary,
      lastFailure: $last_failure,
      lastStderr: $last_stderr,
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

  # Clean up fd
  if (( _MCRN_AI_USING_DAEMON )); then
    ztcp -c "$fd" 2>/dev/null
  else
    builtin exec {fd}<&- 2>/dev/null
  fi
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

  # Store candidates for cycling (daemon may return extras via _MCRN_AI_PENDING_CANDIDATES)
  _MCRN_AI_CANDIDATES=("$command")
  _MCRN_AI_CANDIDATE_IDX=1

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

# ── Daemon Request Path ──────────────────────────────────────────────
_mcrn_ai_send_via_daemon() {
  local payload="$1" mode="$2"
  local helpers_dir
  helpers_dir="$(_mcrn_ai_helpers_dir)"

  zmodload -e zsh/net/tcp || zmodload zsh/net/tcp 2>/dev/null || return 1

  ztcp 127.0.0.1 "$_MCRN_AI_DAEMON_PORT" 2>/dev/null || return 1
  local tcp_fd=$REPLY
  _MCRN_AI_USING_DAEMON=1

  local request="{\"id\":${RANDOM},\"type\":\"generate\",\"format\":\"zle\",\"payload\":${payload}}"
  print -u "$tcp_fd" "$request"

  _mcrn_ai_debug_log "daemon request sent on fd=$tcp_fd"

  _MCRN_AI_RESULT_FD=$tcp_fd
  zle -F "$tcp_fd" _mcrn_ai_result_handler
  return 0
}

# ── Subprocess Request Path (fallback) ───────────────────────────────
_mcrn_ai_send_via_subprocess() {
  local payload="$1" mode="$2"
  local helpers_dir
  helpers_dir="$(_mcrn_ai_helpers_dir)"
  local helper="$helpers_dir/copilot-helper.mjs"

  _MCRN_AI_USING_DAEMON=0

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
    printf '%s\n' "$ec"
    printf '%s\n' "$err"
    printf '%s' "$cmd"
  )
  zle -F "$_MCRN_AI_RESULT_FD" _mcrn_ai_result_handler

  _mcrn_ai_debug_log "subprocess result fd=$_MCRN_AI_RESULT_FD launched"
}

# ── Main ZLE Widget ─────────────────────────────────────────────────
typeset -g _MCRN_AI_ASYNC_EFFECTIVE_PROMPT=""

mcrn_ai_generate() {
  # If a request is already in flight, cancel it first
  if (( _MCRN_AI_ASYNC_ACTIVE )); then
    _mcrn_ai_cancel_async
    return
  fi

  # Clear any ghost-text suggestion
  _mcrn_ai_ghost_clear

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
  _MCRN_AI_ASYNC_MODE="$mode"
  _MCRN_AI_ASYNC_ACTIVE=1
  _MCRN_AI_SPINNER_IDX=0

  # Spinner subprocess: writes a line every 300ms for zle -F to pick up
  builtin exec {_MCRN_AI_SPINNER_FD}< <(
    while true; do
      sleep 0.3
      printf 'tick\n'
    done
  )
  zle -F "$_MCRN_AI_SPINNER_FD" _mcrn_ai_spinner_handler

  _mcrn_ai_debug_log "spinner fd=$_MCRN_AI_SPINNER_FD"

  # Try daemon first, fall back to subprocess
  if _mcrn_ai_daemon_ensure 2>/dev/null && \
     _mcrn_ai_send_via_daemon "$payload" "$mode" 2>/dev/null; then
    _mcrn_ai_debug_log "using daemon on port $_MCRN_AI_DAEMON_PORT"
  else
    _mcrn_ai_send_via_subprocess "$payload" "$mode"
  fi

  zle -R
}

# ── Key Bindings ─────────────────────────────────────────────────────
zle -N mcrn_ai_generate
bindkey '^g' mcrn_ai_generate
bindkey -M viins '^g' mcrn_ai_generate 2>/dev/null || true
bindkey -M vicmd '^g' mcrn_ai_generate 2>/dev/null || true
# Ghost-text: right-arrow or Ctrl+F to accept full suggestion
bindkey '^[OC' _mcrn_ai_ghost_accept_full 2>/dev/null || true  # Right arrow
bindkey '^[[C' _mcrn_ai_ghost_accept_full 2>/dev/null || true  # Right arrow (alt)
bindkey '^F' _mcrn_ai_ghost_accept_full 2>/dev/null || true    # Ctrl+F
# Ghost-text: Ctrl+Right to accept word-by-word
bindkey '^[[1;5C' _mcrn_ai_ghost_accept_word 2>/dev/null || true  # Ctrl+Right
