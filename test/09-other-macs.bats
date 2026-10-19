#!/usr/bin/env bats
# Behaviour that only shows up on a Mac other than the first one: no
# 1Password signer, no ~/.gitconfig yet, older backups, remote sessions.

setup() {
  export DOTFILES_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  export TEST_HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$TEST_HOME"
}

install_into_test_home() {
  run env HOME="$TEST_HOME" DOTFILES_WORKTREE="$DOTFILES_DIR" DOTFILES_ROOT="$DOTFILES_DIR" \
    DOTFILES_INSTALL_BREW=0 DOTFILES_APPLY_MACOS_DEFAULTS=0 DOTFILES_LINK_MODE=safe \
    DOTFILES_GIT_SIGNER="$1" /bin/bash "$DOTFILES_DIR/scripts/install.sh"
}

@test "without the 1Password signer, git still commits (unsigned)" {
  install_into_test_home "$BATS_TEST_TMPDIR/no-such-signer"
  [ "$status" -eq 0 ]
  [ ! -e "$TEST_HOME/.config/git/signing.gitconfig" ]

  repo="$BATS_TEST_TMPDIR/repo"
  git init -q "$repo"
  run env HOME="$TEST_HOME" GIT_CONFIG_NOSYSTEM=1 git -C "$repo" commit -q --allow-empty -m test
  [ "$status" -eq 0 ]
  run env HOME="$TEST_HOME" GIT_CONFIG_NOSYSTEM=1 git -C "$repo" config --get commit.gpgsign
  [ -z "$output" ]
}

@test "with the signer, commit signing is linked" {
  signer="$BATS_TEST_TMPDIR/op-ssh-sign"
  printf '#!/bin/sh\n' > "$signer"
  chmod +x "$signer"
  install_into_test_home "$signer"
  [ "$status" -eq 0 ]
  [ -L "$TEST_HOME/.config/git/signing.gitconfig" ]
  run env HOME="$TEST_HOME" GIT_CONFIG_NOSYSTEM=1 git config --get commit.gpgsign
  [ "$output" = "true" ]
}

@test "the installer's git alias goes to ~/.gitconfig, not the tracked config" {
  before="$(git -C "$DOTFILES_DIR" hash-object .config/git/config)"
  install_into_test_home "$BATS_TEST_TMPDIR/no-such-signer"
  [ "$status" -eq 0 ]
  run env HOME="$TEST_HOME" git config --file "$TEST_HOME/.gitconfig" --get alias.dotfiles
  [ "$status" -eq 0 ]
  [ "$(git -C "$DOTFILES_DIR" hash-object .config/git/config)" = "$before" ]
}

@test "restore without a path skips backups that only link back to the repo" {
  root="$TEST_HOME/.dotfiles.backup"
  mkdir -p "$root/20260101_000000" "$root/20260202_000000"
  printf 'my original\n' > "$root/20260101_000000/.zshrc"
  printf '%s\n' "$(cd "$DOTFILES_DIR" && pwd -P)/.zshrc" > "$root/20260202_000000/.zshrc.symlink"

  run env HOME="$TEST_HOME" /bin/bash "$DOTFILES_DIR/scripts/restore-dotfiles.sh" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"Restore plan from $root/20260101_000000"* ]]
}

@test "restore explains a staging failure and leaves no staging files" {
  backup="$BATS_TEST_TMPDIR/backup"
  mkdir -p "$backup/.config/atuin"
  printf 'restored\n' > "$backup/.zshrc"
  printf 'unreadable\n' > "$backup/.config/atuin/config.toml"
  chmod 000 "$backup/.config/atuin/config.toml"
  printf 'live\n' > "$TEST_HOME/.zshrc"

  run env HOME="$TEST_HOME" /bin/bash "$DOTFILES_DIR/scripts/restore-dotfiles.sh" --yes "$backup"
  chmod 600 "$backup/.config/atuin/config.toml"

  [ "$status" -ne 0 ]
  [[ "$output" == *"Restore staging failed; no live files were changed"* ]]
  [ "$(cat "$TEST_HOME/.zshrc")" = "live" ]
  [ -z "$(find "$TEST_HOME" -name '*.restore-new.*')" ]
}

@test "uninstall keeps Tailscale unless asked by name" {
  run /bin/bash "$DOTFILES_DIR/scripts/brew-tiers.sh" uninstall --keep none core
  [ "$status" -eq 0 ]
  [[ "$output" == *"Keeping tailscale-app"* ]]
  [[ "$output" != *"--cask tailscale-app"* ]]
  run /bin/bash "$DOTFILES_DIR/scripts/brew-tiers.sh" uninstall --keep none --remove-tailscale core
  [[ "$output" == *"brew uninstall --cask tailscale-app"* ]]
}

@test "signing is unlinked when the signer disappears" {
  signer="$BATS_TEST_TMPDIR/op-ssh-sign"
  printf '#!/bin/sh\n' > "$signer"
  chmod +x "$signer"
  install_into_test_home "$signer"
  [ -L "$TEST_HOME/.config/git/signing.gitconfig" ]
  rm "$signer"
  install_into_test_home "$signer"
  [ "$status" -eq 0 ]
  [ ! -e "$TEST_HOME/.config/git/signing.gitconfig" ]
  repo="$BATS_TEST_TMPDIR/repo"
  git init -q "$repo"
  run env HOME="$TEST_HOME" GIT_CONFIG_NOSYSTEM=1 git -C "$repo" commit -q --allow-empty -m test
  [ "$status" -eq 0 ]
}

