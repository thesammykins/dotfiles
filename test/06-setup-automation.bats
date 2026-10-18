#!/usr/bin/env bats

setup() {
  export DOTFILES_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
}

@test "workstation Brewfile includes Beeper, Vesktop, and QuickDrop" {
  run rg -n 'cask "beeper"|cask "vesktop"|mas "QuickDrop", id: 6740147178' "$DOTFILES_DIR/Brewfile.workstation"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "beeper" ]]
  [[ "$output" =~ "vesktop" ]]
  [[ "$output" =~ "QuickDrop" ]]
}

@test "developer Brewfile standardizes on OrbStack and OpenCode" {
  run rg -n 'cask "orbstack"|tap "anomalyco/tap"|brew "anomalyco/tap/opencode"' "$DOTFILES_DIR/Brewfile.dev"
  [ "$status" -eq 0 ]
}

@test "developer Brewfile owns host utilities and mobile toolchains" {
  for entry in \
    'brew "shellcheck"' \
    'brew "shfmt"' \
    'brew "gitleaks"' \
    'brew "uv"' \
    'brew "buildkite/buildkite/bk@3"' \
    'brew "mobile-dev-inc/tap/maestro"' \
    'brew "asc"' \
    'brew "xcodes"' \
    'cask "android-commandlinetools"' \
    'cask "android-platform-tools"' \
    'cask "temurin"' \
    'mas "TestFlight", id: 899247664'; do
    run rg -F -x "$entry" "$DOTFILES_DIR/Brewfile.dev"
    [ "$status" -eq 0 ]
  done
}

@test "workstation Brewfile owns the selected daily applications" {
  for entry in \
    'cask "appcleaner"' \
    'cask "bitwarden"' \
    'cask "lzhgus/tap/capso"' \
    'cask "discord"' \
    'cask "handy"' \
    'cask "hyperkey"' \
    'cask "keyclu"' \
    'cask "stats"' \
    'cask "the-unarchiver"' \
    'cask "thebrowsercompany-dia"' \
    'cask "warp@preview"'; do
    run rg -F -x "$entry" "$DOTFILES_DIR/Brewfile.workstation"
    [ "$status" -eq 0 ]
  done
}

@test "installer exposes explicit macOS automation flags" {
  run rg -n 'DOTFILES_APPLY_MACOS_DEFAULTS' "$DOTFILES_DIR/scripts/install.sh" "$DOTFILES_DIR/README.md"
  [ "$status" -eq 0 ]
}

@test "installer does not upgrade Brew dependencies implicitly" {
  run rg -n 'bundle install --no-upgrade' "$DOTFILES_DIR/scripts/install.sh"
  [ "$status" -eq 0 ]
}

@test "installer exposes structured backend status" {
  run rg -n 'DOTFILES_STATUS_FILE|"linked"|"installed"|"skipped"|"outdated"|"failed"' \
    "$DOTFILES_DIR/scripts/install.sh"
  [ "$status" -eq 0 ]
}

@test "retired global runtime migration artifacts are absent" {
  run test -e "$DOTFILES_DIR/scripts/migrate-to-mise.sh" -o -e "$DOTFILES_DIR/scripts/runtime-formulas.txt"
  [ "$status" -ne 0 ]
}

@test "brew audit reports outdated packages separately" {
  run rg -n 'Tracked and installed but outdated|brew outdated' "$DOTFILES_DIR/scripts/report-unmanaged-brew-apps.sh"
  [ "$status" -eq 0 ]
}

@test "brew audit disables package-manager auto-update" {
  run rg -n '^export HOMEBREW_NO_AUTO_UPDATE=1$' "$DOTFILES_DIR/scripts/report-unmanaged-brew-apps.sh"
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

@test "installer uses defaults for optional macOS automation" {
  run rg -n 'defaults write|Pictures/Screenshots' "$DOTFILES_DIR/scripts/install.sh"
  [ "$status" -eq 0 ]
}

@test "personal app state helpers are not part of dotfiles" {
  run test -e "$DOTFILES_DIR/scripts/backup-dia-profile.sh" -o -e "$DOTFILES_DIR/scripts/restore-dia-profile.sh" -o -e "$DOTFILES_DIR/scripts/run-opencode.sh"
  [ "$status" -ne 0 ]

  run rg -n 'dockutil|vopencode' "$DOTFILES_DIR/scripts/install.sh" "$DOTFILES_DIR/.zshrc" "$DOTFILES_DIR/README.md"
  [ "$status" -ne 0 ]
}

@test "unmanaged app report script exists and checks brew plus mas" {
  run rg -n 'brew bundle dump|mas list|Brewfile.workstation' "$DOTFILES_DIR/scripts/report-unmanaged-brew-apps.sh"
  [ "$status" -eq 0 ]
}
