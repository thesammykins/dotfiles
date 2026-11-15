# Global agent guidance

Defaults for every project on this Mac. The user's request and the repository's own `AGENTS.md` win where they differ.

## Where to work

- Repositories live in `~/repos`. Clone, build and run there, inside the project's checkout. Put scratch work in a temporary folder, not elsewhere in the home folder.
- `~/repos/.tools` holds mise's installs and the tool caches; the usual paths in the home folder link to it. Leave those links in place.
- Nothing for development is installed globally. A project's runtimes and CLIs are pinned in its own `mise.toml` and run with `mise exec --` or `mise run`. When a tool is missing, add it to that `mise.toml`; do not use `brew install`, `npm -g`, `pipx` or `uv tool` for it.
- The only global developer tools are Xcode (installed with `xcodes`) and the Android platform tools (`adb`). Homebrew is for system tools and GUI apps, and those are listed in the dotfiles Brewfiles.
- A runtime on the global PATH is not for project work: Homebrew's `node` is there only because varlock depends on it, and `/usr/bin` has Apple's old `python3` and `ruby`. Pin the project's own in `mise.toml`.
- Secrets come from 1Password through varlock references. Never write one to a tracked file or paste one into a command that gets logged.

## Git

- Commit directly to `main`. Create a branch or a pull request only when asked.
- Run the repository's checks before a commit that will be pushed.
- Ask before the first push, publish or release to a destination. An approval is the user's own words naming the action and the destination; record a standing one under "Standing approvals" in that repository's `AGENTS.md`. Once approved, push without asking again.
- Create version tags only when asked.

## Public by default

Assume every repository becomes public and its history is permanent.

- Keep real data from this Mac and network out of commits: hostnames, usernames, emails, LAN and VPN addresses, serials, signing identities, account or team IDs, tokens, keys and home-folder paths. Use obviously fake values of the same shape in fixtures, logs, screenshots and examples.
- Keep raw captures in a gitignored folder and commit only the sanitised copy.
- Check the staged diff for these before each commit. If real data reaches a commit, stop and say so; removing it needs a history rewrite.
- Give subagents the same rule.

## Code and tests

- Decide reversible, in-scope choices yourself. Ask only when a missing requirement changes what gets built, or for a preference, a private fact or an approval.
- Validate untrusted data where it enters: API responses, environment variables, parsed files. Surface errors instead of swallowing them.
- Add a layer or helper when a second use exists, not before.
- Write a test only when it checks behaviour someone relies on and would fail on a plausible regression. Keep checks runnable in parts, so one area can be retested alone.
- Stop when the acceptance checks pass, and report what remains unverified.

## UI

Read the repository's `DESIGN.md` first when it exists, and reuse its components and tokens. Lean dark. Cut taglines, helper text and secondary labels; if a screen needs them to make sense, fix the layout. Use few borders, dividers, tags and colour shades.

## Skills

Load a skill when the task matches its description; none is required by default. Keep language, framework and platform skills in the project, not in `~/.agents/skills`.
