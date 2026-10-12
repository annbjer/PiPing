"""Reject unsafe app metadata; do not repair it or inspect signing credentials."""

import os
import stat
import subprocess
import sys


def reject(reason):
    raise ValueError("Local SettleBell app tree " + reason + ".")


def validate(path, relative):
    if any(ord(character) < 32 or ord(character) == 127 for character in path):
        reject("must not contain control-character paths")
    before = os.lstat(path)
    if before.st_uid != os.geteuid():
        reject("must be owned entirely by the effective user")
    mode = stat.S_IMODE(before.st_mode)
    if mode & 0o022:
        reject("must not be writable by group or others")
    if stat.S_ISDIR(before.st_mode):
        allowed_modes = {0o700, 0o755}
    elif stat.S_ISREG(before.st_mode):
        if before.st_nlink != 1:
            reject("must not contain hard-linked files")
        allowed_modes = (
            {0o700, 0o755}
            if relative in {"Contents/MacOS/SettleBell", "Contents/Helpers/SettleBellSignal"}
            else {0o600, 0o644}
        )
    else:
        reject("must contain only real directories and regular files (no symlinks or special objects)")
    if mode not in allowed_modes:
        reject("has an unexpected file or directory mode")
    acl = subprocess.run(["/bin/ls", "-lde", path], capture_output=True, check=True)
    # On macOS, -e emits each extended ACL entry on a separate line. Paths
    # containing line/control characters were rejected above, not parsed as ACLs.
    if len(acl.stdout.splitlines()) != 1:
        reject("must not contain extended ACLs")
    after = os.lstat(path)
    def identity(value):
        return (value.st_dev, value.st_ino, value.st_uid, value.st_mode,
                value.st_nlink, value.st_ctime_ns)
    if identity(before) != identity(after):
        reject("changed during metadata validation")
    if stat.S_ISDIR(before.st_mode):
        with os.scandir(path) as entries:
            for entry in entries:
                child_relative = f"{relative}/{entry.name}" if relative else entry.name
                validate(entry.path, child_relative)


def validate_tree(path):
    root = os.path.abspath(path)
    if not stat.S_ISDIR(os.lstat(root).st_mode):
        reject("root must be a real directory")
    validate(root, "")


if __name__ == "__main__":
    try:
        if len(sys.argv) != 2:
            raise ValueError("usage: validate_local_app_tree.py path/to/SettleBell.app")
        validate_tree(sys.argv[1])
    except (OSError, ValueError, subprocess.SubprocessError, RecursionError) as error:
        message = str(error) if isinstance(error, ValueError) else "Local SettleBell app tree could not be safely inspected."
        raise SystemExit(message)
