# AGENTS.md - MCRN Tactical Display Dotfiles

## Core Philosophy / Mandate

This dotfiles repository is themed around **The Expanse / MCRN Tactical Display** aesthetic. Every configuration choice must align with these principles:

### MCRN Aesthetic
- **Visual Identity**: Void black (`#1a0b0c`) background with PDC Amber (`#ffd34e`) foreground
- **Design Language**: Utilitarian, label-based interface inspired by Rocinante bridge displays
- **Typography**: TX-02 Nerd Font for a technical, squared-off feel with icon support (Fallback: SpaceMono Nerd Font)
- **Vibe**: Warm, high-contrast, militaristic precision

### Warp-like Workflow
- **Shell Integration**: Ghostty must maintain shell integration for output selection and cursor placement
- **Split Opacity**: `unfocused-split-opacity = 0.85` in Ghostty to focus attention on the active pane
- **Session Model**: Prefer native Ghostty tabs/splits over terminal multiplexers on macOS

### Performance Mandate
- **Fast startup**: Shell must initialize instantly
- **Minimal overhead**: Use native shell features over external scripts when possible
- **Efficient tools**: Rust-based CLI stack (eza, bat, ripgrep, fd, dust) for speed

### MCRN Tactical AI (Copilot SDK ZLE Widget)
- **Engine**: `@github/copilot-sdk` authenticated through the local Copilot CLI/session.
- **Model**: Default `gpt-5-mini` via `MCRN_COPILOT_MODEL`.
- **Execution**: The widget is bound to `Ctrl+G`. It sends the current shell context to the Copilot helper, enforces single-command output, and replaces the buffer with one parsed zsh command. Hitting `Ctrl+G` on an empty buffer retries the last query.

### Toolchain Mandate (Mise vs Homebrew)
- **Homebrew**: Used for machine bootstrap, CLI utilities, and GUI apps. The repo is split into `Brewfile` (base), `Brewfile.dev` (developer tools), and `Brewfile.workstation` (daily-use GUI apps).
- **Mise**: Global toolchain manager for developer runtimes (`node`, `python`, `go`, `java`, etc.). Configured in `~/.config/mise/config.toml`.
- **Container Runtime**: Prefer OrbStack on macOS over Docker Desktop.

### Secrets And Agent Sync
- **Secret Source of Truth**: Stable env-style secrets belong in the 1Password `ENV` vault and are resolved via `varlock`, not stored in tracked configs or shell startup files.
- **Varlock Schema**: The canonical machine-level schema lives at `.config/varlock/.env.schema` and should remain safe to commit.
- **Interactive Tools**: Use `vopencode` or `varlock run --no-redact-stdout` for interactive CLIs that need TTY detection.
- **Cross-Tool Agent Config**: `.agents/` is tracked here as the canonical source for `dotagents`-managed AGENTS/rules/skills sync.

---

## Component Rules

### Homebrew Bundle Layout

**Locations**: `Brewfile`, `Brewfile.dev`, `Brewfile.workstation`

**Rules**:
- `Brewfile` should stay lean: shell, terminal, auth, core CLI, and machine bootstrap essentials.
- `Brewfile.dev` is for developer-machine tools such as `mise`, `opencode`, `copilot-cli`, `varlock`, validation tools, and local containers.
- `Brewfile.workstation` is for daily-use personal GUI apps that should exist on every primary Mac.
- Avoid turning the Brewfiles into a dump of every installed app on one machine.

### Ghostty Configuration

**Location**: `.config/ghostty/config`

**CRITICAL**: This config is **symlinked** to the macOS Library path. Do NOT edit directly in `~/Library/Application Support/com.mitchellh.ghostty/config`. Edit the source at `.config/ghostty/config` instead.

**Mandatory Settings**:
```conf
background = #1a0b0c
foreground = #ffd34e
unfocused-split-opacity = 0.85
shell-integration = detect
shell-integration-features = cursor,sudo,title,ssh-env
font-family = "TX02 Nerd Font"
```

**Behavior Rules**:
- Cursor: Block style, amber (`#ffd34e`), no blink (`cursor-style-blink = false`)
- Scrollback: `scrollback-limit = 10000000` (value in bytes)
- Titlebar: Must be native macOS or completely hidden, do not use false.

---

### Zsh Configuration

**Location**: `.zshrc`

**Tool Stack**:
- **eza**: Modern `ls` replacement
- **bat**: Syntax-highlighted `cat` replacement
- **rg (ripgrep)**: 10x faster `grep`
- **fd**: Intuitive `find` replacement

