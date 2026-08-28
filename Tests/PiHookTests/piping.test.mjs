import assert from "node:assert/strict";
import test from "node:test";
import {
  canonicalHelperPath,
  makeNativeHelperRunner,
  registerPiPing,
} from "../../Integration/Pi/piping.ts";

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

test("uses the installed helper and reports launch failures without throwing", async () => {
  const invocations = [];
  const failures = [];
  const execute = (file, args, options, completion) => {
    invocations.push({ file, args, options });
    completion(Object.assign(new Error("synthetic failure"), { code: "ENOENT" }));
  };
  const runner = makeNativeHelperRunner(execute, (message) => failures.push(message));

  await runner("settled");

  assert.deepEqual(invocations, [{
    file: canonicalHelperPath,
    args: ["settled"],
    options: { timeout: 1_000, windowsHide: true },
  }]);
  assert.deepEqual(failures, [
    "[PiPing] Could not deliver the settled lifecycle signal "
      + "through the installed helper (ENOENT). "
      + "PiPing notifications are unavailable for this Pi session.",
  ]);
});

test("independently resolves when the helper completion never arrives", async () => {
  const failures = [];
  let helperCompletion;
  let deadline;
  let cancelled = 0;
  const runner = makeNativeHelperRunner(
    (_file, _args, _options, completion) => {
      helperCompletion = completion;
    },
    (message) => failures.push(message),
    (completion, milliseconds) => {
      assert.equal(milliseconds, 1_250);
      deadline = completion;
      return () => { cancelled += 1; };
    },
  );

  const run = runner("start");
  deadline();
  await run;
  helperCompletion(null);

  assert.equal(cancelled, 1);
  assert.deepEqual(failures, [
    "[PiPing] Could not deliver the start lifecycle signal "
      + "through the installed helper (timeout). "
      + "PiPing notifications are unavailable for this Pi session.",
  ]);
});

test("converts a synchronous executor failure into non-throwing reporting", async () => {
  const failures = [];
  const runner = makeNativeHelperRunner(
    () => {
      throw Object.assign(new Error("synthetic failure"), { code: "EACCES" });
    },
    (message) => failures.push(message),
  );

  await runner("settled");

  assert.deepEqual(failures, [
    "[PiPing] Could not deliver the settled lifecycle signal "
      + "through the installed helper (EACCES). "
      + "PiPing notifications are unavailable for this Pi session.",
  ]);
});
