# AGENTS.md - Dotfiles

## Scope

This repo owns a small dotfiles payload: shell config, app config, Brewfile
tiers (`core`, `workstation`, `dev`, `ci`), `manual-installs.txt`, global
`mise` settings, varlock schema, and shared agent guidance. `new-mac` runs it;
see that repo's AGENTS.md for the questions to ask before setting up a Mac.

## Rules

- Keep this repo boring and repeatable.
- Prefer `mise` for runtimes and project tasks.
- Prefer Homebrew for system tools and GUI apps.
- Keep Brewfiles curated; do not mirror every installed package. A third-party
  package needs its `tap` line in the same Brewfile.
- Apps Homebrew can't install go in `manual-installs.txt`.
- `scripts/brew-tiers.sh uninstall` removes apps: preview it and get a yes
  before running it with `--apply`.
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
mise run audit
DOTFILES_DRY_RUN=1 DOTFILES_LINK_MODE=safe DOTFILES_TIERS=core,workstation,dev bash scripts/install.sh
```
