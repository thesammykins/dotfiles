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

@test "audit points users to the single guided setup" {
  run rg -n '\./setup\.sh' "$DOTFILES_DIR/scripts/audit-macos-dotfiles.sh"
  [ "$status" -eq 0 ]

  run rg -n 'mise run plan|mise run apply' "$DOTFILES_DIR/scripts/audit-macos-dotfiles.sh"
  [ "$status" -ne 0 ]
}

@test "install contract is explicit about linked files" {
  run rg -n 'link_item "\$DOTFILES_WORKTREE/\.zshrc"' "$DOTFILES_DIR/scripts/install.sh"
  [ "$status" -eq 0 ]

  run rg -n 'link_item "\$DOTFILES_WORKTREE/\.config/starship\.toml"' "$DOTFILES_DIR/scripts/install.sh"
  [ "$status" -eq 0 ]

  run rg -n 'link_item "\$DOTFILES_WORKTREE/\.config/mise/config\.toml"' "$DOTFILES_DIR/scripts/install.sh"
  [ "$status" -eq 0 ]

  run rg -n 'link_item "\$DOTFILES_WORKTREE/\.agents/AGENTS\.md"' "$DOTFILES_DIR/scripts/install.sh"
  [ "$status" -eq 0 ]
}
