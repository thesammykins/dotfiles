# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154,SC2168
# ~/.dotfiles/zsh/plugins/mcrn-ai.zsh
# MCRN Tactical Display - Real-Time AI ZLE Widget
# Generates shell commands from natural language without leaving the prompt.
# Engine: llama-server (llama.cpp)
# Model: qwen3-codersmall-q8_0.gguf

# Model configuration variables
export MCRN_LLM_DIR="${MCRN_LLM_DIR:-$HOME/.cache/llm-models}"
export MCRN_LLM_FILE="${MCRN_LLM_FILE:-qwen3-codersmall-q8_0.gguf}"
export MCRN_LLM_MODEL="$MCRN_LLM_DIR/$MCRN_LLM_FILE"
export MCRN_LLM_PORT="${MCRN_LLM_PORT:-8080}"
export MCRN_LLM_LOG="${MCRN_LLM_LOG:-/tmp/mcrn-llama-server.log}"

# Global variable to store the last generated command for quick retry
typeset -g _MCRN_LAST_AI_QUERY=""

# Auto-start llama-server if it's not running
_mcrn_ensure_server() {
  if ! pgrep -f "llama-server.*$MCRN_LLM_FILE" >/dev/null; then
    zle -M "[MCRN UPLINK] Initializing tactical server..."
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
        zle -M "[MCRN ERROR] Tactical server initialization failed. Check $MCRN_LLM_LOG"
        return 1
      fi
    done
    zle -M "[MCRN UPLINK] Tactical server online."
  fi
  return 0
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

  if [[ ! -x "$(command -v llama-server)" ]]; then
    zle -M "[MCRN ERROR] llama-server not found. Ensure llama.cpp is installed."
    return
  fi

  if [[ ! -x "$(command -v jq)" ]]; then
    zle -M "[MCRN ERROR] jq not found. Required for JSON parsing."
    return
  fi

  if [[ ! -f "$MCRN_LLM_MODEL" ]]; then
    zle -M "[MCRN ERROR] Model missing at $MCRN_LLM_MODEL"
    return
  fi

  _mcrn_ensure_server || return

  # Show visual indicator that generation has started
  zle -M "[MCRN UPLINK] Querying tactical database..."
  zle redisplay

  # Construct the system prompt with dynamic environment context and few-shot examples
  local sys_os
  sys_os="macOS ($(uname -sm))"
  local sys_pwd="$PWD"
  local sys_home="$HOME"
  local system_prompt="You are a strict CLI command generator for macOS zsh.
Your ONLY job is to translate natural language into a single, valid, raw shell command.

ENVIRONMENT:
- OS: $sys_os
- Shell: zsh
- Home: $sys_home
- PWD: $sys_pwd

RULES:
1. NEVER explain. NEVER use markdown. NEVER use backticks.
2. Prefer standard macOS paths (e.g., ~/Downloads, ~/Desktop) unless a local path is explicitly implied.
3. Use modern macOS/zsh idiomatic commands (e.g., find, grep, awk, lsof, ipconfig, pbcopy).
4. If the prompt implies your current location, use the PWD provided.

EXAMPLES:
User: list files larger than 10MB in downloads
Command: find ~/Downloads -type f -size +10M

User: kill process listening on port 8080
Command: lsof -ti:8080 | xargs kill -9

User: find text 'TODO' in python files here
Command: rg 'TODO' -g '*.py'"

  # Construct the JSON payload safely using jq to handle escaping
  local payload
  payload=$(jq -n \
    --arg system_prompt "$system_prompt" \
    --arg user_input "$user_input" \
    '{
    model: "qwen",
    messages: [
      {
        role: "system",
        content: $system_prompt
      },
      {
        role: "user",
        content: $user_input
      }
    ],
    response_format: {
      type: "json_schema",
      json_schema: {
        name: "bash_cmd",
        schema: {
          type: "object",
          properties: {
            command: {type: "string"}
          },
          required: ["command"]
        }
      }
    },
    temperature: 0.1,
    n_predict: 128
  }')

  # Invoke llama-server via curl
  local response
  response="$(curl -s -X POST "http://127.0.0.1:$MCRN_LLM_PORT/v1/chat/completions" \
    -H "Content-Type: application/json" \
    -d "$payload")"
  
  if [[ -z "$response" ]]; then
    zle -M "[MCRN ERROR] No connection to tactical server."
    zle redisplay
    return
  fi

  # Extract the command from the JSON response
  local raw_content
  raw_content="$(echo "$response" | jq -r '.choices[0].message.content' 2>/dev/null)"
  
  local final_cmd
  # Depending on the strictness of the model, it might return just the JSON string,
  # or a JSON string wrapped in markdown block. Let's safely extract it.
  # First try parsing the content as JSON (since we requested JSON schema)
  final_cmd="$(echo "$raw_content" | jq -r '.command' 2>/dev/null)"
  
  # Fallback if jq fails (e.g. model injected markdown)
  if [[ -z "$final_cmd" || "$final_cmd" == "null" ]]; then
      final_cmd="$(echo "$raw_content" | sed -e 's/^```[a-z]*//g' -e 's/```$//g' | xargs)"
  fi

  if [[ -n "$final_cmd" && "$final_cmd" != "null" ]]; then
    # Replace buffer and move cursor to the end
    BUFFER="$final_cmd"
    CURSOR=${#BUFFER}
    zle -M "[MCRN UPLINK] Command received. Review before execution."
  else
    zle -M "[MCRN ERROR] Failed to parse response from tactical database."
  fi
  
  zle redisplay
}

# Bind to Ctrl+G for generation
zle -N mcrn_ai_generate
bindkey '^g' mcrn_ai_generate

# Bind Ctrl+R to retry if you clear the buffer
# (Ctrl+R is usually history search, so we'll leave it as Ctrl+G, 
# since mcrn_ai_generate already retries when buffer is empty)
