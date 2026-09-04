# Setup and verification

## Safe local verification

Requirements:

- macOS 26 or later
- the latest stable full Xcode 26 or later at `/Applications/Xcode.app`
- Swift tools 6.2 or later, supplied by Xcode
- Node provided by the existing Pi installation for hook tests

Run:

```bash
./script/verify.sh
```

Read-only status:

```bash
./script/status.sh
```

The script uses repository-relative paths, the supported stable Xcode
application, ignored build directories, synthetic tests, and unsigned outputs. It does not launch either
app, request permission, contact CloudKit, or send a notification.

The repository verifier performs unsigned public-safe macOS and iOS Release
builds and separately cross-compiles the iOS Swift package branch against the
installed Simulator SDK. It does not require a running Simulator. Interactive
Simulator validation additionally requires the matching Xcode platform runtime;
runtimes are installed separately and are not managed by repository scripts.

## Public-safe and private-local configuration

Tracked configuration contains only public-safe placeholders and defaults
CloudKit activation to off. Ordinary verification and source-local builds never
read ignored private configuration. The dedicated signed-local builder alone
passes an ignored `Config/Local.xcconfig`, created from
`Config/Local.xcconfig.example` only after the signing and device-test gate.
Never commit or print its values.

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
app. There is no watchOS app: Apple normally routes the iPhone notification to
its paired Apple Watch. A real Pi completion produced the Mac notification, the
CloudKit-backed iPhone notification, and normal Apple Watch mirroring. Notification routing,
previews, sounds, and optional Siri Announce Notifications remain controlled by
Apple system settings.

## Mac-only source build and local installation

This path provides local Mac notifications without an Apple Developer account,
signing identity, CloudKit container, iPhone app, or Watch app. It requires full
stable Xcode at `/Applications/Xcode.app`; Command Line Tools alone cannot
compile the official Icon Composer source.

From a trusted source checkout, first run the normal verifier. Then build a
public-safe Release app, apply local ad-hoc hardened-runtime signatures, perform
the read-only preflight, and explicitly approve installation:

```bash
./script/verify.sh
./script/build_source_local.sh
./script/install_source_local.sh --check
./script/install_source_local.sh --install
```

The generated `dist/source-local/SettleBell.app.zip` uses only:

- bundle identifier `org.example.SettleBell.macOS`;
- display name **SettleBell Development**;
- public placeholder container text with CloudKit activation disabled;
- no provisioning profile, Apple team, or capability entitlement; and
- ad-hoc app/helper signatures with hardened runtime.

The guarded installer validates the archive before making changes, refuses to
replace anything except an earlier source-local development build, retains at
most three compressed update rollbacks, replaces only `/Applications/SettleBell.app`, and
verifies one app process and one LaunchServices path. It never invokes `sudo`,
changes Apple accounts, accesses signing credentials, installs Pi, or enables
notification permission. Grant notification permission in SettleBell when macOS
asks, then install the Pi edge separately as described below.

Generated app archives are ignored local artifacts, not public release files.
Ad-hoc installation is intended for source-building developers; it is not a
substitute for a future Developer ID-signed and notarized downloadable app.

### Source-local uninstall

Inspect the exact removal plan, then explicitly uninstall:

```bash
./script/uninstall_source_local.sh --check
./script/uninstall_source_local.sh --uninstall
```

The uninstaller refuses private, foreign, or future official builds; retains at
most three compressed recovery copies; removes the canonical source-local app; removes the
protected runtime only when its ownership, permissions, and contents are exact;
and removes a matching local-checkout Pi package when safely detected. A Git or
other remote Pi package must be removed using its exact original source with
`pi remove`. The script removes only the public development app's preferences;
macOS notification authorization and history remain Apple-managed.

To restore a chosen validated rollback or recovery archive, use the same guarded
installer rather than extracting an app into a discoverable directory:

```bash
rollback=.build/source-uninstall-backups/SettleBell-removed-TIMESTAMP.app.zip
./script/install_source_local.sh --check "$rollback"
./script/install_source_local.sh --install "$rollback"
```

For an update rollback, select the corresponding archive under
`.build/source-install-backups/`. Inspect the timestamp and run `--check` before
the separately approved `--install`; do not keep extracted backup apps.

Before postchecks commit an update, normal errors and HUP, INT, or TERM signals
restore the atomically quarantined prior app. Restoration intent and prior-app
identity are pinned before quarantine; candidate-removal intent is established
before promotion; and the two installer rollback flags commit in one shell
state transition after postchecks. Recovery roots are current-user-owned,
ACL-free mode-`0700` real directories; existing matching archives are validated
before destructive work and again before bounded pruning. A process captured by
uninstall is matched by PID, canonical command path, and start identity again
immediately before it is signalled. During uninstall, the final pinned
identity check and uninstall commit occur before preferences or the quarantined
app are deleted, so rollback never restores an app after deleting its settings.
After commit, cleanup is best effort. A power loss, SIGKILL, or
equivalent uncatchable interruption can leave a hidden
`/Applications/.SettleBell-source-transaction.*`, `.SettleBell-source-uninstall.*`,
`.SettleBell-signed-transaction.*`, or `.SettleBell-piping-retirement.*`
directory. Known legacy PiPing transaction residue also blocks migration.
Subsequent guarded commands refuse to continue. Do not delete or launch anything
inside residue: validate the moved payload and compressed recovery archive,
confirm the relevant canonical path, and obtain explicit approval for recovery.
This exceptional path should be handled by a knowledgeable reviewer rather than
an improvised `rm`.

