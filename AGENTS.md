# AGENTS.md - MCRN Tactical Display Dotfiles

## Core Philosophy / Mandate

This dotfiles repository is themed around **The Expanse / MCRN Tactical Display** aesthetic. Every configuration choice must align with these principles:

### MCRN Aesthetic
- **Visual Identity**: Void black (`#1a0b0c`) background with PDC Amber (`#ffd34e`) foreground
- **Design Language**: Utilitarian, label-based interface inspired by Rocinante bridge displays
- **Typography**: Space Mono Nerd Font for a technical, squared-off feel with icon support
- **Vibe**: Warm, high-contrast, militaristic precision

### Warp-like Workflow
- **Shell Integration**: Ghostty must maintain shell integration for output selection and cursor placement
- **Split Opacity**: `unfocused-split-opacity = 0.85` in Ghostty to focus attention on the active pane
- **Fuzzy Navigation**: Tmux sessions and workspaces use fuzzy switching to mimic Warp's command palette

### Performance Mandate
- **Fast startup**: Shell must initialize instantly
- **Minimal overhead**: Use native shell features over external scripts when possible
- **Efficient tools**: Rust-based CLI stack (eza, bat, ripgrep, fd, dust) for speed

---

## Component Rules

### Ghostty Configuration

**Location**: `.config/ghostty/config`

**CRITICAL**: This config is **symlinked** to the macOS Library path. Do NOT edit directly in `~/Library/Application Support/com.mitchellh.ghostty/config`. Edit the source at `.config/ghostty/config` instead.

**Mandatory Settings**:
```conf
background = #1a0b0c
foreground = #ffd34e
unfocused-split-opacity = 0.85
shell-integration = detect
shell-integration-features = cursor,sudo,title
font-family = "SpaceMono Nerd Font"
```

**Behavior Rules**:
- Cursor: Block style, amber (`#ffd34e`), no blink (`cursor-style-blink = false`)
- Scrollback: `scrollback-limit = 10000000` (value in bytes)
- Titlebar: Must be native macOS or completely hidden, do not use false.

---

### Tmux Configuration

**Location**: `.tmux.conf`

**Integration Rules**:
- Uses `tpm` (Tmux Plugin Manager) for plugins.
- Prefix key: `Ctrl+A` (screen-style for ergonomics)
- Status bar: Bottom position, updated every 5 seconds

---

### Zsh Configuration

**Location**: `.zshrc`

**Tool Stack**:
- **eza**: Modern `ls` replacement
- **bat**: Syntax-highlighted `cat` replacement
- **rg (ripgrep)**: 10x faster `grep`
- **fd**: Intuitive `find` replacement

**Pathing Rules**:
- `DOTFILES` export must point to the actual dotfiles directory (`$HOME/Development/dotfiles`).
- **NEVER** hardcode user paths (e.g., do not use `/Users/sammykins/`, use `$HOME/`).

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
holomap = "#75331a"        # Dim blue/brown (Git branch, Kotlin, Haskell)
sensor_ghost = "#b04c2a"   # Secondary accent (Python, Ruby)
ice = "#ffd34e"            # Bright amber (duration, Go)
starlight = "#eaeaea"      # White
```

**Module Rules**:
- Do not use text labels for languages (e.g., `PY::`). Use Nerd Font glyphs explicitly mapped to the MCRN color palette.
- Keep the right prompt empty (`right_format = ""`) to reduce visual clutter.
- Disable unused/verbose modules (username, hostname, package, cloud providers).