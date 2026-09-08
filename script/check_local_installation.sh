#!/usr/bin/env bash
set -euo pipefail

# Classification selects a validator; it is not itself validation. Do not fall
# back to a different installation class if the selected validator rejects it.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CANONICAL_APP="/Applications/SettleBell.app"
PLIST="$CANONICAL_APP/Contents/Info.plist"
reject() {
  echo "Canonical SettleBell installation is missing or has an invalid identity." >&2
  exit 1
}
[[ "$#" -eq 0 ]] || reject
[[ -d "$CANONICAL_APP" && ! -L "$CANONICAL_APP" &&
   ! -L "$CANONICAL_APP/Contents" && -f "$PLIST" && ! -L "$PLIST" ]] || reject
BUNDLE_IDENTIFIER="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$PLIST" 2>/dev/null)" || reject
DISPLAY_NAME="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleDisplayName' "$PLIST" 2>/dev/null)" || reject
[[ -n "$BUNDLE_IDENTIFIER" && -n "$DISPLAY_NAME" ]] || reject

if [[ "$BUNDLE_IDENTIFIER" == "org.example.SettleBell.macOS" ||
      "$DISPLAY_NAME" == "SettleBell Development" ]]; then
  [[ "$BUNDLE_IDENTIFIER" == "org.example.SettleBell.macOS" &&
     "$DISPLAY_NAME" == "SettleBell Development" ]] || reject
  CHECKER="check_source_installation.sh"
else
  CHECKER="check_installation.sh"
fi
# A caller's private-check path override must not redirect a generic canonical check.
exec /usr/bin/env -u SETTLEBELL_CANONICAL_APP "$ROOT_DIR/script/$CHECKER"
