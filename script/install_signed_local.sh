#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="${1:-}"
ARCHIVE="${2:-$ROOT_DIR/dist/private/PiPing.app.zip}"
CANONICAL_APP="/Applications/PiPing.app"
PUBLIC_BUNDLE_IDENTIFIER="org.example.PiPing.macOS"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

if [[ "$MODE" != "--check" && "$MODE" != "--install" ]] || [[ $# -gt 2 ]]; then
  echo "usage: $0 [--check|--install] [path/to/PiPing.app.zip]" >&2
  echo "Build the local-only signed archive with script/build_signed_local.sh first." >&2
  exit 2
fi
if [[ ! -f "$ARCHIVE" ]]; then
  echo "Signed local archive not found." >&2
  exit 1
fi

mkdir -p "$ROOT_DIR/.build/install-backups"
STAGE_ROOT="$(mktemp -d "$ROOT_DIR/.build/install-stage.XXXXXX")"
PENDING_APP="/Applications/.PiPing-installing-$$.app"
PREVIOUS_APP="/Applications/.PiPing-previous-$$.app"
restore_needed=false
candidate_installed=false
backup=""

cleanup() {
  "$LSREGISTER" -u "$PENDING_APP" 2>/dev/null || true
  rm -rf "$PENDING_APP" "$STAGE_ROOT"
  if [[ "$candidate_installed" == true || "$restore_needed" == true ]]; then
    pids="$(pgrep -f '^/Applications/PiPing\.app/Contents/MacOS/PiPing$' || true)"
    if [[ -n "$pids" ]]; then kill $pids 2>/dev/null || true; fi
    if [[ "$candidate_installed" == true ]]; then
      "$LSREGISTER" -u "$CANONICAL_APP" 2>/dev/null || true
      rm -rf "$CANONICAL_APP"
    fi
    if [[ "$restore_needed" == true ]]; then
      if [[ -e "$PREVIOUS_APP" ]]; then
        mv "$PREVIOUS_APP" "$CANONICAL_APP" || true
      elif [[ -n "$backup" && -f "$backup" ]]; then
        restore_root="$(mktemp -d "$ROOT_DIR/.build/install-restore.XXXXXX")"
        if ditto -x -k "$backup" "$restore_root" \
          && [[ -d "$restore_root/PiPing.app" ]]; then
          ditto "$restore_root/PiPing.app" "$CANONICAL_APP" || true
        fi
        rm -rf "$restore_root"
      fi
      if [[ -d "$CANONICAL_APP" ]] \
        && "$ROOT_DIR/script/validate_signed_local_app.sh" "$CANONICAL_APP" >/dev/null 2>&1; then
        "$LSREGISTER" -f "$CANONICAL_APP" 2>/dev/null || true
        open "$CANONICAL_APP" 2>/dev/null || true
      fi
    fi
  fi
}
trap cleanup EXIT

unzip -tq "$ARCHIVE"
ditto -x -k "$ARCHIVE" "$STAGE_ROOT"
SOURCE_APP="$STAGE_ROOT/PiPing.app"
HELPER="$SOURCE_APP/Contents/Helpers/PiPingSignal"
if [[ ! -d "$SOURCE_APP" || ! -x "$HELPER" ]]; then
  echo "Archive does not contain the expected PiPing app and helper." >&2
  exit 1
fi
"$ROOT_DIR/script/validate_signed_local_app.sh" "$SOURCE_APP"

bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$SOURCE_APP/Contents/Info.plist")"
display_name="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleDisplayName' "$SOURCE_APP/Contents/Info.plist" 2>/dev/null || true)"
if [[ -z "$bundle_id" || "$bundle_id" == "$PUBLIC_BUNDLE_IDENTIFIER" || "$display_name" == "PiPing Development" ]]; then
  echo "Refusing to install a public-safe unsigned/development artifact as the canonical app." >&2
  exit 1
fi
if [[ "$MODE" == "--check" ]]; then
  echo "Signed local archive and embedded helper passed preflight validation."
  exit 0
fi

rm -rf "$PENDING_APP" "$PREVIOUS_APP"
ditto "$SOURCE_APP" "$PENDING_APP"
"$ROOT_DIR/script/validate_signed_local_app.sh" "$PENDING_APP"

if [[ -d "$CANONICAL_APP" ]]; then
  backup="$ROOT_DIR/.build/install-backups/PiPing-before-$(date +%Y%m%dT%H%M%S).app.zip"
  ditto -c -k --sequesterRsrc --keepParent "$CANONICAL_APP" "$backup"
  unzip -tq "$backup"
fi

pids="$(pgrep -f '^/Applications/PiPing\.app/Contents/MacOS/PiPing$' || true)"
if [[ -n "$pids" ]]; then
  kill $pids
  sleep 2
fi

"$LSREGISTER" -u "$PENDING_APP" 2>/dev/null || true
"$LSREGISTER" -u "$CANONICAL_APP" 2>/dev/null || true
if [[ -d "$CANONICAL_APP" ]]; then
  mv "$CANONICAL_APP" "$PREVIOUS_APP"
  restore_needed=true
fi
mv "$PENDING_APP" "$CANONICAL_APP"
candidate_installed=true
"$ROOT_DIR/script/validate_signed_local_app.sh" "$CANONICAL_APP"

"$LSREGISTER" -u "$PREVIOUS_APP" 2>/dev/null || true
rm -rf "$PREVIOUS_APP"
"$LSREGISTER" -f "$CANONICAL_APP"
open "$CANONICAL_APP"
sleep 4
env -u PIPING_CANONICAL_APP "$ROOT_DIR/script/check_installation.sh"
candidate_installed=false
restore_needed=false

if [[ -n "$backup" ]]; then
  echo "Compressed rollback: $backup"
fi
echo "Installed the signed local app at $CANONICAL_APP"
