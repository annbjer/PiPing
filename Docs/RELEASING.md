# Release process

## Version 0.1.0 policy

The first public release is source-only. Do not attach, upload, or otherwise
distribute a PiPing application bundle, IPA, provisioning profile, development
archive, or locally generated `dist/` artifact.

The currently installed private development app and generated source-local
ad-hoc app are not release artifacts. `dist/source-local/` exists only for a
source builder's guarded local installation and must not be uploaded. A future
downloadable Mac binary requires a separately approved public bundle
identity, Developer ID Application signing, hardened runtime, notarization,
stapling, final entitlement inspection, and an exact binary-archive audit.

## Versioning

PiPing uses semantic versioning for source releases and annotated Git tags in
the form `vMAJOR.MINOR.PATCH`.

- `MARKETING_VERSION` and `package.json` must match the release version.
- `CURRENT_PROJECT_VERSION` increases for every installable app build; it is not
  reset for a source tag.
- Release notes identify whether the release is source-only or includes audited
  binaries.

## Required release sequence

1. Complete the required Mac, iPhone/Watch, clean-VM, and pinned Pi-package
   acceptance against the current private checkpoint.
2. Reconcile `README.md`, `CHANGELOG.md`, `SECURITY.md`, `CONTRIBUTING.md`,
   setup, agent-installation, architecture, privacy, threat-model, and
   release-readiness documentation with that evidence.
3. Commit only the reconciled candidate files, require a clean working tree,
   and record the exact commit and tree.
4. Run `./script/verify.sh`, then build and test from an exact `git archive`
   extraction with no ignored local files available. Install or update the clean
   VM only from the resulting exact archive-derived local app and repeat its
   required postchecks.
5. Complete `Docs/RELEASE_AUDIT.md` against tracked files, reachable history,
   the source archive, and every generated release file.
6. Confirm the intended Git author and committer identities, remove local
   agent/checkpoint refs that are not release history, and inspect the exact
   private branch and ref list.
7. Run a fresh read-only GPT 5.6 Daybreak Blue security/privacy review against
   the exact candidate commit and archive. Resolve every finding at every
   severity and repeat affected checks.
8. Obtain separate explicit approval to push only that exact candidate to the
   private remote, then require hosted CI to pass for the same commit. Any fix
   restarts the reconciliation, commit, archive, audit, review, and CI cycle.
9. Obtain separate explicit owner approval before changing repository
   visibility. Immediately after the approved public visibility change, enable
   and exercise GitHub private vulnerability reporting as described in
   `SECURITY.md`; do not tag, announce, release, or list the package first.
10. Obtain an independent explicit owner approval for each tag,
    release-asset upload, GitHub release, public announcement/publication, and
    package-gallery listing. Approval for one action never authorizes another.

## Canonical source archive

Before requesting tag approval, create and audit the release archive from the
exact candidate commit rather than the working tree:

```bash
version=0.1.0
candidate_commit="$(git rev-parse HEAD)"
git archive \
  --format=tar.gz \
  --prefix="PiPing-${version}/" \
  --output="PiPing-${version}-source.tar.gz" \
  "$candidate_commit"
shasum -a 256 "PiPing-${version}-source.tar.gz" \
  > "PiPing-${version}-source.tar.gz.sha256"
```

Extract that archive into a temporary directory, rerun the supported verifier,
and scan the extracted bytes before any tag exists. After a separately approved
annotated tag is created, verify that it peels to the audited commit and that a
fresh archive resolved through the tag is byte-identical:

```bash
tag_commit="$(git rev-parse "v${version}^{}")"
test "$tag_commit" = "$candidate_commit"
git archive \
  --format=tar.gz \
  --prefix="PiPing-${version}/" \
  --output="PiPing-${version}-source.from-tag.tar.gz" \
  "$tag_commit"
cmp "PiPing-${version}-source.tar.gz" \
  "PiPing-${version}-source.from-tag.tar.gz"
rm "PiPing-${version}-source.from-tag.tar.gz"
```

Publish the audited source archive, checksum, release notes, and no application
binary for version 0.1.0.

## Publication safety

- Push only the reviewed branch; never use `git push --mirror`.
- Never use `git add -f` to bypass private/generated-file exclusions.
- Never publish an existing `.build/`, `dist/`, Xcode archive, or backup.
- Never publish Apple Development-signed software as an official binary.
- Never include private configuration values in logs or release notes.
- If any credential entered Git history, rotate it before repairing history.
