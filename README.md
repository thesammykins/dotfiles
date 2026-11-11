# Dotfiles

Shell and app config, Brewfile tiers and shared agent instructions for Sammy's
Macs. The checkout lives at `~/repos/dotfiles`;
[`new-mac`](https://github.com/thesammykins/new-mac) installs and updates it:

```bash
git clone https://github.com/thesammykins/new-mac.git /tmp/new-mac && /tmp/new-mac/setup.sh
```

`scripts/install.sh` links every path in `scripts/managed-paths.txt` into
`$HOME`, copying anything it replaces to `~/.dotfiles.backup/<timestamp>`.
Commit signing is linked only on Macs with the 1Password app.
Machine-only settings go in `~/.zshrc.local`. Skills, secrets and terminal-app
themes live elsewhere.

## Brewfile tiers

| Tier | File | For |
| --- | --- | --- |
| `core` | `Brewfile` | Every Mac except CI runners |
| `workstation` | `Brewfile.workstation` | Personal apps |
| `dev` | `Brewfile.dev` | Developer tools and agent CLIs, on top of workstation |
| `ci` | `Brewfile.ci` | CI runner Macs, on their own |

```bash
scripts/brew-tiers.sh install core workstation dev
scripts/brew-tiers.sh uninstall dev           # preview
scripts/brew-tiers.sh uninstall --apply dev   # do it
```

Uninstall keeps anything a kept tier still lists, and keeps Tailscale unless
you pass `--remove-tailscale`. Apps Homebrew can't install are listed in
`manual-installs.txt`; `mise run audit` lists anything installed that no
Brewfile covers.

## Repos volume

Optional, run by hand. Adapted from
[elithrar/dotfiles](https://github.com/elithrar/dotfiles/tree/main#macos-repos-volume)
(MIT). Read upstream's README for the full recovery notes.

```bash
bash scripts/repos-volume.sh          # once; asks for sudo
bash scripts/tool-storage.sh          # preview
bash scripts/tool-storage.sh --apply  # move caches, leave symlinks
```

`repos-volume.sh` adds an **unencrypted** APFS volume to the startup container,
mounted at `~/repos` via a UUID entry in `/etc/fstab`, with Spotlight and
persistent FSEvents off. It shares free space with the startup disk; it is not
extra capacity. It refuses a non-empty `~/repos`, never deletes or force-unmounts
anything, and keeps its state in `/var/db/dotfiles-repos-$(id -u)/record`. If it
stops part-way, inspect that record and `diskutil apfs list` before rerunning;
never delete the volume or record just to retry.

`tool-storage.sh` moves mise, Rust, npm/pnpm, uv/pip, Go, Bun, Gradle, SwiftPM
and Xcode DerivedData onto `~/repos/.tools`. Quit Xcode and Android Studio and run
`gradle --stop` first, and run it from Terminal, not from a mise-installed tool.
Rerun after installing a new toolchain.

new-mac creates this volume before cloning anything into `~/repos` (personal,
work and agent-dev profiles), which is why the bootstrap clone above goes to
`/tmp`. CI and minimal profiles use a plain `~/repos` folder. To move a project
in by hand, `ditto` it into `~/repos`, verify it, run `mise trust` in it (mise
trusts configs by real path), and rerun `scripts/install.sh` if it was this repo.

## Checks

```bash
mise run check
```

## Orbs

`.agents/setup` installs missing Linux validation tools and mise for Amp's cached
orb snapshot. Warm runs reuse installed tools. It does not link dotfiles, install
Homebrew tiers, or change disks. No resume hook or services are needed.

`mise run check` runs the full suite, but `test/07-install.bats` requires macOS
and the PATH test in `test/02-mise.bats` assumes `/opt/homebrew` exists. The
installer's dry run also rejects Linux. In an orb, run the portable suites with:

```bash
mise exec -- bats test/05-repo-contract.bats test/08-brew-tiers.bats test/10-tool-storage.bats
```

Type `keys` in a shell for a shortcut reference.
