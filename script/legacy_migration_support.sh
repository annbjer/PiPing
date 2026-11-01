#!/usr/bin/env bash
# Trusted-input and manifest helpers for legacy source-local migration. The
# caller must use set -euo pipefail and a private staging destination.

legacy_pin_archive() {
  local source_archive="$1"
  local pinned_archive="$2"
  local expected_sha256="$3"
  local validator="$4"
  local maximum_bytes=$((100 * 1024 * 1024))
  local source_bytes actual_sha256

  if [[ ! "$expected_sha256" =~ ^[0-9a-f]{64}$ ]]; then
    echo "The trusted legacy archive SHA-256 must be 64 lowercase hexadecimal characters." >&2
    return 2
  fi
  if [[ ! -f "$source_archive" || -L "$source_archive" ]]; then
    echo "The trusted legacy archive is missing or is a symbolic link." >&2
    return 1
  fi
  source_bytes="$(stat -f %z "$source_archive")"
  if [[ "$source_bytes" -gt "$maximum_bytes" ]]; then
    echo "The trusted legacy archive exceeds the 100 MiB limit." >&2
    return 1
  fi
  dd if="$source_archive" of="$pinned_archive" bs=1048576 count=101 2>/dev/null
  chmod 600 "$pinned_archive"
  if [[ "$(stat -f %z "$pinned_archive")" -gt "$maximum_bytes" ]]; then
    echo "The trusted legacy archive changed or exceeded the bounded-copy limit." >&2
    return 1
  fi
  actual_sha256="$(shasum -a 256 "$pinned_archive" | awk '{print $1}')"
  if [[ "$actual_sha256" != "$expected_sha256" ]]; then
    echo "The trusted legacy archive SHA-256 does not match." >&2
    return 1
  fi
  "$validator" "$pinned_archive" >/dev/null
}

legacy_app_manifest() {
  python3 - "$1" <<'PY'
import hashlib
import stat
import sys
from pathlib import Path

root = Path(sys.argv[1])
for path in sorted([root, *root.rglob("*")], key=lambda item: str(item.relative_to(root))):
    relative = "." if path == root else str(path.relative_to(root))
    info = path.lstat()
    mode = stat.S_IMODE(info.st_mode)
    if stat.S_ISLNK(info.st_mode):
        raise SystemExit("legacy app manifest refuses symbolic links")
    if stat.S_ISREG(info.st_mode):
        if info.st_nlink != 1:
            raise SystemExit("legacy app manifest refuses hard-linked files")
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        print(f"f\t{info.st_uid}\t{info.st_gid}\t{mode:o}\t{info.st_size}\t{digest}\t{relative}")
    elif stat.S_ISDIR(info.st_mode):
        print(f"d\t{info.st_uid}\t{info.st_gid}\t{mode:o}\t0\t-\t{relative}")
    else:
        raise SystemExit(f"legacy app manifest refuses special object: {relative}")
PY
}

legacy_manifest_matches_reference() {
  local candidate_manifest
  candidate_manifest="$(legacy_app_manifest "$1")" || return 1
  [[ "$candidate_manifest" == "$LEGACY_REFERENCE_MANIFEST" ]]
}
