# Release process

## Version 0.1.0 policy

The first public release is source-only. Do not attach, upload, or otherwise
distribute a PiPing application bundle, IPA, provisioning profile, development
archive, or locally generated `dist/` artifact.

The currently installed private development app is not a release artifact. A
future downloadable Mac binary requires a separately approved public bundle
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

1. Start from a clean working tree and record the exact commit.
2. Reconcile `README.md`, `CHANGELOG.md`, `SECURITY.md`, `CONTRIBUTING.md`,
   setup, architecture, privacy, threat-model, and release-readiness
   documentation with the code.
3. Run `./script/verify.sh` locally.
4. Build and test from an exact `git archive` extraction with no ignored local
   files available.
5. Complete `Docs/RELEASE_AUDIT.md` against tracked files, reachable history,
   the source archive, and every generated release file.
6. Confirm the intended Git author and committer identities, remove local
   agent/checkpoint refs that are not release history, and inspect the exact
   public branch and ref list.
7. Run a fresh read-only GPT 5.6 Daybreak Blue security/privacy review against
   the exact candidate commit. Resolve every release-blocking finding and repeat
   affected checks.
8. Complete the recorded real-device Mac/iPhone/Watch regression checks.
9. Enable GitHub private vulnerability reporting and verify the process linked
   from `SECURITY.md` before making the repository public.
10. Obtain explicit owner approval before creating a remote, pushing, tagging,
    or publishing a GitHub release.

## Canonical source archive

After the approved commit is tagged, create the release archive from Git rather
than the working tree:

```bash
version=0.1.0
git archive \
  --format=tar.gz \
  --prefix="PiPing-${version}/" \
  --output="PiPing-${version}-source.tar.gz" \
  "v${version}"
shasum -a 256 "PiPing-${version}-source.tar.gz" \
  > "PiPing-${version}-source.tar.gz.sha256"
```

Extract that archive into a temporary directory, rerun the supported verifier,
and scan the extracted bytes. Publish the source archive, checksum, release
notes, and no application binary for version 0.1.0.

## Publication safety

- Push only the reviewed branch; never use `git push --mirror`.
- Never use `git add -f` to bypass private/generated-file exclusions.
- Never publish an existing `.build/`, `dist/`, Xcode archive, or backup.
- Never publish Apple Development-signed software as an official binary.
- Never include private configuration values in logs or release notes.
- If any credential entered Git history, rotate it before repairing history.
