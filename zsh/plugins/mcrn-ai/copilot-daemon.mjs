import fs from "node:fs";
import net from "node:net";
import readline from "node:readline";
import { CopilotService, classifyError } from "./copilot-service.mjs";
import { parseInput, buildContextBlock } from "./copilot-helper.mjs";
import { loadConfig } from "./config.mjs";

const config = loadConfig();
const DEFAULT_MODEL = process.env.MCRN_COPILOT_MODEL || config.model.default || "gpt-5-mini";
const DEFAULT_TIMEOUT_MS = Number.parseInt(
  process.env.MCRN_AI_TIMEOUT_MS || "30000",
  10
);
const TCP_MODE = process.argv.includes("--tcp");
const IDLE_TIMEOUT_SEC = config.daemon.idleTimeoutSec || 300;
const STATE_FILE =
  process.env.MCRN_AI_DAEMON_STATE_FILE ||
  `/tmp/mcrn-ai-daemon-${process.getuid()}.json`;

const safeJson = (payload) => JSON.stringify(payload);

const service = new CopilotService({
  model: DEFAULT_MODEL,
  timeoutMs: DEFAULT_TIMEOUT_MS,
});

let idleTimer = null;

const resetIdleTimer = () => {
  if (idleTimer) clearTimeout(idleTimer);
  idleTimer = setTimeout(() => {
    cleanup();
    process.exit(0);
  }, IDLE_TIMEOUT_SEC * 1000);
  idleTimer.unref();
};

const cleanup = () => {
  if (TCP_MODE) {
    try { fs.unlinkSync(STATE_FILE); } catch {}
  }
};

const shutdown = async () => {
  cleanup();
  await service.stop().catch(() => undefined);
};

process.on("SIGTERM", () => {
  shutdown().finally(() => process.exit(0));
});

process.on("SIGINT", () => {
  shutdown().finally(() => process.exit(0));
});

process.on("exit", cleanup);

// Build context block for widget-format payloads
const buildWidgetContext = (payload) => {
  const input = parseInput(JSON.stringify(payload));
  return buildContextBlock(input);
};

const handleRequest = async (request) => {
  resetIdleTimer();

  const id = request?.id ?? null;
  const type = request?.type;
  const format = request?.format;

  if (type === "health") {
    try {
      await service.start();
      return {
        id,
        type: "health",
        payload: { ok: true, model: service.model },
      };
    } catch (error) {
      return {
        id,
        type: "health",
        payload: { ok: false, ...classifyError(error) },
      };
    }
  }

  if (type !== "generate" && type !== "suggest") {
    return {
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
    };
  }

  const payload = request?.payload || {};
  const requestModel =
    typeof payload.model === "string" && payload.model.length > 0
      ? payload.model
      : DEFAULT_MODEL;

  // Handle suggest requests (lighter path for next-command predictions)
  if (type === "suggest") {
    try {
      const response = await service.suggest({
        lastCommand: payload.lastCommand,
        exitCode: payload.exitCode,
        cwd: payload.cwd,
        home: payload.home,
        recentHistory: payload.recentHistory,
        model: requestModel,
      });
      return { id, type: "suggest", payload: response };
    } catch (error) {
      return {
        id,
        type: "suggest",
        payload: {
          command: "",
          confidence: 0,
          provider: "copilot",
          model: requestModel,
          ...classifyError(error),
        },
      };
    }
  }

  try {
    // Build context block if widget-format payload (has mode field)
    const contextBlock =
      typeof payload.mode === "string" ? buildWidgetContext(payload) : "";

    const response = await service.request({
      prompt: payload.prompt,
      timeoutMs: Number.isFinite(payload.timeoutMs)
        ? payload.timeoutMs
        : DEFAULT_TIMEOUT_MS,
      model: requestModel,
      cwd: payload.cwd,
      home: payload.home,
      dotfiles: payload.dotfiles,
      shell: payload.shell,
      termProgram: payload.termProgram,
      inGitRepo: payload.inGitRepo,
      aliasContextRaw: payload.aliasContextRaw,
      contextBlock,
    });

    return { id, type: "generate", payload: response };
  } catch (error) {
    return {
      id,
      type: "generate",
      payload: {
        command: "",
        confidence: 0,
        provider: "copilot",
        model: requestModel,
        ...classifyError(error),
      },
    };
  }
};

// Format response for ZLE consumption (structured lines)
const formatZle = (result) => {
  const p = result?.payload || {};
  const ec = p.error_code || "";
  const err = p.error || "";
  const cmd = p.command || "";
  return `${ec}\n${err}\n${cmd}`;
};

// ── TCP Mode ────────────────────────────────────────────────────────
const startTcp = () => {
  const server = net.createServer((socket) => {
    const rl = readline.createInterface({
      input: socket,
      crlfDelay: Infinity,
    });

    rl.on("line", async (line) => {
      let request;
      try {
        request = JSON.parse(line);
      } catch {
        const errResp = {
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
        };
        if (!socket.destroyed) {
          socket.write(formatZle(errResp));
          socket.end();
        }
        return;
      }

      const result = await handleRequest(request);

      if (!socket.destroyed) {
        if (request.format === "zle") {
          socket.write(formatZle(result));
        } else {
          socket.write(safeJson(result) + "\n");
        }
        socket.end();
      }
    });

    socket.on("error", () => {});
  });

  server.listen(0, "127.0.0.1", () => {
    const port = server.address().port;
    fs.writeFileSync(
      STATE_FILE,
      JSON.stringify({ pid: process.pid, port }),
      "utf8"
    );
    process.stderr.write(`mcrn-ai daemon listening on 127.0.0.1:${port}\n`);
    resetIdleTimer();
  });

  server.on("error", (err) => {
    process.stderr.write(`mcrn-ai daemon server error: ${err.message}\n`);
    process.exit(1);
  });
};

// ── Stdio Mode (original) ───────────────────────────────────────────
const startStdio = () => {
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

    const result = await handleRequest(request);
    process.stdout.write(safeJson(result) + "\n");
  });

  rl.on("close", () => {
    shutdown().finally(() => process.exit(0));
  });
};

if (TCP_MODE) {
  startTcp();
  // Pre-warm the Copilot SDK so the first generate request doesn't race
  // client.start() against session creation (causes "session.idle" timeout).
  service.start().catch((err) => {
    process.stderr.write(`mcrn-ai daemon: SDK pre-warm failed: ${err.message}\n`);
  });
} else {
  startStdio();
}
