#!/usr/bin/env bats

setup() {
  export DOTFILES_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME/.cargo/bin" "$BATS_TEST_TMPDIR/bin"
  echo data > "$HOME/.cargo/bin/tool"
}

# Pretend ~/repos is a mounted filesystem; nothing else is mocked.
fake_mount() {
  mkdir -p "$HOME/repos"
  touch "$HOME/repos/.dotfiles-repos-volume"
  printf '#!/bin/sh\necho header; echo "/dev/disk9s9 0 0 0 0%% %s"\n' "$HOME/repos" > "$BATS_TEST_TMPDIR/bin/df"
  chmod +x "$BATS_TEST_TMPDIR/bin/df"
  export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
}

@test "refuses to move anything when ~/repos is not mounted" {
  mkdir -p "$HOME/repos"
  run /bin/bash "$DOTFILES_DIR/scripts/tool-storage.sh" --apply
  [ "$status" -ne 0 ]
  [[ "$output" == *"is not mounted"* ]]
  [ -d "$HOME/.cargo" ] && [ ! -L "$HOME/.cargo" ]
}

@test "preview changes nothing; apply moves and links; rerun is a no-op" {
  fake_mount
  run /bin/bash "$DOTFILES_DIR/scripts/tool-storage.sh"
  [ "$status" -eq 0 ]
  [ ! -L "$HOME/.cargo" ]

  run /bin/bash "$DOTFILES_DIR/scripts/tool-storage.sh" --apply
  [ "$status" -eq 0 ]
  [ -L "$HOME/.cargo" ]
  [ "$(cat "$HOME/.cargo/bin/tool")" = data ]
  [ ! -e "$HOME/go" ]

  run /bin/bash "$DOTFILES_DIR/scripts/tool-storage.sh" --apply
  [ "$status" -eq 0 ]
  [[ "$output" == *"linked   $HOME/.cargo"* ]]
}

@test "stops when the original and the volume copy both exist" {
  fake_mount
  mkdir -p "$HOME/repos/.tools/cargo"
  run /bin/bash "$DOTFILES_DIR/scripts/tool-storage.sh" --apply
  [ "$status" -ne 0 ]
  [ -d "$HOME/.cargo" ] && [ ! -L "$HOME/.cargo" ]
}
