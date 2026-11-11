# AGENTS.md - Dotfiles

## Scope

This repo owns a small dotfiles payload: shell config, app config, Brewfile
tiers (`core`, `workstation`, `dev`, `ci`), `manual-installs.txt`, global
`mise` settings, varlock schema, and shared agent guidance. `new-mac` runs it;
see that repo's AGENTS.md for the questions to ask before setting up a Mac.

## Rules

- Keep this repo small. Prefer deleting a feature over adding a flag.
- Projects own runtimes through their own `mise.toml`; the global mise config holds settings only.
- Homebrew owns system tools, GUI apps and agent CLIs (Claude Code, Codex, OpenCode).
- Keep Brewfiles curated; do not mirror every installed package. A third-party
  package needs its `tap` line in the same Brewfile.
- Apps Homebrew can't install go in `manual-installs.txt`.
- `scripts/brew-tiers.sh uninstall` removes apps: preview it and get a yes
  before running it with `--apply`.
- `scripts/repos-volume.sh` and `scripts/tool-storage.sh --apply` change disks
  and move data: never run them without a yes. They stay out of `install.sh`.
- Do not add bespoke terminal themes, generated shell widgets, or local browser profiles here.
- Do not store secrets in tracked files. Use 1Password and varlock references.
- Keep machine-specific overrides in `~/.zshrc.local`.
- Keep `.agents/skills/` out of this repo; skills come from `thesammykins/skills`
  and the private `thesammykins/skills-private`.

## Boundaries

- `new-mac` orchestrates fresh-machine setup.
- `dotfiles` owns shell/app config and Brewfile tiers.
- `skills` owns local/custom skills and upstream skill manifests.
- `codex-stuff` owns Codex plugin packaging.

## Validation

```bash
mise run check
DOTFILES_DRY_RUN=1 bash scripts/install.sh
```

## Standing approvals

- Push the orb-setup change to `origin/main`, validating what Linux supports ([Sammy's approval](https://ampcode.com/threads/T-01a1c8f1-be51-7339-aea5-b07db8a009a4)).
