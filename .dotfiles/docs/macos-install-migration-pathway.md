# macOS Dotfiles Audit + Migration Pathway

This guide is the operational pathway to move both **new Macs** and **drifted existing Macs** to a consistent MCRN tactical setup.

## 1) High-impact findings from current audit

1. **Ghostty config drift risk exists** because two config paths are present in-repo (`.config/ghostty/config` and `Library/Application Support/com.mitchellh.ghostty/config`). The source-of-truth should remain `.config/ghostty/config`.
2. **Installer portability issue was addressed** (`timeout 5 ...` replaced with a stock-macOS-compatible Perl alarm wrapper).
3. **Mise currently uses floating versions** (`latest`, `lts`) which is convenient but can introduce drift between machines over time.
4. **Package replacement needed explicit handling**: runtimes should be moved from Homebrew to mise, and legacy Homebrew runtime formulas should be removed after mise install.
5. **Copilot SDK alignment requirement**: `mcrn-ai` must track current `@github/copilot-sdk` engine/API expectations (Node 20+, append system message mode, session disconnect lifecycle).

## 2) Version-check approach used

Because `brew` may not be installed yet on a new machine, version checks should not depend on local Homebrew commands.

- Ghostty version source: Homebrew Cask `ghostty.rb`
- Core formula version sources: Homebrew Core formula files (`mise.rb`, `starship.rb`, `tmux.rb`, `jq.rb`, `llama.cpp.rb`)
- npm package source: `npm view @github/copilot-sdk version`

Run:

```bash
"$HOME/Development/dotfiles/.dotfiles/scripts/audit-macos-dotfiles.sh"
```

## 3) Package replacement model (Homebrew -> mise)

Use this split consistently:

- **Homebrew**: system CLI + GUI casks (e.g., `git`, `jq`, `tmux`, `ghostty`, `zed`).
- **Mise**: dev runtimes/toolchains (`node`, `python`, `go`, `java`, `dotnet`, `terraform`, `gradle`, etc.).

When migrating an existing machine, run:

```bash
"$HOME/Development/dotfiles/.dotfiles/scripts/migrate-to-mise.sh"
```

If you want the script to auto-remove overlapping Homebrew runtime formulas:

```bash
MISE_AUTO_UNINSTALL_BREW_RUNTIMES=1 "$HOME/Development/dotfiles/.dotfiles/scripts/migrate-to-mise.sh"
```

## 4) Reliable install pathway

### New Mac (clean install)

1. Clone repo to canonical path:
   ```bash
   git clone https://github.com/sammykins/dotfiles.git "$HOME/Development/dotfiles"
   ```
2. Run installer in safe mode first:
   ```bash
   DOTFILES_LINK_MODE=safe SKIP_MODEL_DOWNLOAD=1 "$HOME/Development/dotfiles/.dotfiles/scripts/install.sh"
   ```
3. Run audit script:
   ```bash
   "$HOME/Development/dotfiles/.dotfiles/scripts/audit-macos-dotfiles.sh"
   ```
4. If no blockers, run full install (model download optional):
   ```bash
   "$HOME/Development/dotfiles/.dotfiles/scripts/install.sh"
   ```

### Existing Mac (drifted setup)

1. Audit first:
   ```bash
   "$HOME/Development/dotfiles/.dotfiles/scripts/audit-macos-dotfiles.sh"
   ```
2. Run installer with safe links to avoid destructive overwrite:
   ```bash
   DOTFILES_LINK_MODE=safe "$HOME/Development/dotfiles/.dotfiles/scripts/install.sh"
   ```
3. Reconcile package replacement with mise:
   ```bash
   "$HOME/Development/dotfiles/.dotfiles/scripts/migrate-to-mise.sh"
   ```
4. Resolve skipped links manually (`Target exists, skipping`), then selectively force-link only approved files.
5. Validate shell + Ghostty manually and run Bats tests.

## 5) Hardening recommendations

1. **Pin mise runtimes** to explicit major/minor versions before broad rollout.
2. **Add CI audit job** for script syntax, JSON validity, and Bats checks where environment allows.
3. **Track release cadence monthly** for `ghostty`, `mise`, `starship`, `tmux`, `jq`, `llama.cpp`, and `@github/copilot-sdk`.
4. **Review runtime ownership drift** monthly (`brew list --formula` + `mise ls`).

## 6) Suggested migration operating model

- **Phase 1: Baseline** – run audit on all current machines and record exceptions.
- **Phase 2: Standardize** – pin runtime versions and freeze Brewfile changes for a sprint.
- **Phase 3: Rollout** – apply installer + audit + migrate-to-mise on each Mac.
- **Phase 4: Enforce** – periodic drift checks (weekly/monthly) plus pull-request review gates.


## 7) MCRN AI / Copilot SDK alignment checks

Run the dotfiles audit and inspect the `MCRN AI Copilot SDK alignment` section to verify:

- `@github/copilot-sdk` dependency is current and Node engine compatibility is met.
- helper uses SDK-recommended lifecycle (`session.disconnect()`).
- helper uses `systemMessage` append mode to preserve SDK guardrails.

```bash
"$HOME/Development/dotfiles/.dotfiles/scripts/audit-macos-dotfiles.sh"
```
