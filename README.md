# PiPing

PiPing is a native Apple notification companion for Pi. Phase 1 is deliberately
small: when Pi 0.84.3 has fully settled after a long-running task, PiPing can
show a generic notification on the Mac, an iPhone, and its paired Apple Watch.

The notification is always:

- **Pi needs attention**
- **Pi has fully settled and is ready for you.**
- normal system notification sound

PiPing never derives a payload from task content. The local protocol carries a
fixed `start` or `settled` signal plus a random, ephemeral UUID generated for
each active lifecycle cycle so overlapping runs remain independent. That
UUID is not Pi's session identifier, stays in Mac memory only, and is never sent
to CloudKit. CloudKit stores only one timestamp field and uses the fixed
notification copy. macOS assigns each local notification a separate random
request identifier that is also never sent to CloudKit. PiPing never reads or
serializes prompts, model output, code, logs, file contents, paths, project
names, Pi session identifiers, terminal data, or approval details.

## Current development status

- Native macOS 26 SwiftUI application target and menu-bar companion.
- Native iOS 26 SwiftUI application target.
- Shared Swift core with a 30-second default noise threshold.
- Private CloudKit adapter with an explicit container, one bounded rolling
  record, and a fixed visual subscription.
- Native macOS UserNotifications adapter with standard sound.
- Protected same-user local FIFO with fixed signals, bounded streaming decode,
  and independent in-memory tracking for overlapping Pi sessions.
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

This runs tests and builds ignored, public-safe unsigned macOS and iOS Release
artifacts. It does not overwrite or launch the ignored signed private build,
contact CloudKit, or send a notification.

To build and stage the unsigned macOS app without launching it:

```bash
./script/build_and_run.sh --build-only
```

The unsigned public-safe Mac artifact is staged as the verified archive
`dist/unsigned/PiPing.app.zip` and is labeled **PiPing Development**. Build-only
verification does not retain a discoverable application bundle. This is a
compile-verification artifact, not an official binary release.

Developers with approved ignored Apple signing and CloudKit configuration can
build and install their own local-only signed app with:

```bash
./script/build_signed_local.sh
./script/install_signed_local.sh --install
```

The generated signed archive can contain account-specific entitlements and must
never be published. See [setup](Docs/SETUP.md) for the complete safeguards.

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

PiPing source and assets are available under the [MIT License](LICENSE).
Contributions are welcome under the guidance in [CONTRIBUTING.md](CONTRIBUTING.md).

Version `0.1.0` is planned as a source-only release. The locally installed Apple
Development-signed app and generated `dist/` output are not public release
artifacts. A future downloadable Mac binary requires Developer ID Application
signing, notarization, and a separate exact-artifact audit.

Creating a GitHub remote or publishing still requires explicit approval, a fresh
Daybreak security review against the exact release candidate, and completion of
[Docs/RELEASE_AUDIT.md](Docs/RELEASE_AUDIT.md). See the complete
[release process](Docs/RELEASING.md).
