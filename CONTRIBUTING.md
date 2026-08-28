# Contributing to PiPing

Thank you for helping improve PiPing.

## Before opening a change

PiPing Phase 1 is intentionally notification-only and content-free. Read
`SECURITY.md`, `Docs/PRIVACY.md`, `Docs/ARCHITECTURE.md`, and
`Docs/THREAT_MODEL.md` before changing a trust boundary.

Do not include real prompts, model output, source from unrelated projects,
credentials, signing identifiers, Apple Team IDs, CloudKit container IDs,
device identifiers, provisioning profiles, personal paths, or private local
configuration in issues, tests, commits, screenshots, or pull requests.

Report suspected vulnerabilities through the private process in `SECURITY.md`,
not through a public issue.

## Development requirements

The full verifier currently requires:

- macOS 26;
- stable Xcode 26 at `/Applications/Xcode.app`;
- Swift 6.2; and
- Node.js with type stripping support for the Pi hook tests.

Run from the repository root:

```bash
./script/verify.sh
```

This executes Swift tests, Pi hook tests, unsigned public-safe macOS and iOS
Release builds, and an iOS simulator cross-build. It must not launch an app,
contact CloudKit, or send a notification.

## Change rules

- Keep `Assets/Brand/AppIcon/PiPing.icon` as the sole official icon source.
- Keep the Pi protocol restricted to literal `start` and `settled` signals.
- Keep notification title and body fixed in source.
- Do not add a reply, approval, command, deep-link, or remote-control surface to
  Phase 1.
- Do not add private APIs or edit Apple service databases.
- Do not make the Pi extension inspect prompts, messages, files, tools, model
  data, paths, sessions, or results.
- Keep public defaults safe and CloudKit-disabled.
- Put account-specific values only in ignored `Config/Local.xcconfig`.
- Add focused tests for behavior changes and update documentation when an
  invariant, data flow, requirement, or user-visible behavior changes.

## Pull requests

Keep changes small and explain:

1. what changed;
2. why it is needed;
3. which privacy or security boundaries are affected; and
4. which verification commands passed.

Contributions are submitted under the repository's MIT License.
