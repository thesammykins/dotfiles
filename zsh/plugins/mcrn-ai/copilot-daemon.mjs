import readline from "node:readline";
import { CopilotService, classifyError } from "./copilot-service.mjs";

const DEFAULT_MODEL = process.env.MCRN_COPILOT_MODEL || "gpt-5-mini";
const DEFAULT_TIMEOUT_MS = Number.parseInt(
  process.env.MCRN_AI_TIMEOUT_MS || "30000",
  10
);

const safeJson = (payload) => JSON.stringify(payload);

const service = new CopilotService({
  model: DEFAULT_MODEL,
  timeoutMs: DEFAULT_TIMEOUT_MS,
});

const shutdown = async () => {
  await service.stop().catch(() => undefined);
};

process.on("SIGTERM", () => {
  shutdown().finally(() => process.exit(0));
});

process.on("SIGINT", () => {
  shutdown().finally(() => process.exit(0));
});

const rl = readline.createInterface({
  input: process.stdin,
  crlfDelay: Infinity,
});

rl.on("line", async (line) => {
  let request;
  try {
    request = JSON.parse(line);
  } catch {
    process.stdout.write(
      safeJson({
        id: null,
        type: "error",
        payload: {
          command: "",
          confidence: 0,
          provider: "copilot",
          model: DEFAULT_MODEL,
          error: "invalid_json_request",
          error_code: "copilot_error",
        },
      }) + "\n"
    );
    return;
  }

  const id = request?.id ?? null;
  const type = request?.type;

  if (type === "health") {
    try {
      await service.start();
      process.stdout.write(
        safeJson({
          id,
          type: "health",
          payload: { ok: true, model: service.model },
        }) + "\n"
      );
    } catch (error) {
      process.stdout.write(
        safeJson({
          id,
          type: "health",
          payload: {
            ok: false,
            ...classifyError(error),
          },
        }) + "\n"
      );
    }
    return;
  }

  if (type !== "generate") {
    process.stdout.write(
      safeJson({
        id,
        type: "error",
        payload: {
          command: "",
          confidence: 0,
          provider: "copilot",
          model: request?.payload?.model || DEFAULT_MODEL,
          error: `unsupported_request_type:${String(type || "unknown")}`,
          error_code: "copilot_error",
        },
      }) + "\n"
    );
    return;
  }

  const payload = request?.payload || {};
  try {
    const response = await service.request({
      prompt: payload.prompt,
      timeoutMs: Number.isFinite(payload.timeoutMs)
        ? payload.timeoutMs
        : DEFAULT_TIMEOUT_MS,
      model:
        typeof payload.model === "string" && payload.model.length > 0
          ? payload.model
          : DEFAULT_MODEL,
      cwd: payload.cwd,
      home: payload.home,
      dotfiles: payload.dotfiles,
      shell: payload.shell,
      termProgram: payload.termProgram,
      inGitRepo: payload.inGitRepo,
      aliasContextRaw: payload.aliasContextRaw,
    });

    process.stdout.write(
      safeJson({
        id,
        type: "generate",
        payload: response,
      }) + "\n"
    );
  } catch (error) {
    process.stdout.write(
      safeJson({
        id,
        type: "generate",
        payload: {
          command: "",
          confidence: 0,
          provider: "copilot",
          model:
            typeof payload.model === "string" && payload.model.length > 0
              ? payload.model
              : DEFAULT_MODEL,
          ...classifyError(error),
        },
      }) + "\n"
    );
  }
});

rl.on("close", () => {
  shutdown().finally(() => process.exit(0));
});
