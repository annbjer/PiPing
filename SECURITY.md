# Security policy

## Phase 1 invariants

- PiPing is one-way and notification-only.
- Only `start` and `settled` cross the Pi-to-native boundary.
- Notification text is fixed in source and uses a normal system sound.
- The minimum eligible duration defaults to 30 seconds.
- CloudKit uses the private database and allowlisted fields only.
- No control, reply, approval, terminal, file, log, prompt, or model-output data
  crosses any boundary.
- Local IPC is same-user, bounded, non-networked, and rejects non-FIFO objects,
  insecure permissions, and symlinks.
- CloudKit and notification setup occurs only after an explicit user action.
- No secrets or personal identifiers belong in the repository or Git history.
- Source-local installation requires trusted pinned/checksummed source, explicit
  approval, exact public-development validation, no `sudo`, and bounded
  compressed recovery; ad-hoc signing is not publisher authentication.
- Install/uninstall must refuse private, foreign, and future official apps and
  must never edit Apple's private notification databases.

## Security gates

Before the first real-device test, run a repository-wide Daybreak deep security
scan. Unresolved high-confidence findings block device testing. Before any
candidate push, public visibility, tag, release, or publication, also complete
`Docs/RELEASE_AUDIT.md` against the exact revision and archive payload.

## Reporting a vulnerability

After separately approved public visibility and enablement, use **Report a
vulnerability** on the repository's GitHub **Security** tab. This opens a private
vulnerability report visible only to the reporter and repository maintainers.
Publication remains paused until that channel is enabled and exercised. Do not
disclose a suspected vulnerability in a public issue, discussion, pull request,
or social post before it has been assessed.

Include the affected revision, platform version, reproduction steps, expected
and observed behavior, and an impact assessment. Use synthetic data only. Never
include real credentials, prompts, model output, source from unrelated projects,
personal paths, signing identifiers, CloudKit identifiers, provisioning data,
or device identifiers.

GitHub private vulnerability reporting is available only after the repository
is public. Immediately after a separately approved visibility change, enable
and exercise **Report a vulnerability** before any tag, release, public
announcement, gallery listing, or other publication step. Until that gate is
complete, do not invite reports or open a public issue, discussion, or pull
request for a suspected vulnerability. If **Report a vulnerability** remains
unavailable, pause publication until a private reporting channel is verified.
