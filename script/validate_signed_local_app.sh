#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOCAL_CONFIG="$ROOT_DIR/Config/Local.xcconfig"
APP="${1:-}"

if [[ -z "$APP" || $# -ne 1 ]]; then
  echo "usage: $0 path/to/SettleBell.app" >&2
  exit 2
fi
if [[ ! -d "$APP" || ! -f "$APP/Contents/Info.plist" ]]; then
  echo "Signed local SettleBell app is missing or malformed." >&2
  exit 1
fi
"$ROOT_DIR/script/validate_local_app_tree.sh" "$APP"
if [[ ! -f "$LOCAL_CONFIG" ]]; then
  echo "Ignored Config/Local.xcconfig is required for identity validation." >&2
  exit 1
fi

config_value() {
  local key="$1"
  awk -F= -v key="$key" '
    $1 ~ "^[[:space:]]*" key "[[:space:]]*$" {
      sub(/^[^=]*=[[:space:]]*/, "")
      sub(/[[:space:]]*$/, "")
      print
      found = 1
      next
    }
    END { if (!found) exit 1 }
  ' "$LOCAL_CONFIG"
}

expected_team="$(config_value SETTLEBELL_DEVELOPMENT_TEAM)"
expected_bundle="$(config_value SETTLEBELL_MACOS_BUNDLE_IDENTIFIER)"
expected_container="$(config_value SETTLEBELL_CLOUDKIT_CONTAINER_IDENTIFIER)"
expected_activation="$(config_value SETTLEBELL_CLOUDKIT_ACTIVATION)"
for value in "$expected_team" "$expected_bundle" "$expected_container"; do
  if [[ -z "$value" || "$value" == *PLACEHOLDER* || "$value" == org.example.* ]]; then
    echo "Ignored local signing configuration is incomplete." >&2
    exit 1
  fi
done
if [[ "$expected_activation" != "YES" ]]; then
  echo "Ignored local signing configuration must explicitly enable CloudKit." >&2
  exit 1
fi

HELPER="$APP/Contents/Helpers/SettleBellSignal"
PROFILE="$APP/Contents/embedded.provisionprofile"
if [[ ! -x "$HELPER" || ! -f "$PROFILE" ]]; then
  echo "Signed local app is missing its helper or provisioning profile." >&2
  exit 1
fi
bundle_identifier="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Contents/Info.plist")"
cloud_activation="$(/usr/libexec/PlistBuddy -c 'Print :SettleBellCloudKitActivationEnabled' "$APP/Contents/Info.plist")"
cloud_container="$(/usr/libexec/PlistBuddy -c 'Print :SettleBellCloudKitContainerIdentifier' "$APP/Contents/Info.plist")"
if [[ "$bundle_identifier" != "$expected_bundle" ]]; then
  echo "Signed local app does not use the approved bundle identity." >&2
  exit 1
fi
if [[ "$cloud_activation" != "$expected_activation" \
   || "$cloud_container" != "$expected_container" ]]; then
  echo "Signed local app does not use the exact approved CloudKit metadata." >&2
  exit 1
fi

codesign --verify --deep --strict --verbose=2 "$APP" >/dev/null

signature_field() {
  local path="$1"
  local key="$2"
  codesign -dv --verbose=4 "$path" 2>&1 \
    | awk -F= -v key="$key" '$1 == key && !found {print $2; found=1}'
}

app_team="$(signature_field "$APP" TeamIdentifier)"
helper_team="$(signature_field "$HELPER" TeamIdentifier)"
app_identifier="$(signature_field "$APP" Identifier)"
helper_identifier="$(signature_field "$HELPER" Identifier)"
app_authority="$(signature_field "$APP" Authority)"
helper_authority="$(signature_field "$HELPER" Authority)"

if [[ "$app_identifier" != "$expected_bundle" || "$helper_identifier" != "SettleBellSignal" ]]; then
  echo "Signed local app/helper signature does not use the approved identifier." >&2
  exit 1
fi
if [[ "$app_team" != "$expected_team" || "$helper_team" != "$expected_team" ]]; then
  echo "Signed local app and helper do not use the approved development team." >&2
  exit 1
fi
if [[ "$app_authority" != "Apple Development:"* || "$helper_authority" != "Apple Development:"* ]]; then
  echo "Signed local app and helper must use Apple Development certificates." >&2
  exit 1
fi
apple_development_requirement="anchor apple generic and certificate leaf[field.1.2.840.113635.100.6.1.2] exists and certificate leaf[field.1.2.840.113635.100.6.1.12] exists and certificate leaf[subject.OU] = \"$expected_team\""
if ! codesign --verify --strict -R="$apple_development_requirement" "$APP"; then
  echo "Signed local app does not satisfy the Apple Development requirement." >&2
  exit 1
fi
if ! codesign --verify --strict -R="$apple_development_requirement" "$HELPER"; then
  echo "Signed local helper does not satisfy the Apple Development requirement." >&2
  exit 1
fi
app_signature_details="$(codesign -dv --verbose=4 "$APP" 2>&1)"
helper_signature_details="$(codesign -dv --verbose=4 "$HELPER" 2>&1)"
if [[ "$app_signature_details" != *"(runtime)"* ]]; then
  echo "Signed local app is missing hardened runtime." >&2
  exit 1
fi
if [[ "$helper_signature_details" != *"(runtime)"* ]]; then
  echo "Signed local helper is missing hardened runtime." >&2
  exit 1
fi

TEMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/settlebell-signature-validation.XXXXXX")"
trap 'rm -rf "$TEMP_ROOT"' EXIT
ENTITLEMENTS="$TEMP_ROOT/entitlements.plist"
HELPER_ENTITLEMENTS="$TEMP_ROOT/helper-entitlements.plist"
PROFILE_PLIST="$TEMP_ROOT/profile.plist"
codesign -d --entitlements - --xml "$APP" >"$ENTITLEMENTS" 2>/dev/null
codesign -d --entitlements - --xml "$HELPER" >"$HELPER_ENTITLEMENTS" 2>/dev/null
security cms -D -i "$PROFILE" >"$PROFILE_PLIST"
codesign -d --extract-certificates="$TEMP_ROOT/app-certificate" "$APP" 2>/dev/null
codesign -d --extract-certificates="$TEMP_ROOT/helper-certificate" "$HELPER" 2>/dev/null
plutil -lint "$ENTITLEMENTS" "$PROFILE_PLIST" >/dev/null
if [[ ! -f "$TEMP_ROOT/app-certificate0" || ! -f "$TEMP_ROOT/helper-certificate0" ]]; then
  echo "Could not extract the signed app and helper leaf certificates." >&2
  exit 1
fi

python3 "$ROOT_DIR/script/validate_signed_local_metadata.py" \
  "$ENTITLEMENTS" \
  "$HELPER_ENTITLEMENTS" \
  "$PROFILE_PLIST" \
  "$TEMP_ROOT/app-certificate0" \
  "$TEMP_ROOT/helper-certificate0" \
  "$expected_team" \
  "$expected_bundle" \
  "$expected_container"

echo "Signed local app tree, identity, exact app/helper entitlements, profile authorization, and runtime are valid."
