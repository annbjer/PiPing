# Pi integration edge

`piping.ts` is the only non-Swift product boundary. Pi 0.84.3 and 0.84.4 have
passed package-load and ordinary-turn acceptance with the documented
`before_agent_start` and `agent_settled` events. Other versions are not claimed
compatible until these hooks and `context.isIdle()` are retested.

The hook:

- reads no prompt, message, model, path, Pi session, tool, code, or result data;
- generates a random UUID for each active lifecycle cycle and sends it only with
  the fixed `start` and `settled` helper arguments, allowing overlapping Pi
  processes to remain independent while preventing abandoned state from
  matching a later cycle;
- invokes only `/Applications/PiPing.app/Contents/Helpers/PiPingSignal`,
  without a shell;
- ignores helper failures so it cannot block Pi indefinitely; and
- provides no reverse channel, tool, command, approval, or remote action.

The opaque UUID is not Pi's session ID. It is not persisted by the extension,
included in notification copy, or sent to CloudKit.

For an isolated trial, load the extension explicitly for one Pi run. For normal
use, install the repository through Pi's user-package mechanism. The Pi peer is
optional metadata, not an installed dependency, so PiPing does not materialize
a second Pi runtime. Both procedures and the reversible uninstall command are
documented in `Docs/SETUP.md`.
