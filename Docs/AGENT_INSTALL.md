# Agent-assisted local installation

PiPing can be installed with an agent's help, but the user remains in control.
This procedure is for the source-local Mac-only development build. It does not
enable CloudKit, install the iPhone app, configure an Apple account, or produce
a public distributable binary.

Manual installation and uninstall remain fully supported in `Docs/SETUP.md`.

## Non-negotiable boundaries

An installation agent must:

- use a trusted, pinned source commit or checksum-verified source archive;
- begin with read-only inspection and report every failed prerequisite;
- stop at each approval checkpoint below;
- invoke no silent `sudo` and never request an administrator password;
- access no Apple account, Keychain item, signing credential, provisioning
  profile, ignored `Config/Local.xcconfig`, provider credential, or unrelated
  user file;
- install only `/Applications/PiPing.app` and only after the guarded installer
  accepts the public development identity;
- install the Pi package only through Pi's official `pi install` command;
- never edit Notification Center databases, authorization records, Login Items,
  shell startup files, or unrelated Pi settings; and
- never push, tag, publish, change repository visibility, or upload a generated
  app archive as part of installation.

If the task includes building and full stable Xcode is absent at
`/Applications/Xcode.app/Contents/Developer`, stop and explain that Command Line
Tools cannot build the official Icon Composer source. Installing a separately
trusted, checksum-verified source-local or recovery archive does not itself
require Xcode. Do not install Xcode or change `xcode-select` without separate
explicit approval.

## Approval checkpoint 1: inspection

From the source root, inspect without changing the installation:

```bash
git status --short --branch        # when installing from Git
./script/status.sh
./script/verify.sh                 # only after approval to compile/test
```

Report the exact source commit or archive checksum, Pi version, Xcode presence,
whether `/Applications/PiPing.app` already exists, and whether the working tree
is clean. Do not print ignored local configuration values.

If the canonical app is a private, foreign, or future official build, do not
replace it with the source-local installer.

## Approval checkpoint 2: local build

After explicit approval to create ignored local build output, run:

```bash
./script/build_source_local.sh
```

Report the resulting version/build and whether validation confirmed the public
bundle identity, disabled CloudKit activation, no provisioning profile, no
entitlements, ad-hoc app/helper signatures, and hardened runtime. Do not upload
or publish `dist/source-local/PiPing.app.zip`.

## Approval checkpoint 3: installation preflight

Run the preflight before requesting installation approval:

```bash
./script/install_source_local.sh --check
```

The preflight may extract the archive into a temporary directory for validation
but makes no persistent installation change. Report whether the canonical path
is empty or contains an accepted earlier source-local build.

## Approval checkpoint 4: native installation

Only after explicit approval, run:

```bash
./script/install_source_local.sh --install
```

The guarded installer creates a compressed rollback for an accepted update,
replaces only the canonical app, registers and launches it, and performs the
post-install identity/process/path check. If it fails, stop and preserve the
reported evidence and rollback; do not improvise around its guards.

The user—not the agent—must respond to Apple's notification permission dialog.
The agent may explain how to open System Settings but must not automate approval.

## Approval checkpoint 5: Pi package

After the native app and helper are verified, explain that this changes Pi's
user package list. Only after explicit approval, run from the source root:

```bash
pi install .
pi list
```

Use `/reload` in an existing Pi session or start a new session. Keep the default
30-second threshold unless the user explicitly changes it. Test only with a
normal, content-independent lifecycle; do not collect prompts or responses.

## Guarded uninstall

First report the read-only removal plan:

```bash
./script/uninstall_source_local.sh --check
```

Only after explicit approval:

```bash
./script/uninstall_source_local.sh --uninstall
```

The script preserves a compressed recovery copy, refuses non-development apps,
and removes the runtime only when its ownership, permissions, and contents are
exact. It removes a matching local-checkout Pi package when safely detected. If
PiPing was installed from Git or another source, identify the exact saved source
and ask approval before using `pi remove` for that source.

Apple-managed notification authorization and history are intentionally left to
System Settings. Never edit Apple's private notification databases.

## Copyable install prompt

> Help me install PiPing's Mac-only source-local development build. Read
> `README.md`, `Docs/SETUP.md`, `Docs/AGENT_INSTALL.md`, `SECURITY.md`, and any
> repository agent instructions first. Use a trusted pinned commit or verified
> source checksum. Begin with inspection only and report the source identity,
> prerequisites, existing canonical app state, and exact plan. Do not use sudo,
> install Xcode, alter Apple accounts or credentials, inspect ignored private
> configuration values, change unrelated Pi settings, edit Apple notification
> databases, or install anything yet. Stop for my approval before verification
> builds, before native installation, and again before `pi install`. After each
> approval use only the documented guarded commands. Let me answer Apple's
> notification dialog manually, then run the documented identity, process,
> LaunchServices, package-isolation, and content-free lifecycle checks. Do not
> push, tag, publish, or upload generated app archives.

## Copyable uninstall prompt

> Help me uninstall only PiPing's source-local development build. Read
> `Docs/SETUP.md` and `Docs/AGENT_INSTALL.md`, then run
> `./script/uninstall_source_local.sh --check` only. Report the exact canonical
> app, process, runtime, package, preference, recovery, and Apple-managed state
> that would or would not change. Do not use sudo, stop unrelated processes,
> remove a private/foreign/official app, edit Apple notification databases, or
> make any change until I approve. After approval, use only
> `./script/uninstall_source_local.sh --uninstall` and verify that the app,
> helper, process, safe runtime, exact local package entry, and LaunchServices
> path are absent. Preserve and report the bounded compressed recovery archive.
