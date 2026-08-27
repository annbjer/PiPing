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

## Security gates

Before the first real-device test, run a repository-wide Daybreak deep security
scan. Unresolved high-confidence findings block device testing. Before any
remote or publication, also complete `Docs/RELEASE_AUDIT.md` against the exact
revision and archive payload.

## Reporting

This repository has no public security contact yet. Until publication is
approved, report issues privately to the repository owner without including
real credentials, prompts, source code from unrelated projects, or personal
device data in reproductions.
