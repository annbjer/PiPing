import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdtemp, mkdir, readFile, writeFile, rm, rename, symlink } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";

const publicIdentity = ["org.example.SettleBell.macOS", "SettleBell Development"];
const privateIdentity = ["org.example.SettleBell.private-test", "SettleBell"];

async function fixture(identity, exercise) {
  const root = await mkdtemp(join(tmpdir(), "settlebell-status-test-"));
  const app = join(root, "SettleBell.app");
  const scripts = join(root, "script");
  const bin = join(root, "bin");
  const calls = join(root, "calls");
  try {
    await mkdir(join(app, "Contents"), { recursive: true, mode: 0o700 });
    await mkdir(scripts, { mode: 0o700 });
    await mkdir(bin, { mode: 0o700 });
    await writeFile(join(app, "Contents", "Info.plist"), JSON.stringify({
      CFBundleIdentifier: identity[0], CFBundleDisplayName: identity[1],
    }));
    await writeFile(calls, "");
    for (const name of ["check_local_installation.sh", "status.sh"]) {
      const original = await readFile(new URL(`../../script/${name}`, import.meta.url), "utf8");
      assert.equal(original.split('CANONICAL_APP="/Applications/SettleBell.app"').length, 2);
      // Change only the disposable test copy's endpoints. Production code has
      // no environment override for classification or PlistBuddy.
      const copy = original
        .replace('CANONICAL_APP="/Applications/SettleBell.app"', 'CANONICAL_APP="$FIXTURE_APP"')
        .replaceAll("/usr/libexec/PlistBuddy", '"$FIXTURE_PLIST_BUDDY"')
        .replace('STABLE_DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"', 'STABLE_DEVELOPER_DIR="$FIXTURE_DEVELOPER_DIR"');
      await writeFile(join(scripts, name), copy, { mode: 0o700 });
    }
    await writeFile(join(bin, "plist"), `#!${process.execPath}
const fs = require("node:fs");
const data = JSON.parse(fs.readFileSync(process.argv[4], "utf8"));
const key = process.argv[3].replace(/^Print :/, "");
if (typeof data[key] !== "string") process.exit(1);
process.stdout.write(data[key]);
`, { mode: 0o700 });
    for (const [name, label, exitVariable] of [
      ["check_source_installation.sh", "source", "SOURCE_EXIT"],
      ["check_installation.sh", "signed", "SIGNED_EXIT"],
    ]) {
      await writeFile(join(scripts, name), `#!/bin/bash
[[ -z "\${SETTLEBELL_CANONICAL_APP+x}" ]] || exit 90
printf '${label}\\n' >>"$FIXTURE_CALLS"
exit "\${${exitVariable}:-0}"
`, { mode: 0o700 });
    }
    // Status diagnostics cannot launch Pi, Xcode, or inspect a real Git repo.
    for (const name of ["pi", "xcodebuild", "git"]) {
      await writeFile(join(bin, name), "#!/bin/bash\nexit 0\n", { mode: 0o700 });
    }
    await mkdir(join(root, "developer", "usr", "bin"), { recursive: true, mode: 0o700 });
    await writeFile(join(root, "developer", "usr", "bin", "xcodebuild"), "", { mode: 0o700 });
    const run = (name = "check_local_installation.sh", overrides = {}) => spawnSync(
      "/bin/bash", [join(scripts, name)], {
        encoding: "utf8", timeout: 10000,
        env: {
          ...process.env, PATH: `${bin}:${process.env.PATH}`,
          FIXTURE_APP: app, FIXTURE_CALLS: calls,
          FIXTURE_PLIST_BUDDY: join(bin, "plist"),
          FIXTURE_DEVELOPER_DIR: join(root, "developer"),
          SETTLEBELL_CANONICAL_APP: "/synthetic/forbidden-override.app",
          SOURCE_EXIT: "0", SIGNED_EXIT: "0", ...overrides,
        },
      },
    );
    await exercise({ root, app, calls, run });
  } finally {
    await rm(root, { recursive: true, force: true });
  }
}

