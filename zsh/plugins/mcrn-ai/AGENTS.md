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
- SUGGEST: Passive next-command ghost-text prediction after command completion. Opt-in via config.
- NL DETECT: Auto-detect natural language input and route to AI. Opt-in via config.
- AUTOFIX: Proactive fix suggestions after command failures. Opt-in via config.

## ANTI-PATTERNS
- ENABLING TOOLS WITHOUT A SCOPED ALLOWLIST.
- EXPANDING PATH SCOPE BEYOND `CWD` + `$HOME` WITHOUT EXPLICIT DOCS AND TESTS.
- REPLACING SYSTEM PROMPT WITHOUT INCLUDING `policy.txt` AND OUTPUT RULES.
- RETURNING TEXT, MARKDOWN, MULTI-LINE OUTPUT, OR MULTIPLE COMMANDS ON SEPARATE LINES.
- ADDING EMOJI OR NON-MCRN STYLING.
- USING KILL -9 / SIGKILL IN EXAMPLES WITHOUT EXPLICIT USER REQUEST.
- REDIRECTING STDERR GLOBALLY IN INTERACTIVE SHELLS (USE TEMPFILE APPROACH INSTEAD).

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

## DEBUGGING
- SET `MCRN_AI_DEBUG=1` TO LOG TO `/tmp/mcrn-ai-debug.log`.
- RUN `node ./zsh/plugins/mcrn-ai/copilot-helper.test.mjs` FOR HELPER-LEVEL REGRESSION CHECKS.

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
