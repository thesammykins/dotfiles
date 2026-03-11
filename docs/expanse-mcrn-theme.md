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
| Dim | `#75331a` | Secondary text, time, subdued elements |
| Selection | `#3c180f` | Selection and inactive panels |

## Typography

- Primary: `TX-02 Nerd Font`
- Fallback: `SpaceMono Nerd Font`
- Keep glyphs technical and sparse; no emoji in the prompt.

## Ghostty

- Cursor: solid block, no blink
- Opacity: ~0.9 with blur for a glass-display feel
- Palette: align ANSI to MCRN tones (no neon blues/greens)

## Starship Prompt

Prompt style uses tactical glyphs with a two-line strip.

Example layout:
`⬡ ~/ops Δ ↑ ↓ T+ 1s 󰌠 󰎙` on line 1
`›` on line 2

Key rules:
- Use Nerd Font glyphs, not emoji
- Keep the right prompt empty
- No emoji
- Use amber for primary, rust for labels, red for alerts

## Fastfetch / MOTD

- Keep MCRN logo as-is
- Use red for dividers and labels
- Use amber for primary values
- Use dim brown (`#75331a`) for secondary states

## TUI Theming Ideas

- fzf: rust pointer, amber match, selection background `#3c180f`
- bat: warm background, minimal grid or rulers
- lazygit: rust headers, amber text, red errors
