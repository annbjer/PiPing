#!/usr/bin/env bash
set -euo pipefail

CANONICAL_APP="${PIPING_CANONICAL_APP:-/Applications/PiPing.app}"
CANONICAL_EXECUTABLE="$CANONICAL_APP/Contents/MacOS/PiPing"
CANONICAL_HELPER="$CANONICAL_APP/Contents/Helpers/PiPingSignal"
PLIST="$CANONICAL_APP/Contents/Info.plist"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
PUBLIC_BUNDLE_IDENTIFIER="org.example.PiPing.macOS"

if [[ ! -d "$CANONICAL_APP" || ! -f "$PLIST" ]]; then
  echo "Missing canonical PiPing installation: $CANONICAL_APP" >&2
  exit 1
fi

BUNDLE_IDENTIFIER="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$PLIST")"
MARKETING_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PLIST")"
BUILD_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$PLIST")"
DISPLAY_NAME="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleDisplayName' "$PLIST" 2>/dev/null || true)"

if [[ "$BUNDLE_IDENTIFIER" == "$PUBLIC_BUNDLE_IDENTIFIER" || "$DISPLAY_NAME" == "PiPing Development" ]]; then
  echo "Public-safe development output cannot be the canonical installation" >&2
  exit 1
fi
if [[ ! -x "$CANONICAL_EXECUTABLE" || ! -x "$CANONICAL_HELPER" ]]; then
  echo "Canonical executable or helper is missing" >&2
  exit 1
fi

"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/validate_signed_local_app.sh" "$CANONICAL_APP"

PIDS="$(pgrep -x PiPing || true)"
PID_COUNT="$(printf '%s\n' "$PIDS" | awk 'NF { count += 1 } END { print count + 0 }')"
if [[ "$PID_COUNT" -ne 1 ]]; then
  echo "Expected one PiPing process; found $PID_COUNT" >&2
  exit 1
fi

while IFS= read -r pid; do
  [[ -n "$pid" ]] || continue
  COMMAND="$(ps -p "$pid" -o command=)"
  if [[ "$COMMAND" != "$CANONICAL_EXECUTABLE" ]]; then
    echo "PiPing is running from a noncanonical path: $COMMAND" >&2
    exit 1
  fi
done <<< "$PIDS"

LS_DUMP="$(mktemp "${TMPDIR:-/tmp}/piping-ls.XXXXXX")"
trap 'rm -f "$LS_DUMP"' EXIT
"$LSREGISTER" -dump > "$LS_DUMP" 2>/dev/null
python3 - "$LS_DUMP" "$BUNDLE_IDENTIFIER" "$CANONICAL_APP" <<'PY'
import os
import re
import sys

path, expected_identifier, expected_path = sys.argv[1:]
text = open(path, encoding="utf-8", errors="replace").read()
blocks = re.split(r"-{40,}", text)
current_paths = set()
stale_native = []
for block in blocks:
    identifier_match = re.search(r"^identifier:\s+([^\s]+)", block, re.MULTILINE)
    path_match = re.search(r"^path:\s+(.+?)\s+\(0x", block, re.MULTILINE)
    platform_match = re.search(r"^platform:\s+([^\s]+)", block, re.MULTILINE)
    if not identifier_match or not path_match:
        continue
    identifier = identifier_match.group(1)
    bundle_path = path_match.group(1)
    platform = platform_match.group(1) if platform_match else ""
    if identifier == expected_identifier:
        current_paths.add(os.path.realpath(bundle_path))
    elif identifier.startswith("app.piping.") and platform == "native":
        stale_native.append((identifier, bundle_path))

expected_realpath = os.path.realpath(expected_path)
if current_paths != {expected_realpath}:
    print(
        f"Expected one LaunchServices path for {expected_identifier}: "
        f"{expected_realpath}; found {sorted(current_paths)}",
        file=sys.stderr,
    )
    raise SystemExit(1)
if stale_native:
    print("Stale native PiPing registrations remain:", file=sys.stderr)
    for identifier, bundle_path in stale_native:
        print(f"  {identifier}: {bundle_path}", file=sys.stderr)
    raise SystemExit(1)
PY

echo "  $MARKETING_VERSION ($BUILD_VERSION), $BUNDLE_IDENTIFIER"
echo "  one signed app/helper team, one process, one LaunchServices path"
echo "  helper: $CANONICAL_HELPER"
