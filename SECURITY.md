# Security policy

PiPing is intentionally small and one-way. Its security model is based on fixed
notification content, minimal local signals, private CloudKit storage when
enabled, and guarded installation paths.

## Reporting a vulnerability

We welcome responsible security reports. When **Report a vulnerability** is
available on this repository's **Security** tab, use it to open a private report
visible only to you and the maintainers.

If that button is not available, please do not post sensitive details in a public
issue, discussion, pull request, or social post. Private vulnerability reporting
must be enabled and verified before any public tag or release proceeds.

A useful report includes:

- the affected commit or version;
- relevant macOS, iOS, Xcode, and Pi versions;
- clear reproduction steps;
- expected and observed behavior; and
- the potential impact.

Use synthetic data. Never include credentials, real prompts or model output,
unrelated source code, personal paths, signing or CloudKit identifiers,
provisioning data, or device identifiers. If those details seem necessary,
describe the situation in prose instead of pasting the data.

Security reports are taken seriously and will be reviewed as soon as reasonably
possible. PiPing is maintained by one independent developer, so no fixed response
time can be promised; investigation and fix timing will depend on severity and
maintainer availability.

## Supported versions

PiPing is currently distributed as source. Security fixes land on `main` and in
later source releases. Rebuild from a reviewed current revision rather than
patching an installed app bundle in place.

## Phase 1 security boundaries

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
- Source-local installation requires trusted pinned or checksummed source,
  explicit approval, exact public-development validation, no `sudo`, and bounded
  compressed recovery. Ad-hoc signing is not publisher authentication.
- Install and uninstall must refuse private, foreign, and future official apps;
  establish rollback and commit state before destructive boundaries; route
  normal termination signals through cleanup; and never edit Apple's private
  notification databases.

These boundaries are part of PiPing's design and acceptance criteria. They do not
replace the warranty terms in the [MIT License](LICENSE).

## Maintainer security gates

Changes that affect trust boundaries, local IPC, lifecycle data, CloudKit,
notifications, installation, or signing receive repository-wide security review
before real-device acceptance. Unresolved high-confidence findings block that
acceptance.

Before any tag, release, or release-asset upload, maintainers also complete
[the release audit](Docs/RELEASE_AUDIT.md) against the exact revision and archive
payload. Approval for one publication action never authorizes another. See
[Releasing](Docs/RELEASING.md) for the complete process.
