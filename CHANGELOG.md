# Changelog

All notable changes to PiPing will be documented here. PiPing uses semantic
versioning and source-release tags in the form `vMAJOR.MINOR.PATCH`.

## Unreleased

## [0.1.0] - 2026-08-28

First public source-only release.

### Added

- Native macOS and iOS notification companions for Pi lifecycle completion.
- Fixed, content-free local and private-CloudKit notification delivery.
- Same-user FIFO protocol restricted to `start` and `settled`.
- Configurable local notification thresholds.
- Native Icon Composer artwork with automatic Light/Dark appearance.
- Canonical installed-helper Pi integration with timeout and failure reporting.
- Public-safe build verification and release-audit documentation.

### Security

- CloudKit defaults off in tracked configuration and requires explicit local
  configuration and user enablement.
- APNs registration is bounded and cancellation-safe.
- Local IPC validates ownership, type, permissions, ACLs, and symlink safety.
