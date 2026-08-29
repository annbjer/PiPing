#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARCHIVE="${1:-}"
MAX_ARCHIVE_BYTES=$((100 * 1024 * 1024))
MAX_EXPANDED_BYTES=$((500 * 1024 * 1024))
MAX_ARCHIVE_ENTRIES=4096

if [[ $# -ne 1 || ! -f "$ARCHIVE" || -L "$ARCHIVE" ]]; then
  echo "usage: $0 path/to/PiPing.app.zip" >&2
  exit 2
fi
archive_bytes="$(stat -f %z "$ARCHIVE")"
if [[ "$archive_bytes" -gt "$MAX_ARCHIVE_BYTES" ]]; then
  echo "Signed local archive exceeds the 100 MiB limit." >&2
  exit 1
fi
if zipinfo -l "$ARCHIVE" | grep -E '^l[-rwx]{9}[[:space:]]' >/dev/null; then
  echo "Signed local archive must not contain symbolic links." >&2
  exit 1
fi
archive_entry_count="$(zipinfo -1 "$ARCHIVE" | awk 'END {print NR+0}')"
expanded_bytes="$(unzip -l "$ARCHIVE" | tail -1 | awk '{print $1}')"
if [[ "$archive_entry_count" -eq 0 || "$archive_entry_count" -gt "$MAX_ARCHIVE_ENTRIES" \
   || ! "$expanded_bytes" =~ ^[0-9]+$ || "$expanded_bytes" -gt "$MAX_EXPANDED_BYTES" ]]; then
  echo "Signed local archive entry count or expanded size exceeds the guarded limit." >&2
  exit 1
fi
while IFS= read -r archive_path; do
  case "$archive_path" in
    PiPing.app/*|__MACOSX/|__MACOSX/._PiPing.app) ;;
    __MACOSX/PiPing.app/*)
      metadata_basename="${archive_path##*/}"
      if [[ "$archive_path" != */ && "$metadata_basename" != ._* ]]; then
        echo "Signed local archive contains non-AppleDouble side metadata." >&2
        exit 1
      fi
      ;;
    *)
      echo "Signed local archive contains content outside PiPing.app metadata." >&2
      exit 1
      ;;
  esac
  if [[ "$archive_path" == /* || "$archive_path" == *\\* \
     || "$archive_path" == ".." || "$archive_path" == ../* \
     || "$archive_path" == */../* || "$archive_path" == */.. ]]; then
    echo "Signed local archive contains an unsafe path." >&2
    exit 1
  fi
done < <(zipinfo -1 "$ARCHIVE")

unzip -tq "$ARCHIVE"
STAGE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/piping-signed-archive-validation.XXXXXX")"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
cleanup() {
  "$LSREGISTER" -u "$STAGE_ROOT/PiPing.app" 2>/dev/null || true
  rm -rf "$STAGE_ROOT"
}
trap cleanup EXIT
ditto -x -k "$ARCHIVE" "$STAGE_ROOT"
if [[ ! -d "$STAGE_ROOT/PiPing.app" ]]; then
  echo "Signed local archive does not contain PiPing.app at its root." >&2
  exit 1
fi
"$ROOT_DIR/script/validate_signed_local_app.sh" "$STAGE_ROOT/PiPing.app" >/dev/null
echo "Signed local PiPing archive is valid and restorable."
