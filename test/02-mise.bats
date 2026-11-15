#!/usr/bin/env bats

setup() {
  export DOTFILES_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
}

# Runtimes and agent CLIs are project- or Homebrew-owned, never global mise tools.
@test "global mise config holds settings only" {
  run grep -E '^\[tools\]' "$DOTFILES_DIR/.config/mise/config.toml"
  [ "$status" -ne 0 ]
  run grep -E '^\[settings\]' "$DOTFILES_DIR/.config/mise/config.toml"
  [ "$status" -eq 0 ]
}

@test "installer does not install a global runtime baseline" {
  run rg -n 'MISE_GLOBAL_CONFIG_FILE|mise install' "$DOTFILES_DIR/scripts/install.sh"
  [ "$status" -ne 0 ]
}

# macOS only: needs Homebrew at /opt/homebrew. mise, where installed, puts its
# shims and the current project's tools ahead of Homebrew; that is intended.
# stderr is dropped: with no terminal, compinit and starship complain there.
@test "interactive shells put Homebrew first, once, even when sourced twice" {
  mkdir -p "$BATS_TEST_TMPDIR/home/.local/bin"
  run env -i HOME="$BATS_TEST_TMPDIR/home" PATH="/usr/bin:/bin" DOTFILES="$DOTFILES_DIR" \
    /bin/zsh -c 'cd "$HOME"; source "$DOTFILES/.zshrc" 2>/dev/null; source "$DOTFILES/.zshrc" 2>/dev/null; print -rl -- $path'
  [ "$status" -eq 0 ]
  [ "$(printf '%s\n' "$output" | grep -v '/mise/' | sed -n 1,3p | tr '\n' ' ')" = "/opt/homebrew/bin /opt/homebrew/sbin $BATS_TEST_TMPDIR/home/.local/bin " ]
  [ "$(printf '%s\n' "$output" | grep -c '^/opt/homebrew/bin$')" -eq 1 ]
}

# ssh host cmd and agent runners start login shells that never read ~/.zshrc.
# Sourced directly so /etc/paths.d, which not every Mac has, can't supply it.
@test ".zprofile alone puts Homebrew on PATH" {
  run env -i HOME="$BATS_TEST_TMPDIR" PATH="/usr/bin:/bin" DOTFILES="$DOTFILES_DIR" \
    /bin/zsh -c 'source "$DOTFILES/.zprofile"; command -v brew'
  [ "$status" -eq 0 ]
  [ "$output" = /opt/homebrew/bin/brew ]
}

@test ".zprofile alone finds commands in ~/.local/bin, after Homebrew" {
  mkdir -p "$BATS_TEST_TMPDIR/home/.local/bin"
  printf '#!/bin/sh\n' > "$BATS_TEST_TMPDIR/home/.local/bin/mine"
  chmod +x "$BATS_TEST_TMPDIR/home/.local/bin/mine"
  run env -i HOME="$BATS_TEST_TMPDIR/home" PATH="/usr/bin:/bin" DOTFILES="$DOTFILES_DIR" \
    /bin/zsh -c 'source "$DOTFILES/.zprofile"; command -v mine; print -rl -- $path'
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "$BATS_TEST_TMPDIR/home/.local/bin/mine" ]
  [ "$(printf '%s\n' "$output" | sed -n 2,4p | tr '\n' ' ')" = "/opt/homebrew/bin /opt/homebrew/sbin $BATS_TEST_TMPDIR/home/.local/bin " ]
}
