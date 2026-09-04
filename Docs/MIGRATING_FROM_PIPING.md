# Migrating from PiPing

SettleBell succeeds PiPing without rewriting or replacing PiPing in place. The
PiPing `v0.1.0` tag, source archive, release notes, links, and announcement are
historical provenance and remain immutable.

Migration is intentionally side by side:

| Identity surface | PiPing `v0.1.0` | SettleBell |
| --- | --- | --- |
| Mac app | `/Applications/PiPing.app` | `/Applications/SettleBell.app` |
| Bundled helper | `PiPingSignal` | `SettleBellSignal` |
| Local runtime | `$HOME/.piping/events.fifo` | `$HOME/.settlebell/events.fifo` |
| Notification permission | PiPing bundle identity | Fresh SettleBell bundle identity |
| Local preferences and unread state | PiPing identity | Fresh SettleBell identity |

No script copies notification authorization, Cloud delivery approval, threshold
preferences, unread state, backlog state, or private configuration between the
two identities. Apple permission dialogs remain user-controlled.

## Preserved compatibility boundary

The initial SettleBell migration deliberately retains these three deployed
CloudKit v1 wire/storage identifiers:

- record type `PiPingAttention`;
- rolling record name `piping.attention.current`; and
- subscription ID `piping.attention.v1`.

They are internal compatibility identifiers, not user-visible branding. Keeping
them avoids an implicit CloudKit reset, duplicate delivery path, or schema
migration. Changing them requires a separate migration design and approval.

The canonical Icon Composer source also remains at
`Assets/Brand/AppIcon/PiPing.icon` with unchanged bytes. The historical filename
is intentional; it is still the sole official icon source.

## Source-local migration

The following procedure applies only when the old PiPing app is the exact
public-development, ad-hoc source-local build. Each mutating step requires its
own explicit approval.

1. From a trusted, pinned SettleBell revision, run the verifier and build the new
   source-local archive:

   ```bash
   ./script/verify.sh
   ./script/build_source_local.sh
   ```

2. Preflight and install SettleBell at its new canonical path:

   ```bash
   ./script/install_source_local.sh --check
   ./script/install_source_local.sh --install
   ```

   This does not modify `/Applications/PiPing.app` or `$HOME/.piping`.

3. Approve SettleBell notifications manually. Install or reload the SettleBell
   Pi package only after separate approval, then complete one ordinary eligible
   Pi run. With the default setting, the run must last at least 30 seconds.
   Confirm that the SettleBell notification was presented and acknowledge it.

4. Inspect the legacy retirement plan:

   ```bash
   ./script/retire_legacy_piping_source_local.sh --check
   ```

   The preflight requires one validated, running source-local SettleBell app and
   the exact audited PiPing `v0.1.0` public-development app. It refuses signed,
   foreign, modified, or future official PiPing apps.

5. Only after the genuine notification check and separate retirement approval:

   ```bash
   ./script/retire_legacy_piping_source_local.sh \
     --retire --confirmed-settlebell-notification
   ```

   Retirement atomically quarantines and revalidates PiPing, creates a validated
   compressed recovery archive, retains at most three such archives, unregisters
   only the legacy app, and removes the old runtime only if its owner, mode,
   type, ACL, and contents are exact. It leaves PiPing preferences and
   Apple-managed notification authorization/history intact for rollback.

The retirement script does not inspect or alter Pi package settings. If PiPing
was installed from a Git URL, tag, npm package, or another source, inspect Pi's
saved package list and remove only that exact old source with `pi remove` after
separate approval. Installing the SettleBell package never authorizes removal of
a PiPing package.

## Signed-local PiPing installations

`retire_legacy_piping_source_local.sh` intentionally rejects Apple
Development-signed and private-CloudKit PiPing apps. Do not bypass its validator,
extract a replacement over the old app, or delete the old identity manually.
Leave signed PiPing installed but inactive until a separately reviewed signed
retirement procedure can validate its exact private identity without exposing
account-specific values.

A SettleBell signed-local build must use its own explicitly approved bundle
identities and request fresh notification and Cloud delivery approval. It may
use the preserved CloudKit v1 identifiers above, but that does not transfer any
bundle-keyed permission or local preference.

## Rollback

Before PiPing retirement, rollback is simple: remove only SettleBell with its
matching guarded uninstaller, restore the exact old Pi package source if it was
removed, and reopen the untouched PiPing app.

After source-local PiPing retirement, use the reported compressed recovery
archive only with the guarded installer from the trusted PiPing `v0.1.0` source.
Run its `--check` mode before a separately approved install. Do not extract the
archive into `/Applications` manually and do not keep a discoverable extracted
backup app.

A power loss or `SIGKILL` can leave a hidden transaction directory. Every
PiPing/SettleBell guarded migration command detects known transaction residue
and stops. Preserve the residue for manual validation and recovery; never apply
a broad `git clean` or improvised recursive deletion.
