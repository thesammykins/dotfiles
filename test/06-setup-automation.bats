#!/usr/bin/env bats

setup() {
  export DOTFILES_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
}

@test "workstation Brewfile includes BetterDisplay and QuickDrop" {
  run rg -n 'cask "betterdisplay"|mas "QuickDrop", id: 6740147178' "$DOTFILES_DIR/Brewfile.workstation"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "betterdisplay" ]]
  [[ "$output" =~ "QuickDrop" ]]
}

@test "core Brewfile standardizes on Docker Desktop" {
  run rg -n 'cask "docker-desktop"' "$DOTFILES_DIR/Brewfile"
  [ "$status" -eq 0 ]
}

@test "installer exposes explicit macOS automation flags" {
  run rg -n 'DOTFILES_APPLY_MACOS_DEFAULTS|DOTFILES_APPLY_DOCK' "$DOTFILES_DIR/scripts/install.sh" "$DOTFILES_DIR/README.md"
  [ "$status" -eq 0 ]
}

@test "installer uses defaults and dockutil for optional automation" {
  run rg -n 'defaults write|dockutil --no-restart|Pictures/Screenshots' "$DOTFILES_DIR/scripts/install.sh"
  [ "$status" -eq 0 ]
}

@test "unmanaged app report script exists and checks brew plus mas" {
  run rg -n 'brew bundle dump|mas list|Brewfile.workstation' "$DOTFILES_DIR/scripts/report-unmanaged-brew-apps.sh"
  [ "$status" -eq 0 ]
}
