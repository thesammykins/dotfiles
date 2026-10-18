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

# Claude Code is the one global tool: it runs outside any project, so no
# project config can own it. Language runtimes stay project-owned.
@test "global mise config owns settings and only the claude tool" {
  run awk '/^\[/ { section = $0; next }
    section == "[tools]" && NF && $0 !~ /^[[:space:]]*#/ { print $1 }' \
    "$DOTFILES_DIR/.config/mise/config.toml"
  [ "$status" -eq 0 ]
  [ "$output" = "claude" ]

  run grep -E '^\[settings\]' "$DOTFILES_DIR/.config/mise/config.toml"
  [ "$status" -eq 0 ]
}

@test "installer does not install a global runtime baseline" {
  run rg -n 'MISE_GLOBAL_CONFIG_FILE|mise install' "$DOTFILES_DIR/scripts/install.sh"
  [ "$status" -ne 0 ]
}

@test "shell startup keeps host PATH entries unique when sourced twice" {
  run env -i HOME="$BATS_TEST_TMPDIR/home" PATH="/usr/bin:/bin" DOTFILES="$DOTFILES_DIR" \
    /bin/zsh -c 'source "$DOTFILES/.zshrc"; source "$DOTFILES/.zshrc"; print -rl -- $path'
  [ "$status" -eq 0 ]
  [ "$(printf '%s\n' "$output" | grep -c '^/opt/homebrew/bin$')" -eq 1 ]
  [ "$(printf '%s\n' "$output" | grep -c '^/opt/homebrew/sbin$')" -eq 1 ]
}
