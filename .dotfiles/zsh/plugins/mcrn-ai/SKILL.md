# SKILL.md - MCRN AI TOOL EXTENSIBILITY

## PURPOSE
Extend the MCRN AI plugin with SAFE, READ-ONLY tools. The core contract remains: one raw command line per response.

## TOOL WIRING
- TOOLS LIVE IN `/.dotfiles/zsh/plugins/mcrn-ai/tools/`.
- COPILOT PATH LOADS `tools/index.mjs` AND `config.json`.
- ENV OVERRIDES: `MCRN_AI_TOOLS_ALLOWLIST`, `MCRN_AI_TOOLS_DEVOPS`, `MCRN_AI_TOOL_MAX_OUTPUT_BYTES`, `MCRN_AI_TOOL_MAX_FILE_BYTES`, `MCRN_AI_TOOL_TIMEOUT_MS`.

## BASELINE CONSTRAINTS
- OUTPUT: SINGLE COMMAND LINE ONLY. NO MARKDOWN. NO EXPLANATIONS.
- DEFAULT MODE: TOOLS DISABLED. ENABLE ONLY VIA ALLOWLIST.
- PATH SCOPE: CWD + $HOME ONLY.
- MODEL: COPILOT MUST USE `gpt-5-mini`.

## SAFE EXTENSION PATTERN
1) DEFINE TOOLS WITH `defineTool`.
2) PASS AN EXPLICIT ALLOWLIST INTO `createSession({ tools: [...] })`.
3) KEEP `hooks.onPreToolUse` TO DENY NON-ALLOWLISTED CALLS.
4) ENFORCE COMMAND-ONLY OUTPUT CLIENT-SIDE. REJECT MULTILINE/PROSE.
5) KEEP `systemMessage` MODE AS APPEND UNLESS YOU REBUILD ALL GUARDRAILS.
6) USE CONFIG FIRST; ENV OVERRIDES ONLY WHEN NECESSARY.

## TOOL DESIGN RULES
- TOOLS MUST BE READ-ONLY.
- TOOLS MUST VALIDATE PATHS AGAINST CWD + $HOME.
- TOOLS MUST REJECT BINARY OR NON-UTF8 READS.
- TOOLS MUST ENFORCE SIZE LIMITS (DEFAULT: 1MB).
- TOOL OUTPUT SHOULD BE TRIMMED AND STRUCTURED FOR COMMAND GENERATION ONLY.
- TOOL RUNNERS SHOULD ENFORCE TIMEOUTS AND OUTPUT BYTE LIMITS.

## CONFIG FILES
- CONFIG: `/.dotfiles/zsh/plugins/mcrn-ai/config.json`
- SCHEMA: `/.dotfiles/zsh/plugins/mcrn-ai/config.schema.json`

## RECOMMENDED TOOL CATALOG

### CORE (OS/FS) READ-ONLY
- sys_info: `uname -a`, `sw_vers`, `sysctl hw.*`
- disk_usage: `df -h`, `diskutil list`
- process_list: `ps -axo pid,ppid,rss,command,%mem`
- network_ports: `lsof -i -P -n`

### FILESYSTEM (SCOPED)
- list_files(dir): `ls -la <dir>`
- read_file(path): text-only, UTF-8, size <= 1MB
- search_text(pattern, path): `rg` allowlist, scoped

### DEV/OPS (OPT-IN, READ-ONLY)
- git_status: `git status -sb`
- git_branch: `git rev-parse --abbrev-ref HEAD`
- docker_ps: `docker ps`
- kubectl_get(resource, ns): `kubectl get <resource> -n <ns>`
- aws_identity: `aws sts get-caller-identity`

## DEFINE TOOL EXAMPLES

### list_files
```js
defineTool("list_files", {
  description: "List files in a directory (CWD + HOME only).",
  parameters: {
    type: "object",
    properties: { dir: { type: "string" } },
    required: ["dir"],
    additionalProperties: false,
  },
  handler: async ({ dir }) => runCommand("ls", ["-la", dir]),
});
```

### read_file
```js
defineTool("read_file", {
  description: "Read a text file (UTF-8, <= 1MB).",
  parameters: {
    type: "object",
    properties: { path: { type: "string" } },
    required: ["path"],
    additionalProperties: false,
  },
  handler: async ({ path }) => readTextFileSafe(path, { maxBytes: 1_000_000 }),
});
```

### search_text
```js
defineTool("search_text", {
  description: "Search text with ripgrep (scoped).",
  parameters: {
    type: "object",
    properties: {
      pattern: { type: "string" },
      path: { type: "string" },
    },
    required: ["pattern", "path"],
    additionalProperties: false,
  },
  handler: async ({ pattern, path }) => runCommand("rg", [pattern, path]),
});
```

## HOOKS: DENY BY DEFAULT
```js
hooks: {
  onPreToolUse: async ({ toolName }) => {
    if (!ALLOWLIST.has(toolName)) {
      return { permissionDecision: "deny", additionalContext: "Tool denied" };
    }
    return { permissionDecision: "allow" };
  },
}
```

## SYSTEM MESSAGE SAFETY
- APPEND MODE RECOMMENDED.
- IF YOU REPLACE, RE-ADD:
  - COMMAND-ONLY OUTPUT RULES
  - SAFETY POLICY TEXT
  - READ-ONLY DEFAULTS
  - TOOL ALLOWLIST WITH `availableTools`

## COMMAND-ONLY OUTPUT ENFORCEMENT
- REJECT CONTENT WITH NEWLINES OR BACKTICKS.
- STRIP "command:" PREFIX IF PRESENT.
- FAIL CLOSED ON INVALID OUTPUT.

## LOCAL DEFAULTS
- TOOLS ARE ONLY FOR THE COPILOT PATH.
- LOCAL MODEL PATH: `$HOME/.cache/llm-models/qwen3-codersmall-q8_0.gguf`.

## INITIAL TESTS (MANUAL)
1) TOOL ALLOWLIST: CALL A NON-ALLOWLISTED TOOL -> DENIED.
2) PATH SCOPE: `read_file /etc/hosts` -> REJECTED.
3) SIZE LIMIT: `read_file` > 1MB -> REJECTED.
4) SEARCH: `search_text` FINDS MATCHES IN CWD.
5) DEV/OPS TOOL: `docker_ps` OR `kubectl_get` OR `aws_identity` RETURNS READ-ONLY INFO.
6) CONFIG: EDIT `config.json` THEN RESTART SHELL, VERIFY ALLOWLIST CHANGES APPLY.

## REFERENCES
- POLICY: `/.dotfiles/zsh/plugins/mcrn-ai/policy.txt`
- COPILOT HELPER: `/.dotfiles/zsh/plugins/mcrn-ai/copilot-helper.mjs`
- LOCAL HELPER: `/.dotfiles/zsh/plugins/mcrn-ai/local-helper.sh`
- TOOLS: `/.dotfiles/zsh/plugins/mcrn-ai/tools/index.mjs`
- CONFIG: `/.dotfiles/zsh/plugins/mcrn-ai/config.json`
- SCHEMA: `/.dotfiles/zsh/plugins/mcrn-ai/config.schema.json`
