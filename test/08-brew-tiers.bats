#!/usr/bin/env bats

setup() {
  export DOTFILES_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  export TIERS="$DOTFILES_DIR/scripts/brew-tiers.sh"
  # A stand-in brew that records calls, so no test can change this Mac.
  export FAKE_BIN="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$FAKE_BIN"
  printf '#!/bin/bash\necho "brew $*" >> "%s/brew.log"\n' "$BATS_TEST_TMPDIR" > "$FAKE_BIN/brew"
  chmod +x "$FAKE_BIN/brew"
}

@test "every third-party package's tap is declared in the same Brewfile" {
  for file in Brewfile Brewfile.workstation Brewfile.dev Brewfile.ci; do
    while read -r tap; do
      run rg -F -x "tap \"$tap\"" "$DOTFILES_DIR/$file"
      [ "$status" -eq 0 ] || { echo "$file uses $tap without declaring it"; false; }
    done < <(rg -o '^(brew|cask) "([^/"]+/[^/"]+)/' -r '$2' "$DOTFILES_DIR/$file" | sort -u)
  done
}

@test "dev tier installs the Buildkite CLI and agent" {
  run rg -F -x 'brew "buildkite/buildkite/buildkite-agent@3"' "$DOTFILES_DIR/Brewfile.dev"
  [ "$status" -eq 0 ]
  run rg -F -x 'brew "buildkite/buildkite/bk@3"' "$DOTFILES_DIR/Brewfile.dev"
  [ "$status" -eq 0 ]
}

@test "ci tier stays free of shell extras and desktop apps" {
  run rg -n 'starship|zsh-|atuin|yazi|cask "(1password|raycast|zed|orbstack)"$' "$DOTFILES_DIR/Brewfile.ci"
  [ "$status" -ne 0 ]
  run rg -F -x 'brew "buildkite/buildkite/buildkite-agent@3"' "$DOTFILES_DIR/Brewfile.ci"
  [ "$status" -eq 0 ]
}

@test "install trusts listed taps before bundling and honours dry run" {
  run env PATH="$FAKE_BIN:$PATH" /bin/bash "$TIERS" install --dry-run core dev
  [ "$status" -eq 0 ]
  [[ "$output" == *"brew trust --tap buildkite/buildkite"* ]]
  [[ "$output" == *"--file=$DOTFILES_DIR/Brewfile.dev"* ]]
  [ ! -e "$BATS_TEST_TMPDIR/brew.log" ]
}

@test "removing dev keeps anything core or workstation also lists" {
  run env PATH="$FAKE_BIN:$PATH" /bin/bash "$TIERS" uninstall dev
  [ "$status" -eq 0 ]
  [[ "$output" == *"brew uninstall --formula actionlint"* ]]
  [[ "$output" != *"--formula jq"* ]]
  [[ "$output" == *"Preview only"* ]]
  [ ! -e "$BATS_TEST_TMPDIR/brew.log" ]
}

@test "removing ci keeps layered tiers unless told to keep none" {
  run /bin/bash "$TIERS" uninstall ci
  [[ "$output" == *"Nothing to remove"* ]]
  run /bin/bash "$TIERS" uninstall --keep none ci
  [[ "$output" == *"brew uninstall --formula buildkite/buildkite/buildkite-agent@3"* ]]
}

@test "unknown tiers are rejected" {
  run /bin/bash "$TIERS" install laptop
  [ "$status" -ne 0 ]
  [[ "$output" == *"unknown tier: laptop"* ]]
}

@test "manual-installs.txt rows are kind, app and note separated by tabs" {
  run awk -F'\t' '!/^#/ && NF && !(NF == 3 && ($1 == "manual" || $1 == "ignore")) { print NR": "$0 }' \
    "$DOTFILES_DIR/manual-installs.txt"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
