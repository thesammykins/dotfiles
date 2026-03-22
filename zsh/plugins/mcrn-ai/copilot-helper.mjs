import { CopilotClient } from "@github/copilot-sdk";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { loadConfig } from "./config.mjs";
import { getAllowlist, getAvailableTools, isDevopsTool } from "./tools/index.mjs";

const TIMEOUT_MS = Number.parseInt(process.env.MCRN_AI_TIMEOUT_MS || "12000", 10);

const TOOL_BLOCK_MESSAGE =
  "Tool use is disabled. Return only the command.";
const TOOL_DEVOPS_MESSAGE = "Dev/Ops tools require opt-in.";

const helperDir = path.dirname(fileURLToPath(import.meta.url));
const isDirectRun = process.argv[1]
  ? path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)
  : false;
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

const systemPrompt = ({ cwd, dotfiles, home, inGitRepo, os, shell, termProgram, policy }) => `You are a strict CLI command generator for macOS zsh.
Your ONLY job is to translate natural language into a single, valid, raw shell command.

ENVIRONMENT:
- OS: ${os}
- Shell: ${shell}
- Terminal: ${termProgram}
- Home: ${home}
- PWD: ${cwd}
- Dotfiles: ${dotfiles}
- In git repo: ${inGitRepo ? "yes" : "no"}

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

export const sanitizeCommand = (value) => {
  if (typeof value !== "string") return "";
  let trimmed = value.trim();
  if (trimmed.length === 0) return "";
  if (/[\r\n]/.test(trimmed)) return "";
  if (trimmed.includes("```")) return "";
  trimmed = trimmed.replace(/^command:\s*/i, "");
  if (trimmed.length === 0) return "";
  if (/[\u0000-\u001F\u007F]/.test(trimmed)) return "";
  if (/[;&|]/.test(trimmed)) return "";
  if (trimmed.includes("$(") || trimmed.includes(">") || trimmed.includes("<")) return "";
  return trimmed;
};

const disconnectSession = async (session) => {
  if (!session) return;
  if (typeof session.disconnect === "function") {
    await session.disconnect();
    return;
  }
  if (typeof session.destroy === "function") {
    await session.destroy();
  }
};

const safeJson = (payload) =>
  JSON.stringify(payload, (_key, val) => (typeof val === "string" ? val : val));

const getModelId = (model) => {
  if (!model || typeof model !== "object") return "";
  if (typeof model.id === "string" && model.id.length > 0) return model.id;
  if (typeof model.name === "string" && model.name.length > 0) return model.name;
  return "";
};

const classifyError = (error) => {
  const message = error instanceof Error ? error.message : String(error || "copilot_error");
  const normalized = message.toLowerCase();

  if (normalized.includes("timeout") || normalized.includes("timed out")) {
    return { error: message, error_code: "copilot_timeout" };
  }
  if (normalized.includes("model") && (
    normalized.includes("not found") ||
    normalized.includes("unsupported") ||
    normalized.includes("invalid") ||
    normalized.includes("rejected")
  )) {
    return { error: message, error_code: "copilot_model_rejected" };
  }
  if (
    normalized.includes("enoent") ||
    normalized.includes("not found") ||
    normalized.includes("command not found") ||
    normalized.includes("executable")
  ) {
    return { error: message, error_code: "copilot_cli_missing" };
  }
  if (
    normalized.includes("login") ||
    normalized.includes("auth") ||
    normalized.includes("sign in") ||
    normalized.includes("unauthorized") ||
    normalized.includes("forbidden")
  ) {
    return { error: message, error_code: "copilot_auth_required" };
  }
  if (normalized.includes("copilot")) {
    return { error: message, error_code: "copilot_error" };
  }

  return { error: message, error_code: "copilot_error" };
};

export const resolveModel = (config = loadConfig(), env = process.env) => {
  if (typeof env.MCRN_COPILOT_MODEL === "string" && env.MCRN_COPILOT_MODEL.trim().length > 0) {
    return env.MCRN_COPILOT_MODEL.trim();
  }
  if (config?.model && typeof config.model.default === "string" && config.model.default.trim().length > 0) {
    return config.model.default.trim();
  }
  return "gpt-5-mini";
};

const main = async () => {
  const prompt = await readStdin();
  const config = loadConfig();
  const model = resolveModel(config);
  if (!prompt) {
    process.stdout.write(safeJson({
      command: "",
      confidence: 0,
      provider: "copilot",
      model,
      error: "empty_prompt",
    }));
    return;
  }

  const cwd = process.env.PWD || process.cwd();
  const home = process.env.HOME || "";
  const dotfiles = process.env.DOTFILES || (home ? `${home}/.dotfiles` : "");
  const shell = process.env.SHELL || "zsh";
  const termProgram = process.env.TERM_PROGRAM || "unknown";
  const inGitRepo = process.env.MCRN_AI_IN_GIT_REPO === "1" || fs.existsSync(path.join(cwd, ".git"));
  const os = `${process.platform} (${process.arch})`;

  const policy = loadPolicy();
  const client = new CopilotClient();
  const allowlist = getAllowlist();
  const tools = getAvailableTools();
  const devopsEnabled = config.tools.devopsEnabled;
  let session;
  try {
    await client.start();
    const availableModels = await client.listModels();
    const supportedModelIds = new Set(availableModels.map(getModelId).filter(Boolean));
    if (!supportedModelIds.has(model)) {
      process.stdout.write(safeJson({
        command: "",
        confidence: 0,
        provider: "copilot",
        model,
        error: `Unsupported Copilot model: ${model}`,
        error_code: "copilot_model_rejected",
        available_models: Array.from(supportedModelIds).sort(),
      }));
      await client.stop();
      return;
    }

    session = await client.createSession({
      model,
      systemMessage: {
        mode: "append",
        content: systemPrompt({ cwd, dotfiles, home, inGitRepo, os, shell, termProgram, policy }),
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
    await disconnectSession(session);
    await client.stop();

    process.stdout.write(safeJson({
      command,
      confidence: command ? 1 : 0,
      provider: "copilot",
      model,
    }));
  } catch (error) {
    await disconnectSession(session).catch(() => undefined);
    const classified = classifyError(error);
    await client.forceStop().catch(() => undefined);
    process.stdout.write(safeJson({
      command: "",
      confidence: 0,
      provider: "copilot",
      model,
      ...classified,
    }));
  }
};

if (isDirectRun) {
  main().catch((error) => {
    const config = loadConfig();
    const model = resolveModel(config);
    const classified = classifyError(error);
    process.stdout.write(safeJson({
      command: "",
      confidence: 0,
      provider: "copilot",
      model,
      ...classified,
    }));
  });
}
