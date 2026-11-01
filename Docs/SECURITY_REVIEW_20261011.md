# Independent review and local repair disposition

## Current evidence: build 20, updated 2026-10-31

Commit `aadb769cd98c9df1967e8879df0e0e3a718ca8d6`, tree
`cb21a63de05b94e25a0845cc991b99b2e28e0e54`, source archive SHA-256
`2b60faf10021d792bf58323089e5785f8742d357d48acd8d1e5c8fcdb3558a57`,
passed the October 15 exact extracted-source verifier and separately bounded
existing-profile signed-artifact compatibility checks. Those checks did not
install or launch an app or contact CloudKit.

On October 31, a fresh Mac-only ad-hoc build 20 from that source passed production
artifact validation and one offline administrator-account VM transaction batch:
install, genuine canonical checks, same-build update, one controlled SIGTERM
after candidate promotion with original-directory identity restoration,
guarded uninstall and retained recovery archive validation. The persisted guest
PASS receipt SHA-256 is
`4a6a4a7d14d8a74545af4904e346b3cfe5f1947c708015586e954f9d82b4b436`.
The original build 17 evidence and host installed app were preserved.

These results advance the exact-source, artifact and affected source-local
transaction gates for the BSD-flag/profile/debugger-entitlement repairs. They
are local receipts, not independent execution or security clearance. One
promotion-TERM checkpoint does not establish a full interruption matrix, and
the expected missing-Xcode status failure is not full status success.
Standard-account installation, private legacy signed-app transition, live
CloudKit compatibility and new notification/Pi/mobile/Watch acceptance remain
unverified in this batch. Earlier sections and tables below retain historical
finding dispositions and the evidence available at those checkpoints.

The owner approved final evidence documentation, independent Daybreak Blue
review and candidate push/pull-request hosted CI on October 31. Record the
independent disposition and exact-commit CI result separately when completed;
this approval does not authorize merging, renaming the repository, tagging,
uploading release assets or publishing a release. Product code remains frozen.

## Historical signed compatibility correction: build 20 checkpoint

The approved Xcode 27 existing-only private build attempts for 41fb00c stopped
before producing an installable artifact; automatic provisioning updates were
disabled. Read-only inspection found a matching unexpired cached Mac profile,
valid existing signing certificate and correct Apple silicon Provisioning UDID.
Xcode's automatic selection did not resolve that material; explicit existing
profile selection is the next bounded diagnostic, not an established cure.

The real Mac profile's service ceiling is scalar `"*"`, unlike the array shape
assumed by the SB-NEW-02 repair. Accept Apple's wildcard ceiling (scalar or array
member) alongside explicit CloudKit arrays. Missing/malformed/CloudDocuments-only
ceilings still reject; configured team/app/container/certificate/expiry binding
and exact four-key actual app/empty helper rules remain unchanged. This is a
profile authorization-format correction, not permission to add app capabilities.

The retained development app has the four required fields plus debugger attach.
Do not weaken final validation for it. Before final Release signing, remove ONLY
Xcode's known boolean `com.apple.security.get-task-allow` entitlement and require
all remaining fields to match the exact dictionary; unknown keys or malformed
debug values reject. This does not edit the installed app. Its later update/
rollback handling requires explicit acceptance, not automatic grandfathering.

Owner-approved scope: bounded code/fixtures/docs/commit/build 20/exact-source
checks plus one existing-profile signing compatibility attempt, no installation,
launch, profile generation, account repair, CloudKit operation or publication.
No installable build 20 existed before this checkpoint. Preserve working build 17,
all previous artifacts/evidence and 41fb00c source-local acceptance. Subsequent
results belong to separately sealed exact commit/archive receipts; neither these
corrections nor new private artifact are independently reviewed/release-cleared.

## Historical follow-up: build 18 reviewed, two Low omissions repaired

Daniel relayed Daybreak's read-only follow-up of commit
`77b22030ea6adc265901ed81408b366ca7cc917c`, tree
`29587f0c529651c2610c74f198ae98f6849e998e`, source SHA-256
`1833ba509fdd195c1e03ca2dcd312488d1ad0a89007a9fd2df10f9c739993162`.
It verified all 118 files and independently proved the supplied commit object and
tree link. It accepted the three original code repairs within static scope,
without widening the content/FIFO/parser/lifecycle/consent boundaries, but found
two Low validation omissions. It did not execute code or approve publication.

