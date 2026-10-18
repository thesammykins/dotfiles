#!/usr/bin/env bats

setup() {
  export DOTFILES_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  export TEST_HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$TEST_HOME"
}

run_installer() {
  run env HOME="$TEST_HOME" DOTFILES_WORKTREE="$DOTFILES_DIR" DOTFILES_ROOT="$DOTFILES_DIR" \
    DOTFILES_INSTALL_BREW=0 DOTFILES_APPLY_MACOS_DEFAULTS=0 DOTFILES_LINK_MODE="$1" \
    bash "$DOTFILES_DIR/scripts/install.sh"
}

create_faulting_mv() {
  fake_bin="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$fake_bin"
  cat > "$fake_bin/mv" <<'EOF'
#!/bin/bash
count_file="${RESTORE_MV_COUNT:?}"
count=0
[[ ! -f "$count_file" ]] || count="$(cat "$count_file")"
count=$((count + 1))
printf '%s\n' "$count" > "$count_file"
case ",${RESTORE_MV_FAIL_ON:-}," in
  *",$count,"*) exit 42 ;;
esac
exec /bin/mv "$@"
EOF
  chmod +x "$fake_bin/mv"
}

@test "installer rejects an invalid link mode before touching home" {
  printf 'keep\n' > "$TEST_HOME/.zshrc"

  run_installer mistyped

  [ "$status" -ne 0 ]
  [[ "$output" == *"Invalid DOTFILES_LINK_MODE"* ]]
  [ "$(cat "$TEST_HOME/.zshrc")" = "keep" ]
  [ ! -d "$TEST_HOME/.dotfiles.backup" ]
}

@test "installer accepts a checkout represented by a gitfile" {
  worktree="$BATS_TEST_TMPDIR/worktree"
  mkdir -p "$worktree/.config" "$worktree/.agents"
  printf 'gitdir: /tmp/example.git/worktrees/example\n' > "$worktree/.git"
  while IFS= read -r relative; do
    mkdir -p "$worktree/$(dirname "$relative")"
    printf 'managed\n' > "$worktree/$relative"
  done < "$DOTFILES_DIR/scripts/managed-paths.txt"

  run env HOME="$TEST_HOME" DOTFILES_WORKTREE="$worktree" DOTFILES_ROOT="$DOTFILES_DIR" \
    DOTFILES_DRY_RUN=1 DOTFILES_INSTALL_BREW=0 DOTFILES_LINK_MODE=safe \
    bash "$DOTFILES_DIR/scripts/install.sh"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Repo already exists"* ]]
  [[ "$output" != *"git clone"* ]]
}

@test "restore preflight rejects a missing symlink target before changing any file" {
  backup="$BATS_TEST_TMPDIR/backup"
  mkdir -p "$backup"
  printf 'restored\n' > "$backup/.zshrc"
  printf '%s\n' "$BATS_TEST_TMPDIR/missing-target" > "$backup/.zprofile.symlink"
  printf 'live-zshrc\n' > "$TEST_HOME/.zshrc"
  printf 'live-zprofile\n' > "$TEST_HOME/.zprofile"

  run env HOME="$TEST_HOME" bash "$DOTFILES_DIR/scripts/restore-dotfiles.sh" --yes "$backup"

  [ "$status" -ne 0 ]
  [[ "$output" == *"symlink target does not exist"* ]]
  [ "$(cat "$TEST_HOME/.zshrc")" = "live-zshrc" ]
  [ "$(cat "$TEST_HOME/.zprofile")" = "live-zprofile" ]
}

@test "restore requires confirmation and dry-run changes nothing" {
  backup="$BATS_TEST_TMPDIR/backup"
  mkdir -p "$backup"
  printf 'restored\n' > "$backup/.zshrc"
  printf 'live\n' > "$TEST_HOME/.zshrc"

  run env HOME="$TEST_HOME" bash "$DOTFILES_DIR/scripts/restore-dotfiles.sh" "$backup"
  [ "$status" -ne 0 ]
  [[ "$output" == *"requires --yes"* ]]

  run env HOME="$TEST_HOME" bash "$DOTFILES_DIR/scripts/restore-dotfiles.sh" --dry-run "$backup"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Would restore: .zshrc"* ]]
  [ "$(cat "$TEST_HOME/.zshrc")" = "live" ]
}

@test "restore round-trips every available managed path including git ignore" {
  backup="$BATS_TEST_TMPDIR/backup"
  mkdir -p "$backup/.config/git"
  printf 'restored shell\n' > "$backup/.zshrc"
  printf 'restored ignore\n' > "$backup/.config/git/ignore"
  printf 'live shell\n' > "$TEST_HOME/.zshrc"
  mkdir -p "$TEST_HOME/.config/git"
  printf 'live ignore\n' > "$TEST_HOME/.config/git/ignore"

  run env HOME="$TEST_HOME" bash "$DOTFILES_DIR/scripts/restore-dotfiles.sh" --yes "$backup"

  [ "$status" -eq 0 ]
  [ "$(cat "$TEST_HOME/.zshrc")" = "restored shell" ]
  [ "$(cat "$TEST_HOME/.config/git/ignore")" = "restored ignore" ]
  rollback="$(printf '%s\n' "$output" | sed -n 's/^.*Rollback retained at: //p' | tail -1)"
  [ -f "$rollback/.zshrc" ]
  [ "$(cat "$rollback/.zshrc")" = "live shell" ]
}

