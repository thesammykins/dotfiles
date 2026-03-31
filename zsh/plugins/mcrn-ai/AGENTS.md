# AGENTS.md - MCRN AI PLUGIN

## ROLE
This plugin turns natural language into a single, raw zsh command line. It is NOT a chat agent.

## NON-NEGOTIABLES
- OUTPUT MUST BE EXACTLY ONE SHELL LINE. PIPES, REDIRECTS, AND LOGICAL OPERATORS (&&, ||, ;) ARE ALLOWED WITHIN THAT LINE. MULTI-LINE OUTPUT (BACKSLASH CONTINUATIONS, HEREDOCS) IS FORBIDDEN. NO MARKDOWN. NO EXPLANATIONS.
- TOOLS ARE DISABLED BY DEFAULT. ONLY ENABLE WITH AN EXPLICIT ALLOWLIST.
- SAFETY POLICY IN `policy.txt` IS REQUIRED INPUT TO SYSTEM PROMPT.
- MODEL DEFAULT: COPILOT SHOULD DEFAULT TO `gpt-5-mini`.
- DO NOT ADD DESTRUCTIVE COMMANDS UNLESS USER EXPLICITLY REQUESTS THEM.
- PREFER GRACEFUL SIGNALS (SIGTERM) OVER FORCEFUL ONES (SIGKILL) BY DEFAULT.

## ENVIRONMENT-AWARE COMMAND GENERATION
THE MODEL MUST REASON ABOUT THE USER'S ACTUAL ENVIRONMENT BEFORE GENERATING A COMMAND. THE SYSTEM PROMPT INCLUDES LIVE CONTEXT:
- **PWD**: Current working directory (changes per request, not daemon startup dir).
- **OS + ARCH**: `darwin (arm64)` etc. — DO NOT EMIT LINUX-ONLY FLAGS ON MACOS.
- **SHELL**: Always `zsh`. USE ZSH IDIOMS, NOT BASH-ONLY SYNTAX.
- **TERM_PROGRAM**: The terminal emulator (e.g., `Ghostty`).
- **HOME / DOTFILES**: Canonical paths. NEVER HARDCODE `/Users/<name>`.
- **IN GIT REPO**: Whether PWD is inside a git worktree.
- **GIT SUMMARY**: Branch + dirty state. USE FOR CONTEXT, NOT ASSUMPTIONS.
- **RECENT HISTORY**: Last N commands. INFER WORKFLOW CONTEXT FROM THESE.
- **ALIASES**: Active shell aliases. PREFER `command <util>` TO BYPASS ALIAS SIDE-EFFECTS WHEN CLARITY MATTERS.
- **STDERR + LAST FAILURE**: In fix mode, the failed command and its stderr output.

RULES:
1. READ THE ENVIRONMENT BLOCK FIRST. DO NOT GUESS THE OS OR SHELL.
2. PREFER TOOLS THE USER ALREADY HAS (e.g., `eza` over `ls` if aliased, `rg` over `grep` if in `$commands`).
3. USE MACOS-IDIOMATIC FLAGS (e.g., `stat -f%z` NOT `stat -c%s`, `pbcopy` NOT `xclip`).
4. WHEN THE USER SAYS "HERE" OR "THIS DIRECTORY", USE THE PROVIDED PWD — DO NOT DEFAULT TO `$HOME`.
5. IN FIX MODE, READ THE STDERR CAREFULLY — FIX THE ACTUAL ERROR, NOT A GUESS.

## REQUIRED STYLE
- MCRN TACTICAL VOICE: UPPERCASE LABELS, NO EMOJI, SHORT DIRECT SENTENCES.
- FAST PATHS: NO EXTRA LATENCY, NO UNNECESSARY PIPELINES.
- READ-ONLY DEFAULTS: PREFER LIST/INSPECT OVER MUTATE.

## TOOL WIRING
- TOOL DEFINITIONS LIVE IN `/zsh/plugins/mcrn-ai/tools/`.
- PRIMARY CONFIG: `/zsh/plugins/mcrn-ai/config.json`.
- MODEL QUICK CONFIG: `config.json` -> `model.default`, or override with `MCRN_COPILOT_MODEL`.
- ENV OVERRIDES: `MCRN_AI_TOOLS_ALLOWLIST`, `MCRN_AI_TOOLS_DEVOPS`.
- OPTIONAL OVERRIDE PATH: `MCRN_AI_CONFIG_FILE`.
- SDK PATCH HOOK: `/zsh/plugins/mcrn-ai/patch-copilot-sdk.mjs`.

