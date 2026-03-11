# DOTFILES - MCRN TACTICAL TERMINAL

MCRN-themed dotfiles for Ghostty, zsh, tmux, Starship, and a Copilot-powered AI shell widget. Built for macOS. The canonical install location is `~/.dotfiles`.

## Highlights
- Ghostty with an MCRN palette, shell integration, native macOS titlebar, and inherited working directory.
- Zsh with fast completions, modern CLI defaults, and local overrides in `~/.zshrc.local`.
- Two-line Starship prompt with repo-aware path styling.
- Reproducible runtime management via pinned `mise` versions.

## Quick Start
```bash
git clone https://github.com/sammykins/dotfiles.git "$HOME/.dotfiles"
alias dotfiles='git -C "$HOME/.dotfiles"'
"$HOME/.dotfiles/scripts/install.sh"
exec zsh
```

## Install Model
- `~/.dotfiles` is the repo root and source of truth.
- The installer links tracked config files from the repo into `$HOME`.
- Local machine-only changes belong in `~/.zshrc.local`.
- Backups are stored under `$HOME/.dotfiles.backup/`.

## Optional Flags
- `DOTFILES_LINK_MODE=migrate|safe|force`: choose how existing files are handled. Default: `migrate`.
- `DOTFILES_DRY_RUN=1`: preview filesystem, Brew, and `mise` actions.
- `DOTFILES_CLOUD_BACKUP=1`: copy backups to iCloud if available.
- `DOTFILES_BACKUP_DIR=/path/to/backup`: override the backup target.
- `DOTFILES_INSTALL_WORKSTATION=1`: also install optional workstation GUI apps from `Brewfile.workstation`.
- `DOTFILES_APPLY_MACOS_DEFAULTS=1`: apply the repo's Finder, Dock recents, and screenshot defaults.
- `DOTFILES_APPLY_DOCK=1`: apply the repo's canonical Dock layout with `dockutil`.

## Dry Run
```bash
DOTFILES_DRY_RUN=1 DOTFILES_LINK_MODE=migrate \
  "$HOME/.dotfiles/scripts/install.sh"
"$HOME/.dotfiles/scripts/audit-macos-dotfiles.sh"
"$HOME/.dotfiles/scripts/report-unmanaged-brew-apps.sh"
```

## macOS Automation
- `DOTFILES_APPLY_MACOS_DEFAULTS=1` applies only low-risk settings: Finder visibility/view defaults, Dock recent-app suppression, and PNG screenshots in `~/Pictures/Screenshots`.
- `DOTFILES_APPLY_DOCK=1` resets the Dock to the repo's small canonical app set using `dockutil`.
- Raycast should be restored with Raycast Cloud Sync or settings export/import. Do not track `~/.config/raycast/config.json`; it contains machine auth tokens.
- iCloud Desktop/Documents is intentionally unmanaged here. This repo assumes Google Drive remains the preferred file-sync layer.

## Runtime Migration
```bash
DOTFILES_DRY_RUN=1 "$HOME/.dotfiles/scripts/migrate-to-mise.sh"
"$HOME/.dotfiles/scripts/audit-macos-dotfiles.sh"
"$HOME/.dotfiles/scripts/migrate-to-mise.sh"
```
- Detailed runbook: [`docs/macos-install-migration-pathway.md`](docs/macos-install-migration-pathway.md)
- Use this before onboarding a new Mac or reconciling an existing one.

## AI Command Generation
Press `Ctrl+G` and type a natural language request. The buffer is replaced with a single shell command. The widget uses GitHub Copilot SDK with `gpt-5-mini` by default, and you can override that with `MCRN_COPILOT_MODEL`.

## MCRN AI Paths
- Config: `$HOME/.dotfiles/zsh/plugins/mcrn-ai/config.json`
- Schema: `$HOME/.dotfiles/zsh/plugins/mcrn-ai/config.schema.json`
- Tools: `$HOME/.dotfiles/zsh/plugins/mcrn-ai/tools/index.mjs`

## Validation
```bash
bash "$HOME/.dotfiles/scripts/test.sh"
```

## Restore
```bash
"$HOME/.dotfiles/scripts/restore-dotfiles.sh"
```

## Troubleshooting
- Ghostty config: `$HOME/.config/ghostty/config`
- Mise config: `$HOME/.config/mise/config.toml`
- Zsh config: `$HOME/.zshrc`
- MCRN AI debug log: `/tmp/mcrn-ai-debug.log`

## References
- Ghostty: [ghostty.org](https://ghostty.org/)
- MCRN theme guide: [`docs/expanse-mcrn-theme.md`](docs/expanse-mcrn-theme.md)
