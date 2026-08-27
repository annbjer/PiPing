#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="PiPing"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA="$ROOT_DIR/.build/DerivedData-run"
BUILT_APP="$DERIVED_DATA/Build/Products/Debug/PiPing.app"
DIST_DIR="$ROOT_DIR/dist/unsigned"
DIST_APP="$DIST_DIR/PiPing.app"

if [[ -z "${DEVELOPER_DIR:-}" && -d "/Applications/Xcode.app/Contents/Developer" ]]; then
  export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
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
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  build

SIGNAL_BINARY="$(swift build --package-path "$ROOT_DIR" --scratch-path "$ROOT_DIR/.build/swiftpm" --show-bin-path)/PiPingSignal"
rm -rf "$DIST_APP"
mkdir -p "$DIST_DIR"
ditto "$BUILT_APP" "$DIST_APP"
mkdir -p "$DIST_APP/Contents/Helpers"
cp "$SIGNAL_BINARY" "$DIST_APP/Contents/Helpers/PiPingSignal"
chmod +x "$DIST_APP/Contents/Helpers/PiPingSignal"

open_app() {
  /usr/bin/open -n "$DIST_APP"
}

stop_existing_app() {
  pkill -x "$APP_NAME" >/dev/null 2>&1 || true
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
