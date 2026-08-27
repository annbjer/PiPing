import { execFile } from "node:child_process";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export type PiPingSignal = "start" | "settled";
export type SignalRunner = (signal: PiPingSignal) => Promise<void>;

const integrationDirectory = dirname(fileURLToPath(import.meta.url));
const helperPath = resolve(
  integrationDirectory,
  "../../dist/PiPing.app/Contents/Helpers/PiPingSignal",
);

export const runNativeHelper: SignalRunner = async (signal) => {
  await new Promise<void>((resolvePromise) => {
    execFile(
      helperPath,
      [signal],
      { timeout: 1_000, windowsHide: true },
      () => resolvePromise(),
    );
  });
};

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
