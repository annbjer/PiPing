#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="${1:-}"
CONFIRMATION="${2:-}"
LEGACY_APP="/Applications/PiPing.app"
LEGACY_EXECUTABLE="$LEGACY_APP/Contents/MacOS/PiPing"
LEGACY_BUNDLE_IDENTIFIER="org.example.PiPing.macOS"
LEGACY_RUNTIME_DIR="$HOME/.piping"
LEGACY_FIFO="$LEGACY_RUNTIME_DIR/events.fifo"
SETTLEBELL_APP="/Applications/SettleBell.app"
SETTLEBELL_RUNTIME_DIR="$HOME/.settlebell"
SETTLEBELL_FIFO="$SETTLEBELL_RUNTIME_DIR/events.fifo"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

if [[ "$MODE" == "--check" ]]; then
  if [[ $# -ne 1 ]]; then
    echo "usage: $0 --check" >&2
    exit 2
  fi
elif [[ "$MODE" == "--retire" ]]; then
  if [[ $# -ne 2 || "$CONFIRMATION" != "--confirmed-settlebell-notification" ]]; then
    echo "usage: $0 --retire --confirmed-settlebell-notification" >&2
    exit 2
  fi
else
  echo "usage: $0 [--check | --retire --confirmed-settlebell-notification]" >&2
  exit 2
fi

if [[ ! -w /Applications ]]; then
  echo "/Applications is not writable by the current user; no changes were made." >&2
  exit 1
fi

stale_transaction="$(find /Applications -maxdepth 1 \
  \( -name '.PiPing-source-transaction.*' \
     -o -name '.PiPing-source-uninstall.*' \
     -o -name '.PiPing-signed-transaction.*' \
     -o -name '.PiPing-source-installing-*.app' \
     -o -name '.PiPing-source-previous-*.app' \
     -o -name '.PiPing-installing-*.app' \
     -o -name '.PiPing-previous-*.app' \
     -o -name '.SettleBell-source-transaction.*' \
     -o -name '.SettleBell-source-uninstall.*' \
     -o -name '.SettleBell-signed-transaction.*' \
     -o -name '.SettleBell-piping-retirement.*' \
     -o -name '.SettleBell-source-installing-*.app' \
     -o -name '.SettleBell-source-previous-*.app' \
     -o -name '.SettleBell-installing-*.app' \
     -o -name '.SettleBell-previous-*.app' \) -print -quit)"
if [[ -n "$stale_transaction" ]]; then
  echo "A prior PiPing/SettleBell transaction requires manual recovery before continuing." >&2
  exit 1
fi

if [[ -L "$SETTLEBELL_APP" || -L "$LEGACY_APP" ]]; then
  echo "Refusing a symbolic link at a canonical application path." >&2
  exit 1
fi

# Retirement is never the installation boundary. SettleBell must already be the
# validated, running source-local canonical app before legacy state is touched.
"$ROOT_DIR/script/check_source_installation.sh" >/dev/null

path_identity() {
  stat -f '%d:%i' "$1" 2>/dev/null || true
}

has_extended_acl() {
  ls -lde "$1" 2>/dev/null | awk 'NR > 1 {found=1} END {exit found ? 0 : 1}'
}

settlebell_runtime_is_ready() {
  if [[ -L "$SETTLEBELL_RUNTIME_DIR" || ! -d "$SETTLEBELL_RUNTIME_DIR" \
     || "$(stat -f %Su "$SETTLEBELL_RUNTIME_DIR")" != "$(id -un)" \
     || "$(stat -f %Lp "$SETTLEBELL_RUNTIME_DIR")" != 700 ]] \
     || has_extended_acl "$SETTLEBELL_RUNTIME_DIR"; then
    return 1
  fi
  local unexpected
  unexpected="$(find "$SETTLEBELL_RUNTIME_DIR" -mindepth 1 -maxdepth 1 ! -name events.fifo -print -quit)"
  if [[ -n "$unexpected" || -L "$SETTLEBELL_FIFO" || ! -p "$SETTLEBELL_FIFO" \
     || "$(stat -f %Su "$SETTLEBELL_FIFO")" != "$(id -un)" \
     || "$(stat -f %Lp "$SETTLEBELL_FIFO")" != 600 ]] \
     || has_extended_acl "$SETTLEBELL_FIFO"; then
    return 1
  fi
  return 0
}

if ! settlebell_runtime_is_ready; then
  echo "SettleBell does not have one exact protected runtime FIFO; PiPing remains untouched." >&2
  exit 1
fi
"$ROOT_DIR/script/validate_legacy_piping_source_local_app.sh" "$LEGACY_APP"

legacy_runtime_is_removable() {
  if [[ ! -e "$LEGACY_RUNTIME_DIR" && ! -L "$LEGACY_RUNTIME_DIR" ]]; then return 0; fi
  if [[ -L "$LEGACY_RUNTIME_DIR" || ! -d "$LEGACY_RUNTIME_DIR" \
     || "$(stat -f %Su "$LEGACY_RUNTIME_DIR")" != "$(id -un)" \
     || "$(stat -f %Lp "$LEGACY_RUNTIME_DIR")" != 700 ]] \
     || has_extended_acl "$LEGACY_RUNTIME_DIR"; then
    return 1
  fi
  local unexpected
  unexpected="$(find "$LEGACY_RUNTIME_DIR" -mindepth 1 -maxdepth 1 ! -name events.fifo -print -quit)"
  if [[ -n "$unexpected" || -L "$LEGACY_FIFO" ]]; then return 1; fi
  if [[ -e "$LEGACY_FIFO" ]]; then
    if [[ ! -p "$LEGACY_FIFO" \
       || "$(stat -f %Su "$LEGACY_FIFO")" != "$(id -un)" \
       || "$(stat -f %Lp "$LEGACY_FIFO")" != 600 ]] \
       || has_extended_acl "$LEGACY_FIFO"; then
      return 1
    fi
  fi
  return 0
}

legacy_launchservices_paths() {
  local dump
  dump="$(mktemp "${TMPDIR:-/tmp}/settlebell-legacy-ls.XXXXXX")"
  "$LSREGISTER" -dump >"$dump" 2>/dev/null
  awk -v expected="$LEGACY_BUNDLE_IDENTIFIER" '
    /^-+$/ {
      if (identifier == expected && path != "") print path
      identifier=""; path=""; next
    }
    /^identifier:[[:space:]]+/ {
      value=$0; sub(/^identifier:[[:space:]]+/, "", value)
      sub(/[[:space:]].*$/, "", value); identifier=value; next
    }
    /^path:[[:space:]]+/ {
      value=$0; sub(/^path:[[:space:]]+/, "", value)
      sub(/[[:space:]]+\(0x[[:xdigit:]]+\).*$/, "", value); path=value
    }
    END {if (identifier == expected && path != "") print path}
  ' "$dump" | sort -u
  rm -f "$dump"
}

LEGACY_PIDS="$(pgrep -x PiPing || true)"
LEGACY_PID_COUNT="$(printf '%s\n' "$LEGACY_PIDS" | awk 'NF {count++} END {print count+0}')"
if [[ "$LEGACY_PID_COUNT" -gt 1 ]]; then
  echo "Refusing retirement while multiple PiPing processes exist." >&2
  exit 1
fi
if [[ "$LEGACY_PID_COUNT" -eq 1 ]] \
   && [[ "$(ps -p "$LEGACY_PIDS" -o command=)" != "$LEGACY_EXECUTABLE" ]]; then
  echo "Refusing to stop a noncanonical PiPing process." >&2
  exit 1
fi

legacy_runtime_removable=false
if legacy_runtime_is_removable; then legacy_runtime_removable=true; fi
legacy_ls_paths="$(legacy_launchservices_paths)"
if printf '%s\n' "$legacy_ls_paths" | awk 'NF && $0 != "/Applications/PiPing.app" {bad=1} END {exit bad ? 0 : 1}'; then
  echo "Refusing retirement while a noncanonical PiPing LaunchServices path exists." >&2
  exit 1
fi

if [[ "$MODE" == "--check" ]]; then
  echo "Legacy PiPing source-local retirement preflight passed."
  echo "SettleBell is installed, validated, running, and remains untouched."
  if [[ "$legacy_runtime_removable" == true ]]; then
    echo "The protected legacy runtime can be removed safely."
  else
    echo "The legacy runtime contains unexpected state and would be preserved." >&2
  fi
  echo "Before retirement, deliver and acknowledge one genuine eligible SettleBell notification."
  echo "Remote PiPing packages, if any, require pi remove with their exact original source."
  exit 0
fi

TRANSACTION_ROOT="$(mktemp -d /Applications/.SettleBell-piping-retirement.XXXXXX)"
chmod 700 "$TRANSACTION_ROOT"
QUARANTINED_APP="$TRANSACTION_ROOT/PiPing.payload"
BACKUP_STAGE="$(mktemp -d "${TMPDIR:-/tmp}/settlebell-piping-retirement-backup.XXXXXX")"
chmod 700 "$BACKUP_STAGE"
quarantined_identity=""
restore_needed=false
completed=false
backup=""
backup_temp=""

handle_signal() {
  exit "$1"
}

cleanup() {
  trap '' HUP INT TERM
  local preserve_transaction=false
  [[ -z "$backup_temp" ]] || rm -f "$backup_temp"
  "$LSREGISTER" -u "$QUARANTINED_APP" 2>/dev/null || true
  "$LSREGISTER" -u "$BACKUP_STAGE/PiPing.app" 2>/dev/null || true
  rm -rf "$BACKUP_STAGE"

  if [[ "$completed" == false && "$restore_needed" == true && -d "$QUARANTINED_APP" ]]; then
    if [[ "$(path_identity "$QUARANTINED_APP")" != "$quarantined_identity" ]]; then
      echo "Recovery preserved a changed quarantined PiPing app for manual inspection." >&2
      preserve_transaction=true
    elif [[ ! -e "$LEGACY_APP" && ! -L "$LEGACY_APP" ]]; then
      mv "$QUARANTINED_APP" "$LEGACY_APP"
      if [[ "$(path_identity "$LEGACY_APP")" == "$quarantined_identity" ]] \
        && "$ROOT_DIR/script/validate_legacy_piping_source_local_app.sh" "$LEGACY_APP" >/dev/null 2>&1; then
        "$LSREGISTER" -f "$LEGACY_APP" 2>/dev/null || true
        open "$LEGACY_APP" 2>/dev/null || true
      else
        echo "Recovery could not validate the restored PiPing app." >&2
        preserve_transaction=true
      fi
    else
      echo "Recovery was blocked by an unexpected PiPing canonical path." >&2
      preserve_transaction=true
    fi
  fi

  if [[ "$preserve_transaction" == false ]]; then
    rm -rf "$TRANSACTION_ROOT"
  else
    echo "Preserved interrupted retirement transaction: $TRANSACTION_ROOT" >&2
  fi
}
trap cleanup EXIT
trap 'handle_signal 129' HUP
trap 'handle_signal 130' INT
trap 'handle_signal 143' TERM

quarantined_identity="$(path_identity "$LEGACY_APP")"
if [[ -z "$quarantined_identity" ]] \
  || ! "$ROOT_DIR/script/validate_legacy_piping_source_local_app.sh" "$LEGACY_APP" >/dev/null 2>&1; then
  echo "The legacy PiPing app changed before atomic quarantine." >&2
  exit 1
fi
# Pin restoration intent before the destructive boundary.
restore_needed=true
mv "$LEGACY_APP" "$QUARANTINED_APP"
if [[ "$(path_identity "$QUARANTINED_APP")" != "$quarantined_identity" ]] \
  || ! "$ROOT_DIR/script/validate_legacy_piping_source_local_app.sh" "$QUARANTINED_APP" >/dev/null 2>&1; then
  echo "The atomically quarantined PiPing app failed validation." >&2
  exit 1
fi

if [[ "$LEGACY_PID_COUNT" -eq 1 ]]; then
  kill "$LEGACY_PIDS" 2>/dev/null || true
  for _ in {1..20}; do
    sleep 0.25
    if ! pgrep -x PiPing >/dev/null 2>&1; then break; fi
  done
  if pgrep -x PiPing >/dev/null 2>&1; then
    echo "PiPing process did not exit within five seconds." >&2
    exit 1
  fi
fi
"$LSREGISTER" -u "$LEGACY_APP" 2>/dev/null || true
"$LSREGISTER" -u "$QUARANTINED_APP" 2>/dev/null || true

BACKUP_DIR="$ROOT_DIR/.build/piping-retirement-backups"
mkdir -p "$BACKUP_DIR"
backup="$BACKUP_DIR/PiPing-retired-$(date +%Y%m%dT%H%M%S)-$$.app.zip"
backup_temp="$BACKUP_DIR/.PiPing-retired-$$.tmp.zip"
BACKUP_APP="$BACKUP_STAGE/PiPing.app"
ditto "$QUARANTINED_APP" "$BACKUP_APP"
"$ROOT_DIR/script/validate_legacy_piping_source_local_app.sh" "$BACKUP_APP" >/dev/null
ditto -c -k --keepParent "$BACKUP_APP" "$backup_temp"
"$ROOT_DIR/script/validate_legacy_piping_source_local_archive.sh" "$backup_temp" >/dev/null
"$LSREGISTER" -u "$BACKUP_APP" 2>/dev/null || true
rm -rf "$BACKUP_STAGE"
mv "$backup_temp" "$backup"
backup_temp=""
retained=1
while IFS= read -r archived_app; do
  [[ "$archived_app" != "$backup" ]] || continue
  retained=$((retained + 1))
  if [[ "$retained" -gt 3 ]]; then rm -f "$archived_app"; fi
done < <(find "$BACKUP_DIR" -type f -name 'PiPing-retired-*.app.zip' -print | sort -r)

if [[ "$legacy_runtime_removable" == true ]]; then
  if ! legacy_runtime_is_removable; then
    echo "The legacy runtime changed after preflight; it was not removed." >&2
    exit 1
  fi
  if [[ -p "$LEGACY_FIFO" ]]; then rm "$LEGACY_FIFO"; fi
  if [[ -d "$LEGACY_RUNTIME_DIR" ]]; then rmdir "$LEGACY_RUNTIME_DIR"; fi
elif [[ -e "$LEGACY_RUNTIME_DIR" || -L "$LEGACY_RUNTIME_DIR" ]]; then
  echo "Preserved the legacy runtime because it contains unexpected state." >&2
fi

if pgrep -x PiPing >/dev/null 2>&1; then
  echo "A PiPing process remains after retirement." >&2
  exit 1
fi
if [[ -e "$LEGACY_APP" || -L "$LEGACY_APP" ]]; then
  echo "An unexpected canonical PiPing path appeared during retirement." >&2
  exit 1
fi
if [[ -n "$(legacy_launchservices_paths)" ]]; then
  echo "A PiPing LaunchServices path remains after unregistering the app." >&2
  exit 1
fi
"$ROOT_DIR/script/check_source_installation.sh" >/dev/null
if [[ "$(path_identity "$QUARANTINED_APP")" != "$quarantined_identity" ]]; then
  echo "Quarantined PiPing identity changed before retirement commit." >&2
  exit 1
fi

# All absence/new-app checks and archive validation commit the retirement before
# deletion. Old preferences and Apple notification history remain untouched.
completed=true
restore_needed=false
rm -rf "$QUARANTINED_APP"

echo "Retired the exact legacy PiPing source-local app."
echo "SettleBell remains installed and validated at $SETTLEBELL_APP"
echo "Compressed PiPing recovery copy: $backup"
echo "Legacy preferences and Apple notification authorization/history were preserved."
echo "Remove any remote PiPing package separately with pi remove and its exact original source."
