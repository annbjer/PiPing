# Pre-publication release-surface audit

A candidate push, repository rename, tag, release-asset upload, GitHub release,
public announcement/publication, package publication, gallery listing,
domain/DNS change, or App Store action is prohibited until this checklist is
complete for the exact candidate revision and the owner separately approves
that specific action.

## Required surfaces

- tracked files and submodules;
- untracked and ignored files;
- hidden tooling metadata;
- every reachable object in full Git history;
- generated archives and release bundles; and
- the exact extracted `git archive` payload.

## Required searches

Search for personal names, email addresses, absolute home paths, device IDs and
UDIDs, unnecessary Apple Team IDs, private CloudKit identifiers, tokens,
credentials, `.p8`, provisioning profiles, local xcconfig files, `.env*`,
`.xcuserdata`, DerivedData, result bundles, logs, and editor/agent metadata.

Required license attribution and explicitly approved public project/developer
identity are not private configuration. Record each intentional exception; do
not silently exempt unrelated personal data. Inspect visible screenshot content
and embedded EXIF/XMP/ICC metadata too. Keep only vetted color-rendering metadata
needed to preserve appearance, not display identifiers or calibration metadata.

Use generic defaults with CloudKit off. Audit the exact source archive and any
package payload with private local configuration absent. A successful private
installation is not proof that a generic user's source build is ready. Never
copy private development binaries into a public package or release.

Inspect at minimum:

```bash
git status --short --ignored
git ls-files
git ls-files --others --exclude-standard
git log --all --stat --oneline
git rev-list --objects --all
```

Create the candidate archive in a temporary directory, list it, extract it, and
scan the extracted bytes—not merely the working tree.

If a credential ever entered history, rotate it first and then clean or restart
history. Deleting the current file or adding it to `.gitignore` is insufficient.

Treat `dist/source-local/`, source-install rollback archives, uninstall
recovery archives, and PiPing-retirement archives as generated local artifacts;
validate them for local testing but never include them in a source-only release
attachment allowlist.

For the SettleBell migration, additionally:

- verify the candidate descends from exact PiPing `v0.1.0` commit `14b0262` and
  does not move or rewrite that tag;
- inventory every remaining `PiPing`, `PIPING`, and `piping` token and require it
  to be historical provenance, an exact legacy validator/migration guard, the
  unchanged canonical Icon Composer path, or one of the three approved CloudKit
  v1 compatibility identifiers;
- verify `Assets/Brand/AppIcon/PiPing.icon` is still the only `.icon` source and
  is byte-identical to `v0.1.0`;
- verify the four historical communication WebPs are byte-identical to
  `v0.1.0`, retain their PiPing filenames, and are not misrepresented as new
  SettleBell artwork; and
- prove source-local SettleBell and PiPing paths can coexist, migrate, and roll
  back under interruption without copying identity-keyed consent or state.

Publication additionally requires a clean Daybreak scan, an approved
open-source license, verified private vulnerability reporting, and independent
explicit approval for candidate push, repository rename, tag, release assets,
GitHub release, public announcement/publication, package publication, gallery
listing, domain/DNS change, App Store action, and binary distribution as
separate gates.
