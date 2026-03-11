#!/usr/bin/env bats

setup() {
  export DOTFILES_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
}

@test "MCRN AI config files exist" {
  run stat "$DOTFILES_DIR/zsh/plugins/mcrn-ai/config.json"
  [ "$status" -eq 0 ]

  run stat "$DOTFILES_DIR/zsh/plugins/mcrn-ai/config.schema.json"
  [ "$status" -eq 0 ]

  run stat "$DOTFILES_DIR/zsh/plugins/mcrn-ai/config.mjs"
  [ "$status" -eq 0 ]
}

@test "MCRN AI tool files exist" {
  run stat "$DOTFILES_DIR/zsh/plugins/mcrn-ai/tools/index.mjs"
  [ "$status" -eq 0 ]

  run stat "$DOTFILES_DIR/zsh/plugins/mcrn-ai/tools/utils.mjs"
  [ "$status" -eq 0 ]
}

@test "MCRN AI config has expected keys" {
  run jq -e '.tools.allowlist and .tools.devopsEnabled != null and .limits.maxOutputBytes and .limits.maxFileBytes and .limits.toolTimeoutMs' \
    "$DOTFILES_DIR/zsh/plugins/mcrn-ai/config.json"
  [ "$status" -eq 0 ]
}

@test "Copilot helper loads config" {
  run grep -E 'loadConfig' "$DOTFILES_DIR/zsh/plugins/mcrn-ai/copilot-helper.mjs"
  [ "$status" -eq 0 ]
}

@test "Copilot helper uses configurable gpt-5-mini default" {
  run grep -E 'MCRN_COPILOT_MODEL.*gpt-5-mini' "$DOTFILES_DIR/zsh/plugins/mcrn-ai/copilot-helper.mjs"
  [ "$status" -eq 0 ]
}

@test "Copilot helper keeps append mode and session cleanup" {
  run rg -n 'mode: "append"|session\\.destroy\\(\\)|client\\.stop\\(\\)' "$DOTFILES_DIR/zsh/plugins/mcrn-ai/copilot-helper.mjs"
  [ "$status" -eq 0 ]
}

@test "Copilot helper validates requested model against live model list" {
  run rg -n 'listModels\\(\\)|copilot_model_rejected|available_models' "$DOTFILES_DIR/zsh/plugins/mcrn-ai/copilot-helper.mjs"
  [ "$status" -eq 0 ]
}

@test "Plugin package requires Node 20+" {
  run jq -e '.engines.node | test("20")' "$DOTFILES_DIR/zsh/plugins/mcrn-ai/package.json"
  [ "$status" -eq 0 ]
}
