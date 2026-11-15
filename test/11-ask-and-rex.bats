#!/usr/bin/env bats

setup() {
  export DOTFILES_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  export TEST_HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$TEST_HOME"
}

# Questions are full of ? and *; without noglob zsh stops at "no matches found".
# eval, because zsh -c parses its whole string before the alias exists.
@test "ask hands the question to the agent without globbing it" {
  run env HOME="$TEST_HOME" ASK_AGENT=custom ASK_COMMAND='print -r --' zsh -f -c \
    "source '$DOTFILES_DIR/.config/zsh/ask.zsh'; eval 'ask what is in *.nomatch?'"
  [ "$status" -eq 0 ]
  [ "${lines[-1]}" = 'what is in *.nomatch?' ]
}

# `source ~/.zshrc` in a running shell meets the noglob aliases from the first load.
@test "ask and ax still work after the shell config is sourced a second time" {
  mkdir -p "$TEST_HOME/bin"
  printf '#!/bin/sh\n' > "$TEST_HOME/bin/rex"
  chmod +x "$TEST_HOME/bin/rex"
  run env HOME="$TEST_HOME" PATH="$TEST_HOME/bin:$PATH" REX_SESSION=1 ASK_AGENT=custom ASK_COMMAND='print -r --' zsh -f -c \
    "source '$DOTFILES_DIR/.config/zsh/ask.zsh'; source '$DOTFILES_DIR/.config/zsh/ask.zsh' && eval 'ask is it *.nomatch?' && whence -w ax"
  [ "$status" -eq 0 ]
  [ "${lines[-2]}" = 'is it *.nomatch?' ]
  [ "${lines[-1]}" = 'ax: alias' ]
}

# This repo is public. Saved commands carry hostnames, so they go to the Mac's
# own copy, reached through the link install.sh makes, never the tracked list.
@test "saving a command writes this Mac's list, not the tracked one" {
  mkdir -p "$TEST_HOME/.config/rex/workflows"
  ln -s "$DOTFILES_DIR/.config/rex/workflows/pick.sh" "$TEST_HOME/.config/rex/workflows/pick.sh"
  before="$(cat "$DOTFILES_DIR/.config/rex/workflows/commands.txt")"

  run env HOME="$TEST_HOME" zsh -f "$TEST_HOME/.config/rex/workflows/pick.sh" --add 'ssh box.example' 'My box'
  [ "$status" -eq 0 ]
  [ "$(cat "$DOTFILES_DIR/.config/rex/workflows/commands.txt")" = "$before" ]
  [ ! -L "$TEST_HOME/.config/rex/workflows/commands.txt" ]

  run env HOME="$TEST_HOME" zsh -f "$TEST_HOME/.config/rex/workflows/pick.sh" --list
  [[ "${lines[-1]}" == *"My box"*"ssh box.example" ]]
  [ "${#lines[@]}" -gt 1 ]
}

# Cmd-B and Cmd-Shift-B run the same launcher; its second argument decides
# which program opens, and both must start in the calling terminal's directory.
@test "the file manager launcher opens the one it was asked for in the terminal's directory" {
  bin="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$bin"
  printf '%s\n' '#!/bin/sh' 'echo "{\"foreground\":{\"cwd\":\"/tmp/some dir\",\"name\":\"vim\"},\"home\":\"/wrong\"}"' > "$bin/rex"
  printf '%s\n' '#!/bin/sh' 'for a; do last="$a"; done; echo "fresh:$last" > "$OUT"' > "$bin/fresh"
  printf '%s\n' '#!/bin/sh' 'for a; do last="$a"; done; echo "yazi:$last" > "$OUT"' > "$bin/yazi"
  chmod +x "$bin"/*
  export OUT="$BATS_TEST_TMPDIR/out"

  PATH="$bin:$PATH" HOME="$TEST_HOME" sh "$DOTFILES_DIR/.config/rex/files/launch.sh" b1
  [ "$(cat "$OUT")" = 'fresh:/tmp/some dir' ]

  PATH="$bin:$PATH" HOME="$TEST_HOME" sh "$DOTFILES_DIR/.config/rex/files/launch.sh" b1 yazi
  [ "$(cat "$OUT")" = 'yazi:/tmp/some dir' ]
}
