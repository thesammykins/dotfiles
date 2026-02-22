#!/usr/bin/env bats

@test "ZLE plugin is sourced in zshrc" {
  run grep -E 'source "\$DOTFILES/.dotfiles/zsh/plugins/mcrn-ai.zsh"' "$HOME/Development/dotfiles/.zshrc"
  [ "$status" -eq 0 ]
}

@test "Model exists in cache (Integration test)" {
  # Skip if we haven't bootstrapped
  if [[ ! -d "$HOME/.cache/llm-models" ]]; then
    skip "Bootstrap script hasn't run yet; model cache missing."
  fi
  if [[ -f "$HOME/.cache/llm-models/qwen3-codersmall-q8_0.gguf" ]]; then
    run stat "$HOME/.cache/llm-models/qwen3-codersmall-q8_0.gguf"
  else
    skip "Model file not present: qwen3-codersmall-q8_0.gguf"
  fi
  [ "$status" -eq 0 ]
}
