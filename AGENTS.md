# AGENTS.md - Dotfiles

## Scope

This repo owns shell/app configuration, Homebrew bundle tiers, global `mise` config, and shared agent guidance. It does not own the skills catalog; install skills from `thesammykins/skills`.

## Core Rules

- Keep the setup simple, repeatable, and dry-run-friendly.
- Use `mise` for runtime/tool versions. Homebrew installs machine tools and GUI apps.
- Keep Brewfiles curated. Do not mirror every installed package on one Mac.
- `DOTFILES_INSTALL_BREW=0` is the config-only path used by `new-mac` after it handles Brew bundles.
- Do not store secrets in tracked files. Use 1Password and varlock references.
- Keep machine-specific overrides in local files such as `~/.zshrc.local`.
- Prefer explicit paths based on `$HOME` and `$DEV_ROOT`; do not hardcode usernames.

## Repo Boundaries

- `thesammykins/new-mac` orchestrates fresh-machine setup.
- `thesammykins/dotfiles` owns shell/app configuration and Brewfile tiers.
- `thesammykins/skills` owns custom skills and upstream skill source manifests.
- `thesammykins/codex-stuff` owns Codex plugin marketplace packaging.

## Canonical Paths

- Default checkout: `$HOME/Development/dotfiles`
- Zsh `DOTFILES`: `${DOTFILES:-$HOME/Development/dotfiles}`
- Backup root: `$HOME/.dotfiles.backup`
- Global `mise` config: `.config/mise/config.toml`

## Homebrew Bundle Layout

- `Brewfile`: base shell, terminal, auth, and core CLI baseline.
- `Brewfile.dev`: developer tools such as `mise`, Codex, OpenCode, `copilot-cli`, `varlock`, validation tools, and local containers.
- `Brewfile.workstation`: daily-use personal GUI apps.

## Agent Config

- `.agents/AGENTS.md` is the machine-level shared instruction file.
- `.agents/skills/` is intentionally not tracked here. Use `thesammykins/skills/scripts/install-skills.py`.
- Keep `.agents/commands/` and `.agents/hooks/` available for future agent integrations.

## Validation

Use these after touching bootstrap scripts, Brewfiles, `mise`, or the MCRN AI plugin:

```bash
mise run check
mise run audit
bash ./scripts/test.sh
bash ./scripts/audit-macos-dotfiles.sh
DOTFILES_DRY_RUN=1 DOTFILES_LINK_MODE=safe DOTFILES_INSTALL_DEV=1 DOTFILES_INSTALL_WORKSTATION=1 bash ./scripts/install.sh
```
