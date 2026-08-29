#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARCHIVE="${1:-}"
MAX_ARCHIVE_BYTES=$((100 * 1024 * 1024))
MAX_EXPANDED_BYTES=$((500 * 1024 * 1024))
MAX_ARCHIVE_ENTRIES=2048

if [[ $# -ne 1 || ! -f "$ARCHIVE" || -L "$ARCHIVE" ]]; then
  echo "usage: $0 path/to/PiPing.app.zip" >&2
  exit 2
fi
archive_bytes="$(stat -f %z "$ARCHIVE")"
if [[ "$archive_bytes" -gt "$MAX_ARCHIVE_BYTES" ]]; then
  echo "Source-local archive exceeds the 100 MiB limit." >&2
  exit 1
fi
if zipinfo -l "$ARCHIVE" | grep -E '^l[-rwx]{9}[[:space:]]' >/dev/null; then
  echo "Source-local archive must not contain symbolic links." >&2
  exit 1
fi
archive_entry_count="$(zipinfo -1 "$ARCHIVE" | awk 'END {print NR+0}')"
expanded_bytes="$(unzip -l "$ARCHIVE" | tail -1 | awk '{print $1}')"
if [[ "$archive_entry_count" -eq 0 || "$archive_entry_count" -gt "$MAX_ARCHIVE_ENTRIES" \
   || ! "$expanded_bytes" =~ ^[0-9]+$ || "$expanded_bytes" -gt "$MAX_EXPANDED_BYTES" ]]; then
  echo "Source-local archive entry count or expanded size exceeds the guarded limit." >&2
  exit 1
fi
while IFS= read -r archive_path; do
  case "$archive_path" in
    PiPing.app/*) ;;
    *)
      echo "Source-local archive contains content outside PiPing.app." >&2
      exit 1
      ;;
  esac
  if [[ "$archive_path" == /* || "$archive_path" == *\\* \
     || "$archive_path" == ".." || "$archive_path" == ../* \
     || "$archive_path" == */../* || "$archive_path" == */.. ]]; then
    echo "Source-local archive contains an unsafe path." >&2
    exit 1
  fi
done < <(zipinfo -1 "$ARCHIVE")

unzip -tq "$ARCHIVE"
STAGE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/piping-source-archive-validation.XXXXXX")"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
cleanup() {
  "$LSREGISTER" -u "$STAGE_ROOT/PiPing.app" 2>/dev/null || true
  rm -rf "$STAGE_ROOT"
}
trap cleanup EXIT
ditto -x -k "$ARCHIVE" "$STAGE_ROOT"
if [[ ! -d "$STAGE_ROOT/PiPing.app" ]]; then
  echo "Source-local archive does not contain PiPing.app at its root." >&2
  exit 1
fi
"$ROOT_DIR/script/validate_source_local_app.sh" "$STAGE_ROOT/PiPing.app" >/dev/null
echo "Source-local PiPing archive is valid and restorable."