## TOOLING RULES
- USE `defineTool` + `createSession({ tools: [...] })` ALLOWLIST.
- KEEP `hooks.onPreToolUse` DENY-BY-DEFAULT FOR NON-ALLOWLISTED TOOLS.
- KEEP `systemMessage` IN APPEND MODE UNLESS YOU RE-IMPLEMENT ALL GUARDRAILS.
- ENFORCE SINGLE-LINE OUTPUT CLIENT-SIDE (REJECT NEWLINES, BACKTICKS, PROSE).
- KEEP THE HELPER SAFE TO IMPORT IN TESTS; DO NOT AUTO-RUN ON MODULE IMPORT.
- TOOL CONFIG LIVES IN `/zsh/plugins/mcrn-ai/config.json`; TOOL DEFINITIONS LIVE IN `/zsh/plugins/mcrn-ai/tools/`.

## MODES
- GENERATE: Default. Translate natural language into a shell command.
- FIX: Auto-triggered when buffer is empty and last command exited non-zero. Sends failed command + exit code + stderr for correction.
- REFINE: Triggered when buffer starts with refinement phrases and prior AI command exists. Sends prior command as context for iteration.
- CHAIN: Triggered when buffer starts with "pipe", "then", "now pipe", etc. Extends the prior command with a pipe or step instead of replacing it.
- SUGGEST: Passive next-command ghost-text prediction after command completion. Opt-in via config. Enriched with project context and flight log follow-ups.
- NL DETECT: Auto-detect natural language input and route to AI. Opt-in via config.
- AUTOFIX: Proactive fix suggestions after command failures. Opt-in via config.
- EXPLAIN: `CTRL+E` with a command in the buffer. Returns a one-line explanation via status bar. Buffer untouched.

## ANTI-PATTERNS
- ENABLING TOOLS WITHOUT A SCOPED ALLOWLIST.
- EXPANDING PATH SCOPE BEYOND `CWD` + `$HOME` WITHOUT EXPLICIT DOCS AND TESTS.
- REPLACING SYSTEM PROMPT WITHOUT INCLUDING `policy.txt` AND OUTPUT RULES.
- RETURNING TEXT, MARKDOWN, MULTI-LINE OUTPUT, OR MULTIPLE COMMANDS ON SEPARATE LINES.
- ADDING EMOJI OR NON-MCRN STYLING.
- USING KILL -9 / SIGKILL IN EXAMPLES WITHOUT EXPLICIT USER REQUEST.
- REDIRECTING STDERR GLOBALLY IN INTERACTIVE SHELLS (USE TEMPFILE APPROACH INSTEAD).
- USING DAEMON `process.env` AS ENVIRONMENT SOURCE — ALWAYS READ `cwd`, `home`, `shell`, `termProgram`, `inGitRepo` FROM THE REQUEST PAYLOAD. THE DAEMON'S OWN ENVIRONMENT IS STALE.
- EMITTING LINUX-ONLY FLAGS ON MACOS (e.g., `stat -c`, `xclip`, `--color=always` ON BSD TOOLS).
- IGNORING RECENT HISTORY — THE USER'S LAST COMMANDS PROVIDE CRITICAL WORKFLOW CONTEXT.

## DAEMON
- TCP DAEMON (`copilot-daemon.mjs --tcp`) ELIMINATES COLD-START LATENCY.
- STATE FILE: `/tmp/mcrn-ai-daemon-${UID}.json` (PORT + PID).
- IDLE TIMEOUT: CONFIGURABLE, DEFAULT 5 MINUTES. DAEMON AUTO-EXITS.
- WIDGET TRIES DAEMON FIRST, FALLS BACK TO SUBPROCESS.
- SUPPORTS `format: "zle"` FOR STRUCTURED-LINE RESPONSE FORMAT.

## GHOST-TEXT SUGGESTIONS
- PASSIVE NEXT-COMMAND PREDICTIONS VIA `POSTDISPLAY`.
- ACCEPT FULL: `→` OR `CTRL+F`. ACCEPT WORD: `CTRL+→`.
- RATE-LIMITED, DEBOUNCED, SKIP TRIVIAL COMMANDS.
- REQUIRES DAEMON. DEFAULT OFF (`suggest.enabled: false`).

## NL AUTO-DETECTION
- PURE-ZSH HEURISTIC: `$commands`/`$aliases`/`$functions` LOOKUP + WORD COUNT.
- INTERCEPTS `accept-line`. `ESC+ENTER` BYPASSES TO FORCE SHELL EXECUTION.
- DEFAULT OFF (`nlDetection.enabled: false`).

## CANDIDATE CYCLING
- `ALT+]` / `ALT+[` CYCLE THROUGH AI COMMAND CANDIDATES.
- SHOWS `[N/M]` INDICATOR IN STATUS LINE.

## FLIGHT RECORDER
- RECORDS EVERY AI GENERATION TO `~/.local/share/mcrn-ai/flight-log.jsonl`.
- TRACKS: PROMPT, COMMAND, MODE, CWD, EXECUTION STATUS, EXIT CODE.
- `preexec`/`precmd` HOOKS DETECT WHEN AI COMMANDS ARE ACTUALLY EXECUTED.
- RELEVANT PAST SUCCESSES INJECTED AS FEW-SHOT EXAMPLES IN SYSTEM PROMPT.
- CAPPED AT 1000 ENTRIES (CONFIGURABLE). ROTATES OLDEST.
- CONFIG: `flightLog.enabled`, `flightLog.maxEntries`, `flightLog.fewShotCount`.

