#!/usr/bin/env bats

@test "mise config exists" {
  run stat "$HOME/.config/mise/config.toml"
  [ "$status" -eq 0 ]
}

@test "Zshrc sources mise" {
  run grep -E 'eval "\$\(mise activate zsh\)"' "$HOME/.zshrc"
  [ "$status" -eq 0 ]
}
