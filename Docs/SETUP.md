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

The repository verifier compiles the iOS sources against the installed SDK and
does not require a running Simulator. Simulator validation additionally
requires the matching Xcode platform runtime. The iOS 26.5 runtime used for the
current development verification is installed separately and is not managed by
repository scripts.

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
4. confirm APNs registration; and
5. install the fixed private-database subscription if needed.

The verified private development setup has a signed Mac app and signed iPhone
app. A real Pi completion produced the Mac notification, the CloudKit-backed
iPhone notification, and normal Apple Watch mirroring. Notification routing,
previews, sounds, and optional Siri Announce Notifications remain controlled by
Apple system settings.

## Explicit per-session Pi hook

The tracked hook has been verified by loading it by path for one Pi run. It is
not installed globally and does not alter Pi configuration. From the repository
root, an isolated read-only exercise can use:

```bash
pi --extension Integration/Pi/piping.ts --no-session --tools read,grep,find,ls
```

The bundled native helper must already exist at the path expected by the hook.
Do not use `pi install` or edit global Pi settings without a separate approval.
The package remains `private` and unlicensed to prevent accidental publication.
