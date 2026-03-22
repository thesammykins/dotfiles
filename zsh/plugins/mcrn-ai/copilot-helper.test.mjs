import assert from "node:assert/strict";
import { resolveModel, sanitizeCommand } from "./copilot-helper.mjs";
import { loadConfig } from "./config.mjs";

const baseConfig = {
  model: { default: "gpt-5-mini" },
  tools: { allowlist: [], devopsEnabled: false },
  limits: { maxOutputBytes: 200000, maxFileBytes: 1000000, toolTimeoutMs: 4000 },
};

assert.equal(resolveModel(baseConfig, {}), "gpt-5-mini");
assert.equal(
  resolveModel(baseConfig, { MCRN_COPILOT_MODEL: "gpt-5.4-mini" }),
  "gpt-5.4-mini"
);
assert.equal(
  resolveModel({ ...baseConfig, model: { default: "gpt-5.3-mini" } }, {}),
  "gpt-5.3-mini"
);

assert.equal(sanitizeCommand("ls -la"), "ls -la");
assert.equal(sanitizeCommand("command: rg TODO"), "rg TODO");
assert.equal(sanitizeCommand("ls && pwd"), "");
assert.equal(sanitizeCommand("cat ~/.zshrc > out.txt"), "");
assert.equal(sanitizeCommand("echo $(pwd)"), "");
assert.equal(sanitizeCommand("first\nsecond"), "");

const originalEnv = {
  MCRN_AI_CONFIG_FILE: process.env.MCRN_AI_CONFIG_FILE,
  MCRN_COPILOT_MODEL: process.env.MCRN_COPILOT_MODEL,
  MCRN_AI_TOOL_TIMEOUT_MS: process.env.MCRN_AI_TOOL_TIMEOUT_MS,
};

process.env.MCRN_AI_CONFIG_FILE = new URL("./config.json", import.meta.url).pathname;
process.env.MCRN_COPILOT_MODEL = "";
process.env.MCRN_AI_TOOL_TIMEOUT_MS = "100";

const config = loadConfig();
assert.equal(config.model.default, "gpt-5-mini");
assert.equal(config.limits.toolTimeoutMs, 4000);

if (typeof originalEnv.MCRN_AI_CONFIG_FILE === "string") {
  process.env.MCRN_AI_CONFIG_FILE = originalEnv.MCRN_AI_CONFIG_FILE;
} else {
  delete process.env.MCRN_AI_CONFIG_FILE;
}

if (typeof originalEnv.MCRN_COPILOT_MODEL === "string") {
  process.env.MCRN_COPILOT_MODEL = originalEnv.MCRN_COPILOT_MODEL;
} else {
  delete process.env.MCRN_COPILOT_MODEL;
}

if (typeof originalEnv.MCRN_AI_TOOL_TIMEOUT_MS === "string") {
  process.env.MCRN_AI_TOOL_TIMEOUT_MS = originalEnv.MCRN_AI_TOOL_TIMEOUT_MS;
} else {
  delete process.env.MCRN_AI_TOOL_TIMEOUT_MS;
}

console.log("mcrn-ai helper tests passed");
