#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="${1:-}"
PUBLIC_BUNDLE_IDENTIFIER="org.example.SettleBell.macOS"
PUBLIC_CONTAINER_IDENTIFIER="iCloud.org.example.SettleBell"

if [[ $# -ne 1 || -z "$APP" ]]; then
  echo "usage: $0 path/to/SettleBell.app" >&2
  exit 2
fi
if [[ ! -d "$APP" || ! -f "$APP/Contents/Info.plist" ]]; then
  echo "Source-local SettleBell app is missing or malformed." >&2
  exit 1
fi
"$ROOT_DIR/script/validate_local_app_tree.sh" "$APP"

PLIST="$APP/Contents/Info.plist"
EXECUTABLE="$APP/Contents/MacOS/SettleBell"
HELPER="$APP/Contents/Helpers/SettleBellSignal"
if [[ ! -x "$EXECUTABLE" || ! -x "$HELPER" ]]; then
  echo "Source-local SettleBell executable or helper is missing." >&2
  exit 1
fi

bundle_identifier="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$PLIST")"
bundle_executable="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$PLIST")"
display_name="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleDisplayName' "$PLIST")"
cloud_activation="$(/usr/libexec/PlistBuddy -c 'Print :SettleBellCloudKitActivationEnabled' "$PLIST")"
cloud_container="$(/usr/libexec/PlistBuddy -c 'Print :SettleBellCloudKitContainerIdentifier' "$PLIST")"
if [[ "$bundle_identifier" != "$PUBLIC_BUNDLE_IDENTIFIER" \
   || "$bundle_executable" != "SettleBell" \
   || "$display_name" != "SettleBell Development" \
   || "$cloud_activation" != "NO" \
   || "$cloud_container" != "$PUBLIC_CONTAINER_IDENTIFIER" ]]; then
  echo "Source-local SettleBell app does not use the exact public-safe identity and configuration." >&2
  exit 1
fi
if [[ -e "$APP/Contents/embedded.provisionprofile" ]]; then
  echo "Source-local SettleBell app must not contain a provisioning profile." >&2
  exit 1
fi

codesign --verify --deep --strict "$APP" >/dev/null
codesign --verify --strict "$HELPER" >/dev/null

signature_details() {
  codesign -dv --verbose=4 "$1" 2>&1
}
for binary in "$APP" "$HELPER"; do
  details="$(signature_details "$binary")"
  if [[ "$details" != *"Signature=adhoc"* \
     || "$details" != *"TeamIdentifier=not set"* \
     || "$details" != *"runtime"* \
     || "$details" == *"Authority="* ]]; then
    echo "Source-local SettleBell app and helper must use only ad-hoc hardened-runtime signatures." >&2
    exit 1
  fi
done

TEMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/settlebell-source-validation.XXXXXX")"
trap 'rm -rf "$TEMP_ROOT"' EXIT
for binary in "$APP" "$HELPER"; do
  ENTITLEMENTS="$TEMP_ROOT/entitlements-$(basename "$binary").plist"
  codesign -d --entitlements - --xml "$binary" >"$ENTITLEMENTS" 2>/dev/null || true
  if [[ -s "$ENTITLEMENTS" ]] && grep -q '<key>' "$ENTITLEMENTS"; then
    echo "Source-local SettleBell app and helper must not contain capability entitlements." >&2
    exit 1
  fi
done

echo "Source-local app tree, app/helper identity, configuration, signatures, runtime, and entitlements are valid."
