#!/usr/bin/env bats

setup() {
  export DOTFILES_DIR="${HOME}/Development/dotfiles"
}

@test "MCRN AI config files exist" {
  run stat "$DOTFILES_DIR/.dotfiles/zsh/plugins/mcrn-ai/config.json"
  [ "$status" -eq 0 ]

  run stat "$DOTFILES_DIR/.dotfiles/zsh/plugins/mcrn-ai/config.schema.json"
  [ "$status" -eq 0 ]

  run stat "$DOTFILES_DIR/.dotfiles/zsh/plugins/mcrn-ai/config.mjs"
  [ "$status" -eq 0 ]
}

@test "MCRN AI tool files exist" {
  run stat "$DOTFILES_DIR/.dotfiles/zsh/plugins/mcrn-ai/tools/index.mjs"
  [ "$status" -eq 0 ]

  run stat "$DOTFILES_DIR/.dotfiles/zsh/plugins/mcrn-ai/tools/utils.mjs"
  [ "$status" -eq 0 ]
}

@test "MCRN AI config has expected keys" {
  run jq -e '.tools.allowlist and .tools.devopsEnabled != null and .limits.maxOutputBytes and .limits.maxFileBytes and .limits.toolTimeoutMs' \
    "$DOTFILES_DIR/.dotfiles/zsh/plugins/mcrn-ai/config.json"
  [ "$status" -eq 0 ]
}

@test "Copilot helper loads config" {
  run grep -E 'loadConfig' "$DOTFILES_DIR/.dotfiles/zsh/plugins/mcrn-ai/copilot-helper.mjs"
  [ "$status" -eq 0 ]
}