## Migrating from PiPing

SettleBell uses a new app path, helper, runtime directory, bundle identity,
notification identity, and preference domain. Its installers never overwrite or
remove PiPing. Follow [Migrating from PiPing](MIGRATING_FROM_PIPING.md) to install
and test SettleBell side by side before separately retiring an exact legacy
source-local PiPing app. Signed/private PiPing retirement is deliberately not
performed by the source-local migration script.

The migration does not copy notification authorization, Cloud delivery
approval, threshold preferences, unread/backlog state, or private configuration.
The deployed CloudKit v1 identifiers remain unchanged initially as an explicit
compatibility boundary rather than a branding claim.

## Signed local Mac build and installation

PiPing `v0.1.0` was source-only, and SettleBell `0.2.0` is currently unreleased.
Each developer creates their own ignored `Config/Local.xcconfig`, signing
identity, bundle identifiers, and CloudKit container. Never reuse or publish
another developer's values.

After replacing every placeholder in the ignored local configuration, increment
`CURRENT_PROJECT_VERSION` for a new installable build and run:

```bash
./script/build_signed_local.sh
```

This performs a Release build with automatic Apple Development signing, embeds
and signs `SettleBellSignal`, verifies the complete bundle, writes the ignored
local-only archive `dist/private/SettleBell.app.zip`, and removes the extracted
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
anything. It also refuses to replace a source-local, foreign, or future official
canonical app. It binds the app, helper, hardened runtime, entitlements, and
unexpired provisioning profile to the exact ignored local team, bundle, and
container configuration; atomically quarantines and revalidates an accepted
prior signed-local app under a non-`.app` payload name; creates an atomic,
validated rollback capped at three archives; replaces only
`/Applications/SettleBell.app`; launches it; and runs the canonical installation
check. If post-install validation fails before commit, it restores the pinned
previous canonical app.
After a successful first install, grant notification permission and optionally
enable SettleBell under **System Settings > General > Login Items > Open at Login**.

### macOS icon appearance

macOS controls app-icon appearance separately from window appearance. Choosing
Dark windows alone does not require icons to use their Dark rendition. If the
SettleBell Dock or notification icon remains light, open **System Settings >
Appearance**, set **Icon & widget style** to **Dark**, and choose **Auto** rather
than **Always** for that style. Choose **Auto** in the main **Appearance** row as
well if you want macOS to change the complete interface automatically. The
similarly named automatic folder-color option affects Finder folders only.

This distinction can matter for accessibility and for anyone who relies on
consistent visual cues. SettleBell includes native Light and Dark icon renditions
but intentionally does not inspect or change the user's Appearance, icon,
widget, Liquid Glass, tint, or folder-color preferences.

## Notification threshold

SettleBell defaults to notifying only after a Pi run lasts at least 30 seconds. A
fast response is intentionally quiet; this does not mean the integration failed.
In **SettleBell > Settings**, **Notify me** offers three native, locally persisted
choices:

- **Every completion**
- **After 15 seconds**
- **After 30 seconds** (default)

The preference changes only the native Mac lifecycle gate. It does not add
prompt, response, project, terminal, or Pi session data to notifications. The
local protocol adds only an extension-generated ephemeral UUID to its fixed
signal so overlapping Pi processes can be timed independently.

## Pi hook installation

From the repository root, an isolated read-only exercise can load the tracked
hook for one run without altering Pi's saved configuration:

```bash
pi --extension Integration/Pi/settlebell.ts --no-session --tools read,grep,find,ls
```

For normal use, install the local repository through Pi's official user-package
mechanism:

```bash
pi install .
pi list
```

This adds the SettleBell package to Pi's user settings, making it global to newly
started Pi sessions without replacing other extensions. The Pi peer dependency
is metadata-only and optional, so package installation does not materialize a
second Pi runtime or its transitive dependencies. The package-local npm policy
also prevents Pi-managed Git clones from generating an untracked
`package-lock.json`. Each loaded instance
has an independent random correlation UUID, so concurrently running Pi
processes do not overwrite each other's timers. In an existing Pi session, use
`/reload` after installation. To limit the package to the current
trusted project instead, use `pi install -l .`; project-local and global package
scope follow Pi's normal precedence rules.

Remove the matching entry reversibly from the repository root with `pi remove .`
for user scope or `pi remove -l .` for project scope.

Installing the Pi package installs only the TypeScript lifecycle edge; it does
not install the native Mac application. The app and bundled helper must already
exist at these canonical paths:

- `/Applications/SettleBell.app`
- `/Applications/SettleBell.app/Contents/Helpers/SettleBellSignal`

If the canonical helper is unavailable, the extension reports a generic
availability error in Pi without exposing task content. It never falls back to a
repository, DerivedData, `dist`, or backup executable. The
package remains marked `private` to prevent accidental npm publication. The
repository is MIT-licensed. PiPing `v0.1.0` remains available as historical
source; SettleBell `0.2.0` is planned as a separately audited source release and
is not published through npm.

Pi `0.84.3` and `0.84.4` have passed package-load and ordinary-turn acceptance.
Other Pi versions are not claimed compatible until the lifecycle hooks and idle
semantics are retested.
