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
  run grep -E 'loadConfig' "$DOTFILES_DIR/zsh/plugins/mcrn-ai/copilot-helper.mjs"
  [ "$status" -eq 0 ]
}

@test "Copilot helper resolves model from config or env" {
  run rg -n 'resolveModel|config\.model\.default|MCRN_COPILOT_MODEL' "$DOTFILES_DIR/zsh/plugins/mcrn-ai/copilot-helper.mjs"
  [ "$status" -eq 0 ]
}

@test "Copilot helper keeps append mode and session cleanup" {
  run rg -n 'mode: "append"|disconnectSession|session\\.disconnect\\(\\)|client\\.stop\\(\\)' "$DOTFILES_DIR/zsh/plugins/mcrn-ai/copilot-helper.mjs"
  [ "$status" -eq 0 ]
}

@test "Copilot helper rejects chained shell commands" {
  run rg -n 'trimmed\.includes\("\\$\("\)|\[;&\|\]|trimmed\.includes\(">"\)|trimmed\.includes\("<"\)' "$DOTFILES_DIR/zsh/plugins/mcrn-ai/copilot-helper.mjs"
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

@test "MCRN AI helper node tests exist" {
  run stat "$DOTFILES_DIR/zsh/plugins/mcrn-ai/copilot-helper.test.mjs"
  [ "$status" -eq 0 ]
}

@test "MCRN AI SDK patch script exists" {
  run stat "$DOTFILES_DIR/zsh/plugins/mcrn-ai/patch-copilot-sdk.mjs"
  [ "$status" -eq 0 ]
}
