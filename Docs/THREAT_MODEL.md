# PiPing Phase 1 threat model

## Overview

This document models both PiPing's public-safe default and its opt-in signed
private-local configuration. The signed Mac lifecycle-to-notification path and
the signed iPhone/paired-Watch delivery path have been verified with a genuine
explicit Pi extension run. CloudKit defaults off in tracked configuration and
additionally requires valid private-local configuration plus an explicit Mac
enable action. Phase 2 controls remain disabled in source
(`Sources/PiPingCore/FeatureGates.swift:3-26`).

Phase 1 accepts only the lifecycle facts `start` and `settled`, applies a
30-second minimum, and emits fixed notification copy. It intentionally has no
reply or control channel. The fixed copy and event data are defined in
`Sources/PiPingCore/AttentionContent.swift:3-19`; the threshold and state
transitions are in `Sources/PiPingCore/LifecycleGate.swift:29-60`.

The primary security objectives are:

- keep prompt, model output, code, logs, files, project names, session metadata,
  device identity, and user identity out of every application-defined Phase 1
  record and notification payload;
- preserve the one-way boundary and prevent accidental control surfaces;
- prevent another local user or a filesystem substitution from supplying IPC;
- make notification integrity and noise resistance adequate for an attention
  hint, without treating PiPing as an authorization or safety mechanism; and
- keep the repository public-safe before any commit or publication.

## Threat model, trust boundaries, and assumptions

### Assets and security properties

| Asset or property | Required protection |
| --- | --- |
| Pi task content | Must never be read, serialized, logged, or transmitted |
| Notification content | Compile-time generic title and body only |
| Lifecycle integrity | Only fixed `start`/`settled`; notify only after the threshold |
| Directionality | Mac-to-device attention delivery only; no reply path |
| Local IPC | Same-user, non-networked, bounded, exact allowlist |
| Cloud records | Private database; one fixed rolling record name and timestamp field only |
| Apple credentials and identifiers | External local Xcode/Keychain state, never repository content |
| Availability | Best effort; loss must fail quiet rather than broaden authority |

### Components and effective resources

| Component or resource | Current role | Current exposure |
| --- | --- | --- |
| Pi TypeScript hook | Maps two documented lifecycle events to fixed helper arguments | Local Pi process only; no event fields read (`Integration/Pi/piping.ts:26-38`) |
| Native `PiPingSignal` helper | Validates one argument and writes one fixed signal | Repository-staged helper; no network (`Sources/PiPingSignal/main.swift:22-39`) |
| `$HOME/.piping/events.fifo` | Local one-way IPC | `0600` FIFO inside a validated `0700` directory (`Sources/PiPingCore/LocalIPC.swift:30-160`) |
| Lifecycle gate | Suppresses duplicate, missing, and short runs | In-memory macOS process state only (`Sources/PiPingCore/LifecycleGate.swift:42-60`) |
| macOS UserNotifications | Presents fixed copy with normal system sound | Permission checked; local notification only (`Sources/PiPingMac/Services/SystemLocalNotificationService.swift:37-52`) |
| Private CloudKit database | Mac-to-iPhone attention transport | Publishing requires valid private-local configuration and explicit user enablement (`Sources/PiPingMac/Stores/MacAppStore.swift:77-105`, `180-190`) |
| CloudKit query subscription | Fixed iPhone notification | User-initiated setup; record creation and update, fixed copy/sound, no desired fields (`Sources/PiPingCloudKit/CloudKitSchema.swift:18-30`) |
| Apple Watch | Normal iPhone notification mirroring | No watchOS target, payload, action, or direct transport |
| `.build/` and `dist/` | Local signed or unsigned outputs | Ignored; not release source (`.gitignore:1-5`) |

### Trust boundaries

1. **Pi runtime to extension hook.** Prompt and message objects are untrusted and
   may contain secrets. The handlers ignore event fields and pass only literal
   strings (`Integration/Pi/piping.ts:30-37`). Tests inject synthetic private
   fields and verify only two signals escape (`Tests/PiHookTests/piping.test.mjs:26-40`).