@test "restore through a symlinked checkout still skips link-only backups" {
  alias_dir="$BATS_TEST_TMPDIR/dotfiles-link"
  ln -s "$DOTFILES_DIR" "$alias_dir"
  root="$TEST_HOME/.dotfiles.backup"
  mkdir -p "$root/20260101_000000" "$root/20260202_000000"
  printf 'my original\n' > "$root/20260101_000000/.zshrc"
  printf '%s\n' "$alias_dir/.zshrc" > "$root/20260202_000000/.zshrc.symlink"

  run env HOME="$TEST_HOME" /bin/bash "$alias_dir/scripts/restore-dotfiles.sh" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"Restore plan from $root/20260101_000000"* ]]
}

@test "restore reports a failure on the very first item without bash 3.2 errors" {
  backup="$BATS_TEST_TMPDIR/backup"
  mkdir -p "$backup"
  printf 'unreadable\n' > "$backup/.zshrc"
  chmod 000 "$backup/.zshrc"
  run env HOME="$TEST_HOME" /bin/bash "$DOTFILES_DIR/scripts/restore-dotfiles.sh" --yes "$backup"
  chmod 600 "$backup/.zshrc"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Restore staging failed"* ]]
  [[ "$output" != *"unbound variable"* ]]
}

@test "a dry run without Homebrew warns, records nothing and skips its own links" {
  install_into_test_home "$BATS_TEST_TMPDIR/no-such-signer"
  run env HOME="$TEST_HOME" PATH="/usr/bin:/bin" DOTFILES_HOMEBREW_PREFIXES="$BATS_TEST_TMPDIR/no-homebrew" \
    DOTFILES_WORKTREE="$DOTFILES_DIR" DOTFILES_ROOT="$DOTFILES_DIR" \
    DOTFILES_DRY_RUN=1 DOTFILES_INSTALL_BREW=1 DOTFILES_TIERS=core DOTFILES_APPLY_MACOS_DEFAULTS=0 \
    DOTFILES_STATUS_FILE="$BATS_TEST_TMPDIR/status.json" DOTFILES_GIT_SIGNER="$BATS_TEST_TMPDIR/no-such-signer" \
    /bin/bash "$DOTFILES_DIR/scripts/install.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Homebrew is not installed"* ]]
  [[ "$output" != *"Would back up: $TEST_HOME/.zshrc"* ]]
  run python3 -c 'import json,sys; s=json.load(open(sys.argv[1])); print(s["result"], len(s["linked"]))' "$BATS_TEST_TMPDIR/status.json"
  [ "$output" = "dry-run 0" ]
}

@test "a re-run with nothing to back up leaves no backup folder" {
  install_into_test_home "$BATS_TEST_TMPDIR/no-such-signer"
  run env HOME="$TEST_HOME" DOTFILES_WORKTREE="$DOTFILES_DIR" DOTFILES_ROOT="$DOTFILES_DIR" \
    DOTFILES_INSTALL_BREW=0 DOTFILES_APPLY_MACOS_DEFAULTS=0 DOTFILES_LINK_MODE=migrate \
    DOTFILES_BACKUP_DIR="$BATS_TEST_TMPDIR/rerun-backup" DOTFILES_GIT_SIGNER="$BATS_TEST_TMPDIR/no-such-signer" \
    /bin/bash "$DOTFILES_DIR/scripts/install.sh"
  [ "$status" -eq 0 ]
  [ ! -e "$BATS_TEST_TMPDIR/rerun-backup" ]
  [[ "$output" == *"No existing files needed a backup."* ]]
}

@test "through a symlinked checkout, signing is still unlinked when the signer goes" {
  alias_dir="$BATS_TEST_TMPDIR/dotfiles-link"
  ln -s "$DOTFILES_DIR" "$alias_dir"
  signer="$BATS_TEST_TMPDIR/op-ssh-sign"
  printf '#!/bin/sh\n' > "$signer"
  chmod +x "$signer"
  # Link once through the real path, then run again through the alias.
  install_into_test_home "$signer"
  rm "$signer"
  run env HOME="$TEST_HOME" DOTFILES_WORKTREE="$alias_dir" DOTFILES_ROOT="$alias_dir" \
    DOTFILES_INSTALL_BREW=0 DOTFILES_APPLY_MACOS_DEFAULTS=0 DOTFILES_LINK_MODE=safe \
    DOTFILES_GIT_SIGNER="$signer" /bin/bash "$alias_dir/scripts/install.sh"
  [ "$status" -eq 0 ]
  [ ! -e "$TEST_HOME/.config/git/signing.gitconfig" ]
  [[ "$output" != *"Link differs, skipping"* ]]
}

@test "re-running the installer doesn't create link-only backups" {
  install_into_test_home "$BATS_TEST_TMPDIR/no-such-signer"
  run env HOME="$TEST_HOME" DOTFILES_WORKTREE="$DOTFILES_DIR" DOTFILES_ROOT="$DOTFILES_DIR" \
    DOTFILES_INSTALL_BREW=0 DOTFILES_APPLY_MACOS_DEFAULTS=0 DOTFILES_LINK_MODE=migrate \
    DOTFILES_BACKUP_DIR="$BATS_TEST_TMPDIR/second-backup" DOTFILES_GIT_SIGNER="$BATS_TEST_TMPDIR/no-such-signer" \
    /bin/bash "$DOTFILES_DIR/scripts/install.sh"
  [ "$status" -eq 0 ]
  [ -z "$(find "$BATS_TEST_TMPDIR/second-backup" -name '*.symlink' 2>/dev/null)" ]
}

@test "the ci tier installs delta, which the shared git config uses as its pager" {
  run rg -F -x 'brew "git-delta"' "$DOTFILES_DIR/Brewfile.ci"
  [ "$status" -eq 0 ]
}
