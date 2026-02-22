# DOTFILES - MCRN TACTICAL TERMINAL

MCRN-THEMED DOTFILES FOR GHOSTTY + ZSH + MODERN CLI TOOLING. BUILT FOR MACOS.

## HIGHLIGHTS
- GHOSTTY WITH MCRN PALETTE AND WARP-LIKE WORKFLOW
- ZSH WITH FAST COMPLETIONS + MODERN CLI STACK
- MCRN AI ZLE WIDGET (CTRL+G) WITH COPILOT PRIMARY + LOCAL FALLBACK
- REPRODUCIBLE TOOLCHAIN VIA MISE + HOMEBREW

## QUICK START (THIS MAC)
```bash
git clone https://github.com/sammykins/dotfiles.git "$HOME/Development/dotfiles"
alias dotfiles='git -C "$HOME/Development/dotfiles"'
"$HOME/Development/dotfiles/.dotfiles/scripts/install.sh"
```

## SETUP DETAILS
- THE INSTALLER LINKS `~/.dotfiles` TO THE REPO'S `.dotfiles/` DIRECTORY.
- ZSH SOURCES `~/.zshrc`, WHICH LOADS THE MCRN AI WIDGET.

## QUICK START (NEW MAC)
```bash
git clone https://github.com/sammykins/dotfiles.git "$HOME/Development/dotfiles"
alias dotfiles='git -C "$HOME/Development/dotfiles"'
"$HOME/Development/dotfiles/.dotfiles/scripts/install.sh"
exec zsh
```

## MIGRATION NOTES (WARP -> GHOSTTY)
- WARP IS NOT REMOVED. SETTINGS MIGRATION IS MANUAL.
- BACKUPS ARE CREATED UNDER `$HOME/.dotfiles.backup/`.
- OPTIONAL ICLOUD BACKUP: `DOTFILES_CLOUD_BACKUP=1`.
- SAFE LINKING DEFAULT: EXISTING FILES ARE NOT OVERWRITTEN.

## OPTIONAL FLAGS
- SKIP MODEL DOWNLOAD: `SKIP_MODEL_DOWNLOAD=1` (AVOID 767MB DOWNLOAD)
- CUSTOM WORKTREE: `DOTFILES_WORKTREE=/path/to/dotfiles`
- LINK MODE: `DOTFILES_LINK_MODE=safe|force` (DEFAULT: SAFE)
- ICLOUD BACKUP: `DOTFILES_CLOUD_BACKUP=1`

## REQUIRED LOCATIONS
- REPO: `$HOME/Development/dotfiles`
- DOTFILES ROOT (ACTIVE): `$HOME/.dotfiles`

## AI COMMAND GENERATION
PRESS `CTRL+G` AND TYPE A NATURAL LANGUAGE REQUEST. THE BUFFER REPLACES WITH A SINGLE COMMAND.

## MCRN AI TOOL CONFIG
- CONFIG: `$HOME/.dotfiles/zsh/plugins/mcrn-ai/config.json`
- SCHEMA: `$HOME/.dotfiles/zsh/plugins/mcrn-ai/config.schema.json`
- TOOLS: `$HOME/.dotfiles/zsh/plugins/mcrn-ai/tools/index.mjs`

## TESTS
```bash
bats "$HOME/Development/dotfiles/test/"*.bats
```

## UPDATES
```bash
dotfiles pull
brew update && brew upgrade
```

## TROUBLESHOOTING
- GHOSTTY CONFIG: `$HOME/.config/ghostty/config`
- MISE CONFIG: `$HOME/.config/mise/config.toml`
- ZSH: `$HOME/.zshrc`
- MCRN AI DEBUG LOG: `/tmp/mcrn-ai-debug.log`

## CREDITS
- GHOSTTY: https://ghostty.org/
- MCRN THEME GUIDE: `.dotfiles/docs/expanse-mcrn-theme.md`
