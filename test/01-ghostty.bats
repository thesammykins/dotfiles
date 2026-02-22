#!/usr/bin/env bats

setup() {
  export DOTFILES_DIR="${HOME}/Development/dotfiles"
}

@test "Ghostty config is present" {
  run stat "$DOTFILES_DIR/.config/ghostty/config"
  [ "$status" -eq 0 ]
}

@test "Ghostty uses MCRN shell-integration" {
  run grep -E "^shell-integration = detect|^shell-integration-features =" "$DOTFILES_DIR/.config/ghostty/config"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "cursor,sudo,title" ]]
}

@test "Ghostty uses MCRN aesthetic" {
  run grep -E "^font-family = \"TX02 Nerd Font\"" "$DOTFILES_DIR/.config/ghostty/config"
  [ "$status" -eq 0 ]
}