2. **Hook to native helper.** The hook uses `execFile` with a repository-relative
   fixed executable path, a single typed argument, no shell, and a one-second
   timeout (`Integration/Pi/piping.ts:9-23`). Failure is deliberately quiet.
3. **Helper to macOS companion.** Both sides validate FIFO type, owner, and
   permissions, reject extended ACLs, and open relative to a validated directory
   descriptor with `O_NOFOLLOW`; the reader accepts at most 64 bytes per read
   (`Sources/PiPingCore/LocalIPC.swift:30-182`,
   `Sources/PiPingMac/Services/LocalSignalListener.swift:40-57`).
4. **Companion to local notification center.** Notification permission is an
   explicit user action, and delivery checks current authorization before using
   the fixed title, body, and default sound
   (`Sources/PiPingMac/Services/SystemLocalNotificationService.swift:23-52`).
5. **Companion to private CloudKit.** The adapter selects
   `privateCloudDatabase` and saves one allowlisted rolling record
   (`Sources/PiPingCloudKit/CloudKitAttentionPublisher.swift:12-32`). The
   boundary is reachable only in a correctly entitled private build with a
   non-placeholder explicit container and persisted user approval. The Mac
   reports sent only after CloudKit accepts the record write.
6. **CloudKit to iPhone and paired Watch.** The user-installed subscription requests a
   visual notification with fixed copy, normal sound, and no record fields
   (`Sources/PiPingCloudKit/CloudKitSchema.swift:18-30`). Apple controls delivery,
   lock-screen presentation, Siri Announce Notifications, and Watch mirroring.
   PiPing makes no background-latency or routing guarantee.
7. **Checkout to public release.** Signing material, user Xcode state, local
   configuration, runtime files, environment files, logs, and build products are
   ignored (`.gitignore:7-26`). Ignoring is not proof of absence; the required
   history and exact archive audit is specified in
   `Docs/RELEASE_AUDIT.md:1-39`.

### Attacker capabilities and assumptions

- Untrusted Pi task content may attempt prompt injection, include control-like
  strings, or be extremely large. It cannot influence Phase 1 output unless the
  hook or fixed-copy source is changed.
- A different local macOS user may know the runtime path but cannot normally
  enter the `0700` directory or write the `0600` FIFO.
- A malicious process already running as the same macOS user can attempt to
  write allowed signals, race runtime objects, stop the app, or modify the
  checkout. PiPing does not claim to isolate mutually hostile same-user code.
- A network attacker cannot address the FIFO. CloudKit transport relies on
  Apple platform security, the signed app's entitlements, and the user's iCloud
  account.
- Repository contributors and build tooling are trusted only after review and
  tests. A source or private-build configuration change can activate or widen a
  boundary, so tests and release gates are security controls, not cosmetic
  checks.
- Notifications are informational attention hints. They must never authorize a
  command or prove that a particular Pi session is safe.

## Attack surface, mitigations, and attacker stories

The following stories are risk hypotheses for review. They are not confirmed
vulnerabilities.

