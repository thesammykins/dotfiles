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

@test "installer trusts its managed mise config before installation" {
  run rg -n 'mise trust.*\.config/mise/config\.toml' "$DOTFILES_DIR/scripts/install.sh"
  [ "$status" -eq 0 ]
  [ "$(printf '%s\n' "$output" | wc -l | tr -d ' ')" -eq 2 ]
}

@test "global mise baseline stays small" {
  run grep -E '^[[:space:]]*(java|dotnet|gradle|terraform|flyctl)[[:space:]]*=' "$DOTFILES_DIR/.config/mise/config.toml"
  [ "$status" -ne 0 ]
}
