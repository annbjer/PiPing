import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { readFile } from "node:fs/promises";
import test from "node:test";

// macOS-only installer metadata, real ZIP/ditto rejection fixtures, and pure
// synthetic entitlement/profile comparisons. No private config or real apps.
test("local app and signed metadata adversarial fixtures", {
  skip: process.platform !== "darwin",
}, () => {
  const output = execFileSync("python3", [
    "-B", new URL("../InstallerValidationTests/test_local_validation.py", import.meta.url).pathname,
  ], { encoding: "utf8", timeout: 180_000, stdio: ["ignore", "pipe", "pipe"] });
  assert.equal(output, "");
});

test("both validators enforce metadata before codesign; helper identity and entitlements are checked", async () => {
  for (const name of ["validate_source_local_app.sh", "validate_signed_local_app.sh"]) {
    const text = await readFile(new URL(`../../script/${name}`, import.meta.url), "utf8");
    const guard = text.indexOf('"$ROOT_DIR/script/validate_local_app_tree.sh" "$APP"');
    assert.ok(guard >= 0 && guard < text.indexOf("codesign --verify"));
  }
  const signed = await readFile(new URL("../../script/validate_signed_local_app.sh", import.meta.url), "utf8");
  assert.match(signed, /helper_identifier.*!= "SettleBellSignal"/);
  assert.match(signed, /codesign -d --entitlements - --xml "\$HELPER"/);
  assert.match(signed, /validate_signed_local_metadata\.py/);
});
