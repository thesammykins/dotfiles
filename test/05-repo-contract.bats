#!/usr/bin/env bats

setup() {
  export DOTFILES_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
}

@test "repo contract uses ~/.dotfiles as canonical path" {
  run rg -n --glob '!zsh/plugins/mcrn-ai/node_modules/**' --glob '!test/05-repo-contract.bats' '\$HOME/Development/dotfiles|~/Development/dotfiles' \
    "$DOTFILES_DIR"
  [ "$status" -ne 0 ]
}

@test ".zprofile does not source .zshrc" {
  run rg -n 'source ".*\.zshrc"' "$DOTFILES_DIR/.zprofile"
  [ "$status" -ne 0 ]
}

@test "Ghostty library mirror is not tracked in repo" {
  run test -e "$DOTFILES_DIR/Library/Application Support/com.mitchellh.ghostty/config"
  [ "$status" -ne 0 ]
}

@test "README and AGENTS describe canonical path" {
  run rg -n '\$HOME/\.dotfiles|~/\.dotfiles' "$DOTFILES_DIR/README.md" "$DOTFILES_DIR/AGENTS.md"
  [ "$status" -eq 0 ]
}

@test "Copilot-only contract is documented consistently" {
  run rg -n 'gpt-5-mini|Copilot SDK|copilot' \
    "$DOTFILES_DIR/README.md" \
    "$DOTFILES_DIR/AGENTS.md" \
    "$DOTFILES_DIR/zsh/plugins/mcrn-ai/AGENTS.md" \
    "$DOTFILES_DIR/zsh/plugins/mcrn-ai/SKILL.md"
  [ "$status" -eq 0 ]
}

@test "No repo docs or scripts reference removed local model flow" {
  run rg -n \
    'qwen3-codersmall|llama-server|llama\\.cpp|SKIP_MODEL_DOWNLOAD|local-helper\\.sh|MCRN_AI_PROVIDER|MCRN_LLM_' \
    "$DOTFILES_DIR/README.md" \
    "$DOTFILES_DIR/AGENTS.md" \
    "$DOTFILES_DIR/bootstrap" \
    "$DOTFILES_DIR/scripts/install.sh" \
    "$DOTFILES_DIR/Brewfile" \
    "$DOTFILES_DIR/docs/macos-install-migration-pathway.md" \
    "$DOTFILES_DIR/zsh/plugins/mcrn-ai/AGENTS.md" \
    "$DOTFILES_DIR/zsh/plugins/mcrn-ai/SKILL.md"
  [ "$status" -ne 0 ]
}
