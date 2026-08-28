#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOCAL_CONFIG="$ROOT_DIR/Config/Local.xcconfig"
DERIVED_DATA="$ROOT_DIR/.build/DerivedData-signed-local"
BUILT_APP="$DERIVED_DATA/Build/Products/Release/PiPing.app"
SWIFT_SCRATCH="$ROOT_DIR/.build/swiftpm-signed-local"
OUTPUT_DIR="$ROOT_DIR/dist/private"
OUTPUT_ZIP="$OUTPUT_DIR/PiPing.app.zip"
BUILD_LOG="$ROOT_DIR/.build/signed-local-xcodebuild.log"
STABLE_DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
STAGE_ROOT=""
STAGED_APP=""

cleanup() {
  "$LSREGISTER" -u "$BUILT_APP" 2>/dev/null || true
  if [[ -n "$STAGED_APP" ]]; then
    "$LSREGISTER" -u "$STAGED_APP" 2>/dev/null || true
  fi
  if [[ -n "$STAGE_ROOT" ]]; then
    rm -rf "$STAGE_ROOT"
  fi
  rm -rf "$DERIVED_DATA"
}

if [[ ! -f "$LOCAL_CONFIG" ]]; then
  echo "Create ignored Config/Local.xcconfig from the public example first." >&2
  exit 1
fi
if [[ ! -x "$STABLE_DEVELOPER_DIR/usr/bin/xcodebuild" ]]; then
  echo "Stable Xcode is required at $STABLE_DEVELOPER_DIR" >&2
  exit 1
fi

required_setting() {
  local key="$1"
  local value
  value="$(awk -F= -v key="$key" '
    $1 ~ "^[[:space:]]*" key "[[:space:]]*$" {
      sub(/^[^=]*=[[:space:]]*/, "")
      sub(/[[:space:]]*$/, "")
      print
      exit
    }
  ' "$LOCAL_CONFIG")"
  if [[ -z "$value" || "$value" == *PLACEHOLDER* || "$value" == org.example.* ]]; then
    echo "Config/Local.xcconfig has no approved private value for $key." >&2
    exit 1
  fi
}

required_setting PIPING_DEVELOPMENT_TEAM
required_setting PIPING_MACOS_BUNDLE_IDENTIFIER
required_setting PIPING_CLOUDKIT_CONTAINER_IDENTIFIER

trap cleanup EXIT
export DEVELOPER_DIR="$STABLE_DEVELOPER_DIR"
mkdir -p "$ROOT_DIR/.build" "$OUTPUT_DIR"
rm -f "$OUTPUT_ZIP"
rm -rf "$DERIVED_DATA"

if ! xcodebuild \
  -project "$ROOT_DIR/PiPing.xcodeproj" \
  -scheme PiPing-macOS \
  -configuration Release \
  -destination "generic/platform=macOS" \
  -derivedDataPath "$DERIVED_DATA" \
  -allowProvisioningUpdates \
  build >"$BUILD_LOG" 2>&1; then
  echo "Signed Xcode build failed. Review the ignored local build log." >&2
  exit 1
fi

if [[ ! -d "$BUILT_APP" ]]; then
  echo "Signed Xcode build did not produce PiPing.app." >&2
  exit 1
fi

swift build \
  --package-path "$ROOT_DIR" \
  --scratch-path "$SWIFT_SCRATCH" \
  --configuration release \
  --product PiPingSignal >/dev/null
SIGNAL_BINARY="$(swift build \
  --package-path "$ROOT_DIR" \
  --scratch-path "$SWIFT_SCRATCH" \
  --configuration release \
  --show-bin-path)/PiPingSignal"

STAGE_ROOT="$(mktemp -d "$ROOT_DIR/.build/signed-stage.XXXXXX")"
STAGED_APP="$STAGE_ROOT/PiPing.app"

ditto "$BUILT_APP" "$STAGED_APP"
mkdir -p "$STAGED_APP/Contents/Helpers"
cp "$SIGNAL_BINARY" "$STAGED_APP/Contents/Helpers/PiPingSignal"
chmod +x "$STAGED_APP/Contents/Helpers/PiPingSignal"

identity="$(codesign -dv --verbose=4 "$STAGED_APP" 2>&1 \
  | awk -F= '/^Authority=/ && !found {print $2; found=1}')"
if [[ -z "$identity" ]]; then
  echo "The Mac app does not have an Apple Development signing identity." >&2
  exit 1
fi

entitlements="$STAGE_ROOT/app-entitlements.plist"
codesign -d --entitlements - --xml "$STAGED_APP" >"$entitlements" 2>/dev/null
plutil -lint "$entitlements" >/dev/null

codesign \
  --force \
  --options runtime \
  --timestamp=none \
  --sign "$identity" \
  "$STAGED_APP/Contents/Helpers/PiPingSignal"
codesign \
  --force \
  --options runtime \
  --timestamp=none \
  --entitlements "$entitlements" \
  --sign "$identity" \
  "$STAGED_APP"
codesign --verify --deep --strict --verbose=2 "$STAGED_APP"

rm -f "$OUTPUT_ZIP"
ditto -c -k --sequesterRsrc --keepParent "$STAGED_APP" "$OUTPUT_ZIP"
unzip -tq "$OUTPUT_ZIP"

version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$STAGED_APP/Contents/Info.plist")"
build="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$STAGED_APP/Contents/Info.plist")"
echo "Built private local PiPing $version ($build): $OUTPUT_ZIP"
echo "This Apple Development-signed archive is local-only and must not be published."
