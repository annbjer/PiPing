"""Disposable metadata fixtures. No real signing, registration or installation."""

import copy
import datetime
import importlib.util
import os
from pathlib import Path
import plistlib
import stat
import subprocess
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch
import zipfile

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]


def load_module(name, path):
    specification = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(specification)
    specification.loader.exec_module(module)
    return module


TREE = load_module("app_tree", ROOT / "script/validate_local_app_tree.py")
METADATA = load_module("signed_metadata", ROOT / "script/validate_signed_local_metadata.py")


@unittest.skipUnless(sys.platform == "darwin", "App metadata fixtures require macOS")
class AppTreeTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="settlebell-validator-fixtures-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        # Only disposable copies have canonical paths/LaunchServices redirected.
        # Never add a production installer override or call its real --install.
        self.checkout = self.root / "checkout"
        (self.checkout / "script").mkdir(parents=True)
        (self.checkout / "Config").mkdir()
        self.applications = self.root / "sandbox-apps"
        self.applications.mkdir()
        (self.applications / "KEEP").write_text("unchanged\n")
        for path in (ROOT / "script").glob("*"):
            if path.suffix not in {".sh", ".py"}:
                continue
            content = path.read_text()
            if path.suffix == ".sh":
                content = content.replace("/Applications", str(self.applications))
                content = content.replace(
                    'LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"',
                    'LSREGISTER="/usr/bin/true"',
                )
                self.assertNotIn("/Applications", content)
                self.assertNotIn("LSREGISTER=\"/System/", content)
            destination = self.checkout / "script" / path.name
            destination.write_text(content)
            destination.chmod(0o700 if path.suffix == ".sh" else 0o600)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.trace = self.root / "unexpected-signing-or-runtime-call"
        for command in ("codesign", "security", "open", "pgrep"):
            stub = self.bin / command
            stub.write_text('#!/bin/bash\nprintf unexpected > "$FIXTURE_TRACE"\nexit 91\n')
            stub.chmod(0o700)
        self.env = dict(os.environ, PATH=f"{self.bin}:{os.environ['PATH']}",
                        FIXTURE_TRACE=str(self.trace), TMPDIR=str(self.root))
        self.app = self.make_app(self.root / "input" / "SettleBell.app")

    def make_app(self, app):
        for relative in ("", "Contents", "Contents/MacOS", "Contents/Helpers", "Contents/Resources"):
            directory = app / relative
            directory.mkdir(parents=True, exist_ok=True)
            directory.chmod(0o755)
        plist = {
            "CFBundleIdentifier": "org.example.SettleBell.macOS",
            "CFBundleExecutable": "SettleBell",
            "CFBundleDisplayName": "SettleBell Development",
            "SettleBellCloudKitActivationEnabled": "NO",
            "SettleBellCloudKitContainerIdentifier": "iCloud.org.example.SettleBell",
        }
        (app / "Contents/Info.plist").write_bytes(plistlib.dumps(plist))
        (app / "Contents/Info.plist").chmod(0o644)
        for relative in ("Contents/MacOS/SettleBell", "Contents/Helpers/SettleBellSignal"):
            executable = app / relative
            # Not runnable code; no app/helper execution is part of these tests.
            executable.write_bytes(b"synthetic non-executable payload\n")
            executable.chmod(0o755)
        resource = app / "Contents/Resources/resource.dat"
        resource.write_bytes(b"synthetic resource fixture\n")
        resource.chmod(0o644)
        return app

    def invoke(self, script, *arguments):
        return subprocess.run(
            ["/bin/bash", str(self.checkout / "script" / script), *map(str, arguments)],
            env=self.env, capture_output=True, text=True, timeout=30,
        )

    def assert_rejected_by_both_app_validators(self, expected):
        for name in ("validate_source_local_app.sh", "validate_signed_local_app.sh"):
            with self.subTest(validator=name):
                result = self.invoke(name, self.app)
                self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
                self.assertIn(expected, result.stderr)
                self.assertFalse(self.trace.exists(), "Metadata must fail before signing/runtime tools")

    def test_safe_exact_modes(self):
        TREE.validate_tree(self.app)
        for path in self.app.rglob("*"):
            path.chmod(0o700 if path.is_dir() or os.access(path, os.X_OK) else 0o600)
        self.app.chmod(0o700)
        TREE.validate_tree(self.app)

    def test_native_mutation_blocking_flags(self):
        # Only owner-settable flags on freshly created fixtures. Darwin's SDK
        # reserves/comments out UF_NOUNLINK; system/no-unlink bits are covered
        # synthetically below, never set with sudo or on a working app.
        for name in ("uchg", "uappnd"):
            for relative in ("", "Contents/Helpers/SettleBellSignal", "Contents/Resources/resource.dat"):
                with self.subTest(flag=name, relative=relative):
                    target = self.app / relative
                    original = target.lstat().st_flags
                    try:
                        subprocess.run(["/usr/bin/chflags", name, str(target)], check=True)
                        self.assertNotEqual(target.lstat().st_flags, original)
                        self.assert_rejected_by_both_app_validators("BSD file flags")
                    finally:
                        os.chflags(target, original)
        TREE.validate_tree(self.app)

    def test_benign_flags_are_not_indiscriminately_rejected(self):
        target = self.app / "Contents/Resources/resource.dat"
        original = target.lstat().st_flags
        try:
            subprocess.run(["/usr/bin/chflags", "nodump,hidden", str(target)], check=True)
            TREE.validate_tree(self.app)
        finally:
            os.chflags(target, original)
        # Compression/tracking/archive bits are recognized from Darwin's SDK;
        # do not manufacture compressed data or set privileged system flags.
        for flag in (0, 0x1, 0x20, 0x40, 0x8000, 0x10000, TREE.ALLOWED_BSD_FLAGS):
            TREE.validate_flags(SimpleNamespace(st_flags=flag))

    def test_synthetic_system_no_unlink_and_unreviewed_flags(self):
        for flag in (0x2, 0x4, 0x10, 0x8, 0x80, 0x20000, 0x40000,
                     0x80000, 0x100000, 0x200000, 0x800000, 0x40000000, 0x100):
            with self.subTest(flag=hex(flag)):
                with self.assertRaisesRegex(ValueError, "BSD file flags"):
                    TREE.validate_flags(SimpleNamespace(st_flags=flag))
        for metadata in (SimpleNamespace(), SimpleNamespace(st_flags=None)):
            with self.assertRaisesRegex(ValueError, "native BSD file-flag metadata"):
                TREE.validate_flags(metadata)

    def test_flag_change_alone_is_rejected(self):
        original = os.lstat
        calls = 0

        def changed(path):
            nonlocal calls
            result = original(path)
            calls += 1
            if calls == 3:
                return SimpleNamespace(**{name: getattr(result, name) for name in
                    ("st_dev", "st_ino", "st_uid", "st_mode", "st_nlink", "st_ctime_ns")},
                    st_flags=result.st_flags ^ 0x1)
            return result

        with patch.object(TREE.os, "lstat", side_effect=changed):
            with self.assertRaisesRegex(ValueError, "changed during"):
                TREE.validate_tree(self.app)

    def test_writable_helper(self):
        (self.app / "Contents/Helpers/SettleBellSignal").chmod(0o777)
        self.assert_rejected_by_both_app_validators("writable by group or others")

    def test_writable_root(self):
        self.app.chmod(0o775)
        self.assert_rejected_by_both_app_validators("writable by group or others")

    def test_writable_nested_directory(self):
        (self.app / "Contents/Resources").chmod(0o777)
        self.assert_rejected_by_both_app_validators("writable by group or others")

    def test_extended_acl(self):
        subprocess.run(["/bin/chmod", "+a", "everyone allow write", str(self.app / "Contents/Info.plist")], check=True)
        self.assert_rejected_by_both_app_validators("extended ACLs")

    def test_hardlink(self):
        os.link(self.app / "Contents/Info.plist", self.root / "outside-hardlink")
        self.assert_rejected_by_both_app_validators("hard-linked files")

    def test_fifo(self):
        os.mkfifo(self.app / "Contents/Resources/unexpected.fifo", 0o600)
        self.assert_rejected_by_both_app_validators("special objects")

    def test_symlink(self):
        (self.app / "Contents/Resources/link").symlink_to(self.app / "Contents/Info.plist")
        self.assert_rejected_by_both_app_validators("symlinks")

    def test_symlink_root(self):
        alias = self.root / "alias.app"
        alias.symlink_to(self.app)
        with self.assertRaisesRegex(ValueError, "root must be a real directory"):
            TREE.validate_tree(alias)

    def test_unexpected_modes(self):
        for mode in (0o444, 0o744, 0o4755):
            with self.subTest(mode=oct(mode)):
                (self.app / "Contents/Info.plist").chmod(mode)
                self.assert_rejected_by_both_app_validators("unexpected file or directory mode")

    def test_control_character_name(self):
        path = self.app / "Contents/Resources/item\nname"
        path.write_text("synthetic")
        path.chmod(0o600)
        self.assert_rejected_by_both_app_validators("control-character paths")

    def test_wrong_owner_expectation_without_chown(self):
        # Exercise owner rejection using real lstat metadata and an injected
        # effective UID. This is not an actual wrong-owner/chown acceptance test.
        with patch.object(TREE.os, "geteuid", return_value=os.geteuid() + 1):
            with self.assertRaisesRegex(ValueError, "effective user"):
                TREE.validate_tree(self.app)

    def test_acl_inspection_failure_is_closed(self):
        with patch.object(TREE.subprocess, "run", side_effect=subprocess.CalledProcessError(1, "ls")):
            with self.assertRaises(subprocess.CalledProcessError):
                TREE.validate_tree(self.app)

    def test_metadata_change_is_rejected(self):
        original = os.lstat
        calls = 0

        def changed(path):
            nonlocal calls
            result = original(path)
            calls += 1
            # validate_tree's root shape, validate's before, then its after.
            if calls == 3:
                fields = list(result)
                fields[1] += 1
                return os.stat_result(fields)
            return result

        with patch.object(TREE.os, "lstat", side_effect=changed):
            with self.assertRaisesRegex(ValueError, "changed during"):
                TREE.validate_tree(self.app)

    def prepare_synthetic_signed_shell(self):
        # Test the actual shell-to-Python wiring, NOT certificate validity. All
        # signing/security tools are synthetic, and Local.xcconfig exists only
        # in the disposable checkout, never in the real source checkout.
        team = "FIXTURETEAM"
        bundle = "org.fixture.SettleBell.macOS"
        container = "iCloud.org.fixture.SettleBell"
        local = self.checkout / "Config/Local.xcconfig"
        local.write_text(f"SETTLEBELL_DEVELOPMENT_TEAM = {team}\n"
                         f"SETTLEBELL_MACOS_BUNDLE_IDENTIFIER = {bundle}\n"
                         f"SETTLEBELL_CLOUDKIT_CONTAINER_IDENTIFIER = {container}\n"
                         "SETTLEBELL_CLOUDKIT_ACTIVATION = YES\n")
        with (self.app / "Contents/Info.plist").open("rb") as handle:
            plist = plistlib.load(handle)
        plist.update(CFBundleIdentifier=bundle, SettleBellCloudKitActivationEnabled="YES",
                     SettleBellCloudKitContainerIdentifier=container)
        (self.app / "Contents/Info.plist").write_bytes(plistlib.dumps(plist))
        (self.app / "Contents/embedded.provisionprofile").write_bytes(b"synthetic profile container")
        (self.app / "Contents/embedded.provisionprofile").chmod(0o644)
        entitlements = {
            "com.apple.developer.icloud-container-identifiers": [container],
            "com.apple.developer.icloud-services": ["CloudKit"],
            "com.apple.developer.team-identifier": team,
            "com.apple.application-identifier": f"{team}.{bundle}",
        }
        app_entitlements = self.root / "synthetic-app-entitlements.plist"
        helper_entitlements = self.root / "synthetic-helper-entitlements.plist"
        profile_path = self.root / "synthetic-profile.plist"
        app_entitlements.write_bytes(plistlib.dumps(entitlements))
        helper_entitlements.write_bytes(b"")
        profile_path.write_bytes(plistlib.dumps({
            "TeamIdentifier": [team], "ApplicationIdentifierPrefix": [team],
            "Entitlements": entitlements, "DeveloperCertificates": [b"synthetic-certificate"],
            "ExpirationDate": datetime.datetime(2099, 1, 1),
        }))
        (self.bin / "codesign").write_text('''#!/bin/bash
set -euo pipefail
if [[ "$1" == --verify ]]; then exit 0; fi
path="${@: -1}"
if [[ "$1" == -dv ]]; then
  identifier="$FIXTURE_BUNDLE"
  [[ "$path" != */SettleBellSignal ]] || identifier="$FIXTURE_HELPER_ID"
  printf 'Identifier=%s\\nTeamIdentifier=FIXTURETEAM\\nAuthority=Apple Development: Synthetic Fixture\\nflags=(runtime)\\n' "$identifier"
elif [[ "$2" == --entitlements ]]; then
  if [[ "$path" == */SettleBellSignal ]]; then
    [[ "${FIXTURE_HELPER_EXTRACTION_FAIL:-0}" == 0 ]] || exit 91
    /bin/cat "$FIXTURE_HELPER_ENTITLEMENTS"
  else
    /bin/cat "$FIXTURE_APP_ENTITLEMENTS"
  fi
elif [[ "$2" == --extract-certificates=* ]]; then
  printf synthetic-certificate > "${2#--extract-certificates=}0"
else
  exit 91
fi
''')
        (self.bin / "security").write_text('#!/bin/bash\n/bin/cat "$FIXTURE_PROFILE"\n')
        self.env.update(FIXTURE_BUNDLE=bundle, FIXTURE_HELPER_ID="SettleBellSignal",
                        FIXTURE_APP_ENTITLEMENTS=str(app_entitlements),
                        FIXTURE_HELPER_ENTITLEMENTS=str(helper_entitlements),
                        FIXTURE_PROFILE=str(profile_path))
        return entitlements, app_entitlements, helper_entitlements

    def test_signed_shell_extracts_and_rejects_extra_entitlements(self):
        entitlements, app_path, helper_path = self.prepare_synthetic_signed_shell()
        result = self.invoke("validate_signed_local_app.sh", self.app)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        for target, dictionary in ((app_path, {**entitlements, "get-task-allow": True}),
                                   (helper_path, {"get-task-allow": True})):
            with self.subTest(target=target.name):
                original = target.read_bytes()
                target.write_bytes(plistlib.dumps(dictionary))
                result = self.invoke("validate_signed_local_app.sh", self.app)
                self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
                self.assertIn("not approved", result.stderr)
                target.write_bytes(original)
        helper_path.write_bytes(b"malformed entitlement plist fixture")
        result = self.invoke("validate_signed_local_app.sh", self.app)
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("not approved", result.stderr)
        self.assertNotIn("Traceback", result.stderr)

    def test_signed_shell_checks_profile_cloudkit_authorization(self):
        self.prepare_synthetic_signed_shell()
        target = Path(self.env["FIXTURE_PROFILE"])
        profile = plistlib.loads(target.read_bytes())
        for services in (None, ["CloudDocuments"], ["CloudKit"], ["CloudKit", "CloudDocuments"]):
            with self.subTest(services=services):
                if services is None:
                    profile["Entitlements"].pop("com.apple.developer.icloud-services", None)
                else:
                    profile["Entitlements"]["com.apple.developer.icloud-services"] = services
                target.write_bytes(plistlib.dumps(profile))
                result = self.invoke("validate_signed_local_app.sh", self.app)
                expected = 0 if services and "CloudKit" in services else 1
                self.assertEqual(result.returncode, expected, result.stdout + result.stderr)

    def test_signed_shell_rejects_wrong_helper_identifier_and_extraction_failure(self):
        self.prepare_synthetic_signed_shell()
        self.env["FIXTURE_HELPER_ID"] = "OtherHelper"
        result = self.invoke("validate_signed_local_app.sh", self.app)
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("approved identifier", result.stderr)
        self.env.update(FIXTURE_HELPER_ID="SettleBellSignal", FIXTURE_HELPER_EXTRACTION_FAIL="1")
        result = self.invoke("validate_signed_local_app.sh", self.app)
        self.assertNotEqual(result.returncode, 0, "Failed entitlement extraction must not become an empty dictionary")

    def test_check_rejects_flags_on_extracted_fixture_before_signature(self):
        archive = self.root / "safe-metadata.zip"
        with zipfile.ZipFile(archive, "w") as output:
            for path in [self.app, *self.app.rglob("*")]:
                member = "SettleBell.app" + ("/" + path.relative_to(self.app).as_posix() if path != self.app else "")
                directory = path.is_dir()
                info = zipfile.ZipInfo(member + ("/" if directory else ""))
                info.create_system = 3
                info.external_attr = path.stat().st_mode << 16
                if directory:
                    info.external_attr |= 0x10
                output.writestr(info, b"" if directory else path.read_bytes())
        # ZIP need not encode BSD flags. Inject actual native owner flags ONLY
        # after genuine ditto extraction in disposable installer copies, to test
        # the boundary that receives preserved filesystem metadata. This is not
        # evidence that a particular ZIP format preserves a flag.
        injected = self.root / "injected-flag-paths"
        wrapper = self.bin / "ditto"
        wrapper.write_text('''#!/bin/bash
set -euo pipefail
/usr/bin/ditto "$@"
target="${@: -1}/SettleBell.app${FIXTURE_FLAG_RELATIVE:+/$FIXTURE_FLAG_RELATIVE}"
printf '%s\\n' "$target" >> "$FIXTURE_FLAG_PATHS"
/usr/bin/chflags "$FIXTURE_FLAG_NAME" "$target"
''')
        wrapper.chmod(0o700)
        self.env["FIXTURE_FLAG_PATHS"] = str(injected)
        for flag in ("uchg", "uappnd"):
            for relative in ("", "Contents/Helpers/SettleBellSignal", "Contents/Resources/resource.dat"):
                for script in ("install_source_local.sh", "install_signed_local.sh"):
                    with self.subTest(flag=flag, relative=relative, script=script):
                        self.env.update(FIXTURE_FLAG_NAME=flag, FIXTURE_FLAG_RELATIVE=relative)
                        injected.write_text("")
                        try:
                            result = self.invoke(script, "--check", archive)
                            self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
                            self.assertIn("BSD file flags", result.stderr)
                            self.assertFalse(self.trace.exists())
                            self.assertEqual(list(self.applications.iterdir()), [self.applications / "KEEP"])
                            self.assertEqual((self.applications / "KEEP").read_text(), "unchanged\n")
                        finally:
                            for name in injected.read_text().splitlines():
                                target = Path(name)
                                self.assertTrue(target.resolve().is_relative_to(self.root.resolve()))
                                if target.exists():
                                    flags = target.lstat().st_flags
                                    os.chflags(target, flags & ~(stat.UF_IMMUTABLE | stat.UF_APPEND))

    def test_check_refuses_unwritable_applications_without_mutation(self):
        archive = self.root / "unused.zip"
        archive.write_bytes(b"deliberately not a ZIP: write access must fail first")
        self.applications.chmod(0o555)
        try:
            for script in ("install_source_local.sh", "install_signed_local.sh"):
                result = self.invoke(script, "--check", archive)
                self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
                self.assertIn("not writable by the current user; no changes were made", result.stderr)
                self.assertFalse(self.trace.exists())
                self.assertEqual(list(self.applications.iterdir()), [self.applications / "KEEP"])
                self.assertEqual((self.applications / "KEEP").read_text(), "unchanged\n")
        finally:
            self.applications.chmod(0o755)

    def test_unsafe_zip_is_rejected_by_both_check_modes(self):
        # Real ZIP metadata and real ditto extraction, but sandboxed installer
        # copies and no signature stubs that report success. Canonical path,
        # signing and LaunchServices never reach the host.
        for relative, mode in (("Contents/Helpers/SettleBellSignal", 0o777),
                               ("", 0o775), ("Contents/Resources", 0o777)):
            with self.subTest(relative=relative):
                archive = self.root / "unsafe.zip"
                with zipfile.ZipFile(archive, "w") as output:
                    for path in [self.app, *self.app.rglob("*")]:
                        member = "SettleBell.app" + ("/" + path.relative_to(self.app).as_posix() if path != self.app else "")
                        is_directory = path.is_dir()
                        info = zipfile.ZipInfo(member + ("/" if is_directory else ""))
                        info.create_system = 3
                        permissions = mode if path == self.app / relative else stat.S_IMODE(path.stat().st_mode)
                        info.external_attr = ((stat.S_IFDIR if is_directory else stat.S_IFREG) | permissions) << 16
                        if is_directory:
                            info.external_attr |= 0x10
                        output.writestr(info, b"" if is_directory else path.read_bytes())
                for script in ("install_source_local.sh", "install_signed_local.sh"):
                    result = self.invoke(script, "--check", archive)
                    self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
                    self.assertIn("writable by group or others", result.stderr)
                    self.assertFalse(self.trace.exists())
                    self.assertEqual(list(self.applications.iterdir()), [self.applications / "KEEP"])
                    self.assertEqual((self.applications / "KEEP").read_text(), "unchanged\n")


