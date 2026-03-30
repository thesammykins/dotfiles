# DOTFILES - MCRN TACTICAL TERMINAL

MCRN-themed dotfiles for Ghostty, zsh, Starship, OpenCode, and a Copilot-powered AI shell widget. Built for macOS. The canonical install location is `~/.dotfiles`.

## Highlights
- Ghostty with an MCRN palette, shell integration, native macOS titlebar, and inherited working directory.
- Zsh with fast completions, modern CLI defaults, and local overrides in `~/.zshrc.local`.
- Two-line Starship prompt with repo-aware path styling.
- Reproducible runtime management via pinned `mise` versions.
- Split Homebrew bundles for base machine, developer stack, and workstation apps.
- A tracked `.agents/` directory for `dotagents`-style cross-tool AI rule and skill sync.

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
- `DOTFILES_INSTALL_DEV=1`: also install the developer stack from `Brewfile.dev`.
- `DOTFILES_INSTALL_WORKSTATION=1`: also install workstation apps from `Brewfile.workstation`.
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
- Dia is intentionally handled outside Homebrew. Install it from `diabrowser.com`, then use the Dia backup scripts in this repo to move the local profile between Macs.
- iCloud Desktop/Documents is intentionally unmanaged here. This repo assumes cloud file sync is optional and browser migration is handled explicitly.

## Brewfile Tiers
- `Brewfile`: base shell, terminal, CLI, auth, and Tailscale baseline.
- `Brewfile.dev`: developer machine additions such as `mise`, `opencode`, `varlock`, validation tools, and `orbstack`.
- `Brewfile.workstation`: daily GUI apps for this personal workstation setup (`zed`, `raycast`, `beeper`, `vesktop`, `opencode-desktop`, `QuickDrop`).

## 1Password And Varlock
- Stable env-style secrets live in the `ENV` vault in 1Password, not in tracked config or shell startup files.
- The tracked schema lives at `.config/varlock/.env.schema` and currently resolves local secrets with `op read`, which keeps the setup simple while still using the 1Password desktop app integration.
- The current baseline maps `CONTEXT7_API_KEY`, `ZAI_API_KEY`, `TF_TOKEN_app_terraform_io`, and `NPM_TOKEN` from `op://ENV/...` references.
- Use `vopencode` for interactive OpenCode sessions and `vrun <command>` for other commands that need the same env set.
- Local consumers should prefer env substitution like `{env:CONTEXT7_API_KEY}` or `${NPM_TOKEN}` over hardcoded values.

```bash
vopencode
vrun terraform plan
vrun npm whoami
```

- Reference docs: [`varlock llms.txt`](https://varlock.dev/llms.txt), [`AI tools`](https://varlock.dev/guides/ai-tools/), [`1Password plugin`](https://varlock.dev/plugins/1password/), [`CLI commands`](https://varlock.dev/reference/cli-commands/)

## dotagents
- `.agents/AGENTS.md` is the shared global rules file intended for `dotagents` distribution across Claude, Codex, OpenCode, Gemini, and other supported clients.
- `.agents/skills/` is tracked here so the same skill catalog can be synced onto a fresh Mac without rebuilding local agent state by hand.
- Re-run `npx @iannuttall/dotagents` or `bunx @iannuttall/dotagents` after changing `.agents/` so the tool repairs its symlinks into `~/.claude`, `~/.codex`, `~/.config/opencode`, and related client paths.

## Dia Backup And Restore
Install Dia manually, launch it once, then use:

```bash
"$HOME/.dotfiles/scripts/backup-dia-profile.sh"
"$HOME/.dotfiles/scripts/restore-dia-profile.sh" /path/to/dia-backup
```

- The backup script copies local Dia profile data while excluding caches and lock files.
- Expect bookmarks, history, and settings to migrate well.
- Expect some login state to need reauthentication because parts of Chromium auth can be keychain-backed.

## Runtime Migration
```bash
DOTFILES_DRY_RUN=1 "$HOME/.dotfiles/scripts/migrate-to-mise.sh"
"$HOME/.dotfiles/scripts/audit-macos-dotfiles.sh"
"$HOME/.dotfiles/scripts/migrate-to-mise.sh"
```
- Detailed runbook: [`docs/macos-install-migration-pathway.md`](docs/macos-install-migration-pathway.md)
- Use this before onboarding a new Mac or reconciling an existing one.

## AI Command Generation
Press `Ctrl+G` and type a natural language request. The buffer is replaced with a single shell command. The widget uses GitHub Copilot SDK with `gpt-5-mini` by default, and it now expects the standalone `copilot` CLI to be installed via `Brewfile.dev`.

- Quick model override: set `MCRN_COPILOT_MODEL` in `~/.zshrc.local`.
- Repo default model: edit `zsh/plugins/mcrn-ai/config.json` under `model.default`.

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
- Varlock schema: `$HOME/.dotfiles/.config/varlock/.env.schema`
- Zsh config: `$HOME/.zshrc`
- MCRN AI debug log: `/tmp/mcrn-ai-debug.log`

## References
- Ghostty: [ghostty.org](https://ghostty.org/)
- MCRN theme guide: [`docs/expanse-mcrn-theme.md`](docs/expanse-mcrn-theme.md)
