#!/usr/bin/env bats

setup() {
  # Only run if not in CI (or if CI sets the expected environment)
  export HOME_DIR="${HOME}"
}

@test "Ghostty config is present" {
  run stat "$HOME_DIR/.config/ghostty/config"
  [ "$status" -eq 0 ]
}

@test "Ghostty uses MCRN shell-integration" {
  run grep -E "^shell-integration = detect|^shell-integration-features =" "$HOME_DIR/.config/ghostty/config"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "cursor,sudo,title" ]]
}

@test "Ghostty uses MCRN aesthetic" {
  run grep -E "^font-family = \"TX02 Nerd Font\"" "$HOME_DIR/.config/ghostty/config"
  [ "$status" -eq 0 ]
}