**Pathing Rules**:
- `DOTFILES` export must point to the canonical repo root (`$HOME/.dotfiles`).
- **NEVER** hardcode user paths (e.g., do not use `/Users/sammykins/`, use `$HOME/`).
- Shared env-backed commands should flow through `vopencode`/`vrun`, which resolve secrets from `.config/varlock/.env.schema`.

---

### dotagents Content

**Location**: `.agents/`

**Rules**:
- `.agents/AGENTS.md` is the machine-level shared instruction file for tools synced by `dotagents`.
- `.agents/skills/` is intentionally tracked so fresh machines can restore the same skill catalog.
- Keep `.agents/commands/` and `.agents/hooks/` available even if currently empty; `dotagents` expects the structure.
- Do not store secrets in `.agents/`; any credential-like values must resolve through 1Password + varlock instead.

---

### Browser Migration

**Preferred Browser**: Dia

**Rules**:
- Dia is intentionally not Homebrew-managed here; future agents should treat it as a manual install.
- Browser migration is handled by `scripts/backup-dia-profile.sh` and `scripts/restore-dia-profile.sh`.
- Copy profile data, not caches. Expect some sign-ins to require reauthentication on a new Mac.

---

### Starship Configuration

**Location**: `.config/starship.toml`

**MCRN Tactical Strip Format**:
The prompt must remain a two-line "Tactical Strip":
```text
Line 1: [Nav Glyph ⬡ + Path] [Git Telemetry Δ/↑/↓] [Duration T+] [Language Icons]
Line 2: ›
```

**Mandatory Palette** (always use these exact names and hex codes):
```toml
[palettes.mcrn]
carbon = "#1a0b0c"         # Void black background
hull_breach = "#ff2929"    # Alert red (errors, Rust)
drive_plume = "#b04c2a"    # Rust orange (Node, Lua)
warning = "#ffd34e"        # PDC Amber (primary text, Java, PHP)
holomap = "#c47a40"        # Warm copper (Git branch, Kotlin, Haskell)
sensor_ghost = "#994444"   # Burgundy-rust (Python, Ruby)
ice = "#ffd34e"            # Bright amber (duration, Go)
starlight = "#eaeaea"      # White
```

**Module Rules**:
- Do not use text labels for languages (e.g., `PY::`). Use Nerd Font glyphs explicitly mapped to the MCRN color palette.
- Keep the right prompt empty (`right_format = ""`) to reduce visual clutter.
- Disable unused/verbose modules (username, hostname, package, cloud providers).

---

### MCRN AI Plugin

**Locations**:
- Loader: `zsh/plugins/mcrn-ai.zsh`
- Helper: `zsh/plugins/mcrn-ai/copilot-helper.mjs`
- Config: `zsh/plugins/mcrn-ai/config.json`

**Rules**:
- The widget must keep the single-command contract: no prose, no markdown, no multiline output.
- Default model is `gpt-5-mini`, but it is configurable in `zsh/plugins/mcrn-ai/config.json` and overridable per machine with `MCRN_COPILOT_MODEL`.
- `copilot-cli` must be present through `Brewfile.dev`; the SDK path assumes the standalone CLI exists.
- Keep tool use deny-by-default unless the allowlist explicitly enables it.
- Keep helper imports safe for tests; do not auto-run the helper on module import.

**Known SDK Gotcha**:
- `@github/copilot-sdk` on Node 24/25 currently needs a post-install patch for the `vscode-jsonrpc/node` import path. Preserve `zsh/plugins/mcrn-ai/scripts/patch-copilot-sdk.mjs` and the installer/test hooks that call it unless upstream fully resolves the issue.

---

## Validation Commands

- `bash ./scripts/test.sh`
- `bash ./scripts/audit-macos-dotfiles.sh`
- `DOTFILES_DRY_RUN=1 DOTFILES_LINK_MODE=safe DOTFILES_INSTALL_DEV=1 DOTFILES_INSTALL_WORKSTATION=1 bash ./scripts/install.sh`

Use these after touching bootstrap scripts, Brewfiles, `mise`, or the MCRN AI plugin.

---

## Current Operating Model

- Prefer Ghostty tabs/splits over tmux on macOS; tmux is no longer part of the default repo experience.
- Keep docs practical and migration-focused; avoid over-documenting obvious mechanics.
- Prefer safe, dry-run-friendly installer changes and explicit migration pathways over clever automation.
- OpenCode MCP credentials should use env substitution in `~/.config/opencode/opencode.json`; do not leave literal API keys in that file.
