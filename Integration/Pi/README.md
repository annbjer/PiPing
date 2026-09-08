# Pi integration edge

`settlebell.ts` is the only non-Swift product boundary. Pi 0.84.3 and 0.84.4 passed
package-load and ordinary-turn acceptance on the original PiPing baseline.
Pi 0.85.1 passed those checks on the private SettleBell development baseline,
including owner-observed Watch delivery. This is scoped functional acceptance,
not an exactly-once or live 5–10-session guarantee. Other versions are not
claimed compatible until `before_agent_start`, `agent_settled`, and
`context.isIdle()` are retested.

The hook:

- reads no prompt, message, model, path, Pi session, tool, code, or result data;
- generates a random UUID for each active lifecycle cycle and sends it only with
  the fixed `start` and `settled` helper arguments, allowing overlapping Pi
  processes to remain independent while preventing abandoned state from
  matching a later cycle;
- invokes only `/Applications/SettleBell.app/Contents/Helpers/SettleBellSignal`,
  without a shell;
- ignores helper failures so it cannot block Pi indefinitely; and
- provides no reverse channel, tool, command, approval, or remote action.

The opaque UUID is not Pi's session ID. It is not persisted by the extension,
included in notification copy, or sent to CloudKit.

For an isolated trial, load the extension explicitly for one Pi run. For normal
use, install the repository through Pi's user-package mechanism. The Pi peer is
optional metadata, not an installed dependency, so SettleBell does not materialize
a second Pi runtime. The package-local npm policy also prevents Pi-managed Git
clones from generating an untracked `package-lock.json`. Both procedures and
the reversible uninstall command are
documented in `Docs/SETUP.md`.
