import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const helperDir = path.dirname(fileURLToPath(import.meta.url));

const DEFAULT_CONFIG = {
  tools: {
    allowlist: [],
    devopsEnabled: false,
  },
  limits: {
    maxOutputBytes: 200000,
    maxFileBytes: 1000000,
    toolTimeoutMs: 4000,
  },
};

const normalizeAllowlist = (value) => {
  if (Array.isArray(value)) {
    return value
      .map((item) => (typeof item === "string" ? item.trim().toLowerCase() : ""))
      .filter((item) => item.length > 0);
  }
  if (typeof value !== "string") return [];
  return value
    .split(/[\s,]+/)
    .map((token) => token.trim().toLowerCase())
    .filter((token) => token.length > 0);
};

const readJsonFile = (filePath) => {
  if (!fs.existsSync(filePath)) return null;
  const raw = fs.readFileSync(filePath, "utf8");
  if (!raw.trim()) return null;
  return JSON.parse(raw);
};

const pickNumber = (value, fallback) =>
  Number.isFinite(value) ? Number(value) : fallback;

const pickBoolean = (value, fallback) =>
  typeof value === "boolean" ? value : fallback;

const buildConfig = (input) => {
  const safe = input && typeof input === "object" ? input : {};
  const toolsInput = safe.tools && typeof safe.tools === "object" ? safe.tools : {};
  const limitsInput =
    safe.limits && typeof safe.limits === "object" ? safe.limits : {};

  return {
    tools: {
      allowlist: normalizeAllowlist(toolsInput.allowlist),
      devopsEnabled: pickBoolean(toolsInput.devopsEnabled, false),
    },
    limits: {
      maxOutputBytes: pickNumber(limitsInput.maxOutputBytes, DEFAULT_CONFIG.limits.maxOutputBytes),
      maxFileBytes: pickNumber(limitsInput.maxFileBytes, DEFAULT_CONFIG.limits.maxFileBytes),
      toolTimeoutMs: pickNumber(limitsInput.toolTimeoutMs, DEFAULT_CONFIG.limits.toolTimeoutMs),
    },
  };
};

export const loadConfig = () => {
  const configPath =
    process.env.MCRN_AI_CONFIG_FILE || path.join(helperDir, "config.json");
  let fileConfig = null;
  try {
    fileConfig = readJsonFile(configPath);
  } catch {
    fileConfig = null;
  }

  const merged = buildConfig(fileConfig || {});

  const allowlistEnv = process.env.MCRN_AI_TOOLS_ALLOWLIST;
  if (typeof allowlistEnv === "string" && allowlistEnv.trim().length > 0) {
    merged.tools.allowlist = normalizeAllowlist(allowlistEnv);
  }

  const devopsEnv = process.env.MCRN_AI_TOOLS_DEVOPS;
  if (typeof devopsEnv === "string" && devopsEnv.trim().length > 0) {
    merged.tools.devopsEnabled = ["1", "true", "yes"].includes(
      devopsEnv.toLowerCase()
    );
  }

  const maxOutputEnv = Number.parseInt(
    process.env.MCRN_AI_TOOL_MAX_OUTPUT_BYTES || "",
    10
  );
  if (Number.isFinite(maxOutputEnv)) {
    merged.limits.maxOutputBytes = maxOutputEnv;
  }

  const maxFileEnv = Number.parseInt(
    process.env.MCRN_AI_TOOL_MAX_FILE_BYTES || "",
    10
  );
  if (Number.isFinite(maxFileEnv)) {
    merged.limits.maxFileBytes = maxFileEnv;
  }

  const timeoutEnv = Number.parseInt(
    process.env.MCRN_AI_TOOL_TIMEOUT_MS || "",
    10
  );
  if (Number.isFinite(timeoutEnv)) {
    merged.limits.toolTimeoutMs = timeoutEnv;
  }

  return merged;
};

export const getConfigPath = () =>
  process.env.MCRN_AI_CONFIG_FILE || path.join(helperDir, "config.json");
