#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
case "$MODE" in
  run|--build-only|build-only|--debug|debug|--logs|logs|--telemetry|telemetry|--verify|verify)
    ;;
  *)
    echo "usage: $0 [run|--build-only|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac

APP_NAME="PiPing"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA="$ROOT_DIR/.build/DerivedData-run"
if [[ "$MODE" == "--build-only" || "$MODE" == "build-only" ]]; then
  XCODE_CONFIGURATION="Release"
  SWIFT_CONFIGURATION="release"
else
  XCODE_CONFIGURATION="Debug"
  SWIFT_CONFIGURATION="debug"
fi
BUILT_APP="$DERIVED_DATA/Build/Products/$XCODE_CONFIGURATION/PiPing.app"
DIST_DIR="$ROOT_DIR/dist/unsigned"
DIST_APP="$DIST_DIR/PiPing.app"
DIST_ZIP="$DIST_DIR/PiPing.app.zip"
PUBLIC_BUNDLE_IDENTIFIER="org.example.PiPing.macOS"
STABLE_DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
OFFICIAL_ICON_SOURCE="$ROOT_DIR/Assets/Brand/AppIcon/PiPing.icon"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
STAGE_ROOT=""
STAGED_APP=""
DIST_ARCHIVE_TEMP=""
PREVIOUS_ARCHIVE_TEMP=""
OWNS_DIST_APP=false

cleanup() {
  "$LSREGISTER" -u "$BUILT_APP" 2>/dev/null || true
  rm -rf "$BUILT_APP"
  if [[ -n "$STAGED_APP" ]]; then
    "$LSREGISTER" -u "$STAGED_APP" 2>/dev/null || true
  fi
  if [[ "$OWNS_DIST_APP" == true && ( "$MODE" == "--build-only" || "$MODE" == "build-only" ) ]]; then
    "$LSREGISTER" -u "$DIST_APP" 2>/dev/null || true
    rm -rf "$DIST_APP"
  fi
  [[ -z "$DIST_ARCHIVE_TEMP" ]] || rm -f "$DIST_ARCHIVE_TEMP"
  [[ -z "$PREVIOUS_ARCHIVE_TEMP" ]] || rm -f "$PREVIOUS_ARCHIVE_TEMP"
  [[ -z "$STAGE_ROOT" ]] || rm -rf "$STAGE_ROOT"
}
trap cleanup EXIT

if [[ ! -x "$STABLE_DEVELOPER_DIR/usr/bin/xcodebuild" ]]; then
  echo "Stable Xcode is required at $STABLE_DEVELOPER_DIR" >&2
  exit 1
fi
export DEVELOPER_DIR="$STABLE_DEVELOPER_DIR"
unset XCODE_XCCONFIG_FILE

if [[ ! -d "$OFFICIAL_ICON_SOURCE" ]]; then
  echo "Official app icon is missing: $OFFICIAL_ICON_SOURCE" >&2
  exit 1
fi

ICON_SOURCE_COUNT="$(find "$ROOT_DIR/Assets" -type d -name '*.icon' | wc -l | tr -d ' ')"
FOUND_ICON_SOURCE="$(find "$ROOT_DIR/Assets" -type d -name '*.icon' -print -quit)"
if [[ "$ICON_SOURCE_COUNT" -ne 1 || "$FOUND_ICON_SOURCE" != "$OFFICIAL_ICON_SOURCE" ]]; then
  echo "Expected exactly one app icon source: $OFFICIAL_ICON_SOURCE" >&2
  exit 1
fi

swift build \
  --package-path "$ROOT_DIR" \
  --scratch-path "$ROOT_DIR/.build/swiftpm" \
  --configuration "$SWIFT_CONFIGURATION" \
  --product PiPingSignal

