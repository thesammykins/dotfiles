# ~/.dotfiles/zsh/plugins/mcrn-ai.zsh
# MCRN Tactical Display - Real-Time AI ZLE Widget
# Generates shell commands from natural language without leaving the prompt.
# Engine: llama-cli (llama.cpp)
# Model: Qwen2.5-Coder-1.5B-Instruct-Q4_K_M.gguf

# Model configuration variables
export MCRN_LLM_DIR="${MCRN_LLM_DIR:-$HOME/.cache/llm-models}"
export MCRN_LLM_FILE="${MCRN_LLM_FILE:-Qwen2.5-Coder-1.5B-Instruct-Q4_K_M.gguf}"
export MCRN_LLM_MODEL="$MCRN_LLM_DIR/$MCRN_LLM_FILE"

mcrn_ai_generate() {
  local user_input="${BUFFER}"
  
  if [[ -z "$user_input" ]]; then
    return
  fi

  if [[ ! -x "$(command -v llama-cli)" ]]; then
    zle -M "[MCRN ERROR] llama-cli not found. Ensure llama.cpp is installed."
    return
  fi

  if [[ ! -f "$MCRN_LLM_MODEL" ]]; then
    zle -M "[MCRN ERROR] Model missing at $MCRN_LLM_MODEL"
    return
  fi

  # Show visual indicator that generation has started
  zle -M "[MCRN UPLINK] Querying tactical database..."
  zle redisplay

  # Strict prompt contract enforcing a single bash command without prose
  local system_prompt="SYSTEM: You output ONLY a single bash command. No prose, no formatting, no code fences. Output absolutely nothing else."
  local prompt_text="$system_prompt\nUSER: $user_input\nCOMMAND:"

  # Invoke llama-cli (blocking)
  local response
  response="$(llama-cli \
    --model "$MCRN_LLM_MODEL" \
    --prompt "$prompt_text" \
    --n-predict 96 \
    --temp 0.2 \
    --top-k 40 \
    --top-p 0.9 \
    --no-display-prompt \
    --log-disable 2>/dev/null)"
  
  # Clean up response (trim whitespace, remove potential markdown backticks)
  response="$(echo "$response" | sed -e 's/^```[a-z]*//g' -e 's/```$//g' | xargs)"

  if [[ -n "$response" ]]; then
    # Replace buffer and move cursor to the end
    BUFFER="$response"
    CURSOR=${#BUFFER}
    zle -M "[MCRN UPLINK] Command received. Review before execution."
  else
    zle -M "[MCRN ERROR] Empty response from tactical database."
  fi
  
  zle redisplay
}

# Bind to Ctrl+G
zle -N mcrn_ai_generate
bindkey '^g' mcrn_ai_generate
