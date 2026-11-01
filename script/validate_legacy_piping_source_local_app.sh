#!/usr/bin/env bash
set -euo pipefail

APP="${1:-}"
PUBLIC_BUNDLE_IDENTIFIER="org.example.PiPing.macOS"
PUBLIC_CONTAINER_IDENTIFIER="iCloud.org.example.PiPing"

if [[ $# -ne 1 || -z "$APP" ]]; then
  echo "usage: $0 path/to/PiPing.app" >&2
  exit 2
fi
if [[ ! -d "$APP" || ! -f "$APP/Contents/Info.plist" ]]; then
  echo "Source-local PiPing app is missing or malformed." >&2
  exit 1
fi
if find "$APP" -type l -print -quit | grep -q .; then
  echo "Source-local PiPing app must not contain symbolic links." >&2
  exit 1
fi

PLIST="$APP/Contents/Info.plist"
EXECUTABLE="$APP/Contents/MacOS/PiPing"
HELPER="$APP/Contents/Helpers/PiPingSignal"
if [[ ! -x "$EXECUTABLE" || ! -x "$HELPER" ]]; then
  echo "Source-local PiPing executable or helper is missing." >&2
  exit 1
fi

bundle_identifier="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$PLIST")"
bundle_executable="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$PLIST")"
display_name="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleDisplayName' "$PLIST")"
marketing_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PLIST")"
build_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$PLIST")"
cloud_activation="$(/usr/libexec/PlistBuddy -c 'Print :PiPingCloudKitActivationEnabled' "$PLIST")"
cloud_container="$(/usr/libexec/PlistBuddy -c 'Print :PiPingCloudKitContainerIdentifier' "$PLIST")"
if [[ "$bundle_identifier" != "$PUBLIC_BUNDLE_IDENTIFIER" \
   || "$bundle_executable" != "PiPing" \
   || "$display_name" != "PiPing Development" \
   || "$marketing_version" != "0.1.0" \
   || "$build_version" != "15" \
   || "$cloud_activation" != "NO" \
   || "$cloud_container" != "$PUBLIC_CONTAINER_IDENTIFIER" ]]; then
  echo "Source-local PiPing app does not use the exact public-safe identity and configuration." >&2
  exit 1
fi
if [[ -e "$APP/Contents/embedded.provisionprofile" ]]; then
  echo "Source-local PiPing app must not contain a provisioning profile." >&2
  exit 1
fi
if find "$APP" -type f -links +1 -print -quit | grep -q .; then
  echo "Source-local PiPing app must not contain hard-linked files." >&2
  exit 1
fi
while IFS= read -r app_path; do
  if ls -lde "$app_path" 2>/dev/null | awk 'NR > 1 {found=1} END {exit found ? 0 : 1}'; then
    echo "Source-local PiPing app must not contain extended ACLs." >&2
    exit 1
  fi
done < <(find "$APP" -print)

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
    echo "Source-local PiPing app and helper must use only ad-hoc hardened-runtime signatures." >&2
    exit 1
  fi
done

TEMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/piping-source-validation.XXXXXX")"
trap 'rm -rf "$TEMP_ROOT"' EXIT
for binary in "$APP" "$HELPER"; do
  ENTITLEMENTS="$TEMP_ROOT/entitlements-$(basename "$binary").plist"
  codesign -d --entitlements - --xml "$binary" >"$ENTITLEMENTS" 2>/dev/null || true
  if [[ -s "$ENTITLEMENTS" ]] && grep -q '<key>' "$ENTITLEMENTS"; then
    echo "Source-local PiPing app and helper must not contain capability entitlements." >&2
    exit 1
  fi
done

echo "Source-local app/helper identity, configuration, signatures, runtime, and entitlements are valid."