| ID | Story | Impact | Existing mitigation | Residual risk / later check |
| --- | --- | --- | --- | --- |
| TM-01 | Pi task text tries to become a notification body or command. | Privacy leak or control confusion | Hook ignores event fields; content is fixed in Swift; schema has one timestamp field. | A malicious source change could widen the boundary. Keep tests and review mandatory. |
| TM-02 | Another local user pre-creates a file or symlink at the IPC path. | Signal interception, spoofing, or unsafe file access | Runtime directory is forced to `0700`; both ends use `lstat`, require same-owner FIFO with no group/other bits, and use `O_NOFOLLOW`. | Reassess sandbox/container paths before distribution. |
| TM-03 | A same-user process writes repeated valid signals. | Nuisance notification spam or misleading attention state | Exact two-token allowlist, 30-second gate, duplicate-start suppression, no actions or authority. | Same-user spoofing remains possible by design. Add rate limiting only if real testing shows a noise problem. |
| TM-04 | Oversized or malformed local input targets the parser. | Crash, truncation, or bypass | Reader bounds each read to 64 bytes; decoder accepts only exact `start`/`settled` forms (`Sources/PiPingCore/LifecycleGate.swift:3-18`). | Same-user writers can cause denial of service; fuzz the decoder/listener before device testing. |
| TM-05 | CloudKit is configured with the wrong database, fields, or subscription payload. | Cross-user exposure or content leakage | Adapter hard-codes the private database; the record has one fixed name and only `occurredAt`; the subscription requests no record keys (`Tests/PiPingCloudKitTests/CloudKitSchemaTests.swift:9-36`). | Signed Mac and iOS entitlements and the end-to-end private delivery path were inspected and verified. Re-inspect exact release artifacts after material changes. |
| TM-06 | A notification reveals sensitive content on a locked screen or through Siri/AirPods. | Shoulder-surfing or audible disclosure | Copy is generic and contains no node, project, session, prompt, output, or file data. | Users still control notification previews and Announce settings; setup docs must preserve that choice. |
| TM-07 | Signing keys, Team IDs, device IDs, local paths, or CloudKit identifiers enter Git. | Credential compromise or irreversible public disclosure | Signing credentials remain in local Keychain/Xcode state; account-specific configuration, provisioning data, and build outputs are ignored. Source contains only public placeholders and entitlement templates. | `.gitignore` cannot repair history. Rotate credentials and clean/restart history if contamination ever occurs. |
| TM-08 | Future yes/no/stop work reuses the notification pipeline as a hidden return channel. | Unauthorized remote action or command confusion | Phase 2 gate is false; no category, action, deep link, receiver, App Intent, or watch target exists. | Treat Phase 2 as a separate protocol, threat model, authorization design, and approval gate. |
| TM-09 | CloudKit, notifications, the app, or the FIFO is unavailable. | Missed attention alert | Failures are generic and content-free; the transport has no control authority. | Delivery is best effort. Do not use PiPing for safety-critical completion guarantees. |
| TM-10 | Dashboard, presence, Tailscale, session, project, or file features creep into Phase 1. | Broader metadata and network attack surface | Current architecture explicitly excludes them and no data model exists. | Keep them in a separately approved backlog with a new privacy and connectivity review. |

### Defense-in-depth verification for device testing and release

1. The completed repository-wide Daybreak scan found three Low local-IPC issues;
   all three were fixed and verified before the real-device exercise. Re-run the
   security review after material changes and against the exact release
   candidate (`SECURITY.md:17-22`).
2. Re-run all Swift and hook tests, then add parser/listener malformed-input and
   same-user spoof/noise tests where practical.
3. Re-inspect the exact signed Mac and iOS entitlements and embedded provisioning
   profiles without committing either artifact.
4. Verify that the private CloudKit record still has one fixed name and only the
   timestamp field, and that the subscription still contains fixed copy, no
   desired record fields, no background content, and no category or action.
5. Confirm notification permission, lock-screen preview, default sound, iPhone
   versus Watch routing, and optional Siri announce behavior as user-controlled
   system settings.
6. Re-run the full explicit Pi extension path and confirm that the Mac reports
   remote delivery only after the CloudKit write succeeds.

## Severity calibration

PiPing carries no control authority in Phase 1, so availability and same-user
spoofing generally have lower impact than content disclosure or a boundary
expansion. Use these project-specific levels:

- **Critical:** a Phase 1 path can execute or authorize remote actions, expose
  arbitrary Pi/terminal/file content across devices, or publish usable signing
  or CloudKit credentials.
- **High:** sensitive content can enter notifications or CloudKit; another iCloud
  user can receive records; a hidden reply/control path exists; or a public
  release contains recoverable credentials or personal identifiers.
- **Medium:** a different local user can spoof or intercept events; malformed
  input causes persistent companion compromise; or notification actions can be
  confused with authorization.
- **Low:** same-user nuisance spoofing, bounded denial of service, excessive
  alerts, or generic local status disclosure with no sensitive content.
- **Informational:** best-practice improvements that do not currently cross a
  trust boundary or violate a Phase 1 invariant.

This threat model itself asserts no new finding. Earlier validated local-IPC
findings were fixed before the successful device test. Device and release
verdicts must remain scoped to the exact reviewed revision.
