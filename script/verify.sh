#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STABLE_DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"

if [[ ! -x "$STABLE_DEVELOPER_DIR/usr/bin/xcodebuild" ]]; then
  echo "Stable Xcode is required at $STABLE_DEVELOPER_DIR" >&2
  exit 1
fi
export DEVELOPER_DIR="$STABLE_DEVELOPER_DIR"
IOS_DERIVED_DATA="$ROOT_DIR/.build/DerivedData-verify-ios-release"
cleanup() {
  rm -rf "$IOS_DERIVED_DATA"
}
trap cleanup EXIT

swift test --package-path "$ROOT_DIR" --scratch-path "$ROOT_DIR/.build/swiftpm"
node --experimental-strip-types --test "$ROOT_DIR"/Tests/PiHookTests/*.test.mjs
"$ROOT_DIR/script/build_and_run.sh" --build-only

xcodebuild \
  -project "$ROOT_DIR/PiPing.xcodeproj" \
  -scheme PiPing-iOS \
  -configuration Release \
  -destination "generic/platform=iOS Simulator" \
  -derivedDataPath "$IOS_DERIVED_DATA" \
  PRODUCT_BUNDLE_IDENTIFIER=org.example.PiPing.iOS \
  PIPING_CLOUDKIT_CONTAINER_IDENTIFIER=iCloud.org.example.PiPing \
  PIPING_CLOUDKIT_ACTIVATION=NO \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  build

SIMULATOR_SDK="$(xcrun --sdk iphonesimulator --show-sdk-path)"
swift build \
  --package-path "$ROOT_DIR" \
  --scratch-path "$ROOT_DIR/.build/ios-cross" \
  --configuration release \
  --product PiPingIOS \
  --triple arm64-apple-ios26.0-simulator \
  --sdk "$SIMULATOR_SDK"

rm -rf "$IOS_DERIVED_DATA"
echo "Local unsigned Release verification passed. No app was launched and no notification was sent."