for (const [label, identity, selected, rejected] of [
  ["source-local", publicIdentity, "source", "SOURCE_EXIT"],
  ["private-signed", privateIdentity, "signed", "SIGNED_EXIT"],
]) {
  test(`canonical checker selects ${label} and never falls back after rejection`, async () => {
    await fixture(identity, async ({ calls, run }) => {
      assert.equal(run().status, 0);
      assert.equal(await readFile(calls, "utf8"), `${selected}\n`);
      await writeFile(calls, "");
      assert.equal(run("check_local_installation.sh", { [rejected]: "23" }).status, 23);
      assert.equal(await readFile(calls, "utf8"), `${selected}\n`);
    });
  });
  test(`status accepts valid ${label} installation outside Git and preserves failure`, async () => {
    await fixture(identity, async ({ calls, run }) => {
      const valid = run("status.sh");
      assert.equal(valid.status, 0, valid.stderr);
      assert.match(valid.stdout, /unavailable \(not a Git checkout\)/);
      assert.match(valid.stdout, /Canonical installation: valid/);
      assert.equal(await readFile(calls, "utf8"), `${selected}\n`);
      await writeFile(calls, "");
      assert.equal(run("status.sh", { [rejected]: "23" }).status, 1);
      assert.equal(await readFile(calls, "utf8"), `${selected}\n`);
    });
  });
}

test("mixed, missing and malformed identities fail without invoking a validator", async () => {
  for (const identity of [[publicIdentity[0], privateIdentity[1]], [privateIdentity[0], publicIdentity[1]], ["", ""], [null, null]]) {
    await fixture(identity, async ({ app, calls, run }) => {
      assert.equal(run().status, 1);
      assert.equal(await readFile(calls, "utf8"), "");
      await writeFile(join(app, "Contents", "Info.plist"), "malformed fixture");
      assert.equal(run().status, 1);
      assert.equal(await readFile(calls, "utf8"), "");
    });
  }
});

test("foreign metadata is not validation and cannot bypass signed rejection", async () => {
  await fixture(["org.example.Foreign", "Foreign"], async ({ calls, run }) => {
    assert.equal(run("status.sh", { SIGNED_EXIT: "23" }).status, 1);
    assert.equal(await readFile(calls, "utf8"), "signed\n");
  });
});

test("absent app is reported separately from invalid or symlinked app", async () => {
  await fixture(publicIdentity, async ({ root, app, calls, run }) => {
    const moved = join(root, "held");
    await rename(app, moved);
    assert.equal(run().status, 1);
    const absent = run("status.sh");
    assert.equal(absent.status, 0);
    assert.match(absent.stdout, /Canonical installation: absent/);
    await symlink(moved, app);
    assert.equal(run("status.sh").status, 1);
    await rm(app);
    await symlink(join(root, "missing"), app);
    assert.equal(run("status.sh").status, 1);
    await rm(app);
    await writeFile(app, "not an app");
    assert.equal(run("status.sh").status, 1);
    assert.equal(await readFile(calls, "utf8"), "");
  });
});

test("signed installer retains its strict checker; generic guidance uses dispatch", async () => {
  const signed = await readFile(new URL("../../script/install_signed_local.sh", import.meta.url), "utf8");
  assert.match(signed, /env -u SETTLEBELL_CANONICAL_APP "\$ROOT_DIR\/script\/check_installation.sh"/);
  assert.doesNotMatch(signed, /check_local_installation/);
  const readme = await readFile(new URL("../../README.md", import.meta.url), "utf8");
  assert.match(readme, /\.\/script\/check_local_installation\.sh/);
  const privateCheck = await readFile(new URL("../../script/check_installation.sh", import.meta.url), "utf8");
  assert.match(privateCheck, /Public-safe development output cannot be the canonical installation/);
});
