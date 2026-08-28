#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STABLE_DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"

if [[ ! -x "$STABLE_DEVELOPER_DIR/usr/bin/xcodebuild" ]]; then
  echo "Stable Xcode is required at $STABLE_DEVELOPER_DIR" >&2
  exit 1
fi
export DEVELOPER_DIR="$STABLE_DEVELOPER_DIR"

swift test --package-path "$ROOT_DIR" --scratch-path "$ROOT_DIR/.build/swiftpm"
node --experimental-strip-types --test "$ROOT_DIR"/Tests/PiHookTests/*.test.mjs
"$ROOT_DIR/script/build_and_run.sh" --build-only

SIMULATOR_SDK="$(xcrun --sdk iphonesimulator --show-sdk-path)"
swift build \
  --package-path "$ROOT_DIR" \
  --scratch-path "$ROOT_DIR/.build/ios-cross" \
  --product PiPingIOS \
  --triple arm64-apple-ios26.0-simulator \
  --sdk "$SIMULATOR_SDK"

echo "Local unsigned verification passed. No app was launched and no notification was sent."
