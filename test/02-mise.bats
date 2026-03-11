#!/usr/bin/env bats

setup() {
  export DOTFILES_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
}

@test "mise config exists" {
  run stat "$DOTFILES_DIR/.config/mise/config.toml"
  [ "$status" -eq 0 ]
}

@test "Zshrc sources mise" {
  run grep -E 'eval "\$\(mise activate zsh\)"' "$DOTFILES_DIR/.zshrc"
  [ "$status" -eq 0 ]
}

@test "mise runtimes are pinned" {
  run grep -E '=[[:space:]]*"(latest|lts)"' "$DOTFILES_DIR/.config/mise/config.toml"
  [ "$status" -ne 0 ]
}
