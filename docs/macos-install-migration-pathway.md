# macOS Dotfiles Audit + Migration Pathway

This guide is the operational pathway to move both **new Macs** and **drifted existing Macs** to a consistent MCRN tactical setup.

## 1) High-impact findings from current audit

1. **Ghostty should have one tracked source of truth**: keep only `.config/ghostty/config` in the repo and link the macOS Library path to it during install.
2. **Installer portability issue was addressed** (`timeout 5 ...` replaced with a stock-macOS-compatible Perl alarm wrapper).
3. **Mise is pinned and belongs in the developer bundle**: keep runtimes in `Brewfile.dev` + `.config/mise/config.toml`, not in the base machine bundle.
4. **Container default changed**: standardize on OrbStack instead of Docker Desktop for local Mac development.
5. **Dia has no practical sync**: browser migration should be handled by explicit profile backup/restore scripts rather than package automation.
6. **Copilot SDK alignment requirement**: `mcrn-ai` must track current `@github/copilot-sdk` engine/API expectations (Node 20+, append system message mode, session disconnect lifecycle).

## 2) Version-check approach used

Because `brew` may not be installed yet on a new machine, version checks should not depend on local Homebrew commands.

- Ghostty version source: Homebrew Cask `ghostty.rb`
- Core formula version sources: Homebrew Core formula files (`mise.rb`, `starship.rb`, `jq.rb`, `opencode.rb`)
- npm package source: `npm view @github/copilot-sdk version`

Run:

```bash
"$HOME/.dotfiles/scripts/audit-macos-dotfiles.sh"
```

## 3) Package replacement model (Homebrew -> mise)

Use this split consistently:

- **Homebrew base**: system CLI + GUI casks (e.g., `git`, `jq`, `ghostty`, `tailscale-app`).
- **Homebrew dev**: developer-machine tools (e.g., `mise`, `orbstack`, validation tools).
- **Homebrew workstation**: personal GUI apps (e.g., `zed`, `raycast`, `beeper`, `vesktop`, `opencode-desktop`).
- **Mise**: dev runtimes/toolchains and fast-moving CLIs (`node`, `python`, `go`, `java`, `rust`, `dotnet`, `terraform`, `gradle`, `uv`, `pnpm`, `opencode`, etc.).

When migrating an existing machine, run:

```bash
"$HOME/.dotfiles/scripts/migrate-to-mise.sh"
```

If you want the script to auto-remove overlapping Homebrew runtime formulas:

```bash
MISE_AUTO_UNINSTALL_BREW_RUNTIMES=1 "$HOME/.dotfiles/scripts/migrate-to-mise.sh"
```

## 4) Reliable install pathway

### New Mac (clean install)

1. Clone repo to canonical path:
   ```bash
   git clone https://github.com/sammykins/dotfiles.git "$HOME/.dotfiles"
   ```
2. Run installer in safe mode first:
   ```bash
   DOTFILES_LINK_MODE=safe DOTFILES_INSTALL_DEV=1 DOTFILES_INSTALL_WORKSTATION=1 "$HOME/.dotfiles/scripts/install.sh"
   ```
3. Run audit script:
   ```bash
   "$HOME/.dotfiles/scripts/audit-macos-dotfiles.sh"
   ```
4. Install Dia manually from `diabrowser.com`, launch it once, then restore or import browser data.
5. If no blockers, run full install:
   ```bash
   DOTFILES_INSTALL_DEV=1 DOTFILES_INSTALL_WORKSTATION=1 "$HOME/.dotfiles/scripts/install.sh"
   ```

### Existing Mac (drifted setup)

1. Audit first:
   ```bash
   "$HOME/.dotfiles/scripts/audit-macos-dotfiles.sh"
   ```
2. Run installer with safe links to avoid destructive overwrite:
   ```bash
   DOTFILES_LINK_MODE=safe DOTFILES_INSTALL_DEV=1 DOTFILES_INSTALL_WORKSTATION=1 "$HOME/.dotfiles/scripts/install.sh"
   ```
3. Reconcile package replacement with mise:
   ```bash
   "$HOME/.dotfiles/scripts/migrate-to-mise.sh"
   ```
4. Resolve skipped links manually (`Target exists, skipping`), then selectively force-link only approved files.
5. Back up Dia before migration if it is already in use:
   ```bash
   "$HOME/.dotfiles/scripts/backup-dia-profile.sh"
   ```
6. Validate shell + Ghostty manually and run Bats tests.

## 5) Hardening recommendations

1. **Pin mise runtimes** to explicit major/minor versions before broad rollout.
2. **Add CI audit job** for script syntax, JSON validity, and Bats checks where environment allows.
3. **Track release cadence monthly** for `ghostty`, `mise`, `starship`, `opencode`, `jq`, `orbstack`, and `@github/copilot-sdk`.
4. **Review runtime ownership drift** monthly (`brew list --formula` + `mise ls`).

## 6) Suggested migration operating model

- **Phase 1: Baseline** – run audit on all current machines and record exceptions.
- **Phase 2: Standardize** – pin runtime versions and freeze Brewfile changes for a sprint.
- **Phase 3: Rollout** – apply installer + audit + migrate-to-mise on each Mac, then restore the Dia profile if needed.
- **Phase 4: Enforce** – periodic drift checks (weekly/monthly) plus pull-request review gates.


## 7) MCRN AI / Copilot SDK alignment checks

Run the dotfiles audit and inspect the `MCRN AI Copilot SDK alignment` section to verify:

- `@github/copilot-sdk` dependency is current and Node engine compatibility is met.
- helper uses the current lifecycle teardown (`session.disconnect()`).
- helper uses `systemMessage` append mode to preserve SDK guardrails.

```bash
"$HOME/.dotfiles/scripts/audit-macos-dotfiles.sh"
```
