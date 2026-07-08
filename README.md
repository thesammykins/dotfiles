# Dotfiles

Small macOS dotfiles repo for shell config, Homebrew bundle tiers, a narrow
global `mise` runtime baseline, and shared agent instructions.

Fresh Mac setup starts in [`thesammykins/new-mac`](https://github.com/thesammykins/new-mac).
This repo is the payload that `new-mac` installs.

## Quick Start

```bash
git clone https://github.com/thesammykins/dotfiles.git "$HOME/Development/dotfiles"
bash "$HOME/Development/dotfiles/scripts/install.sh"
exec zsh
```

## What This Repo Owns

- `.zshrc` and `.zprofile`
- `.config/starship.toml`
- `.config/mise/config.toml`
- `.config/atuin/config.toml`
- `.config/varlock/.env.schema`
- `.agents/AGENTS.md` and `.agents/GEMINI.md`
- `Brewfile`, `Brewfile.dev`, and `Brewfile.workstation`

It intentionally does not own terminal-app themes, generated AI widgets, local
browser profiles, secrets, or installed agent skills.

## Install Flags

- `DOTFILES_WORKTREE=/path/to/dotfiles`: override the checkout path.
- `DOTFILES_LINK_MODE=migrate|safe|force`: choose how existing files are handled. Default: `migrate`.
- `DOTFILES_DRY_RUN=1`: preview file, Brew, and `mise` actions.
- `DOTFILES_INSTALL_BREW=0`: link config without running Homebrew.
- `DOTFILES_INSTALL_DEV=1`: install developer tools from `Brewfile.dev`.
- `DOTFILES_INSTALL_WORKSTATION=1`: install personal apps from `Brewfile.workstation`.
- `DOTFILES_APPLY_MACOS_DEFAULTS=1`: apply low-risk Finder/Dock/screenshot defaults.
- `DOTFILES_CLOUD_BACKUP=1`: copy backups to iCloud if available.

## Brewfile Tiers

- `Brewfile`: core shell, CLI, auth, and VPN tools.
- `Brewfile.dev`: developer tools such as `mise`, Codex, OpenCode, validation tools, and OrbStack.
- `Brewfile.workstation`: personal GUI apps.

Keep these curated. Do not mirror every installed package from one Mac.

## Runtime Baseline

Global `mise` pins are intentionally small: Node, Python, Go, and uv. Put
project-specific tools such as Java, .NET, Gradle, Terraform, and deployment CLIs
in the project that needs them.

## Secrets

Tracked files must not contain secrets. Store durable env-style secrets in
1Password and expose them through varlock.

```bash
vrun npm whoami
```

## Validation

```bash
mise run check
mise run audit
DOTFILES_DRY_RUN=1 DOTFILES_LINK_MODE=safe DOTFILES_INSTALL_DEV=1 DOTFILES_INSTALL_WORKSTATION=1 bash scripts/install.sh
```

## Repo Boundaries

- `thesammykins/new-mac`: fresh-machine orchestration and profile selection.
- `thesammykins/dotfiles`: shell/app config and Brewfile tiers.
- `thesammykins/skills`: local skills and upstream skill manifests.
- `thesammykins/codex-stuff`: Codex plugin marketplace.
- `thesammykins/brewfile`: legacy/deprecated Brewfile repo.
