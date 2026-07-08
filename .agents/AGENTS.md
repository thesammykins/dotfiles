# AGENTS.md

## Core Behavior

- Follow KISS and DRY.
- Inspect the real repo or system state before making non-trivial changes.
- Prefer existing project tasks and conventions over new abstractions.
- Use `mise` when a repo exposes tasks or tool versions through `mise.toml`.
- Keep code and docs inside the active project unless the user explicitly asks for global changes.
- Do not print, commit, move, or summarize secrets.

## Workflow

- Use a branch for substantial git work.
- Read files before editing and match existing style.
- For multi-step implementation, keep progress visible and verify before calling work complete.
- If a command fails, read the error and fix the root cause instead of retrying blindly.
- Do not use destructive git commands unless explicitly requested.

## Tooling

- `git`: version control.
- `gh`: GitHub automation.
- `brew`: macOS package management.
- `mise`: runtime and task manager.
- `op`: 1Password secret references.
- `agent-browser`: browser validation when a UI needs real browser evidence.

## Boundaries

- `new-mac` orchestrates machine setup.
- `dotfiles` owns shell/app config and Brewfile tiers.
- `skills` owns custom skills and upstream skill manifests.
- `codex-stuff` owns Codex plugins.

## Durable Notes

- Public scoped npm packages need `"publishConfig": { "access": "public" }` in `package.json`.
- OpenSCAD edge features on rounded bodies need edge-specific geometry and visual validation.
- `agent-browser` keeps Chrome-for-Testing daemons alive until sessions are explicitly closed or timed out.
