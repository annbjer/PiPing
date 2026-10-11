# Release process

## SettleBell 0.2.0 policy

PiPing `v0.1.0`, its tag, source assets, release notes, links, and announcement
are immutable historical provenance. Never retag, replace, or regenerate that
release under the SettleBell name.

SettleBell's first developer preview, `0.2.0`, is source-only
unless a later exact-binary gate is separately approved. Do not attach, upload,
or otherwise distribute a SettleBell application bundle, IPA, provisioning
profile, development archive, or locally generated `dist/` artifact.

The currently installed private development apps and generated source-local
ad-hoc apps are not release artifacts. `dist/source-local/` exists only for a
source builder's guarded local installation and must not be uploaded. A future
downloadable Mac binary requires separately approved permanent identities,
Developer ID Application signing, hardened runtime, notarization, stapling,
final entitlement inspection, and an exact binary-archive audit.

## Versioning

SettleBell uses semantic versioning for source releases and annotated Git tags in
the form `vMAJOR.MINOR.PATCH`.

- `MARKETING_VERSION` and `package.json` must match the release version.
- `CURRENT_PROJECT_VERSION` increases for every installable app build; it is not
  reset for a source tag.
- Release notes identify whether the release is source-only or includes audited
  binaries.

## Current local evidence (updated 2026-10-11; not release clearance)

The clean `bd531628` source snapshot passed `./script/verify.sh` and produced a
validated Mac-only source-local 0.2.0 (17) archive on the development Mac. A
matching archive and exact-commit source copy were transferred privately to a
separate test Mac; its guarded native installation and Pi package installation
passed. The owner reported a real notification on macOS 27.0 with Pi 0.87.1 after trying the
proposed 35-second test prompt; independent elapsed-time measurement was not
recorded. This does **not** replace clean-VM, pinned package,
iPhone/Watch, history/privacy audit, independent security review, or exact
candidate/CI gates below. No remote, main branch, push, tag, or public release
was created from this local candidate. Keep generated archives private.

On 2026-10-06, the exact committed `8cbca6019a0cea99aff4ff8115d11a0a6d93bf41`
source archive passed 56 Swift tests, 24 hook tests, public-safe macOS/iOS Release
builds, and the iOS cross-build under Xcode 27.0 on macOS 27.0.1. All 109 source
files matched Git bytes, types, and executable modes. Existing app trees,
canonical process, and prior registrations were preserved. The owner also
confirmed a Mac notification after a measured 35-second tool wait in an
ordinary Pi 1.0.4 turn with the existing private 0.2.0 (17) app and a hook
byte-identical to `bd531628`. This is not new iPhone/Watch acceptance. A test-only
discarded throwing Task compiler diagnostic remains recorded; no product
failure was identified, and independent review of that diagnostic is pending.

On 2026-10-11, an owner-relayed desktop-control test report recorded a successful
install, genuine canonical installation check, and guarded uninstall of the
Mac-only app derived from that exact source archive. The guest ran macOS 26.6.2
with Command Line Tools 26.6, using an existing administrator account as a
non-root user. This does not establish standard-account installation success.
The expected missing-full-Xcode status failure was checked; full status-success
acceptance was not performed. Guest evidence and the compressed recovery archive
were retained. A private test-harness route-detection correction was required;
product source and app archive checksums remained unchanged. This was not a new
notification, Pi integration, mobile, or migration test campaign.

The subsequent `c4212af` revision changes only README artwork and references;
these documentation corrections also leave product, configuration, test, and
script bytes unchanged. Prior tests remain scoped to the revisions above, not
an assertion that a later exact archive's full verifier or independent review
has run. Next: freeze the reconciled candidate, audit its exact source archive,
reconcile required affected checks with the retained evidence, and complete the
independent-review and exact-candidate CI gates. Remote configuration and
candidate push still require separate approval. None of this evidence authorizes
binary publication or use of a local ad-hoc app as a release asset.

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
   intended remote, then require hosted CI to pass for the same commit. Any fix
   restarts the reconciliation, commit, archive, audit, review, and CI cycle.
9. Reverify repository security controls, including private vulnerability
   reporting, against the intended public repository before tagging.
10. Obtain an independent explicit owner approval for each repository rename,
    tag, release-asset upload, GitHub release, public announcement/publication,
    package publication, package-gallery listing, domain/DNS change, and App
    Store action. Approval for one action never authorizes another.

## Canonical source archive

Before requesting tag approval, create and audit the release archive from the
exact candidate commit rather than the working tree:

```bash
version=0.2.0
candidate_commit="$(git rev-parse HEAD)"
git archive \
  --format=tar.gz \
  --prefix="SettleBell-${version}/" \
  --output="SettleBell-${version}-source.tar.gz" \
  "$candidate_commit"
shasum -a 256 "SettleBell-${version}-source.tar.gz" \
  > "SettleBell-${version}-source.tar.gz.sha256"
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
  --prefix="SettleBell-${version}/" \
  --output="SettleBell-${version}-source.from-tag.tar.gz" \
  "$tag_commit"
cmp "SettleBell-${version}-source.tar.gz" \
  "SettleBell-${version}-source.from-tag.tar.gz"
rm "SettleBell-${version}-source.from-tag.tar.gz"
```

Publish the audited source archive, checksum, release notes, and no application
binary for version `0.2.0` only after its independent publication approvals.

## Publication safety

- Push only the reviewed branch; never use `git push --mirror`.
- Never use `git add -f` to bypass private/generated-file exclusions.
- Never publish an existing `.build/`, `dist/`, Xcode archive, or backup.
- Never publish Apple Development-signed software as an official binary.
- Never include private configuration values in logs or release notes.
- Never rewrite PiPing `v0.1.0` or remove its historical provenance.
- Keep package identity, repository rename, domains/DNS, App Store records,
  promotion, and binary distribution as separate approval gates.
- If any credential entered Git history, rotate it before repairing history.
