# Pi integration edge

`piping.ts` is the only non-Swift product boundary. Pi 0.84.3 loads it in its
existing extension runtime so PiPing can observe the documented
`before_agent_start` and `agent_settled` events.

The hook:

- reads no prompt, message, model, path, session, tool, code, or result data;
- sends only the fixed strings `start` and `settled` to the native helper;
- invokes a fixed repository-relative helper path without a shell;
- ignores helper failures so it cannot block Pi indefinitely; and
- provides no reverse channel, tool, command, approval, or remote action.

Do not install this package globally during local scaffold verification. See
`Docs/SETUP.md` for the later gated procedure.
