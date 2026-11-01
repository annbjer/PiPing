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

## Current local evidence (updated 2026-10-31; not release clearance)

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
byte-identical to `bd531628`. This is not new iPhone/Watch acceptance. The
historical test-only discarded throwing Task diagnostic remains in that run's
evidence. Independent review classified it as informational, not a product
vulnerability; a subsequent focused fixture pass retains/awaits the task.

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

The subsequent `c4212af` artwork/README revision and `d5bd76a` privacy/release
documentation corrections left product, configuration, test and script bytes
unchanged. Daybreak independently reviewed all 111 files of the `d5bd76a` source
packet, reconstructed tree `81ecea6ef2337bbb9ead2d4c454b10cd083a2fbd`, and verified
archive SHA-256 `f249f860086fe5d64ea192a5e0f6df855e91d6751e93d10b053b7e3f000b5aae`.
It identified installer validation defects and release/evidence gaps; it did not
approve publication or execute tests.

Replacement commit `77b22030ea6adc265901ed81408b366ca7cc917c`, tree
`29587f0c529651c2610c74f198ae98f6849e998e`, source archive SHA-256
`1833ba509fdd195c1e03ca2dcd312488d1ad0a89007a9fd2df10f9c739993162`, passed the
full exact extracted-source verifier: 63 Swift test functions, 26 Node tests
including 26-method Python fixtures, public-safe macOS/iOS Release and iOS
cross-builds. Its Mac-only ad-hoc build 18 and 11 native artifact/unsafe-derivative
cases passed without installation, preserving 18 existing app trees, the running
canonical process and 27 prior registrations with zero new relevant registrations.
Daybreak independently verified all 118 source files and the supplied commit/tree
link, and accepted the original three code repairs within static scope. It found
two new Low omissions (BSD flags/profile CloudKit authorization), not release
clearance. The next repaired installable build is 19; new exact-source evidence
must remain pinned separately. See
[review disposition](SECURITY_REVIEW_20261011.md) for finding statuses, accepted
source-only risk dispositions and remaining acceptance/publication gates.

On 2026-10-15, exact commit `aadb769cd98c9df1967e8879df0e0e3a718ca8d6`,
tree `cb21a63de05b94e25a0845cc991b99b2e28e0e54`, source archive SHA-256
`2b60faf10021d792bf58323089e5785f8742d357d48acd8d1e5c8fcdb3558a57`, passed the
exact extracted-source verifier: 63 Swift test functions, 26 Node tests including
37 Python fixture methods, public-safe macOS/iOS Release and iOS cross-builds.
The separately bounded existing-profile signed-artifact compatibility and 15
native/unsafe artifact cases passed without installation, launch or live CloudKit.

On 2026-10-31, a fresh Mac-only ad-hoc build 20 from the same exact source archive
passed production artifact validation. Its private app ZIP SHA-256 was
`1df5065b743a0e5ad8eb763f652b638605c5ec19db959e4de1e8c3ae4b67a38d`.
The restored offline SettleBell VM then passed one single-use transaction batch
under non-root Lab Administrator: install, real canonical checks, same-build
update, one controlled promotion-TERM rollback restoring the original canonical
directory identity, guarded uninstall and retained recovery archive validation.
Terminal exit was 0; the persisted guest PASS.json SHA-256 was
`4a6a4a7d14d8a74545af4904e346b3cfe5f1947c708015586e954f9d82b4b436`.
The expected missing-full-Xcode status failure was checked separately; full
status success and standard-account installation remain unverified. This is one
rollback checkpoint, not a broad interruption matrix. No new notification,
Pi integration, mobile/Watch, private legacy signed-app transition or live
CloudKit acceptance is claimed. Prior build 17 evidence, the host installed app,
Pi settings and frozen tracked source were preserved. Keep test apps private.

The local tracked-source/archive/reachable-history audit was refreshed for
`aadb769`; its heuristic findings were classified and no private credential or
configuration hit remained. This is not independent review clearance. Final
documentation reconciliation, exact-candidate independent follow-up, hosted CI
and separately approved repository/publication actions remain open.

Prior functional tests remain scoped to their pinned revisions. Product/script
repairs require affected checks and a new exact-source verifier, audited archive,
independent follow-up and exact-commit hosted CI; the old guest PASS is not
acceptance of new validators. Remote configuration and candidate push still
require separate approval. None of this evidence authorizes binary publication
or use of a local ad-hoc app as a release asset.

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
7. Run a fresh read-only Daybreak Blue security/privacy review against
   the exact candidate commit and archive. Resolve every finding at every
   severity and repeat affected checks. The owner approved using the currently
   available Daybreak Blue model for the October 31 independent follow-up;
   record its exact model and reviewed commit in the separate review receipt.
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