class SignedMetadataTests(unittest.TestCase):
    def setUp(self):
        self.team = "FIXTURETEAM"
        self.bundle = "org.example.fixture.macOS"
        self.container = "iCloud.org.example.fixture"
        self.certificate = b"synthetic certificate fixture, not a real certificate"
        self.entitlements = {
            "com.apple.developer.icloud-container-identifiers": [self.container],
            "com.apple.developer.icloud-services": ["CloudKit"],
            "com.apple.developer.team-identifier": self.team,
            "com.apple.application-identifier": f"{self.team}.{self.bundle}",
        }
        self.helper = {}
        self.profile = {
            "TeamIdentifier": [self.team], "ApplicationIdentifierPrefix": [self.team],
            "Entitlements": copy.deepcopy(self.entitlements),
            "DeveloperCertificates": [self.certificate],
            "ExpirationDate": datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(days=1),
            "UUID": "synthetic-profile-A",
        }

    def validate(self, helper_certificate=None):
        METADATA.validate_metadata(self.entitlements, self.helper, self.profile,
                                   self.certificate, helper_certificate or self.certificate,
                                   self.team, self.bundle, self.container)

    def test_exact_metadata(self):
        self.validate()

    def test_extra_app_entitlements(self):
        for key, value in (("get-task-allow", True), ("keychain-access-groups", ["synthetic"]),
                           ("com.apple.security.application-groups", ["synthetic"]),
                           ("unknown-capability", False)):
            with self.subTest(key=key):
                self.entitlements[key] = value
                with self.assertRaisesRegex(ValueError, "only the exact"):
                    self.validate()
                del self.entitlements[key]

    def test_extra_helper_entitlement(self):
        self.helper["get-task-allow"] = True
        with self.assertRaisesRegex(ValueError, "helper must not"):
            self.validate()

    def test_expanded_container_or_service(self):
        for key, value in (("com.apple.developer.icloud-container-identifiers", "iCloud.org.example.extra"),
                           ("com.apple.developer.icloud-services", "CloudDocuments")):
            with self.subTest(key=key):
                self.entitlements[key].append(value)
                with self.assertRaisesRegex(ValueError, "only the exact"):
                    self.validate()
                self.entitlements[key].pop()

    def test_missing_entitlement(self):
        del self.entitlements["com.apple.application-identifier"]
        with self.assertRaisesRegex(ValueError, "only the exact"):
            self.validate()

    def test_different_same_team_profile_is_not_identity_pinned(self):
        # Deliberately allowed by the narrowed documented authorization policy:
        # actual app/helper entitlements stay exact despite a broader profile.
        self.profile["UUID"] = "synthetic-profile-B"
        self.profile["Entitlements"]["keychain-access-groups"] = ["synthetic"]
        self.validate()
        self.entitlements["keychain-access-groups"] = ["synthetic"]
        with self.assertRaisesRegex(ValueError, "only the exact"):
            self.validate()

    def test_profile_cloudkit_service_authorization(self):
        profile_entitlements = self.profile["Entitlements"]
        for services in (None, [], ["CloudDocuments"], "CloudKit", {"CloudKit": True}, ["CloudKit", 1]):
            with self.subTest(services=services):
                if services is None:
                    profile_entitlements.pop("com.apple.developer.icloud-services", None)
                else:
                    profile_entitlements["com.apple.developer.icloud-services"] = services
                with self.assertRaisesRegex(ValueError, "does not authorize"):
                    self.validate()
        profile_entitlements["com.apple.developer.icloud-services"] = ["CloudKit"]
        self.validate()
        profile_entitlements["com.apple.developer.icloud-services"] = ["CloudKit", "CloudDocuments"]
        self.validate()  # Broader profile ceiling does not widen the actual app.
        self.entitlements["com.apple.developer.icloud-services"].append("CloudDocuments")
        with self.assertRaisesRegex(ValueError, "only the exact"):
            self.validate()

    def test_profile_identity_and_authorization(self):
        for key, value in (("TeamIdentifier", ["OTHERTEAM"]),
                           ("ApplicationIdentifierPrefix", ["OTHERTEAM"]),
                           ("DeveloperCertificates", [b"other synthetic certificate"]),
                           ("Entitlements", []),
                           ("ExpirationDate", datetime.datetime(2000, 1, 1))):
            with self.subTest(key=key):
                original = self.profile[key]
                self.profile[key] = value
                with self.assertRaises(ValueError):
                    self.validate()
                self.profile[key] = original

    def test_different_helper_certificate(self):
        with self.assertRaisesRegex(ValueError, "different leaf certificates"):
            self.validate(helper_certificate=b"other synthetic certificate")


if __name__ == "__main__":
    unittest.main(verbosity=2)
