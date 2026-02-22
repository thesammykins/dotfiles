#!/usr/bin/env bats

@test "ZLE plugin is sourced in zshrc" {
  run grep -E 'source "\$DOTFILES/zsh/plugins/mcrn-ai.zsh"' "$HOME/.zshrc"
  [ "$status" -eq 0 ]
}

@test "Model exists in cache (Integration test)" {
  # Skip if we haven't bootstrapped
  if [[ ! -d "$HOME/.cache/llm-models" ]]; then
    skip "Bootstrap script hasn't run yet; model cache missing."
  fi
  run stat "$HOME/.cache/llm-models/Qwen2.5-Coder-1.5B-Instruct-Q4_K_M.gguf"
  [ "$status" -eq 0 ]
}
