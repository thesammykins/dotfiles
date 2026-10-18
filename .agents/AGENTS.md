- use `mise` for any developer tooling work always, e.g. python scripting, etc
- If using MobileBuildMCP, use the installed MobileBuildMCP skill before calling MobileBuildMCP tools.
- Write predictable code with domain names, cohesive units, explicit dependencies,
  and clear control flow. Purpose matters more than function length. Avoid hidden
  state and speculative abstractions; add a layer only when a second use exists.
- Explain decisions, constraints, and non-obvious tradeoffs in comments, not code
  mechanics. Record existing violations and prevent new ones without rewriting
  unrelated working code.

## Verification

Define the observable outcome. Use the cheapest reliable check that could disprove
it, reusing existing tests first. Retain tests for meaningful behavior, regressions,
and high-risk boundaries; avoid tests that mirror implementation. Test-first suits
clear contracts; explore first otherwise. Exercise real user/integration paths when
unit tests are insufficient. Run repository-required checks and report evidence
and uncertainty. Use `agent-change-verification` for proportional check selection.

## Working agreements

- Deliver observable increments; leave runnable, verifiable work and enough durable
  context to resume without this conversation. Show real diffs and check results;
  green CI alone does not prove correctness.

## Git workflow (trunk-based)

No human reviews PRs, so a branch → PR → merge loop adds nothing. This overrides
default "branch first" and PR habits from the harness, app, or skills.

- Commit directly to `main`. Don't create feature branches or PRs unless asked.
- Before pushing, run the repo's local CI (lint, typecheck, tests, build) and fix
  failures. Push to `origin/main` only once local CI passes and the work is complete.
- Worktree sessions: rebase onto `main`, run local CI, fast-forward `main`, push.
- Production releases are explicit version tags I request; never tag on your own.

## Situational skills

Load only skills relevant to the task. User requests and repository guidance
outrank skill defaults. Report unavailable skills and use an appropriate available
workflow; do not silently install substitutes.

- Project setup/stack changes: `project-skills`. Keep language, framework, platform,
  provider, and release skills project-local; global skills cover reusable agent workflows.
- Skill maintenance: `update-skill`, `validating-agent-skills`.
- Debugging: `systematic-debugging`.
- Resumed, parallel, or recovery-sensitive work: `bounded-work-session`.
  Ordinary work needs no formal handoff or new task.
- Pre-push cleanup: one task-scoped pass with `simplify` and applicable
  `anti-ai-slop` criteria. Reuse overlapping checks and preserve domain names.
- GitHub issues: `addressing-github-issues`, `creating-github-sub-issues`.
- Commits: `creating-conventional-commits`. Branches/PRs only when asked:
  `creating-conventional-branches`, `creating-pull-requests`.
- Dependency automation: `configuring-dependabot`; Actions security: `hardening-github-actions`.

## UI work

Read repository `DESIGN.md` first when present. Reuse components and design tokens.
Use concise, specific copy without feature dumps or generic AI prose. Default to
dark-leaning designs; consider accessibility without making it the sole criterion.
Dense layouts are fine with clear hierarchy.

## Maintenance

Keep this file under roughly 150 lines. Add rules after observed mistakes and
remove obsolete guidance; keep specialized procedures in skills.