| Finding | Subsequent local repair | Remaining gate |
| --- | --- | --- |
| SB-NEW-01 — Low, BSD flags | Read native st_flags before accepting an object and pin flags in the before/after identity. Reject mutation-blocking, restricted and unreviewed bits; explicitly allow nodump, compression, document tracking, hidden and archived flags. Never clear input flags to make an app pass. | Native owner-settable flag fixtures cover root/helper/resource and both app validators/sandboxed check paths. System/no-unlink flags use synthetic metadata only; no privileged setters. New exact-source/artifact and affected transaction acceptance remain required. |
| SB-NEW-02 — Low, profile CloudKit authorization | Require a well-typed profile service list containing CloudKit. Additional profile-only service ceilings remain allowed, but actual app services stay exactly CloudKit and the helper entitlement-free. | Synthetic missing/CloudDocuments-only/exact/broader-profile fixtures; real intended Apple Development build still requires separate approval/acceptance. |

The owner approved the local repair/commit/exact-verification scope with working
apps/settings preserved. These are installation/preflight checks, not changes to
running notification delivery. New installable artifacts use build 19; installed
build 17 apps and retained build 18 artifacts/evidence are unchanged. Git commits
and private evidence provide a reversible source checkpoint; no automatic
installation, permissions repair, CloudKit reset or feature disable is authorized.
Real private signed compatibility is not established by synthetic tests.

Follow-up dispositions accepted for this trusted-source-only/source-only preview:

- SB-RISK-01: defer ZIP parser unification/collision hardening, not proof of safety;
  reopen before downloadable binaries or arbitrary app ZIP acceptance.
- SB-RISK-02: migration documentation mitigation accepted, requiring inactive
  PiPing/hook and a fresh Pi process; attestation stays noncryptographic.
- SB-RESIDUAL-01: documented submitted timestamp may complete after disable.
- SB-EVID-02/03/04: wording/prerequisite/task repairs accepted. No interruption
  matrix or standard-account installation acceptance is claimed.

SB-EVID-01 advanced for 77b2203: its exact extracted-source verifier and real
Mac-only artifact/unsafe-derivative checks passed, with preserved apps/process/
registrations. Those are reported local receipts, not Daybreak execution.
Real signed build, current transaction acceptance, read-only historical CloudKit
subscription normalization/compatibility, exact-commit hosted CI, final history/
publication audit, immutable PiPing tag and intended repository/security/owner
publication gates remain open. No broad VM/mobile campaign or subscription reset
is authorized. Record subsequent commit/archive verification separately rather
than editing a tested commit after the fact. These new repairs are not yet
independently reviewed.

## Historical reviewed baseline, not release clearance

Daniel relayed Daybreak's independent read-only review of SettleBell 0.2.0 (17):

- asserted commit: `d5bd76a10fef0c59e802b17572bff8af8b5d2c1b`;
- independently reconstructed tree: `81ecea6ef2337bbb9ead2d4c454b10cd083a2fbd`;
- verified source archive SHA-256:
  `f249f860086fe5d64ea192a5e0f6df855e91d6751e93d10b053b7e3f000b5aae`;
- all 111 supplied files inspected, including artwork; no Git history, commit
  objects, private signing state, binaries or raw guest evidence inspected;
- no builds, tests, installers, live CloudKit or publication performed.

The review found no apparent task-content disclosure path or high-confidence
FIFO/parser/mailbox/lifecycle/consent-generation defect within that static scope.
It identified two Medium installer defects, one Low subscription defect and
release/evidence gaps. It explicitly withheld release approval.

The repairs below are subsequent candidate changes, not part of that reviewed
archive and not independently cleared. The reviewed baseline packet and prior
functional evidence must remain pinned to their original revisions.

## Finding-by-finding disposition

This table records the 2026-10-12 local repair checkpoint, before committing or
running the full exact-source verifier. Subsequent verification must be recorded
separately against its exact commit/tree/archive rather than silently promoting
these focused results. The next installable build number is 18; retained working
apps and earlier functional evidence remain build 17.

