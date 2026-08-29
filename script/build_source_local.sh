#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UNSIGNED_ARCHIVE="$ROOT_DIR/dist/unsigned/PiPing.app.zip"
OUTPUT_DIR="$ROOT_DIR/dist/source-local"
OUTPUT_ARCHIVE="$OUTPUT_DIR/PiPing.app.zip"
OUTPUT_TEMP="$OUTPUT_DIR/.PiPing.app.$$.zip"
BUILD_LOG="$ROOT_DIR/.build/source-local-build.log"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
STAGE_ROOT=""

cleanup() {
  if [[ -n "$STAGE_ROOT" ]]; then
    "$LSREGISTER" -u "$STAGE_ROOT/PiPing.app" 2>/dev/null || true
    rm -rf "$STAGE_ROOT"
  fi
  rm -f "$OUTPUT_TEMP"
}
trap cleanup EXIT

mkdir -p "$ROOT_DIR/.build"
if ! "$ROOT_DIR/script/build_and_run.sh" --build-only >"$BUILD_LOG" 2>&1; then
  echo "Source-local build failed. Review the ignored local build log." >&2
  exit 1
fi
if [[ ! -f "$UNSIGNED_ARCHIVE" ]]; then
  echo "Public-safe build did not produce the expected archive." >&2
  exit 1
fi

STAGE_ROOT="$(mktemp -d "$ROOT_DIR/.build/source-local-stage.XXXXXX")"
unzip -tq "$UNSIGNED_ARCHIVE"
ditto -x -k "$UNSIGNED_ARCHIVE" "$STAGE_ROOT"
APP="$STAGE_ROOT/PiPing.app"
HELPER="$APP/Contents/Helpers/PiPingSignal"
if [[ ! -d "$APP" || ! -x "$HELPER" ]]; then
  echo "Public-safe archive does not contain the expected app and helper." >&2
  exit 1
fi

# Apply only local ad-hoc hardened-runtime signatures. No Apple identity,
# provisioning profile, private entitlement, or private container is used.
codesign --force --sign - --options runtime "$HELPER"
codesign --force --sign - --options runtime "$APP"
"$ROOT_DIR/script/validate_source_local_app.sh" "$APP"

mkdir -p "$OUTPUT_DIR"
ditto -c -k --keepParent "$APP" "$OUTPUT_TEMP"
"$ROOT_DIR/script/validate_source_local_archive.sh" "$OUTPUT_TEMP" >/dev/null
mv -f "$OUTPUT_TEMP" "$OUTPUT_ARCHIVE"

version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
build="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP/Contents/Info.plist")"
echo "Built source-local PiPing $version ($build): $OUTPUT_ARCHIVE"
echo "This ad-hoc development archive is local-only and must not be published."