xcodebuild \
  -project "$ROOT_DIR/PiPing.xcodeproj" \
  -scheme PiPing-macOS \
  -configuration "$XCODE_CONFIGURATION" \
  -destination "generic/platform=macOS" \
  -derivedDataPath "$DERIVED_DATA" \
  PRODUCT_BUNDLE_IDENTIFIER="$PUBLIC_BUNDLE_IDENTIFIER" \
  INFOPLIST_KEY_CFBundleDisplayName="PiPing Development" \
  PIPING_CLOUDKIT_CONTAINER_IDENTIFIER="iCloud.org.example.PiPing" \
  PIPING_CLOUDKIT_ACTIVATION=NO \
  DEVELOPMENT_TEAM= \
  CODE_SIGN_ENTITLEMENTS= \
  PROVISIONING_PROFILE_SPECIFIER= \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  build

SIGNAL_BINARY="$(swift build \
  --package-path "$ROOT_DIR" \
  --scratch-path "$ROOT_DIR/.build/swiftpm" \
  --configuration "$SWIFT_CONFIGURATION" \
  --show-bin-path)/PiPingSignal"
mkdir -p "$DIST_DIR"
STAGE_ROOT="$(mktemp -d "$ROOT_DIR/.build/unsigned-stage.XXXXXX")"
STAGED_APP="$STAGE_ROOT/PiPing.app"
ditto "$BUILT_APP" "$STAGED_APP"
mkdir -p "$STAGED_APP/Contents/Helpers"
cp "$SIGNAL_BINARY" "$STAGED_APP/Contents/Helpers/PiPingSignal"
chmod +x "$STAGED_APP/Contents/Helpers/PiPingSignal"

if [[ -e "$DIST_APP" ]]; then
  PREVIOUS_ZIP="$ROOT_DIR/.build/PiPing-unsigned-previous-$(date +%Y%m%dT%H%M%S).app.zip"
  PREVIOUS_ARCHIVE_TEMP="${PREVIOUS_ZIP}.tmp"
  ditto -c -k --sequesterRsrc --keepParent "$DIST_APP" "$PREVIOUS_ARCHIVE_TEMP"
  unzip -tq "$PREVIOUS_ARCHIVE_TEMP"
  mv "$PREVIOUS_ARCHIVE_TEMP" "$PREVIOUS_ZIP"
  PREVIOUS_ARCHIVE_TEMP=""
  rm -rf "$DIST_APP"
fi
mv "$STAGED_APP" "$DIST_APP"
OWNS_DIST_APP=true

# Xcode's build action may register an unsigned product even when it is never
# launched. Keep development products out of the production LaunchServices set;
# `open` will register the staged development app only for an explicit run.
"$LSREGISTER" -u "$BUILT_APP" 2>/dev/null || true
"$LSREGISTER" -u "$DIST_APP" 2>/dev/null || true

open_app() {
  /usr/bin/open -n "$DIST_APP"
}

stop_existing_app() {
  local executable="$DIST_APP/Contents/MacOS/$APP_NAME"
  local pids
  pids="$(pgrep -f "^${executable}$" || true)"
  if [[ -n "$pids" ]]; then
    kill $pids
  fi
}

case "$MODE" in
  run)
    stop_existing_app
    open_app
    ;;
  --build-only|build-only)
    DIST_ARCHIVE_TEMP="$DIST_DIR/.PiPing.app.$$.zip"
    ditto -c -k --sequesterRsrc --keepParent "$DIST_APP" "$DIST_ARCHIVE_TEMP"
    unzip -tq "$DIST_ARCHIVE_TEMP"
    mv -f "$DIST_ARCHIVE_TEMP" "$DIST_ZIP"
    DIST_ARCHIVE_TEMP=""
    "$LSREGISTER" -u "$DIST_APP" 2>/dev/null || true
    rm -rf "$DIST_APP"
    OWNS_DIST_APP=false
    echo "Built $DIST_ZIP"
    ;;
  --debug|debug)
    stop_existing_app
    lldb -- "$DIST_APP/Contents/MacOS/PiPing"
    ;;
  --logs|logs)
    stop_existing_app
    open_app
    /usr/bin/log stream --info --style compact --predicate 'process == "PiPing"'
    ;;
  --telemetry|telemetry)
    stop_existing_app
    open_app
    /usr/bin/log stream --info --style compact --predicate 'subsystem == "org.example.PiPing.macOS"'
    ;;
  --verify|verify)
    stop_existing_app
    open_app
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
esac
