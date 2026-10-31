#!/usr/bin/env bats

setup() {
  export DOTFILES_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  export TEST_HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$TEST_HOME"
}

# $1: signer path; $2: optional checkout path to run the installer from
install_into_test_home() {
  run env HOME="$TEST_HOME" GIT_CONFIG_NOSYSTEM=1 DOTFILES_GIT_SIGNER="$1" \
    /bin/bash "${2:-$DOTFILES_DIR}/scripts/install.sh"
}

fake_signer() {
  signer="$BATS_TEST_TMPDIR/op-ssh-sign"
  printf '#!/bin/sh\n' > "$signer"
  chmod +x "$signer"
}

@test "replaced files are backed up, and a rerun backs up nothing" {
  printf 'my own zshrc\n' > "$TEST_HOME/.zshrc"
  install_into_test_home "$BATS_TEST_TMPDIR/no-such-signer"
  [ "$status" -eq 0 ]
  [ -L "$TEST_HOME/.zshrc" ]
  [ "$(cat "$TEST_HOME"/.dotfiles.backup/*/.zshrc)" = "my own zshrc" ]

  sleep 1
  install_into_test_home "$BATS_TEST_TMPDIR/no-such-signer"
  [ "$status" -eq 0 ]
  [ "$(ls "$TEST_HOME/.dotfiles.backup" | wc -l | tr -d ' ')" -eq 1 ]
}

@test "a dry run changes nothing" {
  printf 'my own zshrc\n' > "$TEST_HOME/.zshrc"
  run env HOME="$TEST_HOME" DOTFILES_DRY_RUN=1 DOTFILES_APPLY_MACOS_DEFAULTS=1 \
    DOTFILES_GIT_SIGNER="$BATS_TEST_TMPDIR/no-such-signer" /bin/bash "$DOTFILES_DIR/scripts/install.sh"
  [ "$status" -eq 0 ]
  [ ! -L "$TEST_HOME/.zshrc" ]
  [ ! -e "$TEST_HOME/.dotfiles.backup" ]
  [ ! -e "$TEST_HOME/.gitconfig" ]
}

@test "without the 1Password signer, git still commits (unsigned)" {
  install_into_test_home "$BATS_TEST_TMPDIR/no-such-signer"
  [ "$status" -eq 0 ]
  [ ! -e "$TEST_HOME/.config/git/signing.gitconfig" ]
  repo="$BATS_TEST_TMPDIR/repo"
  git init -q "$repo"
  run env HOME="$TEST_HOME" GIT_CONFIG_NOSYSTEM=1 git -C "$repo" commit -q --allow-empty -m test
  [ "$status" -eq 0 ]
}

@test "with the signer, commit signing is linked" {
  fake_signer
  install_into_test_home "$signer"
  [ "$status" -eq 0 ]
  run env HOME="$TEST_HOME" GIT_CONFIG_NOSYSTEM=1 git config --get commit.gpgsign
  [ "$output" = "true" ]
}

@test "signing is unlinked when the signer disappears, even via a symlinked checkout" {
  fake_signer
  install_into_test_home "$signer"
  [ -L "$TEST_HOME/.config/git/signing.gitconfig" ]
  rm "$signer"
  ln -s "$DOTFILES_DIR" "$BATS_TEST_TMPDIR/dotfiles-link"
  install_into_test_home "$signer" "$BATS_TEST_TMPDIR/dotfiles-link"
  [ "$status" -eq 0 ]
  [ ! -e "$TEST_HOME/.config/git/signing.gitconfig" ]
}

@test "the git alias goes to ~/.gitconfig, not the tracked config" {
  before="$(git -C "$DOTFILES_DIR" hash-object .config/git/config)"
  install_into_test_home "$BATS_TEST_TMPDIR/no-such-signer"
  [ "$status" -eq 0 ]
  run git config --file "$TEST_HOME/.gitconfig" --get alias.dotfiles
  [ "$status" -eq 0 ]
  [ "$(git -C "$DOTFILES_DIR" hash-object .config/git/config)" = "$before" ]
}

@test "links into the repo spelled another way are repointed, not backed up" {
  real="$(cd "$DOTFILES_DIR" && pwd -P)"
  # Old-style link through a symlinked parent, like ~/Development -> ~/repos.
  ln -s "$real" "$BATS_TEST_TMPDIR/old-root"
  ln -s "$BATS_TEST_TMPDIR/old-root/.zshrc" "$TEST_HOME/.zshrc"
  # Relative link straight into the checkout.
  mkdir -p "$TEST_HOME/.config"
  ln -s "$(python3 -c 'import os,sys; print(os.path.relpath(sys.argv[1], os.path.realpath(sys.argv[2])))' "$real/.config/starship.toml" "$TEST_HOME/.config")" "$TEST_HOME/.config/starship.toml"
  install_into_test_home "$BATS_TEST_TMPDIR/no-such-signer"
  [ "$status" -eq 0 ]
  [ "$(readlink "$TEST_HOME/.zshrc")" = "$real/.zshrc" ]
  [ "$(readlink "$TEST_HOME/.config/starship.toml")" = "$real/.config/starship.toml" ]
  [ ! -e "$TEST_HOME/.dotfiles.backup" ]
  run git config --file "$TEST_HOME/.gitconfig" --get alias.dotfiles
  [ "$output" = "!git -C \"$real\"" ]
}
