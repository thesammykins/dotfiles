# Dotfiles

Portable configuration payload for Sammy's Macs: shell and application config,
three curated Brewfile tiers, shared mise settings, and shared agent
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

- `.zshrc`, `.zprofile`, Starship, Atuin, Git ignore, varlock, and global mise settings
- `.agents/AGENTS.md` and `.agents/GEMINI.md`
- `Brewfile`, `Brewfile.dev`, and `Brewfile.workstation`

Projects own their language runtime and package-manager versions. This repository
does not own installed skills, Codex-managed plugin caches, secrets, browser
profiles, or machine-specific `~/.zshrc.local` contents.

## Finding shell shortcuts

Type `keys` (or `shortcuts`) for a compact reference of useful commands and
terminal-specific shortcuts. Warp gets its native shortcuts; ordinary terminals
get this setup's Zsh, Atuin, and fzf bindings. Interactive login shells show a
one-line reminder; scripts and non-interactive shells do not.

In Warp, `Cmd-P` opens the native searchable command palette. Its shortcuts can
be remapped in Settings. In ordinary terminals, fzf's directory picker works with
`Esc` followed by lowercase `c`, even when Option is not configured as Meta.

## Maintainer checks

```bash
mise run check
mise run audit
```

The internal installer remains directly callable for recovery and CI, but its
environment contract is intentionally not part of the normal user workflow.
