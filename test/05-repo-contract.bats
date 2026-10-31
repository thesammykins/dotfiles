#!/usr/bin/env bats

setup() {
  export DOTFILES_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
}

@test "repo contract uses ~/Development/dotfiles as canonical path" {
  run rg -n --hidden --glob '!.git/**' --glob '!test/05-repo-contract.bats' '(\$HOME/\.dotfiles|~/\.dotfiles)(/|"|$)' "$DOTFILES_DIR"
  [ "$status" -ne 0 ]
}

@test ".zprofile does not source .zshrc" {
  run rg -n 'source ".*\.zshrc"' "$DOTFILES_DIR/.zprofile"
  [ "$status" -ne 0 ]
}

@test "terminal-app themes and generated shell widgets are not tracked" {
  run rg -n --hidden --glob '!.git/**' --glob '!test/05-repo-contract.bats' \
    'MCRN|mcrn-ai|Ghostty|ghostty|Copilot SDK|copilot-sdk|MCRN_COPILOT|fastfetch|opencode-desktop|copilot-cli' \
    "$DOTFILES_DIR"
  [ "$status" -ne 0 ]
}

@test "README and AGENTS describe simple ownership" {
  run rg -n '\$HOME/Development/dotfiles|~/Development/dotfiles' "$DOTFILES_DIR/README.md" "$DOTFILES_DIR/AGENTS.md"
  [ "$status" -eq 0 ]

  run rg -n 'terminal-app themes|generated shell widgets|skills' "$DOTFILES_DIR/README.md" "$DOTFILES_DIR/AGENTS.md"
  [ "$status" -eq 0 ]
}

@test "one manifest owns every managed home path" {
  run cat "$DOTFILES_DIR/scripts/managed-paths.txt"
  [ "$status" -eq 0 ]
  [ "$output" = $'.zshrc\n.zprofile\n.config/starship.toml\n.config/mise/config.toml\n.config/atuin/config.toml\n.config/git/ignore\n.config/git/config\n.config/git/allowed_signers\n.config/git/signing.gitconfig\n.config/varlock/.env.schema\n.agents/AGENTS.md' ]

  run rg -l 'managed-paths\.txt' "$DOTFILES_DIR/scripts"
  [ "$output" = "$DOTFILES_DIR/scripts/install.sh" ]
}
