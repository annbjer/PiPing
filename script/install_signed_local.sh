#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="${1:-}"
ARCHIVE="${2:-$ROOT_DIR/dist/private/PiPing.app.zip}"
CANONICAL_APP="/Applications/PiPing.app"
CANONICAL_EXECUTABLE="$CANONICAL_APP/Contents/MacOS/PiPing"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
MAX_ARCHIVE_BYTES=$((100 * 1024 * 1024))

if [[ "$MODE" != "--check" && "$MODE" != "--install" ]] || [[ $# -gt 2 ]]; then
  echo "usage: $0 [--check|--install] [path/to/PiPing.app.zip]" >&2
  echo "Build the local-only signed archive with script/build_signed_local.sh first." >&2
  exit 2
fi
if [[ ! -f "$ARCHIVE" || -L "$ARCHIVE" ]]; then
  echo "Signed local archive must be a regular, non-symbolic-link file." >&2
  exit 1
fi
if [[ ! -w /Applications ]]; then
  echo "/Applications is not writable by the current user; no changes were made." >&2
  exit 1
fi
stale_transaction="$(find /Applications -maxdepth 1 \
  \( -name '.PiPing-signed-transaction.*' \
     -o -name '.PiPing-source-transaction.*' \
     -o -name '.PiPing-source-uninstall.*' \
     -o -name '.PiPing-installing-*.app' \
     -o -name '.PiPing-previous-*.app' \
     -o -name '.PiPing-source-installing-*.app' \
     -o -name '.PiPing-source-previous-*.app' \) -print -quit)"
if [[ -n "$stale_transaction" ]]; then
  echo "A prior PiPing transaction requires manual recovery before continuing." >&2
  exit 1
fi

STAGE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/piping-signed-install.XXXXXX")"
chmod 700 "$STAGE_ROOT"
FIXED_ARCHIVE="$STAGE_ROOT/PiPing.app.zip"
TRANSACTION_ROOT=""
CANDIDATE_APP=""
PREVIOUS_APP=""
restore_needed=false
candidate_installed=false
candidate_identity=""
previous_identity=""
backup=""
backup_temp=""

path_identity() {
  stat -f '%d:%i' "$1" 2>/dev/null || true
}

stop_canonical_process() {
  local pids
  pids="$(pgrep -f '^/Applications/PiPing\.app/Contents/MacOS/PiPing$' || true)"
  if [[ -n "$pids" ]]; then
    kill $pids 2>/dev/null || true
    for _ in {1..20}; do
      sleep 0.25
      if ! pgrep -f '^/Applications/PiPing\.app/Contents/MacOS/PiPing$' >/dev/null 2>&1; then
        return 0
      fi
    done
    echo "Canonical PiPing process did not exit within five seconds." >&2
    return 1
  fi
}

handle_signal() {
  exit "$1"
}

cleanup() {
  trap '' HUP INT TERM
  local current_identity preserve_transaction=false
  "$LSREGISTER" -u "$STAGE_ROOT/PiPing.app" 2>/dev/null || true
  "$LSREGISTER" -u "$STAGE_ROOT/Backup/PiPing.app" 2>/dev/null || true
  [[ -z "$CANDIDATE_APP" ]] || "$LSREGISTER" -u "$CANDIDATE_APP" 2>/dev/null || true
  [[ -z "$PREVIOUS_APP" ]] || "$LSREGISTER" -u "$PREVIOUS_APP" 2>/dev/null || true
  [[ -z "$backup_temp" ]] || rm -f "$backup_temp"

  if [[ "$candidate_installed" == true ]]; then
    current_identity="$(path_identity "$CANONICAL_APP")"
    if [[ -n "$candidate_identity" && "$current_identity" == "$candidate_identity" ]]; then
      stop_canonical_process >/dev/null 2>&1 || true
      "$LSREGISTER" -u "$CANONICAL_APP" 2>/dev/null || true
      rm -rf "$CANONICAL_APP"
    elif [[ -e "$CANONICAL_APP" || -L "$CANONICAL_APP" ]]; then
      echo "Automatic rollback did not remove an unexpected canonical path." >&2
      preserve_transaction=true
    fi
  fi

  if [[ "$restore_needed" == true && -n "$PREVIOUS_APP" && -d "$PREVIOUS_APP" ]]; then
    if [[ "$(path_identity "$PREVIOUS_APP")" != "$previous_identity" ]]; then
      echo "Automatic rollback preserved a changed previous app for manual inspection." >&2
      preserve_transaction=true
    elif [[ ! -e "$CANONICAL_APP" && ! -L "$CANONICAL_APP" ]]; then
      mv "$PREVIOUS_APP" "$CANONICAL_APP"
      if [[ "$(path_identity "$CANONICAL_APP")" == "$previous_identity" ]] \
        && "$ROOT_DIR/script/validate_signed_local_app.sh" "$CANONICAL_APP" >/dev/null 2>&1; then
        "$LSREGISTER" -f "$CANONICAL_APP" 2>/dev/null || true
        open "$CANONICAL_APP" 2>/dev/null || true
      else
        echo "Automatic rollback could not validate the restored canonical app." >&2
        preserve_transaction=true
      fi
    else
      echo "Automatic rollback was blocked by an unexpected canonical path; the previous app was preserved." >&2
      preserve_transaction=true
    fi
  fi

  if [[ -n "$TRANSACTION_ROOT" && "$preserve_transaction" == false ]]; then
    rm -rf "$TRANSACTION_ROOT"
  elif [[ -n "$TRANSACTION_ROOT" && -d "$TRANSACTION_ROOT" ]]; then
    echo "Preserved interrupted signed transaction for recovery: $TRANSACTION_ROOT" >&2
  fi
  rm -rf "$STAGE_ROOT"
}
trap cleanup EXIT
trap 'handle_signal 129' HUP
trap 'handle_signal 130' INT
trap 'handle_signal 143' TERM

source_archive_bytes="$(stat -f %z "$ARCHIVE")"
if [[ "$source_archive_bytes" -gt "$MAX_ARCHIVE_BYTES" ]]; then
  echo "Signed local archive exceeds the 100 MiB limit." >&2
  exit 1
fi
dd if="$ARCHIVE" of="$FIXED_ARCHIVE" bs=1048576 count=101 2>/dev/null
chmod 600 "$FIXED_ARCHIVE"
if [[ "$(stat -f %z "$FIXED_ARCHIVE")" -gt "$MAX_ARCHIVE_BYTES" ]]; then
  echo "Signed local archive changed or exceeded the bounded-copy limit." >&2
  exit 1
fi
"$ROOT_DIR/script/validate_signed_local_archive.sh" "$FIXED_ARCHIVE"
ditto -x -k "$FIXED_ARCHIVE" "$STAGE_ROOT"
SOURCE_APP="$STAGE_ROOT/PiPing.app"
if [[ ! -d "$SOURCE_APP" ]]; then
  echo "Archive does not contain PiPing.app at its root." >&2
  exit 1
fi
"$ROOT_DIR/script/validate_signed_local_app.sh" "$SOURCE_APP"

if [[ -L "$CANONICAL_APP" ]]; then
  echo "Refusing a symbolic link at the canonical application path." >&2
  exit 1
fi
if [[ -e "$CANONICAL_APP" ]] \
  && ! "$ROOT_DIR/script/validate_signed_local_app.sh" "$CANONICAL_APP" >/dev/null 2>&1; then
  echo "Refusing to replace a canonical app outside the exact approved signed-local identity." >&2
  exit 1
fi
PIDS="$(pgrep -x PiPing || true)"
PID_COUNT="$(printf '%s\n' "$PIDS" | awk 'NF {count++} END {print count+0}')"
if [[ "$PID_COUNT" -gt 1 ]]; then
  echo "Refusing installation while multiple PiPing processes exist." >&2
  exit 1
fi
if [[ "$PID_COUNT" -eq 1 ]] \
   && [[ "$(ps -p "$PIDS" -o command=)" != "$CANONICAL_EXECUTABLE" ]]; then
  echo "Refusing installation while PiPing runs from a noncanonical path." >&2
  exit 1
fi
if [[ "$MODE" == "--check" ]]; then
  echo "Signed local archive and embedded helper passed preflight validation."
  exit 0
fi

TRANSACTION_ROOT="$(mktemp -d /Applications/.PiPing-signed-transaction.XXXXXX)"
chmod 700 "$TRANSACTION_ROOT"
CANDIDATE_APP="$TRANSACTION_ROOT/Candidate.payload"
PREVIOUS_APP="$TRANSACTION_ROOT/Previous.payload"
ditto "$SOURCE_APP" "$CANDIDATE_APP"
"$ROOT_DIR/script/validate_signed_local_app.sh" "$CANDIDATE_APP"
candidate_identity="$(path_identity "$CANDIDATE_APP")"
if [[ -z "$candidate_identity" ]]; then
  echo "Could not pin the signed candidate app identity." >&2
  exit 1
fi

if [[ -d "$CANONICAL_APP" ]]; then
  previous_identity="$(path_identity "$CANONICAL_APP")"
  if [[ -z "$previous_identity" ]] \
    || ! "$ROOT_DIR/script/validate_signed_local_app.sh" "$CANONICAL_APP" >/dev/null 2>&1; then
    echo "The previous signed app changed before atomic quarantine." >&2
    exit 1
  fi
  # Establish restoration intent before the atomic move. A normal termination
  # signal on either side of mv therefore leaves either the canonical app in
  # place or a pinned Previous.payload that cleanup can validate and restore.
  restore_needed=true
  mv "$CANONICAL_APP" "$PREVIOUS_APP"
  if [[ "$(path_identity "$PREVIOUS_APP")" != "$previous_identity" ]] \
    || ! "$ROOT_DIR/script/validate_signed_local_app.sh" "$PREVIOUS_APP" >/dev/null 2>&1; then
    echo "The atomically quarantined previous signed app failed validation." >&2
    exit 1
  fi
  stop_canonical_process

  BACKUP_DIR="$ROOT_DIR/.build/install-backups"
  mkdir -p "$BACKUP_DIR"
  backup="$BACKUP_DIR/PiPing-before-$(date +%Y%m%dT%H%M%S)-$$.app.zip"
  backup_temp="$BACKUP_DIR/.PiPing-before-$$.tmp.zip"
  BACKUP_APP="$STAGE_ROOT/Backup/PiPing.app"
  mkdir -p "$STAGE_ROOT/Backup"
  ditto "$PREVIOUS_APP" "$BACKUP_APP"
  "$ROOT_DIR/script/validate_signed_local_app.sh" "$BACKUP_APP" >/dev/null
  ditto -c -k --keepParent "$BACKUP_APP" "$backup_temp"
  "$ROOT_DIR/script/validate_signed_local_archive.sh" "$backup_temp" >/dev/null
  "$LSREGISTER" -u "$BACKUP_APP" 2>/dev/null || true
  rm -rf "$STAGE_ROOT/Backup"
  mv "$backup_temp" "$backup"
  backup_temp=""
  retained=1
  while IFS= read -r archived_app; do
    [[ "$archived_app" != "$backup" ]] || continue
    retained=$((retained + 1))
    if [[ "$retained" -gt 3 ]]; then rm -f "$archived_app"; fi
  done < <(find "$BACKUP_DIR" -type f -name 'PiPing-before-*.app.zip' -print | sort -r)
elif [[ "$PID_COUNT" -eq 1 ]]; then
  echo "A canonical PiPing process exists without a canonical app." >&2
  exit 1
fi

if [[ -e "$CANONICAL_APP" || -L "$CANONICAL_APP" ]]; then
  echo "An unexpected object appeared at the canonical application path." >&2
  exit 1
fi
mv "$CANDIDATE_APP" "$CANONICAL_APP"
candidate_installed=true
if [[ "$(path_identity "$CANONICAL_APP")" != "$candidate_identity" ]]; then
  echo "The signed candidate did not retain its pinned canonical identity." >&2
  exit 1
fi
"$ROOT_DIR/script/validate_signed_local_app.sh" "$CANONICAL_APP"

"$LSREGISTER" -u "$PREVIOUS_APP" 2>/dev/null || true
"$LSREGISTER" -f "$CANONICAL_APP"
open "$CANONICAL_APP"
sleep 4
env -u PIPING_CANONICAL_APP "$ROOT_DIR/script/check_installation.sh"

if [[ "$restore_needed" == true ]] \
  && [[ "$(path_identity "$PREVIOUS_APP")" != "$previous_identity" ]]; then
  echo "Previous signed app identity changed before transaction completion." >&2
  exit 1
fi
candidate_installed=false
restore_needed=false
if [[ -d "$PREVIOUS_APP" ]]; then rm -rf "$PREVIOUS_APP"; fi

if [[ -n "$backup" ]]; then echo "Compressed rollback: $backup"; fi
echo "Installed the signed local app at $CANONICAL_APP"
