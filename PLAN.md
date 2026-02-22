# PLAN — Expanse MCRN Tactical Terminal (Warp-like)

## 1. Ghostty Config Consolidation & Warp Features
**Target Files:**
- `/Users/samanthamyers/Development/dotfiles/.config/ghostty/config`
- `~/Library/Application Support/com.mitchellh.ghostty/config`

**Specific Actions:**
1. Back up `~/Library/Application Support/com.mitchellh.ghostty/config` to `config.bak`.
2. Delete the original `~/Library/Application Support/com.mitchellh.ghostty/config`.
3. Create a symlink: `ln -sf /Users/samanthamyers/Development/dotfiles/.config/ghostty/config ~/Library/Application\ Support/com.mitchellh.ghostty/config`.
4. Edit `.config/ghostty/config`:
   - Ensure `shell-integration = detect` (or `zsh`) is set.
   - Update `shell-integration-features = cursor,sudo,title` to unlock Warp-like output selection and cursor placement.
   - Add `unfocused-split-opacity = 0.85` for pane dimming.

## 2. Zsh Path Corrections
**Target File:**
- `/Users/samanthamyers/Development/dotfiles/.zshrc`

**Specific Actions:**
1. Change Line 28:
   - From: `export DOTFILES="$HOME/dotfiles-staging/.dotfiles"`
   - To: `export DOTFILES="$HOME/Development/dotfiles"`
2. Change Lines 164 & 177:
   - Replace `/Users/sammykins/` with `$HOME/` so plugins and aliases (like peon-ping) resolve correctly for the current user.

## 3. Tmux Plugin Manager (TPM)
**Target File:**
- `/Users/samanthamyers/Development/dotfiles/.tmux.conf`

**Specific Actions:**
1. Uncomment the TPM initialization block at the bottom of the file (lines ~124-126).
2. Ensure `tmux-plugins/tpm` and `tmux-plugins/tmux-sensible` are uncommented.
3. Run `git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm` if it doesn't exist.
4. Execute `~/.tmux/plugins/tpm/scripts/install_plugins.sh` to install the plugins, enabling fuzzy workspace switching.

## 4. Starship "MCRN Tactical Strip" Prompt
**Target File:**
- `/Users/samanthamyers/Development/dotfiles/.config/starship.toml`

**Specific Actions:**
1. Remove `right_format`.
2. Define `[palettes.mcrn]`:
   - `carbon = "#1a0b0c"`
   - `hull_breach = "#ff2929"`
   - `drive_plume = "#b04c2a"`
   - `warning = "#ffd34e"`
   - `holomap = "#75331a"`
   - `sensor_ghost = "#b04c2a"`
   - `ice = "#ffd34e"`
   - `starlight = "#eaeaea"`
3. Implement a two-line layout in `format`:
   ```toml
   format = """
   $directory$git_branch$git_status$cmd_duration$python$nodejs$rust$golang$ruby$java$kotlin$haskell$php$lua
   $character"""
   ```
4. Style modules:
   - **Directory:** Prefix `⬡ `, color `warning`.
   - **Git Branch:** Color `holomap`.
   - **Git Status:** Modified `Δ` (red), Ahead `↑` (orange), Behind `↓` (orange).
   - **Cmd Duration:** Format `T+[$duration]`, color `ice`.
   - **Character:** `›`
5. Configure specific language icons mapped to the MCRN palette:
   - Python: `󰌠 ` (sensor_ghost)
   - Nodejs: `󰎙 ` (drive_plume)
   - Rust: `󱘗 ` (hull_breach)
   - Golang: `󰟓 ` (ice)
   - Ruby: `💎 ` (sensor_ghost)
   - Java: `☕ ` (warning)
   - Kotlin: `󰌋 ` (holomap)
   - Haskell: `λ ` (holomap)
   - PHP: `󰌟 ` (warning)
   - Lua: `󰢱 ` (drive_plume)
