# macOS Dotfiles Audit + Migration Pathway

This guide is the operational pathway to move both new Macs and drifted existing Macs to a consistent MCRN tactical setup. Fresh-machine orchestration now starts in `thesammykins/new-mac`; this repo remains the dotfiles payload.

## 1) High-impact findings from current audit

1. **Ghostty should have one tracked source of truth**: keep only `.config/ghostty/config` in the repo and link the macOS Library path to it during install.
2. **Installer portability issue was addressed**: timeout checks use stock macOS-compatible commands.
3. **Mise is pinned and belongs in the developer bundle**: keep runtimes in `Brewfile.dev` + `.config/mise/config.toml`, not in the base machine bundle.
4. **Container default changed**: standardize on OrbStack instead of Docker Desktop for local Mac development.
5. **Dia has no practical sync**: browser migration should be handled by explicit profile backup/restore scripts rather than package automation.
6. **Skills moved out of dotfiles**: use `thesammykins/skills` to install custom and upstream skills into `$HOME/.agents/skills`.

## 2) Version-check approach used

Because `brew` may not be installed yet on a new machine, version checks should not depend on local Homebrew commands.

- Ghostty version source: Homebrew Cask `ghostty.rb`
- Core formula version sources: Homebrew Core formula files (`mise.rb`, `starship.rb`, `jq.rb`, `opencode.rb`)
- npm package source: `npm view @github/copilot-sdk version`

Run:

```bash
"$HOME/Development/dotfiles/scripts/audit-macos-dotfiles.sh"
```
## 3) Package replacement model

Use this split consistently:

- **Homebrew base**: system CLI + GUI casks such as `git`, `jq`, `ghostty`, and `tailscale-app`.
- **Homebrew dev**: developer-machine tools such as `mise`, Codex, OpenCode, OrbStack, and validation tools.
- **Homebrew workstation**: personal GUI apps such as `zed`, `raycast`, `beeper`, `vesktop`, and `opencode-desktop`.
- **Mise**: dev runtimes/toolchains such as `node`, `python`, `go`, `java`, `dotnet`, `terraform`, and `gradle`.

When migrating an existing machine, run:

```bash
"$HOME/Development/dotfiles/scripts/migrate-to-mise.sh"
```

If you want the script to auto-remove overlapping Homebrew runtime formulas:

```bash
MISE_AUTO_UNINSTALL_BREW_RUNTIMES=1 "$HOME/Development/dotfiles/scripts/migrate-to-mise.sh"
```

## 4) Reliable install pathway

### New Mac

Use the root orchestrator:

```bash
git clone https://github.com/thesammykins/new-mac.git "$HOME/Development/new-mac"
cd "$HOME/Development/new-mac"
./setup.sh --profile personal --dry-run
./setup.sh --profile personal --yes
```

### Dotfiles-only install

```bash
git clone https://github.com/thesammykins/dotfiles.git "$HOME/Development/dotfiles"
DOTFILES_LINK_MODE=safe DOTFILES_INSTALL_DEV=1 DOTFILES_INSTALL_WORKSTATION=1 "$HOME/Development/dotfiles/scripts/install.sh"
"$HOME/Development/dotfiles/scripts/audit-macos-dotfiles.sh"
```

If no blockers remain:

```bash
DOTFILES_INSTALL_DEV=1 DOTFILES_INSTALL_WORKSTATION=1 "$HOME/Development/dotfiles/scripts/install.sh"
```

### Existing Mac

1. Audit first:
   ```bash
   "$HOME/Development/dotfiles/scripts/audit-macos-dotfiles.sh"
   ```
2. Run installer with safe links to avoid destructive overwrite:
   ```bash
   DOTFILES_LINK_MODE=safe DOTFILES_INSTALL_DEV=1 DOTFILES_INSTALL_WORKSTATION=1 "$HOME/Development/dotfiles/scripts/install.sh"
   ```
3. Reconcile package replacement with mise:
   ```bash
   "$HOME/Development/dotfiles/scripts/migrate-to-mise.sh"
   ```
4. Resolve skipped links manually, then selectively force-link only approved files.
5. Back up Dia before migration if it is already in use:
   ```bash
   "$HOME/Development/dotfiles/scripts/backup-dia-profile.sh"
   ```
6. Validate shell + Ghostty manually and run Bats tests.

## 5) Hardening recommendations

1. Pin mise runtimes to explicit major/minor versions before broad rollout.
2. Add CI audit jobs for script syntax, JSON validity, and Bats checks where environment allows.
3. Track release cadence monthly for `ghostty`, `mise`, `starship`, Codex, OpenCode, `jq`, OrbStack, and `@github/copilot-sdk`.
4. Review runtime ownership drift monthly with `brew list --formula` and `mise ls`.

## 6) Suggested migration operating model

- **Phase 1: Baseline** - run audit on all current machines and record exceptions.
- **Phase 2: Standardize** - pin runtime versions and freeze Brewfile changes for a sprint.
- **Phase 3: Rollout** - apply installer + audit + migrate-to-mise on each Mac, then restore the Dia profile if needed.
- **Phase 4: Enforce** - periodic drift checks plus pull-request review gates.

## 7) MCRN AI / Copilot SDK alignment checks

Run the dotfiles audit and inspect the `MCRN AI Copilot SDK alignment` section to verify:

- `@github/copilot-sdk` dependency is current and Node engine compatibility is met.
- helper uses the current lifecycle teardown.
- helper preserves SDK guardrails.

```bash
"$HOME/Development/dotfiles/scripts/audit-macos-dotfiles.sh"
```
