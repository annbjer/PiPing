# Changelog

All notable changes to PiPing will be documented here. PiPing uses semantic
versioning and source-release tags in the form `vMAJOR.MINOR.PATCH`.

## Unreleased

The first planned public version is the source-only `0.1.0` developer preview.
It has not been tagged or published.

### Added

- Native macOS and iOS notification companions for Pi lifecycle completion.
- Fixed, content-free local and private-CloudKit notification delivery.
- Same-user FIFO protocol restricted to `start` and `settled` plus an opaque,
  per-cycle UUID for independent overlapping sessions.
- Configurable local notification thresholds.
- Native Icon Composer artwork with automatic Light/Dark appearance.
- Canonical installed-helper Pi integration with timeout and failure reporting.
- Bounded lifecycle tracking, FIFO decoding, mailbox, delivery backlog, and
  unread notification state.
- Native notification-click and dismissal acknowledgement for the menu-bar
  attention indicator.
- Guarded no-account source-local Mac build, install, validation, rollback, and
  uninstall tooling with explicit agent approval boundaries.
- Tested Pi compatibility table for versions 0.84.3 and 0.84.4.
- Public-safe build verification and release-audit documentation.

### Changed

- Refresh macOS notification authorization at startup.
- Report mobile delivery unavailable in CloudKit-disabled builds.
- Remove unread IDs when local notification delivery fails before presentation.
- Mark the Pi peer dependency optional so package installation does not
  materialize a second Pi runtime.

### Security

- CloudKit defaults off in tracked configuration and requires explicit private
  configuration and user enablement.
- Ordinary and source-local builds never read ignored private configuration.
- APNs registration is bounded and cancellation-safe.
- Local IPC validates ownership, type, permissions, ACLs, and symlink safety.
- Source-local installation validates archive paths, identity, signatures,
  hardened runtime, profiles, entitlements, canonical paths, and bounded
  compressed recovery without using `sudo`.
