# macOS notification icon repair

Date: 2026-08-28

## Finding

The official `Assets/Brand/AppIcon/PiPing.icon` and Xcode 26.6 output were valid.
A signed probe with a fresh bundle identifier used byte-for-byte copies of build
8's `Assets.car` and `PiPing.icns` and rendered the correct Light icon in a real
macOS notification. Dark appearance also rendered correctly.

The old private Mac identity continued to show the pale grid placeholder even
after clean builds, version increments, restarts, and a candidate whose compiled
icon asset had a different name. The failure was therefore persistent macOS
Notification Center/IconServices state keyed to the old bundle identifier, not
Swift, UserNotifications, signing, artwork contrast, plist keys, or zero-sized
asset-stack references.

Because PiPing was still a private development app, the Mac target was migrated
once to a clean final private identifier in ignored `Config/Local.xcconfig`.
The canonical app path, helper path, CloudKit container, iOS identity, official
Icon Composer source, and automatic Light/Dark selection were preserved.

## Reliability rules

- Keep exactly one production app at `/Applications/PiPing.app`.
- The Pi extension invokes only
  `/Applications/PiPing.app/Contents/Helpers/PiPingSignal`.
- Do not launch production helpers from DerivedData, `dist`, backups, or a
  worktree.
- Keep rollback applications compressed. Merely changing an extracted app
  directory's suffix does not stop LaunchServices from recognizing its internal
  bundle structure.
- Give unsigned local builds the distinct display name **PiPing Development**.
- Increment `CURRENT_PROJECT_VERSION` for every installed build.
- Run `script/check_installation.sh` after installing a signed build.
- Do not edit Notification Center or IconServices private databases. Historical
  System Settings rows can outlive an uninstalled development identity but do
  not represent running apps.

## Validation

The accepted build must pass all of the following:

1. deep/strict signature verification, including `PiPingSignal`;
2. one canonical process and one LaunchServices path;
3. a real threshold-qualified Light notification with the Pi mark;
4. automatic live update to the Dark icon in the banner and Notification Center;
5. iOS Light/Dark build and device regression checks;
6. the repository verifier and Pi hook tests.
