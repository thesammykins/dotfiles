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

@test "uninstall keeps Tailscale unless asked by name" {
  run /bin/bash "$DOTFILES_DIR/scripts/brew-tiers.sh" uninstall --keep none core
  [ "$status" -eq 0 ]
  [[ "$output" == *"Keeping tailscale-app"* ]]
  [[ "$output" != *"--cask tailscale-app"* ]]
  run /bin/bash "$DOTFILES_DIR/scripts/brew-tiers.sh" uninstall --keep none --remove-tailscale core
  [[ "$output" == *"brew uninstall --cask tailscale-app"* ]]
}

@test "the ci tier installs delta, which the shared git config uses as its pager" {
  run rg -F -x 'brew "git-delta"' "$DOTFILES_DIR/Brewfile.ci"
  [ "$status" -eq 0 ]
}

@test "brew audit checks installed state instead of bundle leaves for missing items" {
  run bash -c '
    source "$1/scripts/report-unmanaged-brew-apps.sh"
    brew() {
      case "$1:${2:-}" in
        list:--formula) printf "%s\n" shellcheck uv ;;
        list:--cask) printf "%s\n" orbstack ;;
        tap:) printf "%s\n" vendor/tap ;;
      esac
    }
    installed_brew_entries
  ' _ "$DOTFILES_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" == $'brew:shellcheck\nbrew:uv\ncask:orbstack\ntap:vendor/tap' ]]
}

@test "brew audit normalizes tapped package names" {
  cat > "$BATS_TEST_TMPDIR/Brewfile" <<'EOF'
brew "anomalyco/tap/opencode"
cask "vendor/tap/example-app"
tap "vendor/tap"
EOF

  run bash -c 'source "$1/scripts/report-unmanaged-brew-apps.sh"; parse_brewfile_entries "$2"' _ \
    "$DOTFILES_DIR" "$BATS_TEST_TMPDIR/Brewfile"
  [ "$status" -eq 0 ]
  [[ "$output" == *"brew:opencode"* ]]
  [[ "$output" == *"cask:example-app"* ]]
  [[ "$output" == *"tap:vendor/tap"* ]]
}

@test "brew audit accepts left-padded MAS identifiers" {
  run bash -c '
    source "$1/scripts/report-unmanaged-brew-apps.sh"
    mas() { printf "    899247664  TestFlight      (4.3.1)\n"; }
    current_mas_entries
  ' _ "$DOTFILES_DIR"
  [ "$status" -eq 0 ]
  [ "$output" = $'mas:899247664\tTestFlight' ]
}
