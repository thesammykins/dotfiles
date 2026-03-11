#!/usr/bin/env bats

setup() {
  export DOTFILES_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
}

@test "ZLE plugin is sourced in zshrc" {
  run grep -E 'source "\$DOTFILES/zsh/plugins/mcrn-ai.zsh"' "$DOTFILES_DIR/.zshrc"
  [ "$status" -eq 0 ]
}

@test "Copilot model defaults to gpt-5-mini" {
  run grep -E 'MCRN_COPILOT_MODEL.*gpt-5-mini' "$DOTFILES_DIR/zsh/plugins/mcrn-ai.zsh"
  [ "$status" -eq 0 ]
}

@test "No local fallback remains in widget" {
  run rg -n '_mcrn_ai_call_local|_mcrn_ensure_server|MCRN_AI_PROVIDER|MCRN_LLM_' \
    "$DOTFILES_DIR/zsh/plugins/mcrn-ai.zsh"
  [ "$status" -ne 0 ]
}

@test "Local helper script has been removed" {
  run test -e "$DOTFILES_DIR/zsh/plugins/mcrn-ai/local-helper.sh"
  [ "$status" -ne 0 ]
}

@test "No local model install flow remains in active repo files" {
  run rg -n \
    'qwen3-codersmall|llama-server|llama\\.cpp|SKIP_MODEL_DOWNLOAD|MCRN_AI_PROVIDER|MCRN_LLM_' \
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
