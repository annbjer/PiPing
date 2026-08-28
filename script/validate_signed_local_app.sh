#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOCAL_CONFIG="$ROOT_DIR/Config/Local.xcconfig"
APP="${1:-}"

if [[ -z "$APP" || $# -ne 1 ]]; then
  echo "usage: $0 path/to/PiPing.app" >&2
  exit 2
fi
if [[ ! -d "$APP" || ! -f "$APP/Contents/Info.plist" ]]; then
  echo "Signed local PiPing app is missing or malformed." >&2
  exit 1
fi
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

expected_team="$(config_value PIPING_DEVELOPMENT_TEAM)"
expected_bundle="$(config_value PIPING_MACOS_BUNDLE_IDENTIFIER)"
expected_container="$(config_value PIPING_CLOUDKIT_CONTAINER_IDENTIFIER)"
for value in "$expected_team" "$expected_bundle" "$expected_container"; do
  if [[ -z "$value" || "$value" == *PLACEHOLDER* || "$value" == org.example.* ]]; then
    echo "Ignored local signing configuration is incomplete." >&2
    exit 1
  fi
done

HELPER="$APP/Contents/Helpers/PiPingSignal"
PROFILE="$APP/Contents/embedded.provisionprofile"
if [[ ! -x "$HELPER" || ! -f "$PROFILE" ]]; then
  echo "Signed local app is missing its helper or provisioning profile." >&2
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
app_authority="$(signature_field "$APP" Authority)"
helper_authority="$(signature_field "$HELPER" Authority)"
bundle_identifier="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Contents/Info.plist")"

if [[ "$bundle_identifier" != "$expected_bundle" || "$app_identifier" != "$expected_bundle" ]]; then
  echo "Signed local app does not use the approved bundle identity." >&2
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

TEMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/piping-signature-validation.XXXXXX")"
trap 'rm -rf "$TEMP_ROOT"' EXIT
ENTITLEMENTS="$TEMP_ROOT/entitlements.plist"
PROFILE_PLIST="$TEMP_ROOT/profile.plist"
codesign -d --entitlements - --xml "$APP" >"$ENTITLEMENTS" 2>/dev/null
security cms -D -i "$PROFILE" >"$PROFILE_PLIST"
codesign -d --extract-certificates="$TEMP_ROOT/app-certificate" "$APP" 2>/dev/null
codesign -d --extract-certificates="$TEMP_ROOT/helper-certificate" "$HELPER" 2>/dev/null
plutil -lint "$ENTITLEMENTS" "$PROFILE_PLIST" >/dev/null
if [[ ! -f "$TEMP_ROOT/app-certificate0" || ! -f "$TEMP_ROOT/helper-certificate0" ]]; then
  echo "Could not extract the signed app and helper leaf certificates." >&2
  exit 1
fi

python3 - \
  "$ENTITLEMENTS" \
  "$PROFILE_PLIST" \
  "$TEMP_ROOT/app-certificate0" \
  "$TEMP_ROOT/helper-certificate0" \
  "$expected_team" \
  "$expected_bundle" \
  "$expected_container" <<'PY'
import datetime
import plistlib
import sys

(
    entitlements_path,
    profile_path,
    app_certificate_path,
    helper_certificate_path,
    team,
    bundle,
    container,
) = sys.argv[1:]
with open(entitlements_path, "rb") as handle:
    entitlements = plistlib.load(handle)
with open(profile_path, "rb") as handle:
    profile = plistlib.load(handle)
with open(app_certificate_path, "rb") as handle:
    app_certificate = handle.read()
with open(helper_certificate_path, "rb") as handle:
    helper_certificate = handle.read()

expected_application_identifier = f"{team}.{bundle}"
if entitlements.get("com.apple.developer.icloud-container-identifiers") != [container]:
    raise SystemExit("Signed local app has unexpected iCloud container entitlements.")
if entitlements.get("com.apple.developer.icloud-services") != ["CloudKit"]:
    raise SystemExit("Signed local app has unexpected iCloud service entitlements.")
if entitlements.get("com.apple.developer.team-identifier") != team:
    raise SystemExit("Signed local app is missing the exact entitlement team.")
if entitlements.get("com.apple.application-identifier") != expected_application_identifier:
    raise SystemExit("Signed local app is missing the exact application identifier entitlement.")

if profile.get("TeamIdentifier") != [team]:
    raise SystemExit("Provisioning profile has an unexpected team.")
if profile.get("ApplicationIdentifierPrefix") != [team]:
    raise SystemExit("Provisioning profile has an unexpected application prefix.")
profile_entitlements = profile.get("Entitlements", {})
if profile_entitlements.get("com.apple.application-identifier") != expected_application_identifier:
    raise SystemExit("Provisioning profile has an unexpected application identifier.")
if profile_entitlements.get("com.apple.developer.icloud-container-identifiers") != [container]:
    raise SystemExit("Provisioning profile has an unexpected iCloud container.")
developer_certificates = profile.get("DeveloperCertificates", [])
if app_certificate != helper_certificate:
    raise SystemExit("Signed local app and helper use different leaf certificates.")
if app_certificate not in developer_certificates or helper_certificate not in developer_certificates:
    raise SystemExit("Signed local app/helper certificate is not authorized by the profile.")
expiration = profile.get("ExpirationDate")
now = datetime.datetime.now(datetime.timezone.utc)
if expiration is None:
    raise SystemExit("Provisioning profile has no expiration date.")
if expiration.tzinfo is None:
    expiration = expiration.replace(tzinfo=datetime.timezone.utc)
if expiration <= now:
    raise SystemExit("Provisioning profile has expired.")
PY

echo "Signed local app identity, entitlements, profile, runtime, and helper are valid."