@test "restore creates a unique rollback directory for each run" {
  backup="$BATS_TEST_TMPDIR/backup"
  mkdir -p "$backup"
  printf 'restored\n' > "$backup/.zshrc"
  printf 'live\n' > "$TEST_HOME/.zshrc"

  run env HOME="$TEST_HOME" bash "$DOTFILES_DIR/scripts/restore-dotfiles.sh" --yes "$backup"
  [ "$status" -eq 0 ]
  first_rollback="$(printf '%s\n' "$output" | sed -n 's/^.*Rollback retained at: //p' | tail -1)"

  run env HOME="$TEST_HOME" bash "$DOTFILES_DIR/scripts/restore-dotfiles.sh" --yes "$backup"
  [ "$status" -eq 0 ]
  second_rollback="$(printf '%s\n' "$output" | sed -n 's/^.*Rollback retained at: //p' | tail -1)"

  [ -d "$first_rollback" ]
  [ -d "$second_rollback" ]
  [ "$first_rollback" != "$second_rollback" ]
}

@test "restore rolls back every changed target when promotion fails" {
  backup="$BATS_TEST_TMPDIR/backup"
  mkdir -p "$backup"
  printf 'restored zshrc\n' > "$backup/.zshrc"
  printf 'restored zprofile\n' > "$backup/.zprofile"
  printf 'live zshrc\n' > "$TEST_HOME/.zshrc"
  printf 'live zprofile\n' > "$TEST_HOME/.zprofile"
  create_faulting_mv

  run env HOME="$TEST_HOME" PATH="$fake_bin:/usr/bin:/bin" RESTORE_MV_COUNT="$BATS_TEST_TMPDIR/mv-count" RESTORE_MV_FAIL_ON=4 \
    bash "$DOTFILES_DIR/scripts/restore-dotfiles.sh" --yes "$backup"

  [ "$status" -ne 0 ]
  [[ "$output" == *"applied changes were rolled back"* ]]
  [ "$(cat "$TEST_HOME/.zshrc")" = "live zshrc" ]
  [ "$(cat "$TEST_HOME/.zprofile")" = "live zprofile" ]
}

@test "restore never deletes the original when its first save move fails" {
  backup="$BATS_TEST_TMPDIR/backup"
  mkdir -p "$backup"
  printf 'restored\n' > "$backup/.zshrc"
  printf 'live\n' > "$TEST_HOME/.zshrc"
  create_faulting_mv

  run env HOME="$TEST_HOME" PATH="$fake_bin:/usr/bin:/bin" RESTORE_MV_COUNT="$BATS_TEST_TMPDIR/mv-count" RESTORE_MV_FAIL_ON=1 \
    bash "$DOTFILES_DIR/scripts/restore-dotfiles.sh" --yes "$backup"

  [ "$status" -ne 0 ]
  [[ "$output" == *"applied changes were rolled back"* ]]
  [ "$(cat "$TEST_HOME/.zshrc")" = "live" ]
}

@test "restore reverts earlier paths when a later save move fails" {
  backup="$BATS_TEST_TMPDIR/backup"
  mkdir -p "$backup"
  printf 'restored zshrc\n' > "$backup/.zshrc"
  printf 'restored zprofile\n' > "$backup/.zprofile"
  printf 'live zshrc\n' > "$TEST_HOME/.zshrc"
  printf 'live zprofile\n' > "$TEST_HOME/.zprofile"
  create_faulting_mv

  run env HOME="$TEST_HOME" PATH="$fake_bin:/usr/bin:/bin" RESTORE_MV_COUNT="$BATS_TEST_TMPDIR/mv-count" RESTORE_MV_FAIL_ON=3 \
    bash "$DOTFILES_DIR/scripts/restore-dotfiles.sh" --yes "$backup"

  [ "$status" -ne 0 ]
  [[ "$output" == *"applied changes were rolled back"* ]]
  [ "$(cat "$TEST_HOME/.zshrc")" = "live zshrc" ]
  [ "$(cat "$TEST_HOME/.zprofile")" = "live zprofile" ]
}

@test "restore reports incomplete rollback and retains an original when restore-back fails" {
  backup="$BATS_TEST_TMPDIR/backup"
  mkdir -p "$backup"
  printf 'restored zshrc\n' > "$backup/.zshrc"
  printf 'restored zprofile\n' > "$backup/.zprofile"
  printf 'live zshrc\n' > "$TEST_HOME/.zshrc"
  printf 'live zprofile\n' > "$TEST_HOME/.zprofile"
  create_faulting_mv

  run env HOME="$TEST_HOME" PATH="$fake_bin:/usr/bin:/bin" RESTORE_MV_COUNT="$BATS_TEST_TMPDIR/mv-count" RESTORE_MV_FAIL_ON=4,5 \
    bash "$DOTFILES_DIR/scripts/restore-dotfiles.sh" --yes "$backup"

  [ "$status" -ne 0 ]
  [[ "$output" == *"rollback is incomplete"* ]]
  [[ "$output" != *"applied changes were rolled back"* ]]
  rollback="$(printf '%s\n' "$output" | sed -n 's/^.*Recovery files retained at: //p' | tail -1)"
  [ -f "$rollback/.zprofile" ]
  [ "$(cat "$rollback/.zprofile")" = "live zprofile" ]
  [ "$(cat "$TEST_HOME/.zshrc")" = "live zshrc" ]
}
