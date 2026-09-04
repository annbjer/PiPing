#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CANONICAL_APP="/Applications/SettleBell.app"
CANONICAL_EXECUTABLE="$CANONICAL_APP/Contents/MacOS/SettleBell"
PLIST="$CANONICAL_APP/Contents/Info.plist"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

"$ROOT_DIR/script/validate_source_local_app.sh" "$CANONICAL_APP"

PIDS="$(pgrep -x SettleBell || true)"
PID_COUNT="$(printf '%s\n' "$PIDS" | awk 'NF { count += 1 } END { print count + 0 }')"
if [[ "$PID_COUNT" -ne 1 ]]; then
  echo "Expected one SettleBell process; found $PID_COUNT" >&2
  exit 1
fi
while IFS= read -r pid; do
  [[ -n "$pid" ]] || continue
  COMMAND="$(ps -p "$pid" -o command=)"
  if [[ "$COMMAND" != "$CANONICAL_EXECUTABLE" ]]; then
    echo "SettleBell is running from a noncanonical path." >&2
    exit 1
  fi
done <<< "$PIDS"

BUNDLE_IDENTIFIER="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$PLIST")"
MARKETING_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PLIST")"
BUILD_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$PLIST")"
LS_DUMP="$(mktemp "${TMPDIR:-/tmp}/settlebell-source-ls.XXXXXX")"
trap 'rm -f "$LS_DUMP"' EXIT
"$LSREGISTER" -dump >"$LS_DUMP" 2>/dev/null
MATCHES="$(mktemp "${TMPDIR:-/tmp}/settlebell-source-ls-matches.XXXXXX")"
trap 'rm -f "$LS_DUMP" "$MATCHES"' EXIT
awk -v expected="$BUNDLE_IDENTIFIER" '
  /^-+$/ {
    if (identifier == expected && path != "") print path
    identifier = ""
    path = ""
    next
  }
  /^identifier:[[:space:]]+/ {
    value = $0
    sub(/^identifier:[[:space:]]+/, "", value)
    sub(/[[:space:]].*$/, "", value)
    identifier = value
    next
  }
  /^path:[[:space:]]+/ {
    value = $0
    sub(/^path:[[:space:]]+/, "", value)
    sub(/[[:space:]]+\(0x[[:xdigit:]]+\).*$/, "", value)
    path = value
  }
  END {
    if (identifier == expected && path != "") print path
  }
' "$LS_DUMP" | sort -u >"$MATCHES"
MATCH_COUNT="$(awk 'NF {count++} END {print count+0}' "$MATCHES")"
MATCH_PATH="$(awk 'NF {print; exit}' "$MATCHES")"
if [[ "$MATCH_COUNT" -ne 1 || "$MATCH_PATH" != "$CANONICAL_APP" ]]; then
  echo "Expected exactly one canonical LaunchServices registration." >&2
  exit 1
fi

echo "Source-local SettleBell installation is valid:"
echo "  $MARKETING_VERSION ($BUILD_VERSION), $BUNDLE_IDENTIFIER"
echo "  one ad-hoc app/helper, one process, one LaunchServices path"
