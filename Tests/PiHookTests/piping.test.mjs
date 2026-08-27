import assert from "node:assert/strict";
import test from "node:test";
import { registerPiPing } from "../../Integration/Pi/piping.ts";

function fakePi() {
  const handlers = new Map();
  return {
    handlers,
    api: {
      on(event, handler) {
        handlers.set(event, handler);
      },
    },
  };
}

test("registers only the two lifecycle handlers", () => {
  const pi = fakePi();
  registerPiPing(pi.api, async () => {});
  assert.deepEqual([...pi.handlers.keys()].sort(), [
    "agent_settled",
    "before_agent_start",
  ]);
});

test("forwards only fixed start and settled signals", async () => {
  const pi = fakePi();
  const signals = [];
  registerPiPing(pi.api, async (signal) => signals.push(signal));

  await pi.handlers.get("before_agent_start")({
    prompt: "synthetic private prompt",
    systemPrompt: "synthetic private system content",
  });
  await pi.handlers.get("agent_settled")(
    { messages: ["synthetic private output"] },
    { isIdle: () => true },
  );

  assert.deepEqual(signals, ["start", "settled"]);
});

test("does not emit settled when another extension made Pi active", async () => {
  const pi = fakePi();
  const signals = [];
  registerPiPing(pi.api, async (signal) => signals.push(signal));

  await pi.handlers.get("agent_settled")({}, { isIdle: () => false });
  assert.deepEqual(signals, []);
});
