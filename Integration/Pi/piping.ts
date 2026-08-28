import { execFile } from "node:child_process";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export type PiPingSignal = "start" | "settled";
export type SignalRunner = (signal: PiPingSignal) => Promise<void>;
export type FailureReporter = (message: string) => void;

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
  "/Applications/PiPing.app/Contents/Helpers/PiPingSignal";

const executeHelper: HelperExecutor = (file, args, options, completion) => {
  execFile(file, args, options, (error) => completion(error));
};

const reportToPiTerminal: FailureReporter = (message) => {
  console.error(message);
};

export function makeNativeHelperRunner(
  execute: HelperExecutor = executeHelper,
  reportFailure: FailureReporter = reportToPiTerminal,
): SignalRunner {
  return async (signal) => new Promise<void>((resolvePromise) => {
    execute(
      canonicalHelperPath,
      [signal],
      { timeout: 1_000, windowsHide: true },
      (error) => {
        if (error) {
          const reason = error.killed
            ? "timeout"
            : String(error.code ?? "unknown error");
          reportFailure(
            `[PiPing] Could not deliver the ${signal} lifecycle signal `
              + `through the installed helper (${reason}). `
              + "PiPing notifications are unavailable for this Pi session.",
          );
        }
        resolvePromise();
      },
    );
  });
}

export const runNativeHelper: SignalRunner = makeNativeHelperRunner();

export function registerPiPing(
  pi: Pick<ExtensionAPI, "on">,
  runSignal: SignalRunner = runNativeHelper,
): void {
  pi.on("before_agent_start", async () => {
    await runSignal("start");
  });

  pi.on("agent_settled", async (_event, context) => {
    if (context.isIdle()) {
      await runSignal("settled");
    }
  });
}

export default registerPiPing;