| Finding | Local repair or proposed disposition | Remaining gate |
| --- | --- | --- |
| SB-SEC-01 — Medium, unsafe app metadata | Both app validators call one recursive guard before signature checks: effective-user ownership, exact modes, no group/other write bits, extended ACLs, hardlinks, symlinks or special objects. It rejects rather than repairs untrusted metadata. | Generated source-local/signed-local archive acceptance and affected install/update/rollback/uninstall checks have not run with the new guard. |
| SB-SEC-02 — Medium, extra signed entitlements | Exact four-key Mac app entitlement dictionary; empty helper entitlements; helper signature identifier `SettleBellSignal`; failed extraction is fatal. Profile claims narrowed to existing team/application/container/certificate/expiry authorization, not UUID/hash or complete capability-set pinning. | Controlled real signed fixtures and the intended private build still need separately approved validation. Synthetic tests do not establish certificate/profile authenticity or current Xcode entitlement compatibility. |
| SB-SEC-03 — Low, subscription ID-only reuse | Compare query type, ID, record type, predicate, zone, exact triggers and fixed notification settings, rejecting extra payload/localization/badge/background/mutable settings. Empty/nil desired keys are equivalent. Mismatch throws reset-required; iOS displays that state. No deletion/replacement path added. | Focused synthetic checks pass; the iOS-specific status change still needs the exact-source compile verifier. No live subscription or deployed identifier was changed. |
| SB-RISK-01 — Low, parser differential hypothesis | Proposed deferral of parser unification/adversarial collision hardening for this source-only preview. No extraction escape was demonstrated. Existing path/type/size checks and trusted local-source prerequisites remain; threat model now explicitly records the differential. Unsafe-mode ZIP fixtures do not resolve this hypothesis. | Owner/reviewer acceptance of this explicit deferral is still required. Arbitrary downloaded app ZIPs are not an approved installation input. |
| SB-RISK-02 — Low, ambiguous retirement attestation | Migration docs require PiPing and its exact hook inactive, preserve rollback state, and start a fresh Pi process before the eligible SettleBell run. Typed attestation is expressly owner evidence, not cryptographic provenance. | Documentation mitigation proposed for acceptance; no dual-hook migration test was repeated and retirement logic/settings were not changed. |
| SB-RESIDUAL-01 — Informational, submitted CloudKit write | Existing timestamp-only residual remains documented: disable cannot recall an already-submitted request. No cancellation guarantee or additional networking added. | Retain the existing consent tests and disclosure; no new product fix proposed. |
| SB-EVID-01 — Medium, exact-revision release gates | Keep exact-archive verification, hosted exact-commit CI, immutable PiPing tag provenance, intended refs/destination/visibility and private reporting gates open. | The initial local repair pass did not authorize a commit, hosted CI, remote operation or publication. Subsequent approvals and exact-revision results must be recorded separately. |
| SB-EVID-02 — Low, interruption coverage claim | Narrow changelog wording: repository regressions inspect source ordering; retained guest acceptance is scoped separately. No behavioral interruption matrix or power-loss/SIGKILL rollback guarantee is claimed. | New validators still require affected transaction acceptance; retained older evidence is not silently promoted to current acceptance. |
| SB-EVID-03 — Low, account prerequisite | README/Setup explicitly require existing `/Applications` write access, normally a non-root administrator; no sudo/password prompt or standard-account support/acceptance. Python 3 requirement is also explicit. | An unwritable sandbox directory verifies clean refusal in both `--check` paths. No account permissions were changed; this is not an actual standard-account test. The prior guest prerequisite stop remains historical evidence. |
| SB-EVID-04 — Informational, discarded task | Retain the delayed callback task, cancel it on exit and await its result. | Focused APNs waiter tests pass without the discarded-task diagnostic; exact-source verifier still pending. |

## Focused local fixture coverage

- App trees: accepted `0755`/`0700` directories/executables and `0644`/`0600`
  data; writable helper/root/nested directories; actual macOS extended ACL;
  hardlink; FIFO; symlink/root symlink; unexpected mode/control-character path;
  failed ACL inspection and changed metadata.
- Ownership rejection uses real `lstat` data with an injected effective-UID
  expectation, **not** an actual wrong-owner tree or privileged `chown`.
- ZIP fixtures preserve unsafe Unix modes and use actual `ditto` extraction.
  Only disposable installer copies are used for `--check`, with canonical paths
  redirected to a private fixture directory and LaunchServices disabled. Both
  checks reject before signing/runtime calls or canonical-path changes. Both
  checks also refuse an unwritable sandbox applications directory before
  archive extraction.
- Pure entitlement/profile fixtures and a shell-wiring fixture use only
  synthetic identifiers, certificate bytes and plist data. Mock signature/CMS
  success is explicitly not real cryptographic validation. Extra app/helper
  entitlements, wrong helper ID and extraction failure reject; profile UUID
  changes alone deliberately remain allowed under the narrowed policy.
- CloudKit fixtures create schema objects without a container/network call:
  correct reuse, missing subscription/one save, 25 schema mismatches rejected
  both at readiness and installation, and fetch/save failures. No duplicate or
  replacement operation is allowed on mismatch.
- Focused APNs waiter tests exercise the repaired delayed task.

The Node test suite includes the disposable Python fixtures so hosted verification
will exercise them; those fixtures are macOS-only. These are focused synthetic
checks of the precommit repair tree, not a full exact-source verifier, app build,
installation campaign, live device test or independent review of the fixes.

## Next approval boundary

Review the local diff, approve the reconciled commit, then generate and audit its
exact archive and run the supported verifier. Approve only the affected real
artifact/transaction checks, preserving working apps and recovery evidence. Have
Daybreak review the exact replacement candidate and dispositions before the
separately approved hosted CI/repository/publication sequence. Do not repeat an
indiscriminate VM/mobile campaign or reset CloudKit automatically.
