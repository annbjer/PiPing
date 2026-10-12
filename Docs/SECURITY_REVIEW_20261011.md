# Independent review and local repair disposition

## Reviewed baseline, not release clearance

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
