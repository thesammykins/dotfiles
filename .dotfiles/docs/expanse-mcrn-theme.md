# Expanse MCRN Theme Guide

This document captures the MCRN (Rocinante) theming decisions for our Ghostty + zsh environment.
It is the single source of truth for the palette, typography, and prompt style.

## Design Intent

- Emulate The Expanse MCRN tactical UI: warm, utilitarian, and high contrast.
- Prefer uppercase, label-style UI elements over icons or emoji.
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

- Primary: `Space Mono` (installed)
- Optional: `Share Tech Mono` for a squarer, engineering-deck feel
- Header style: uppercase labels like `DIR::`, `GIT::`, `SYS::`

## Ghostty

- Cursor: solid block, no blink
- Opacity: ~0.9 with blur for a glass-display feel
- Palette: align ANSI to MCRN tones (no neon blues/greens)

## Starship Prompt

Prompt style uses tactical labels instead of icons.

Example layout:
`SYS::roci DIR::~/ops GIT::main` on line 1
`►` on line 2

Key rules:
- Uppercase labels
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
