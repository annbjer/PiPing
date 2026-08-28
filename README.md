# PiPing

PiPing is a native Apple notification companion for Pi. Phase 1 is deliberately
small: when Pi 0.84.3 has fully settled after a long-running task, PiPing can
show a generic notification on the Mac, an iPhone, and its paired Apple Watch.

The notification is always:

- **Pi needs attention**
- **Pi has fully settled and is ready for you.**
- normal system notification sound

PiPing's application-defined lifecycle payload contains only a timestamp and
the fixed notification copy. It never reads or serializes prompts, model output,
code, logs, file contents, paths, project names, session identifiers, terminal
data, or approval details.

## Current development status

- Native macOS 26 SwiftUI application target and menu-bar companion.
- Native iOS 26 SwiftUI application target.
- Shared Swift core with a 30-second default noise threshold.
- Private CloudKit adapter with an explicit container, one bounded rolling
  record, and a fixed visual subscription.
- Native macOS UserNotifications adapter with standard sound.
- Protected same-user local FIFO and fixed `start` / `settled` protocol.
- Minimal dependency-free Pi TypeScript integration edge.
- Public-safe tracked configuration with CloudKit disabled by default and an
  ignored private-local override path.
- Signed Mac and iPhone development builds verified on real devices.
- Genuine explicit and ordinary `pi` runs delivered the fixed notification on
  the Mac and iPhone, with normal system mirroring to the paired Apple Watch.
- The iOS 26.5 Simulator runtime is installed for local simulator validation.

The signed Mac app runs as one listener window and reports remote delivery as
sent only after CloudKit accepts the rolling-record write. The private
development machine loads the Pi extension through Pi's user-package mechanism,
so each newly started ordinary `pi` session is observed automatically. No remote
repository or publication has been performed.

## Local verification

Stable Xcode 26 is selected per command without changing the machine-wide
`xcode-select` value:

```bash
./script/verify.sh
```

This builds ignored, public-safe unsigned artifacts. It does not overwrite or
launch the ignored signed private build, contact CloudKit, or send a
notification.

To build and stage the unsigned macOS app without launching it:

```bash
./script/build_and_run.sh --build-only
```

The unsigned public-safe Mac artifact is staged as the verified archive
`dist/unsigned/PiPing.app.zip` and is labeled **PiPing Development**. Build-only
verification does not retain a discoverable application bundle.

The Pi integration deliberately invokes only the installed helper at
`/Applications/PiPing.app/Contents/Helpers/PiPingSignal`. It never follows a
DerivedData, repository, or backup build path. Notification authorization,
LaunchServices metadata, and icon caches are keyed to the private macOS bundle
identifier supplied by ignored `Config/Local.xcconfig`; changing that identifier
creates a new macOS notification identity.

A read-only canonical-install check is available after installing the signed
private build:

```bash
./script/check_installation.sh
```

To inspect the local toolchain, public defaults, private-override presence,
prospective signing/configuration surface, and working tree without changing
anything or printing private values:

```bash
./script/status.sh
```

See [setup](Docs/SETUP.md), [architecture](Docs/ARCHITECTURE.md),
[privacy](Docs/PRIVACY.md), and the [security policy](SECURITY.md).

## License and publication

No open-source license has been selected yet, so this checkout is not ready for
publication. Creating a GitHub remote or publishing requires separate approval,
a fresh Daybreak deep security scan against the exact release candidate,
selection of an OSI-approved license, and the release-surface audit in
[Docs/RELEASE_AUDIT.md](Docs/RELEASE_AUDIT.md).
