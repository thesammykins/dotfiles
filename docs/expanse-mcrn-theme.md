# Expanse MCRN Theme Guide

This document captures the MCRN (Rocinante) theming decisions for our Ghostty + zsh environment.
It is the single source of truth for the palette, typography, and prompt style.

## Design Intent

- Emulate The Expanse MCRN tactical UI: warm, utilitarian, and high contrast.
- Prefer terse tactical glyphs and labels over emoji.
- Keep the interface low-glare for long sessions.

## Core Palette

| Role | Hex | Usage |
| --- | --- | --- |
| Background | `#1a0b0c` | Base background (warm void) |
| Foreground | `#ffd34e` | Primary text, primary indicators |
| Accent Rust | `#b04c2a` | Headers, labels, borders |
| Alert Red | `#ff2929` | Errors, critical states |
| Dim | `#c47a40` | Secondary text, git branch, borders, subdued elements |
| Selection | `#3c180f` | Selection and inactive panels |
| Sensor Ghost | `#994444` | Muted burgundy-rust, differentiates from Accent Rust |

## Typography

- Primary: `TX-02 Nerd Font`
- Fallback: `SpaceMono Nerd Font`
- Keep glyphs technical and sparse; no emoji in the prompt.

## Ghostty

- Cursor: solid block, no blink
- Opacity: ~0.9 with blur for a glass-display feel
- Palette: align ANSI to MCRN tones (no neon blues/greens)

## Starship Prompt

Prompt style uses sharp powerline blocks with a two-line tactical layout.

Example layout:
` ⬡ ~/Dev/copilot-zle   main ● ◦  ⬢ ` on line 1
`◷ 1s ❯` on line 2

Right prompt:
`◌ idle` when idle, or `◔ gen 142ms` / `✦ fix 142ms` in a right-aligned telemetry block.

Key rules:
- Use Nerd Font glyphs, not emoji
- Keep the right prompt minimal: AI/risk/duration telemetry only
- No emoji
- Keep the directory and git area expressive, with backgrounds doing most of the contrast work
- Use amber for primary, rust for labels, red for alerts

## Fastfetch / MOTD

- Keep MCRN logo as-is
- Use red for dividers and labels
- Use amber for primary values
- Use warm copper (`#c47a40`) for secondary states

## TUI Theming Ideas

- fzf: rust pointer, amber match, selection background `#3c180f`
- bat: warm background, minimal grid or rulers
- lazygit: rust headers, amber text, red errors
