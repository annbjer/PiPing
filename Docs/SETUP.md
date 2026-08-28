# Setup and verification

## Safe local verification

Requirements:

- macOS 26
- stable Xcode 26 at the standard application location
- Node provided by the existing Pi installation for hook tests

Run:

```bash
./script/verify.sh
```

Read-only status:

```bash
./script/status.sh
```

The script uses repository-relative paths, stable Xcode 26, ignored build
directories, synthetic tests, and unsigned outputs. It does not launch either
app, request permission, contact CloudKit, or send a notification.

The repository verifier performs unsigned public-safe macOS and iOS Release
builds and separately cross-compiles the iOS Swift package branch against the
installed Simulator SDK. It does not require a running Simulator. Interactive
Simulator validation additionally requires the matching Xcode platform runtime;
runtimes are installed separately and are not managed by repository scripts.

## Public-safe and private-local configuration

Tracked configuration contains only public-safe placeholders and defaults
CloudKit activation to off. Private development uses an ignored
`Config/Local.xcconfig`, created from `Config/Local.xcconfig.example` only after
the signing and device-test gate. Never commit or print its values.

The targets use automatic signing with local Apple account state:

- macOS requires the CloudKit capability only;
- iOS requires CloudKit and Push Notifications; and
- both signed targets must resolve to the same private CloudKit container.

The Mac does not publish merely because the private build is capable of it. The
user must explicitly choose **Enable iPhone / Watch Delivery**. The approval is
stored locally and can be disabled again in the app.

On iOS, **Configure Notifications** performs the following user-initiated
sequence:

1. confirm that the explicitly configured private container is usable;
2. confirm that the iCloud account is available;
3. request alert and sound permission;
4. confirm APNs registration within a 15-second bound; and
5. install the fixed private-database subscription if needed.

Because Apple's APNs callback does not identify individual attempts, a timed-out
or cancelled registration requires closing and reopening the iPhone app before
retrying. This prevents a late callback from completing the wrong attempt.

The verified private development setup has a signed Mac app and signed iPhone
app. A real Pi completion produced the Mac notification, the CloudKit-backed
iPhone notification, and normal Apple Watch mirroring. Notification routing,
previews, sounds, and optional Siri Announce Notifications remain controlled by
Apple system settings.

## Signed local Mac build and installation

Version `0.1.0` distributes source only. Each developer creates their own
ignored `Config/Local.xcconfig`, signing identity, bundle identifiers, and
CloudKit container. Never reuse or publish another developer's values.

After replacing every placeholder in the ignored local configuration, increment
`CURRENT_PROJECT_VERSION` for a new installable build and run:

```bash
./script/build_signed_local.sh
```

This performs a Release build with automatic Apple Development signing, embeds
and signs `PiPingSignal`, verifies the complete bundle, writes the ignored
local-only archive `dist/private/PiPing.app.zip`, and removes the extracted
signed build product. The archive may contain account-specific entitlements and
must never be attached to the source release.

Preflight the archive, then install or replace the canonical app only with the
explicit guarded command:

```bash
./script/install_signed_local.sh --check
./script/install_signed_local.sh --install
```

The installer rejects public-safe, ad-hoc, foreign-team, wrong-identity,
mismatched-helper, and altered-CloudKit artifacts before copying or launching
anything. It binds the app, helper, hardened runtime, entitlements, and unexpired
provisioning profile to the exact ignored local team, bundle, and container
configuration; creates and tests a compressed rollback; replaces only
`/Applications/PiPing.app`, launches it, and runs the canonical installation
check. If post-install validation fails, it restores the previous canonical app.
After a successful first install, grant notification permission and optionally
enable PiPing under **System Settings > General > Login Items > Open at Login**.

### macOS icon appearance

macOS controls app-icon appearance separately from window appearance. If the
PiPing Dock or notification icon remains light while windows have switched to
Dark Mode, open **System Settings > Appearance**, set **Icon & widget style** to
**Dark**, and choose **Auto** for that style. This allows the system to select
PiPing's light or dark icon alongside the current appearance. The similarly
named automatic folder-color option affects Finder folders only.

## Notification threshold

PiPing defaults to notifying only after a Pi run lasts at least 30 seconds. A
fast response is intentionally quiet; this does not mean the integration failed.
In **PiPing > Settings**, **Notify me** offers three native, locally persisted
choices:

- **Every completion**
- **After 15 seconds**
- **After 30 seconds** (default)

The preference changes only the native Mac lifecycle gate. It does not expand
the two-token Pi protocol or add prompt, response, project, or session data to
notifications.

## Pi hook installation

From the repository root, an isolated read-only exercise can load the tracked
hook for one run without altering Pi's saved configuration:

```bash
pi --extension Integration/Pi/piping.ts --no-session --tools read,grep,find,ls
```

For normal use, install the local repository through Pi's official user-package
mechanism:

```bash
pi install .
pi list
```

This adds the PiPing package to Pi's user settings, making it global to newly
started Pi sessions without replacing other extensions. In an existing Pi
session, use `/reload` after installation. To limit the package to the current
trusted project instead, use `pi install -l .`; project-local and global package
scope follow Pi's normal precedence rules.

Remove the matching entry reversibly from the repository root with `pi remove .`
for user scope or `pi remove -l .` for project scope.

Installing the Pi package installs only the TypeScript lifecycle edge; it does
not install the native Mac application. The app and bundled helper must already
exist at these canonical paths:

- `/Applications/PiPing.app`
- `/Applications/PiPing.app/Contents/Helpers/PiPingSignal`

The extension deliberately fails quiet if that helper is unavailable. It never
falls back to a repository, DerivedData, `dist`, or backup executable. The
package remains marked `private` to prevent accidental npm publication. The
repository is MIT-licensed and the planned `0.1.0` release is distributed from
GitHub as source rather than through npm.