## PROJECT CONTEXT
- AUTO-DETECTS PROJECT TYPE FROM CWD: `package.json` SCRIPTS, `Makefile`/`Justfile` TARGETS, `Cargo.toml`, `pyproject.toml`, `go.mod`, DOCKER, TOOLCHAIN (mise/direnv/nvm).
- APPENDS A `PROJECT` BLOCK TO THE SYSTEM PROMPT.
- CACHED PER-CWD PER SESSION (ZERO REPEAT I/O).
- CONFIG: `context.includeProjectInfo`.

## USER TEMPLATES
- OPTIONAL FILE: `~/.config/mcrn-ai/templates.txt`.
- FORMAT: SAME AS `policy.txt` — DESCRIPTION→COMMAND PAIRS.
- APPENDED TO SYSTEM PROMPT AFTER POLICY, SO USER PATTERNS TAKE PRECEDENCE.
- ENV OVERRIDE: `MCRN_AI_TEMPLATES_FILE`.

## EXPLAIN MODE
- `CTRL+E` WITH A COMMAND IN THE BUFFER.
- SENDS TO MODEL WITH EXPLAIN-ONLY SYSTEM PROMPT.
- RESULT SHOWN VIA `zle -M` STATUS BAR. BUFFER UNTOUCHED.
- REQUIRES DAEMON. MCRN TACTICAL VOICE.

## DRY VALIDATION
- AFTER AI GENERATES A COMMAND, CHECKS IF THE PRIMARY BINARY EXISTS.
- IF NOT FOUND: `[WARN: 'binary' NOT FOUND]` APPENDED TO STATUS MESSAGE.
- ADVISORY ONLY — COMMAND STILL PLACED IN BUFFER.
- HANDLES `command <util>` PREFIX AND ENV ASSIGNMENTS.

## DEBUGGING
- SET `MCRN_AI_DEBUG=1` TO LOG TO `/tmp/mcrn-ai-debug.log`.
- RUN `node ./zsh/plugins/mcrn-ai/copilot-helper.test.mjs` FOR HELPER-LEVEL REGRESSION CHECKS.

## WHAT THE MODEL SEES (vs. THIS FILE)
THIS FILE IS DEVELOPER GUIDANCE FOR HUMANS AND AGENTS EDITING THE PLUGIN CODE. IT IS **NOT** LOADED INTO THE COPILOT MODEL'S CONTEXT.

THE MODEL'S BEHAVIOR IS GOVERNED BY TWO FILES:
1. **`copilot-service.mjs` → `systemPrompt()`**: THE HARDCODED SYSTEM PROMPT WITH ENVIRONMENT BLOCK, RULES, AND EXAMPLES. THIS IS WHERE TOOL PREFERENCES (fd OVER find, rg OVER grep, etc.) AND macOS-SPECIFIC GUIDANCE LIVE.
2. **`policy.txt`**: SAFETY POLICY AND COMMAND TEMPLATES. APPENDED TO THE SYSTEM PROMPT.

IF THE MODEL GENERATES BAD COMMANDS (WRONG OS FLAGS, IGNORING INSTALLED TOOLS, WRONG DIRECTORY), FIX THE SYSTEM PROMPT IN `copilot-service.mjs` AND/OR THE TEMPLATES IN `policy.txt` — NOT THIS FILE.

## KNOWN GOTCHAS
- `@github/copilot-sdk` on Node 24/25 still needs the `vscode-jsonrpc/node` import patched to `node.js`.
- Preserve the post-install patch flow in `patch-copilot-sdk.mjs`, `scripts/install.sh`, and `scripts/test.sh` unless upstream fully resolves it.
- `copilot-cli` should come from `Brewfile.dev`; avoid inventing alternate install paths in repo docs unless the bootstrap model changes.

## REFERENCES
- POLICY: `/zsh/plugins/mcrn-ai/policy.txt`
- COPILOT HELPER: `/zsh/plugins/mcrn-ai/copilot-helper.mjs`
- HELPER TESTS: `/zsh/plugins/mcrn-ai/copilot-helper.test.mjs`
- SDK PATCH: `/zsh/plugins/mcrn-ai/patch-copilot-sdk.mjs`
- COPILOT CLI: INSTALLED VIA `Brewfile.dev`
- TOOLS: `/zsh/plugins/mcrn-ai/tools/index.mjs`
- CONFIG: `/zsh/plugins/mcrn-ai/config.json`
- SCHEMA: `/zsh/plugins/mcrn-ai/config.schema.json`
- FLIGHT LOG: `/zsh/plugins/mcrn-ai/flight-log.mjs`
- PROJECT CONTEXT: `/zsh/plugins/mcrn-ai/project-context.mjs`
- USER TEMPLATES: `~/.config/mcrn-ai/templates.txt`
