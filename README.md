# Dotfiles

Portable configuration payload for Sammy's Macs: shell and application config,
three curated Brewfile tiers, the pinned global mise baseline, and shared agent
instructions.

The canonical checkout is `$HOME/Development/dotfiles`.

Installation and updates are owned by
[`thesammykins/new-mac`](https://github.com/thesammykins/new-mac):

```bash
cd "$HOME/Development/new-mac"
./setup.sh
```

`new-mac` invokes this repository's idempotent installer as a backend, keeps
Homebrew upgrades out of normal setup, preserves replaced files in timestamped
backups, and consumes a structured result describing linked, installed, skipped,
outdated, and failed items.

## What this repository owns

- `.zshrc`, `.zprofile`, Starship, Atuin, Git ignore, varlock, and mise configuration
- `.agents/AGENTS.md` and `.agents/GEMINI.md`
- `Brewfile`, `Brewfile.dev`, and `Brewfile.workstation`

It does not own installed skills, Codex-managed plugin caches, secrets, browser
profiles, or machine-specific `~/.zshrc.local` contents.

## Maintainer checks

```bash
mise run check
mise run audit
```

The internal installer remains directly callable for recovery and CI, but its
environment contract is intentionally not part of the normal user workflow.
