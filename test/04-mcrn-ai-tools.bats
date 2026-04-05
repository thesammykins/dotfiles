#!/usr/bin/env bats

setup() {
  export DOTFILES_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
}

@test "MCRN AI config files exist" {
  run stat "$DOTFILES_DIR/zsh/plugins/mcrn-ai/config.json"
  [ "$status" -eq 0 ]

  run stat "$DOTFILES_DIR/zsh/plugins/mcrn-ai/config.schema.json"
  [ "$status" -eq 0 ]

  run stat "$DOTFILES_DIR/zsh/plugins/mcrn-ai/lib/config.mjs"
  [ "$status" -eq 0 ]
}

@test "MCRN AI tool files exist" {
  run stat "$DOTFILES_DIR/zsh/plugins/mcrn-ai/lib/copilot-service.mjs"
  [ "$status" -eq 0 ]

  run stat "$DOTFILES_DIR/zsh/plugins/mcrn-ai/lib/project-context.mjs"
  [ "$status" -eq 0 ]
}

@test "MCRN AI config has expected keys" {
  run jq -e '.model.default and .tools.allowlist and .tools.devopsEnabled != null and .limits.maxOutputBytes and .limits.maxFileBytes and .limits.toolTimeoutMs' \
    "$DOTFILES_DIR/zsh/plugins/mcrn-ai/config.json"
  [ "$status" -eq 0 ]
}

@test "MCRN AI config schema includes model default" {
  run jq -e '.properties.model.properties.default.default == "gpt-5-mini"' \
    "$DOTFILES_DIR/zsh/plugins/mcrn-ai/config.schema.json"
  [ "$status" -eq 0 ]
}

@test "Copilot helper loads config" {
  run grep -E 'loadConfig' "$DOTFILES_DIR/zsh/plugins/mcrn-ai/lib/copilot-helper.mjs"
  [ "$status" -eq 0 ]
}

@test "Copilot helper resolves model from config or env" {
  run rg -n 'resolveModel|config\.model\.default|COPILOT_ZLE_MODEL' "$DOTFILES_DIR/zsh/plugins/mcrn-ai/lib/copilot-helper.mjs"
  [ "$status" -eq 0 ]
}

@test "Copilot helper keeps append mode and session cleanup" {
  run rg -n 'mode: "append"|disconnectSession|session\\.disconnect\\(\\)|client\\.stop\\(\\)' "$DOTFILES_DIR/zsh/plugins/mcrn-ai/lib/copilot-helper.mjs"
  [ "$status" -eq 0 ]
}

@test "Copilot helper sanitizes dangerous patterns" {
  run rg -n '\\beval\\b|backtick|\\u0000|\\`\[\\^' "$DOTFILES_DIR/zsh/plugins/mcrn-ai/lib/copilot-helper.mjs"
  [ "$status" -eq 0 ]
}

@test "Copilot helper handles model errors via classifyError" {
  # SAM-43: listModels() removed from hot path; model errors are caught
  # lazily by classifyError when createSession/sendAndWait throws
  run rg -n 'copilot_model_rejected|classifyError' "$DOTFILES_DIR/zsh/plugins/mcrn-ai/lib/copilot-helper.mjs"
  [ "$status" -eq 0 ]
}

@test "Copilot helper has structured input parsing (SAM-39)" {
  run rg -n 'parseInput|buildContextBlock' "$DOTFILES_DIR/zsh/plugins/mcrn-ai/lib/copilot-helper.mjs"
  [ "$status" -eq 0 ]
}

@test "Plugin package requires Node 20+" {
  run jq -e '.engines.node | test("20")' "$DOTFILES_DIR/zsh/plugins/mcrn-ai/package.json"
  [ "$status" -eq 0 ]
}

@test "MCRN AI helper node tests exist" {
  run stat "$DOTFILES_DIR/zsh/plugins/mcrn-ai/tests/copilot-helper.test.mjs"
  [ "$status" -eq 0 ]
}

