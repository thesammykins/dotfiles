import { CopilotClient } from "@github/copilot-sdk";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { loadConfig } from "./config.mjs";
import { getAllowlist, getAvailableTools, isDevopsTool } from "./tools/index.mjs";

const MODEL = "gpt-5-mini";
const TIMEOUT_MS = Number.parseInt(process.env.MCRN_AI_TIMEOUT_MS || "12000", 10);

const TOOL_BLOCK_MESSAGE =
  "Tool use is disabled. Return only the command.";
const TOOL_DEVOPS_MESSAGE = "Dev/Ops tools require opt-in.";

const helperDir = path.dirname(fileURLToPath(import.meta.url));
const policyPath =
  process.env.MCRN_AI_POLICY_FILE || path.join(helperDir, "policy.txt");

const loadPolicy = () => {
  try {
    if (!fs.existsSync(policyPath)) return "";
    const content = fs.readFileSync(policyPath, "utf8").trim();
    return content.length > 0 ? content : "";
  } catch {
    return "";
  }
};

const systemPrompt = ({ cwd, home, os, policy }) => `You are a strict CLI command generator for macOS zsh.
Your ONLY job is to translate natural language into a single, valid, raw shell command.

ENVIRONMENT:
- OS: ${os}
- Shell: zsh
- Home: ${home}
- PWD: ${cwd}

RULES:
1. NEVER explain. NEVER use markdown. NEVER use backticks.
2. Output exactly one command and nothing else.
3. Prefer standard macOS paths (e.g., ~/Downloads, ~/Desktop) unless a local path is explicitly implied.
4. Use modern macOS/zsh idiomatic commands (e.g., find, rg, awk, lsof, ipconfig, pbcopy).
5. If the prompt implies your current location, use the PWD provided.
6. Prefer readable output and avoid truncated fields when better alternatives exist.
7. When using ps, prefer full command/args output (command/args) over comm when clarity matters.
8. Avoid unnecessary pipes if a single command/flag can do the job.

EXAMPLES:
User: list files larger than 10MB in downloads
Command: find ~/Downloads -type f -size +10M

User: kill process listening on port 8080
Command: lsof -ti:8080 | xargs kill -9

User: find text 'TODO' in python files here
Command: rg 'TODO' -g '*.py'
${policy ? `\n\n${policy}` : ""}`;

const readStdin = async () =>
  new Promise((resolve, reject) => {
    let data = "";
    process.stdin.setEncoding("utf8");
    process.stdin.on("data", (chunk) => {
      data += chunk;
    });
    process.stdin.on("end", () => resolve(data.trim()));
    process.stdin.on("error", reject);
  });

const sanitizeCommand = (value) => {
  if (typeof value !== "string") return "";
  let trimmed = value.trim();
  if (trimmed.length === 0) return "";
  if (/[\r\n]/.test(trimmed)) return "";
  if (trimmed.includes("```")) return "";
  trimmed = trimmed.replace(/^command:\s*/i, "");
  if (trimmed.length === 0) return "";
  if (/[\u0000-\u001F\u007F]/.test(trimmed)) return "";
  return trimmed;
};

const safeJson = (payload) =>
  JSON.stringify(payload, (_key, val) => (typeof val === "string" ? val : val));

const main = async () => {
  const prompt = await readStdin();
  if (!prompt) {
    process.stdout.write(safeJson({
      command: "",
      confidence: 0,
      provider: "copilot",
      error: "empty_prompt",
    }));
    return;
  }

  const cwd = process.env.PWD || process.cwd();
  const home = process.env.HOME || "";
  const os = `${process.platform} (${process.arch})`;

  const policy = loadPolicy();
  const client = new CopilotClient();
  const config = loadConfig();
  const allowlist = getAllowlist();
  const tools = getAvailableTools();
  const devopsEnabled = config.tools.devopsEnabled;
  try {
    await client.start();
    const session = await client.createSession({
      model: MODEL,
      systemMessage: {
        mode: "replace",
        content: systemPrompt({ cwd, home, os, policy }),
      },
      availableTools: Array.from(allowlist),
      tools,
      hooks: {
        onPreToolUse: async ({ toolName }) => {
          if (!allowlist.has(toolName)) {
            return {
              permissionDecision: "deny",
              additionalContext: TOOL_BLOCK_MESSAGE,
            };
          }
          if (isDevopsTool(toolName) && !devopsEnabled) {
            return {
              permissionDecision: "deny",
              additionalContext: TOOL_DEVOPS_MESSAGE,
            };
          }
          return {
            permissionDecision: "allow",
          };
        },
      },
    });

    const response = await session.sendAndWait({ prompt }, TIMEOUT_MS);
    const content = response?.data?.content ?? "";
    const command = sanitizeCommand(content);
    await session.destroy();
    await client.stop();

    process.stdout.write(safeJson({
      command,
      confidence: command ? 1 : 0,
      provider: "copilot",
    }));
  } catch (error) {
    await client.forceStop().catch(() => undefined);
    process.stdout.write(safeJson({
      command: "",
      confidence: 0,
      provider: "copilot",
      error: error instanceof Error ? error.message : "copilot_error",
    }));
  }
};

main().catch((error) => {
  process.stdout.write(safeJson({
    command: "",
    confidence: 0,
    provider: "copilot",
    error: error instanceof Error ? error.message : "copilot_error",
  }));
});
