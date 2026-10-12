# Changelog

All notable changes to SettleBell will be documented here. SettleBell was
originally released as PiPing and uses semantic versioning with source-release
tags in the form `vMAJOR.MINOR.PATCH`.

## 0.2.0 — Source-only developer preview

SettleBell's first developer preview is source-only. Locally generated apps and
archives are not public release artifacts.

### Fixed

- Reject mutation-blocking/restricted or unreviewed BSD file flags while allowing
  reviewed benign flags, and check flags for metadata stability (SB-NEW-01).
- Verify that a signed-local provisioning profile authorizes the requested
  CloudKit service without expanding actual app/helper entitlements (SB-NEW-02).
- Reject unsafe app-tree ownership, modes, ACLs, hardlinks, symlinks and special
  objects in both local installation validators (SB-SEC-01).
- Require exact signed app entitlements, an entitlement-free helper and its
  expected signature identifier; distinguish profile authorization from profile
  identity pinning (SB-SEC-02).
- Validate an existing CloudKit subscription's complete fixed schema and stop
  with a reset-required state on mismatch, without replacing it (SB-SEC-03).
- Retain and await the delayed APNs test callback task (SB-EVID-04).
- Show the existing observable CloudKit delivery status in Mac Settings instead
  of a static setup message (SB-UI-001).
- Invalidate queued Cloud publication on disable and prevent stale in-flight
  outcomes from overwriting current consent status (SB-REV-001).
- Route generic local-installation checks to the correct strict validator while
  keeping signed-installer checks private-only (SB-REV-002).
- Clarify intentional public attribution/artwork exceptions and reconcile the
  packaged Pi edge's scoped 0.85.1 compatibility statement (SB-REV-003/004).

### Changed

- Add SettleBell Light/Dark desktop hero images while preserving historical
  PiPing artwork; use lossless WebP with only sanitized color-profile metadata.
- Document scoped Pi 0.85.1 private acceptance, status meanings, and remaining
  release-validation boundaries.
- Rename the native Apple companion from PiPing to SettleBell to distinguish it
  from the independently developed `@bukutsu/pi-ping` terminal extension.
- Prepare a side-by-side identity and guarded migration path while preserving
  the immutable PiPing `v0.1.0` release and deployed CloudKit v1 wire/storage
  identifiers.
- Give SettleBell independent app/helper paths, bundle identities, FIFO runtime,
  notification authorization, preferences, and unread/backlog state rather than
  silently copying PiPing state.
- Add legacy source-local validation pinned to PiPing `0.1.0 (15)`, a separately
  trusted archive/hash, bounded private input pin, repeated exact installed-tree
  match, fresh interactive notification attestation, interruption rollback, and
  at most three validated
  recovery archives; signed/private PiPing retirement remains out of scope.

## 0.1.0 - 2026-08-31

PiPing's first public version is a source-only developer preview.

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

- Start FIFO listening from the macOS application lifecycle so Login Item
  launches work without presenting the main window.
- Refresh macOS notification authorization at startup.
- Report mobile delivery unavailable in CloudKit-disabled builds.
- Remove unread IDs when local notification delivery fails before presentation.
- Mark the Pi peer dependency optional so package installation does not
  materialize a second Pi runtime, and prevent Pi-managed Git clones from
  generating an untracked package lock.

### Security

- CloudKit defaults off in tracked configuration and requires explicit private
  configuration and user enablement.
- Ordinary and source-local builds never read ignored private configuration.
- APNs registration is bounded and cancellation-safe.
- Local IPC validates ownership, type, permissions, ACLs, and symlink safety.
- Guarded install/uninstall transactions pin prior identity and establish
  rollback, candidate-promotion, or commit state before atomic moves and
  preference deletion; normal
  HUP, INT, and TERM signals route through cleanup. Repository regressions
  inspect transaction source ordering; retained clean-VM acceptance is scoped
  separately. This wording does not claim a behavioral interruption matrix or
  automatic recovery from power loss/SIGKILL.
- Guarded local installation validates archive paths, identity, signatures,
  hardened runtime, canonical paths, and bounded compressed recovery without
  using `sudo`; source-local apps must have no entitlements, while signed-local
  apps validate team, container, activation metadata, certificate and helper
  configuration with provisioning-profile authorization checks. For current
  SettleBell, the app/helper entitlement sets are exact; the profile itself is
  not pinned by UUID/hash or by its complete capability set.
