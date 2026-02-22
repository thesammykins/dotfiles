#!/bin/bash
set -euo pipefail

PORT="${MCRN_LLM_PORT:-8080}"
TIMEOUT_MS="${MCRN_AI_TIMEOUT_MS:-12000}"
N_PROBS="${MCRN_LOCAL_N_PROBS:-5}"

PROMPT="$(cat)"
PROMPT="${PROMPT//$'\r'/}"
PROMPT="${PROMPT//$'\n'/}"
if [[ -z "${PROMPT}" ]]; then
  printf '{"command":"","confidence":0,"provider":"local","error":"empty_prompt"}'
  exit 0
fi

SYS_OS="macOS ($(uname -sm))"
SYS_PWD="${PWD}"
SYS_HOME="${HOME}"

SYSTEM_PROMPT="You are a strict CLI command generator for macOS zsh.
Your ONLY job is to translate natural language into a single, valid, raw shell command.

ENVIRONMENT:
- OS: ${SYS_OS}
- Shell: zsh
- Home: ${SYS_HOME}
- PWD: ${SYS_PWD}

RULES:
1. NEVER explain. NEVER use markdown. NEVER use backticks.
2. Output exactly one command and nothing else.
3. Prefer standard macOS paths (e.g., ~/Downloads, ~/Desktop) unless a local path is explicitly implied.
4. Use modern macOS/zsh idiomatic commands (e.g., find, rg, awk, lsof, ipconfig, pbcopy).
5. If the prompt implies your current location, use the PWD provided.

EXAMPLES:
User: list files larger than 10MB in downloads
Command: find ~/Downloads -type f -size +10M

User: kill process listening on port 8080
Command: lsof -ti:8080 | xargs kill -9

User: find text 'TODO' in python files here
Command: rg 'TODO' -g '*.py'"

FINAL_PROMPT="${SYSTEM_PROMPT}

User: ${PROMPT}
Command:"

REQUEST=$(jq -n \
  --arg prompt "$FINAL_PROMPT" \
  --argjson n_probs "${N_PROBS}" \
  '{
    prompt: $prompt,
    n_predict: 128,
    temperature: 0.1,
    post_sampling_probs: true,
    n_probs: $n_probs,
    json_schema: {
      type: "object",
      properties: {
        command: { type: "string" }
      },
      required: ["command"]
    }
  }')

RESPONSE=$(curl -s -X POST "http://127.0.0.1:${PORT}/completion" \
  -H "Content-Type: application/json" \
  --max-time "$((TIMEOUT_MS / 1000))" \
  -d "$REQUEST")

if [[ -z "${RESPONSE}" ]]; then
  printf '{"command":"","confidence":0,"provider":"local","error":"no_response"}'
  exit 0
fi

CONTENT=$(printf '%s' "$RESPONSE" | jq -r '.content // empty')
COMMAND=$(printf '%s' "$CONTENT" | jq -r '.command // empty' 2>/dev/null || true)
COMMAND=$(printf '%s' "$COMMAND" | sed -e 's/^[[:space:]]*//g' -e 's/[[:space:]]*$//g')

if [[ -z "${COMMAND}" ]]; then
  printf '{"command":"","confidence":0,"provider":"local","error":"invalid_command"}'
  exit 0
fi

if printf '%s' "$COMMAND" | grep -q '[[:cntrl:]]'; then
  printf '{"command":"","confidence":0,"provider":"local","error":"control_chars"}'
  exit 0
fi

if printf '%s' "$COMMAND" | grep -q $'\n'; then
  printf '{"command":"","confidence":0,"provider":"local","error":"multiline"}'
  exit 0
fi

LOGPROBS=$(printf '%s' "$RESPONSE" | jq -r '.completion_probabilities // empty' 2>/dev/null || true)
if [[ -z "${LOGPROBS}" || "${LOGPROBS}" == "null" ]]; then
  printf '{"command":"","confidence":0,"provider":"local","error":"missing_logprobs"}'
  exit 0
fi

CONFIDENCE=$(printf '%s' "$RESPONSE" | jq -r '
  .completion_probabilities
  | map(.prob // empty)
  | map(select(. != null))
  | (if length == 0 then 0 else (map(select(. > 0)) | map(log) | add / length | exp) end)
  ' 2>/dev/null || echo 0)


if [[ -z "${CONFIDENCE}" ]]; then
  CONFIDENCE=0
fi

printf '{"command":%s,"confidence":%s,"provider":"local"}' \
  "$(printf '%s' "$COMMAND" | jq -Rs '.')" \
  "${CONFIDENCE}"