@test "MCRN AI SDK patch script exists" {
  run stat "$DOTFILES_DIR/zsh/plugins/mcrn-ai/scripts/patch-copilot-sdk.mjs"
  [ "$status" -eq 0 ]
}

@test "MCRN AI config has context and ui sections (SAM-44)" {
  run jq -e '.context.recentHistoryCount and .context.includeGitSummary != null and .context.includeLastFailure != null and .ui.highlightAiBuffer != null and .ui.highlightStyle' \
    "$DOTFILES_DIR/zsh/plugins/mcrn-ai/config.json"
  [ "$status" -eq 0 ]
}

@test "MCRN AI config schema defines context and ui (SAM-44)" {
  run jq -e '.properties.context.properties.recentHistoryCount and .properties.ui.properties.highlightStyle' \
    "$DOTFILES_DIR/zsh/plugins/mcrn-ai/config.schema.json"
  [ "$status" -eq 0 ]
}

@test "Policy file prefers graceful signals (SAM-46)" {
  run rg -c 'graceful.*signal|SIGTERM' "$DOTFILES_DIR/zsh/plugins/mcrn-ai/policy.txt"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

@test "System prompt has signal and safety rules (SAM-46/47)" {
  # Rule 9: graceful signals; Rule 10: non-destructive defaults
  run rg -c 'graceful signals|non-destructive' "$DOTFILES_DIR/zsh/plugins/mcrn-ai/lib/copilot-helper.mjs"
  [ "$status" -eq 0 ]
  [ "$output" -ge 2 ]
}

@test "ZSH widget has async state variables (SAM-45)" {
  run rg -c '_COPILOT_ZLE_ASYNC_ACTIVE|_COPILOT_ZLE_SPINNER_FD|_COPILOT_ZLE_RESULT_FD' "$DOTFILES_DIR/zsh/plugins/mcrn-ai/shell/copilot-zle-core.zsh"
  [ "$status" -eq 0 ]
  [ "$output" -ge 3 ]
}

@test "ZSH widget has spinner and result handlers (SAM-45)" {
  run rg -c '_copilot_zle_spinner_handler|_copilot_zle_result_handler|_copilot_zle_cancel_async' "$DOTFILES_DIR/zsh/plugins/mcrn-ai/shell/copilot-zle-core.zsh"
  [ "$status" -eq 0 ]
  [ "$output" -ge 3 ]
}

@test "ZSH widget has mode detection for fix and refine (SAM-40/41)" {
  run rg -c '_copilot_zle_detect_mode|fix.*mode|refine.*mode' "$DOTFILES_DIR/zsh/plugins/mcrn-ai/shell/copilot-zle-core.zsh"
  [ "$status" -eq 0 ]
  [ "$output" -ge 2 ]
}

@test "ZSH widget builds structured payload (SAM-39)" {
  run rg -c '_copilot_zle_build_payload|jq -n -c' "$DOTFILES_DIR/zsh/plugins/mcrn-ai/shell/copilot-zle-core.zsh"
  [ "$status" -eq 0 ]
  [ "$output" -ge 2 ]
}

@test "ZSH widget reads config with jq (SAM-44)" {
  run rg -c '_copilot_zle_read_config' "$DOTFILES_DIR/zsh/plugins/mcrn-ai/shell/copilot-zle-core.zsh"
  [ "$status" -eq 0 ]
  [ "$output" -ge 3 ]
}

@test "Copilot helper has structured debug output (SAM-49)" {
  run rg -c 'debugLog|COPILOT DEBUG|LATENCY=|SANITIZE_ACTION' "$DOTFILES_DIR/zsh/plugins/mcrn-ai/lib/copilot-helper.mjs"
  [ "$status" -eq 0 ]
  [ "$output" -ge 4 ]
}

@test "ZSH widget passes MCRN_AI_DEBUG to subprocess (SAM-49)" {
  run rg -c 'COPILOT_ZLE_DEBUG=.*node|COPILOT_ZLE_DEBUG=.*NODE_NO_WARNINGS' "$DOTFILES_DIR/zsh/plugins/mcrn-ai/shell/copilot-zle-core.zsh"
  [ "$status" -eq 0 ]
}
