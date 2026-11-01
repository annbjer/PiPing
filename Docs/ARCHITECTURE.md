# Architecture

## Phase 1 data flow

```mermaid
flowchart LR
    Pi[Pi 0.84.3 / 0.84.4 / 0.85.1 tested] -->|before_agent_start / agent_settled only| Hook[Minimal Pi hook]
    Hook -->|fixed signal plus ephemeral UUID| Helper[Native SettleBellSignal]
    Helper -->|0600 FIFO in 0700 directory| Mac[macOS companion]
    Mac -->|fixed title and body| Local[macOS UserNotifications]
    Mac -->|private config plus explicit enable| Cloud[Private CloudKit database]
    Cloud -->|user-installed fixed subscription| Phone[iPhone app]
    Phone -. system mirroring .-> Watch[Paired Apple Watch]
```

The Pi hook reads no lifecycle event fields. It generates a random UUID for
each active lifecycle cycle, unrelated to Pi's persisted session identity.
Repeated starts before settlement retain that cycle's token; after a settlement
attempt, the next cycle always receives a fresh token so an abandoned Mac timer
cannot match a later run. `before_agent_start` opens the duration window and
`agent_settled` closes it only after Pi has no automatic retry, compaction retry,
or queued continuation left. The Mac tracks tokens independently, so
overlapping Pi processes can each notify. A newer `start` replaces stale state
only for the same still-active token. State is bounded to 256 active tokens and
expires after seven days; FIFO
input is decoded as a bounded stream so combined and split reads preserve whole
messages. The serialized delivery backlog is capped at 64 and the in-memory
unread-ID set at 256. Runs under the selected threshold are ignored.

## Components

| Component | Responsibility | Network behavior |
| --- | --- | --- |
| `SettleBellCore` | Fixed copy, two-signal/opaque-token protocol, bounded stream decoder, multi-session duration gate | None |
| `SettleBellSignal` | Validate and atomically write one fixed signal plus UUID | None |
| `SettleBellMac` | Listen locally, apply threshold, present Mac status and notifications | Cloud publishing requires valid private build configuration and explicit user enablement |
| `SettleBellCloudKit` | Build one allowlisted rolling record and a fixed visual subscription | Explicit private container only |
| `SettleBellIOS` | Check iCloud, request notifications, confirm APNs, and install the subscription | User-initiated setup; automatic refresh of existing setup state when opened |
| Pi hook | Translate two documented Pi lifecycle events and the current cycle's random UUID to native helper calls | None |

In a privately configured iOS build with notification permission already allowed,
opening the app automatically checks iCloud availability and the fixed
subscription. It confirms APNs registration only after finding a matching
subscription. This refresh does not request notification permission or create,
replace, or delete a subscription. The public build's disabled CloudKit gate
stops the refresh before those network checks.

The macOS app delegate owns one long-lived `MacAppStore` and starts its FIFO
listener from `applicationDidFinishLaunching`. Listener availability therefore
does not depend on a SwiftUI window task and is established for Login Item
launches before the canonical helper is used.

The tracked public build defaults CloudKit activation to `false` and rejects
placeholder container identifiers. The source-local builder forces those public
values even when an ignored private override exists, then applies ad-hoc
hardened-runtime signatures with no profile or entitlements. Separate guarded
validation/install/uninstall scripts refuse foreign canonical apps, preserve
bounded compressed recovery, and never enable CloudKit or mutate Apple-managed
notification databases. An ignored private-local build override may enable
CloudKit only through the separate Apple Development-signed path. The Mac still
requires a persisted user enable action. PiPing and SettleBell otherwise remain
separate bundle identities, canonical app/helper paths, FIFO runtimes,
notification permissions, preference domains, and unread/backlog state. Phase 2
controls remain hard-coded to `false`.

## Apple delivery behavior

The Mac uses `UNUserNotificationCenter` with `.default` sound. CloudKit uses the
user's private database and a visual query subscription with the same fixed
copy and `default` sound. Every attention event overwrites one fixed rolling
record whose only application field is `occurredAt`. The subscription fires on
record creation and update, requests no record fields, and sends no background
content.

The Mac serializes attention delivery so rapid completions cannot race updates
to the one rolling CloudKit record. It reports remote delivery as sent only
after CloudKit accepts that event's write. This confirms the private-database
write, not presentation on every device. Each queued attention captures the
current in-memory consent generation only if delivery is enabled. Disable
invalidates that generation; it is checked after local delivery and immediately
before invoking the publisher, then again before accepting a publication status.
An already handed-off request may complete, but cannot overwrite a disabled or
newly re-enabled status. Old queued work is never revived by re-enabling. The
consent generation is not persisted, sent over IPC, or written to CloudKit.

The initial SettleBell migration keeps
PiPing's deployed v1 record type `PiPingAttention`, rolling record name
`piping.attention.current`, and subscription ID `piping.attention.v1`. These are
internal compatibility identifiers; renaming them requires a separately
reviewed CloudKit reset or migration. Normal iPhone notification routing
determines whether the iPhone or paired Watch alerts. Siri Announce
Notifications remains an optional system setting; SettleBell does not implement
speech or voice commands.

The menu-bar attention dot tracks the UUIDs of locally generated notification
requests in memory. SettleBell registers one fixed, actionless notification category
with Apple's public `.customDismissAction` option. Clicking or dismissing a
SettleBell notification acknowledges that exact request through the system delegate;
opening the SettleBell menu acknowledges all. The category presents no action button
and no command channel. SettleBell does not monitor terminal focus or window titles
and cannot infer the originating terminal without expanding the privacy boundary.

Private development acceptance includes Pi 0.85.1 package loading and ordinary
threshold-qualified turns: Pi settled, the Mac notified, and optional delivery
reached the paired Watch after iPhone notification setup. This is functional
owner-observed acceptance, not an exactly-once or all-routing-states guarantee.
The original PiPing baseline also passed two overlapping ordinary Pi sessions;
SettleBell's controlled overlap and automated token tests do not substitute for
a live 5–10-process stress test. Normal local use installs the
repository through Pi's user-package mechanism; no notification or control data
is added to Pi's configuration beyond the local package reference.

The main window and Settings read the same observable
`MacAppStore.cloudDeliveryStatus.label`. Status presentation does not enable
CloudKit, request consent, or perform network operations. `Ready` means delivery
is enabled, not a live connectivity check; `Published` means CloudKit accepted a
write, not that a device displayed an alert.

## Explicit exclusions

Phase 1 has no command model, user-visible notification action, App Intent,
deep link, node presence, dashboard, project/file view, Pi session metadata,
terminal identity, Tailscale dependency, terminal surface, approval surface, or
arbitrary network configuration. The ephemeral local correlation UUID conveys
no project or session content and is discarded from memory after settlement,
expiry, overflow reset, or app restart.

A future action vocabulary is a separate security boundary and module. Nothing
in Phase 1 acts as a dormant return channel.
