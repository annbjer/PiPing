import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { readFile } from "node:fs/promises";
import test from "node:test";
import {
  canonicalHelperPath,
  makeNativeHelperRunner,
  registerSettleBell,
} from "../../Integration/Pi/settlebell.ts";

const firstToken = "00000000-0000-0000-0000-000000000001";
const secondToken = "00000000-0000-0000-0000-000000000002";

function assertTextOrder(text, markers, label) {
  let cursor = 0;
  for (const marker of markers) {
    const index = text.indexOf(marker, cursor);
    assert.notEqual(index, -1, `${label}: missing ${marker}`);
    cursor = index + marker.length;
  }
}

function assertNormalSignalRouting(script, label) {
  assert.match(script, /cleanup\(\) \{\n  trap '' HUP INT TERM/);
  assert.match(script, /trap 'handle_signal 129' HUP/);
  assert.match(script, /trap 'handle_signal 130' INT/);
  assert.match(script, /trap 'handle_signal 143' TERM/);
  assert.match(script, /handle_signal\(\) \{\n  exit "\$1"\n\}/, label);
}

function fakePi() {
  const handlers = new Map();
  return {
    handlers,
    api: {
      on(event, handler) {
        handlers.set(event, handler);
      },
    },
  };
}

test("package keeps the Pi peer optional and has no lifecycle scripts", async () => {
  const manifest = JSON.parse(
    await readFile(new URL("../../package.json", import.meta.url), "utf8"),
  );
  assert.equal(
    manifest.peerDependencies["@earendil-works/pi-coding-agent"],
    "*",
  );
  assert.equal(
    manifest.peerDependenciesMeta["@earendil-works/pi-coding-agent"].optional,
    true,
  );
  assert.equal(manifest.dependencies, undefined);
  assert.deepEqual(manifest.files, [
    "Integration/Pi/settlebell.ts",
    "Integration/Pi/README.md",
    "LICENSE",
  ]);
  for (const name of ["preinstall", "install", "postinstall"]) {
    assert.equal(manifest.scripts[name], undefined);
  }
  assert.equal(
    await readFile(new URL("../../.npmrc", import.meta.url), "utf8"),
    "package-lock=false\n",
  );
});

test("installers order quarantine, promotion, and commit state safely", async () => {
  for (const [label, relativePath] of [
    ["source installer", "../../script/install_source_local.sh"],
    ["signed installer", "../../script/install_signed_local.sh"],
  ]) {
    const script = await readFile(new URL(relativePath, import.meta.url), "utf8");
    assertNormalSignalRouting(script, label);
    assert.match(script, /\.PiPing-source-transaction\.\*/);
    assert.match(script, /\.SettleBell-piping-retirement\.\*/);
    const transaction = script.slice(
      script.indexOf('if [[ -d "$CANONICAL_APP" ]]; then'),
    );
    assertTextOrder(
      transaction,
      [
        'previous_identity="$(path_identity "$CANONICAL_APP")"',
        "restore_needed=true",
        'mv "$CANONICAL_APP" "$PREVIOUS_APP"',
        'if [[ "$(path_identity "$PREVIOUS_APP")" != "$previous_identity" ]]',
        "candidate_installed=true",
        'mv "$CANDIDATE_APP" "$CANONICAL_APP"',
        'if [[ "$(path_identity "$CANONICAL_APP")" != "$candidate_identity" ]]; then',
        "candidate_installed=false restore_needed=false",
        'if [[ -d "$PREVIOUS_APP" ]]; then rm -rf "$PREVIOUS_APP"; fi',
      ],
      label,
    );
  }
});

test("guarded lifecycle scripts validate private backup directories and archives", async () => {
  for (const relativePath of [
    "../../script/install_source_local.sh",
    "../../script/install_signed_local.sh",
    "../../script/uninstall_source_local.sh",
    "../../script/retire_legacy_piping_source_local.sh",
  ]) {
    const script = await readFile(new URL(relativePath, import.meta.url), "utf8");
    assert.match(script, /source "\$ROOT_DIR\/script\/guarded_backup_support\.sh"/);
    assertTextOrder(
      script,
      [
        'guarded_prepare_private_directory "$ROOT_DIR/.build"',
        'guarded_prepare_private_directory "$BACKUP_DIR"',
        "guarded_validate_existing_archives",
        "guarded_prune_validated_archives",
      ],
      relativePath,
    );
  }
});

test("uninstaller commits before deleting preferences or the prior app", async () => {
  const script = await readFile(
    new URL("../../script/uninstall_source_local.sh", import.meta.url),
    "utf8",
  );
  assertNormalSignalRouting(script, "source uninstaller");
  assert.match(script, /\.PiPing-source-transaction\.\*/);
  assert.match(script, /\.SettleBell-piping-retirement\.\*/);
  const signal = script.slice(script.indexOf('current_pids="$(pgrep -x SettleBell'));
  assertTextOrder(
    signal,
    [
      'current_pids="$(pgrep -x SettleBell',
      'ps -p "$PIDS" -o command=',
      'ps -p "$PIDS" -o lstart=',
      'kill "$PIDS"',
    ],
    "source uninstaller process pin",
  );
  const quarantine = script.slice(
    script.indexOf('quarantined_identity="$(path_identity "$CANONICAL_APP")"'),
  );
  assertTextOrder(
    quarantine,
    [
      'quarantined_identity="$(path_identity "$CANONICAL_APP")"',
      'mv "$CANONICAL_APP" "$QUARANTINED_APP"',
      'if [[ "$(path_identity "$QUARANTINED_APP")" != "$quarantined_identity" ]]',
    ],
    "source uninstaller quarantine",
  );
  const finalIdentityCheck = quarantine.lastIndexOf(
    'if [[ "$(path_identity "$QUARANTINED_APP")" != "$quarantined_identity" ]]; then',
  );
  assert.notEqual(finalIdentityCheck, -1);
  assertTextOrder(
    quarantine.slice(finalIdentityCheck),
    [
      'if [[ "$(path_identity "$QUARANTINED_APP")" != "$quarantined_identity" ]]; then',
      "completed=true",
      'defaults delete "$PUBLIC_BUNDLE_IDENTIFIER"',
      'rm -rf "$QUARANTINED_APP"',
    ],
    "source uninstaller commit",
  );
});

test("legacy retirement requires validated SettleBell and commits safely", async () => {
  const script = await readFile(
    new URL("../../script/retire_legacy_piping_source_local.sh", import.meta.url),
    "utf8",
  );
  assertNormalSignalRouting(script, "legacy source-local retirement");
  assert.match(script, /--legacy-archive/);
  assert.match(script, /--legacy-sha256/);
  assert.match(script, /read -r notification_attestation < \/dev\/tty/);
  assert.match(script, /I observed and acknowledged a SettleBell notification/);
  assert.doesNotMatch(script, /--confirmed-settlebell-notification/);
  assert.doesNotMatch(script, /defaults delete/);
  assert.doesNotMatch(script, /\.pi\/agent\/settings\.json/);
  assertTextOrder(
    script,
    [
      "legacy_pin_archive",
      '"$LEGACY_ARCHIVE" "$PINNED_LEGACY_ARCHIVE" "$LEGACY_ARCHIVE_SHA256"',
      '"$ROOT_DIR/script/check_source_installation.sh" >/dev/null',
      'ditto -x -k "$PINNED_LEGACY_ARCHIVE" "$REFERENCE_STAGE"',
      "if ! settlebell_runtime_is_ready; then",
      '"$ROOT_DIR/script/validate_legacy_piping_source_local_app.sh" "$LEGACY_APP"',
      'LEGACY_REFERENCE_MANIFEST="$(legacy_app_manifest "$REFERENCE_APP")"',
      'if ! legacy_manifest_matches_reference "$LEGACY_APP"; then',
      'quarantined_identity="$(path_identity "$LEGACY_APP")"',
      "restore_needed=true",
      'mv "$LEGACY_APP" "$QUARANTINED_APP"',
      'legacy_manifest_matches_reference "$QUARANTINED_APP"',
    ],
    "legacy retirement preflight and quarantine",
  );
  const signal = script.slice(script.indexOf('current_legacy_pids="$(pgrep -x PiPing'));
  assertTextOrder(
    signal,
    [
      'current_legacy_pids="$(pgrep -x PiPing',
      'ps -p "$LEGACY_PIDS" -o command=',
      'ps -p "$LEGACY_PIDS" -o lstart=',
      'kill "$LEGACY_PIDS"',
    ],
    "legacy retirement process pin",
  );
  const finalIdentityCheck = script.lastIndexOf(
    'if [[ "$(path_identity "$QUARANTINED_APP")" != "$quarantined_identity" ]]',
  );
  assert.notEqual(finalIdentityCheck, -1);
  assertTextOrder(
    script.slice(finalIdentityCheck),
    [
      'if [[ "$(path_identity "$QUARANTINED_APP")" != "$quarantined_identity" ]]',
      'legacy_manifest_matches_reference "$QUARANTINED_APP"',
      "completed=true",
      "restore_needed=false",
      'rm -rf "$QUARANTINED_APP"',
    ],
    "legacy retirement commit",
  );
});

test("legacy archive pin and manifest reject later source/target mutation", () => {
  const supportPath = new URL(
    "../../script/legacy_migration_support.sh",
    import.meta.url,
  ).pathname;
  const output = execFileSync("/bin/bash", ["-c", String.raw`
set -euo pipefail
source "$SUPPORT_PATH"
tmp="$(mktemp -d "$TMPDIR/settlebell-legacy-support-test.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT
printf 'archive-payload\n' >"$tmp/source.zip"
cat >"$tmp/validator" <<'VALIDATOR'
#!/usr/bin/env bash
grep -qx archive-payload "$1"
VALIDATOR
chmod 700 "$tmp/validator"
sha="$(shasum -a 256 "$tmp/source.zip" | awk '{print $1}')"
legacy_pin_archive "$tmp/source.zip" "$tmp/pinned.zip" "$sha" "$tmp/validator"
printf 'replacement\n' >"$tmp/source.zip"
grep -qx archive-payload "$tmp/pinned.zip"
mkdir "$tmp/reference" "$tmp/candidate"
chmod 700 "$tmp/reference" "$tmp/candidate"
printf 'payload\n' >"$tmp/reference/item"
printf 'payload\n' >"$tmp/candidate/item"
chmod 600 "$tmp/reference/item" "$tmp/candidate/item"
LEGACY_REFERENCE_MANIFEST="$(legacy_app_manifest "$tmp/reference")"
legacy_manifest_matches_reference "$tmp/candidate"
printf 'changed\n' >"$tmp/candidate/item"
if legacy_manifest_matches_reference "$tmp/candidate"; then exit 1; fi
printf 'payload\n' >"$tmp/candidate/item"
ln "$tmp/candidate/item" "$tmp/candidate/hardlink"
if legacy_manifest_matches_reference "$tmp/candidate" 2>/dev/null; then exit 1; fi
printf 'pass\n'
`], {
    encoding: "utf8",
    env: {
      ...process.env,
      SUPPORT_PATH: supportPath,
      TMPDIR: process.env.TMPDIR ?? "/tmp",
    },
  });
  assert.equal(output, "pass\n");
});

test("legacy validator pins the v0.1.0 public build and rejects link/ACL expansion", async () => {
  const validator = await readFile(
    new URL("../../script/validate_legacy_piping_source_local_app.sh", import.meta.url),
    "utf8",
  );
  assert.match(validator, /marketing_version.*!= "0\.1\.0"/s);
  assert.match(validator, /build_version.*!= "15"/s);
  assert.match(validator, /-type f -links \+1/);
  assert.match(validator, /must not contain extended ACLs/);
});

test("registers only the two lifecycle handlers", () => {
  const pi = fakePi();
  registerSettleBell(pi.api, async () => {}, () => firstToken);
  assert.deepEqual([...pi.handlers.keys()].sort(), [
    "agent_settled",
    "before_agent_start",
  ]);
});

test("forwards only fixed signals and one opaque extension token", async () => {
  const pi = fakePi();
  const signals = [];
  registerSettleBell(
    pi.api,
    async (signal, sessionToken) => signals.push({ signal, sessionToken }),
    () => firstToken,
  );

  await pi.handlers.get("before_agent_start")({
    prompt: "synthetic private prompt",
    systemPrompt: "synthetic private system content",
  });
  await pi.handlers.get("agent_settled")(
    { messages: ["synthetic private output"] },
    { isIdle: () => true },
  );

  assert.deepEqual(signals, [
    { signal: "start", sessionToken: firstToken },
    { signal: "settled", sessionToken: firstToken },
  ]);
});

test("keeps overlapping Pi extension instances independently identifiable", async () => {
  const firstPi = fakePi();
  const secondPi = fakePi();
  const signals = [];
  const runSignal = async (signal, sessionToken) => {
    signals.push({ signal, sessionToken });
  };
  registerSettleBell(firstPi.api, runSignal, () => firstToken);
  registerSettleBell(secondPi.api, runSignal, () => secondToken);

  await firstPi.handlers.get("before_agent_start")({});
  await secondPi.handlers.get("before_agent_start")({});
  await firstPi.handlers.get("agent_settled")({}, { isIdle: () => true });
  await secondPi.handlers.get("agent_settled")({}, { isIdle: () => true });

  assert.deepEqual(signals, [
    { signal: "start", sessionToken: firstToken },
    { signal: "start", sessionToken: secondToken },
    { signal: "settled", sessionToken: firstToken },
    { signal: "settled", sessionToken: secondToken },
  ]);
});

test("reuses a token only within one active cycle and rotates after settlement", async () => {
  const pi = fakePi();
  const signals = [];
  const availableTokens = [firstToken, secondToken];
  registerSettleBell(
    pi.api,
    async (signal, lifecycleToken) => signals.push({ signal, lifecycleToken }),
    () => availableTokens.shift(),
  );

  await pi.handlers.get("before_agent_start")({});
  await pi.handlers.get("before_agent_start")({});
  await pi.handlers.get("agent_settled")({}, { isIdle: () => true });
  await pi.handlers.get("before_agent_start")({});
  await pi.handlers.get("agent_settled")({}, { isIdle: () => true });

  assert.deepEqual(signals, [
    { signal: "start", lifecycleToken: firstToken },
    { signal: "start", lifecycleToken: firstToken },
    { signal: "settled", lifecycleToken: firstToken },
    { signal: "start", lifecycleToken: secondToken },
    { signal: "settled", lifecycleToken: secondToken },
  ]);
});

test("generates a distinct opaque UUID for each default extension instance", async () => {
  const firstPi = fakePi();
  const secondPi = fakePi();
  const tokens = [];
  const runSignal = async (_signal, sessionToken) => tokens.push(sessionToken);
  registerSettleBell(firstPi.api, runSignal);
  registerSettleBell(secondPi.api, runSignal);

  await firstPi.handlers.get("before_agent_start")({});
  await secondPi.handlers.get("before_agent_start")({});

  const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
  assert.match(tokens[0], uuid);
  assert.match(tokens[1], uuid);
  assert.notEqual(tokens[0], tokens[1]);
});

test("does not emit settled when another extension made Pi active", async () => {
  const pi = fakePi();
  const signals = [];
  registerSettleBell(
    pi.api,
    async (signal) => signals.push(signal),
    () => firstToken,
  );

  await pi.handlers.get("agent_settled")({}, { isIdle: () => false });
  assert.deepEqual(signals, []);
});

test("uses the installed helper and reports launch failures without throwing", async () => {
  const invocations = [];
  const failures = [];
  const execute = (file, args, options, completion) => {
    invocations.push({ file, args, options });
    completion(Object.assign(new Error("synthetic failure"), { code: "ENOENT" }));
  };
  const runner = makeNativeHelperRunner(execute, (message) => failures.push(message));

  await runner("settled", firstToken);

  assert.deepEqual(invocations, [{
    file: canonicalHelperPath,
    args: ["settled", firstToken],
    options: { timeout: 1_000, windowsHide: true },
  }]);
  assert.deepEqual(failures, [
    "[SettleBell] Could not deliver the settled lifecycle signal "
      + "through the installed helper (ENOENT). "
      + "SettleBell notifications are unavailable for this Pi session.",
  ]);
});

test("independently resolves when the helper completion never arrives", async () => {
  const failures = [];
  let helperCompletion;
  let deadline;
  let cancelled = 0;
  const runner = makeNativeHelperRunner(
    (_file, _args, _options, completion) => {
      helperCompletion = completion;
    },
    (message) => failures.push(message),
    (completion, milliseconds) => {
      assert.equal(milliseconds, 1_250);
      deadline = completion;
      return () => { cancelled += 1; };
    },
  );

  const run = runner("start", firstToken);
  deadline();
  await run;
  helperCompletion(null);

  assert.equal(cancelled, 1);
  assert.deepEqual(failures, [
    "[SettleBell] Could not deliver the start lifecycle signal "
      + "through the installed helper (timeout). "
      + "SettleBell notifications are unavailable for this Pi session.",
  ]);
});

test("converts a synchronous executor failure into non-throwing reporting", async () => {
  const failures = [];
  const runner = makeNativeHelperRunner(
    () => {
      throw Object.assign(new Error("synthetic failure"), { code: "EACCES" });
    },
    (message) => failures.push(message),
  );

  await runner("settled", firstToken);

  assert.deepEqual(failures, [
    "[SettleBell] Could not deliver the settled lifecycle signal "
      + "through the installed helper (EACCES). "
      + "SettleBell notifications are unavailable for this Pi session.",
  ]);
});
