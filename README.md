# Dotfiles

Portable configuration payload for Sammy's Macs: shell and application config,
four curated Brewfile tiers, shared mise settings, and shared agent
instructions.

The canonical checkout is `$HOME/Development/dotfiles`.

Installation and updates are owned by
[`thesammykins/new-mac`](https://github.com/thesammykins/new-mac):

```bash
git clone https://github.com/thesammykins/new-mac.git ~/Development/new-mac && ~/Development/new-mac/setup.sh
```

`new-mac` invokes this repository's idempotent installer as a backend, keeps
Homebrew upgrades out of normal setup, preserves replaced files in timestamped
backups, and consumes a structured result describing linked, installed, skipped,
outdated, and failed items.

## What this repository owns

- `.zshrc`, `.zprofile`, Starship, Atuin, Git ignore, varlock, and global mise settings
- `.agents/AGENTS.md`
- `Brewfile`, `Brewfile.workstation`, `Brewfile.dev`, `Brewfile.ci`, and
  `manual-installs.txt` for apps Homebrew can't install

Projects own their language runtime and package-manager versions. This repository
does not own installed skills, Codex-managed plugin caches, secrets, browser
profiles, or machine-specific `~/.zshrc.local` contents.

## Brewfile tiers

| Tier | File | For |
| --- | --- | --- |
| `core` | `Brewfile` | Every Mac except CI runners: shell, CLI basics, 1Password, Tailscale |
| `workstation` | `Brewfile.workstation` | Personal apps, no developer tooling |
| `dev` | `Brewfile.dev` | Developer tooling, layered on workstation, including the Buildkite CLI and agent |
| `ci` | `Brewfile.ci` | CI runner Macs on their own; the runner's release toolchain comes from its project setup, not Homebrew |

`scripts/brew-tiers.sh` installs any combination and removes a tier without
touching what another kept tier still lists:

```bash
scripts/brew-tiers.sh install core workstation dev
scripts/brew-tiers.sh uninstall dev                      # preview: become workstation-only
scripts/brew-tiers.sh uninstall --apply dev              # do it
scripts/brew-tiers.sh uninstall --keep none --apply ci   # retire a CI runner
```

The installer asks which tiers to install when run in a terminal. It trusts
exactly the third-party taps the chosen Brewfiles list, because Homebrew
refuses formulae from untrusted taps. `mise run audit` also lists apps in
`/Applications` that no Brewfile or `manual-installs.txt` covers.

## Private skills

Skills with personal content live in a separate private repository,
[`thesammykins/skills-private`](https://github.com/thesammykins/skills-private),
installed by `new-mac` alongside the public
[`thesammykins/skills`](https://github.com/thesammykins/skills) catalog.

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
