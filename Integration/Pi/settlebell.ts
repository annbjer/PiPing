import { execFile } from "node:child_process";
import { randomUUID } from "node:crypto";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export type SettleBellSignal = "start" | "settled";
export type SignalRunner = (
  signal: SettleBellSignal,
  lifecycleToken: string,
) => Promise<void>;
export type LifecycleTokenFactory = () => string;
export type FailureReporter = (message: string) => void;
export type DeadlineScheduler = (
  completion: () => void,
  timeoutMilliseconds: number,
) => () => void;

interface HelperExecutionError extends Error {
  code?: string | number | null;
  killed?: boolean;
}

export type HelperExecutor = (
  file: string,
  args: string[],
  options: { timeout: number; windowsHide: boolean },
  completion: (error: HelperExecutionError | null) => void,
) => void;

export const canonicalHelperPath =
  "/Applications/SettleBell.app/Contents/Helpers/SettleBellSignal";

const executeHelper: HelperExecutor = (file, args, options, completion) => {
  execFile(file, args, options, (error) => completion(error));
};

const reportToPiTerminal: FailureReporter = (message) => {
  console.error(message);
};

const scheduleDeadline: DeadlineScheduler = (completion, timeoutMilliseconds) => {
  const timer = setTimeout(completion, timeoutMilliseconds);
  return () => clearTimeout(timer);
};

const helperExecutionTimeoutMilliseconds = 1_000;
const runnerDeadlineMilliseconds = 1_250;

export function makeNativeHelperRunner(
  execute: HelperExecutor = executeHelper,
  reportFailure: FailureReporter = reportToPiTerminal,
  schedule: DeadlineScheduler = scheduleDeadline,
): SignalRunner {
  return async (signal, lifecycleToken) => new Promise<void>((resolvePromise) => {
    let finished = false;
    let cancelDeadline = () => {};
    const finish = (reason?: string) => {
      if (finished) return;
      finished = true;
      cancelDeadline();
      if (reason) {
        reportFailure(
          `[SettleBell] Could not deliver the ${signal} lifecycle signal `
            + `through the installed helper (${reason}). `
            + "SettleBell notifications are unavailable for this Pi session.",
        );
      }
      resolvePromise();
    };
    cancelDeadline = schedule(
      () => finish("timeout"),
      runnerDeadlineMilliseconds,
    );
    if (finished) {
      cancelDeadline();
      return;
    }

    try {
      execute(
        canonicalHelperPath,
        [signal, lifecycleToken],
        { timeout: helperExecutionTimeoutMilliseconds, windowsHide: true },
        (error) => {
          if (!error) {
            finish();
            return;
          }
          finish(error.killed ? "timeout" : String(error.code ?? "unknown error"));
        },
      );
    } catch (error) {
      const executionError = error as HelperExecutionError;
      finish(String(executionError.code ?? "unknown error"));
    }
  });
}

export const runNativeHelper: SignalRunner = makeNativeHelperRunner();

export function registerSettleBell(
  pi: Pick<ExtensionAPI, "on">,
  runSignal: SignalRunner = runNativeHelper,
  makeLifecycleToken: LifecycleTokenFactory = randomUUID,
): void {
  let activeLifecycleToken: string | undefined;

  pi.on("before_agent_start", async () => {
    const lifecycleToken = activeLifecycleToken ?? makeLifecycleToken();
    activeLifecycleToken = lifecycleToken;
    await runSignal("start", lifecycleToken);
  });

  pi.on("agent_settled", async (_event, context) => {
    if (!context.isIdle() || activeLifecycleToken === undefined) return;
    const lifecycleToken = activeLifecycleToken;
    activeLifecycleToken = undefined;
    await runSignal("settled", lifecycleToken);
  });
}

export default registerSettleBell;
