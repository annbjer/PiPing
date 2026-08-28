#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="PiPing"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA="$ROOT_DIR/.build/DerivedData-run"
BUILT_APP="$DERIVED_DATA/Build/Products/Debug/PiPing.app"
DIST_DIR="$ROOT_DIR/dist/unsigned"
DIST_APP="$DIST_DIR/PiPing.app"
PUBLIC_BUNDLE_IDENTIFIER="org.example.PiPing.macOS"
STABLE_DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
OFFICIAL_ICON_SOURCE="$ROOT_DIR/Assets/Brand/AppIcon/PiPing.icon"

if [[ ! -x "$STABLE_DEVELOPER_DIR/usr/bin/xcodebuild" ]]; then
  echo "Stable Xcode is required at $STABLE_DEVELOPER_DIR" >&2
  exit 1
fi
export DEVELOPER_DIR="$STABLE_DEVELOPER_DIR"

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
  --product PiPingSignal

xcodebuild \
  -project "$ROOT_DIR/PiPing.xcodeproj" \
  -scheme PiPing-macOS \
  -configuration Debug \
  -destination "generic/platform=macOS" \
  -derivedDataPath "$DERIVED_DATA" \
  PRODUCT_BUNDLE_IDENTIFIER="$PUBLIC_BUNDLE_IDENTIFIER" \
  PIPING_CLOUDKIT_ACTIVATION=NO \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  build

SIGNAL_BINARY="$(swift build --package-path "$ROOT_DIR" --scratch-path "$ROOT_DIR/.build/swiftpm" --show-bin-path)/PiPingSignal"
mkdir -p "$DIST_DIR"
STAGE_ROOT="$(mktemp -d "$ROOT_DIR/.build/unsigned-stage.XXXXXX")"
STAGED_APP="$STAGE_ROOT/PiPing.app"
ditto "$BUILT_APP" "$STAGED_APP"
mkdir -p "$STAGED_APP/Contents/Helpers"
cp "$SIGNAL_BINARY" "$STAGED_APP/Contents/Helpers/PiPingSignal"
chmod +x "$STAGED_APP/Contents/Helpers/PiPingSignal"

if [[ -e "$DIST_APP" ]]; then
  PREVIOUS_APP="$ROOT_DIR/.build/PiPing-unsigned-previous-$(date +%Y%m%dT%H%M%S).app"
  mv "$DIST_APP" "$PREVIOUS_APP"
fi
mv "$STAGED_APP" "$DIST_APP"

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
    echo "Built $DIST_APP"
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
  *)
    echo "usage: $0 [run|--build-only|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
