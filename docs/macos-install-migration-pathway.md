# Mac Setup Migration Pathway

This repo is now a small dotfiles payload. Fresh-machine orchestration starts in
`thesammykins/new-mac`.

## Fresh Mac

1. Install Xcode Command Line Tools, Homebrew, Git, and `mise`.
2. Clone `thesammykins/new-mac` into `$HOME/Development/new-mac`.
3. Run `mise run plan -- --profile personal --dry-run`.
4. Run `mise run apply -- --profile personal --yes`.

## Existing Mac

1. Pull the latest `thesammykins/dotfiles`.
2. Run a safe dry-run:

   ```bash
   DOTFILES_DRY_RUN=1 DOTFILES_LINK_MODE=safe DOTFILES_INSTALL_DEV=1 DOTFILES_INSTALL_WORKSTATION=1 bash scripts/install.sh
   ```

3. Run `mise run audit`.
4. Reconcile skipped links manually.
5. Apply with `DOTFILES_LINK_MODE=migrate` when the plan looks right.

## Ownership

- Homebrew installs machine tools and GUI apps.
- `mise` owns runtimes and language toolchains.
- `~/.zshrc.local` owns machine-only overrides.
- 1Password and varlock own secrets.
- Agent skills are installed from `thesammykins/skills`, not copied into this repo.
