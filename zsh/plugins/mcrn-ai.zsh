# ~/.dotfiles/zsh/plugins/mcrn-ai.zsh
# MCRN compatibility wrapper for the ghostline-zle / copilot-zle core.

export MCRN_AI_TIMEOUT_MS="${MCRN_AI_TIMEOUT_MS:-30000}"
export MCRN_COPILOT_MODEL="${MCRN_COPILOT_MODEL:-gpt-5-mini}"
export MCRN_AI_PLUGIN_PATH="${MCRN_AI_PLUGIN_PATH:-${(%):-%x}}"
export MCRN_AI_DEBUG_LOG="${MCRN_AI_DEBUG_LOG:-/tmp/mcrn-ai-debug.log}"

typeset -g _MCRN_AI_COMPAT_DIR="${MCRN_AI_PLUGIN_PATH:A:h}/mcrn-ai"

export MCRN_AI_CONFIG_FILE="${MCRN_AI_CONFIG_FILE:-${_MCRN_AI_COMPAT_DIR}/config.json}"
export MCRN_AI_DAEMON_STATE_FILE="${MCRN_AI_DAEMON_STATE_FILE:-/tmp/mcrn-ai-daemon-${UID}.json}"
export MCRN_AI_DATA_DIR="${MCRN_AI_DATA_DIR:-$HOME/.local/share/mcrn-ai}"
export MCRN_AI_TEMPLATES_FILE="${MCRN_AI_TEMPLATES_FILE:-$HOME/.config/mcrn-ai/templates.txt}"
export MCRN_AI_STDERR_FILE="${MCRN_AI_STDERR_FILE:-/tmp/mcrn-ai-stderr-$$.log}"

export COPILOT_ZLE_TIMEOUT_MS="${COPILOT_ZLE_TIMEOUT_MS:-$MCRN_AI_TIMEOUT_MS}"
export COPILOT_ZLE_MODEL="${COPILOT_ZLE_MODEL:-$MCRN_COPILOT_MODEL}"
export COPILOT_ZLE_ROOT_DIR="${_MCRN_AI_COMPAT_DIR}"
export COPILOT_ZLE_PLUGIN_PATH="${_MCRN_AI_COMPAT_DIR}/copilot-zle.zsh"
export COPILOT_ZLE_DEBUG_LOG="${COPILOT_ZLE_DEBUG_LOG:-$MCRN_AI_DEBUG_LOG}"
export COPILOT_ZLE_CONFIG_FILE="$MCRN_AI_CONFIG_FILE"
export COPILOT_ZLE_DAEMON_STATE_FILE="${COPILOT_ZLE_DAEMON_STATE_FILE:-$MCRN_AI_DAEMON_STATE_FILE}"
export COPILOT_ZLE_DATA_DIR="${COPILOT_ZLE_DATA_DIR:-$MCRN_AI_DATA_DIR}"
export COPILOT_ZLE_TEMPLATES_FILE="${COPILOT_ZLE_TEMPLATES_FILE:-$MCRN_AI_TEMPLATES_FILE}"
export COPILOT_ZLE_STDERR_FILE="${COPILOT_ZLE_STDERR_FILE:-$MCRN_AI_STDERR_FILE}"

if [[ -n "${MCRN_AI_DEBUG:-}" && -z "${COPILOT_ZLE_DEBUG:-}" ]]; then
  export COPILOT_ZLE_DEBUG="$MCRN_AI_DEBUG"
fi

if [[ ! -f "${_MCRN_AI_COMPAT_DIR}/copilot-zle.zsh" ]]; then
  print -u2 -- "mcrn-ai: missing core plugin at ${_MCRN_AI_COMPAT_DIR}/copilot-zle.zsh"
  return 1
fi

source "${_MCRN_AI_COMPAT_DIR}/copilot-zle.zsh"
