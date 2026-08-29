#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="${1:-}"
CANONICAL_APP="/Applications/PiPing.app"
CANONICAL_EXECUTABLE="$CANONICAL_APP/Contents/MacOS/PiPing"
PUBLIC_BUNDLE_IDENTIFIER="org.example.PiPing.macOS"
RUNTIME_DIR="$HOME/.piping"
FIFO="$RUNTIME_DIR/events.fifo"
SETTINGS="$HOME/.pi/agent/settings.json"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

if [[ "$MODE" != "--check" && "$MODE" != "--uninstall" ]] || [[ $# -ne 1 ]]; then
  echo "usage: $0 [--check|--uninstall]" >&2
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
     -o -name '.PiPing-previous-*.app' \) -print -quit)"
if [[ -n "$stale_transaction" ]]; then
  echo "A prior PiPing transaction requires manual recovery before continuing." >&2
  exit 1
fi
if [[ -L "$CANONICAL_APP" ]]; then
  echo "Refusing a symbolic link at the canonical application path." >&2
  exit 1
fi
"$ROOT_DIR/script/validate_source_local_app.sh" "$CANONICAL_APP"

path_identity() {
  stat -f '%d:%i' "$1" 2>/dev/null || true
}

has_extended_acl() {
  ls -lde "$1" 2>/dev/null | awk 'NR > 1 {found=1} END {exit found ? 0 : 1}'
}

runtime_is_removable() {
  if [[ ! -e "$RUNTIME_DIR" && ! -L "$RUNTIME_DIR" ]]; then return 0; fi
  if [[ -L "$RUNTIME_DIR" || ! -d "$RUNTIME_DIR" \
     || "$(stat -f %Su "$RUNTIME_DIR")" != "$(id -un)" \
     || "$(stat -f %Lp "$RUNTIME_DIR")" != 700 ]] \
     || has_extended_acl "$RUNTIME_DIR"; then
    return 1
  fi
  local unexpected
  unexpected="$(find "$RUNTIME_DIR" -mindepth 1 -maxdepth 1 ! -name events.fifo -print -quit)"
  if [[ -n "$unexpected" || -L "$FIFO" ]]; then return 1; fi
  if [[ -e "$FIFO" ]]; then
    if [[ ! -p "$FIFO" \
       || "$(stat -f %Su "$FIFO")" != "$(id -un)" \
       || "$(stat -f %Lp "$FIFO")" != 600 ]] \
       || has_extended_acl "$FIFO"; then
      return 1
    fi
  fi
  return 0
}

PI_COMMAND="$(command -v pi 2>/dev/null || true)"
if [[ -z "$PI_COMMAND" && -d "$HOME/.local/share/pi-node" ]]; then
  for candidate in "$HOME"/.local/share/pi-node/*/bin/pi; do
    if [[ -x "$candidate" ]]; then
      PI_COMMAND="$candidate"
      break
    fi
  done
fi
NODE_COMMAND="$(command -v node 2>/dev/null || true)"
if [[ -z "$NODE_COMMAND" && -n "$PI_COMMAND" ]]; then
  NODE_COMMAND="$(dirname "$PI_COMMAND")/node"
fi

local_package_present() {
  if [[ ! -f "$SETTINGS" ]]; then
    printf 'false'
    return
  fi
  if [[ -z "$PI_COMMAND" || ! -x "$NODE_COMMAND" ]]; then
    if grep -Fq "/$(basename "$ROOT_DIR")\"" "$SETTINGS"; then
      echo "A possible matching local Pi package exists, but Pi/Node is unavailable." >&2
      return 1
    fi
    printf 'false'
    return
  fi
  "$NODE_COMMAND" - "$SETTINGS" "$ROOT_DIR" <<'NODE'
const fs = require("node:fs");
const path = require("node:path");
const [settingsPath, root] = process.argv.slice(2);
const settings = JSON.parse(fs.readFileSync(settingsPath, "utf8"));
const rootPath = fs.realpathSync(root);
const matches = (settings.packages || []).filter((entry) => {
  const source = typeof entry === "string" ? entry : entry?.source;
  if (typeof source !== "string" || /^[a-z]+:/i.test(source)) return false;
  const resolved = path.resolve(path.dirname(settingsPath), source);
  try { return fs.realpathSync(resolved) === rootPath; }
  catch { return false; }
});
if (matches.length > 1) process.exit(2);
process.stdout.write(matches.length === 1 ? "true" : "false");
NODE
}

launchservices_paths() {
  local dump
  dump="$(mktemp "${TMPDIR:-/tmp}/piping-source-uninstall-ls.XXXXXX")"
  "$LSREGISTER" -dump >"$dump" 2>/dev/null
  awk -v expected="$PUBLIC_BUNDLE_IDENTIFIER" '
    /^-+$/ {
      if (identifier == expected && path != "") print path
      identifier=""; path=""; next
    }
    /^identifier:[[:space:]]+/ {
      value=$0; sub(/^identifier:[[:space:]]+/,"",value)
      sub(/[[:space:]].*$/, "", value); identifier=value; next
    }
    /^path:[[:space:]]+/ {
      value=$0; sub(/^path:[[:space:]]+/,"",value)
      sub(/[[:space:]]+\(0x[[:xdigit:]]+\).*$/, "", value); path=value
    }
    END {if (identifier == expected && path != "") print path}
  ' "$dump" | sort -u
  rm -f "$dump"
}

PIDS="$(pgrep -x PiPing || true)"
PID_COUNT="$(printf '%s\n' "$PIDS" | awk 'NF {count++} END {print count+0}')"
if [[ "$PID_COUNT" -gt 1 ]]; then
  echo "Refusing to uninstall while multiple PiPing processes exist." >&2
  exit 1
fi
if [[ "$PID_COUNT" -eq 1 ]] \
   && [[ "$(ps -p "$PIDS" -o command=)" != "$CANONICAL_EXECUTABLE" ]]; then
  echo "Refusing to stop a noncanonical PiPing process." >&2
  exit 1
fi
if [[ -L "$RUNTIME_DIR" || -L "$FIFO" ]]; then
  echo "Refusing to uninstall while the PiPing runtime contains a symbolic link." >&2
  exit 1
fi
runtime_removable=false
if runtime_is_removable; then runtime_removable=true; fi
local_package="$(local_package_present)"
current_ls_paths="$(launchservices_paths)"
if printf '%s\n' "$current_ls_paths" | awk 'NF && $0 != "/Applications/PiPing.app" {bad=1} END {exit bad ? 0 : 1}'; then
  echo "Refusing to uninstall while a noncanonical PiPing LaunchServices path exists." >&2
  exit 1
fi

if [[ "$MODE" == "--check" ]]; then
  echo "Source-local uninstall preflight passed."
  if [[ "$runtime_removable" == true ]]; then
    echo "The protected PiPing runtime can be removed safely."
  else
    echo "The runtime contains unexpected state and would be preserved." >&2
  fi
  if [[ "$local_package" == true ]]; then
    echo "The matching local-checkout Pi package would also be removed."
  else
    echo "No matching local-checkout Pi package was found; remote packages require their original pi remove source."
  fi
  exit 0
fi

TRANSACTION_ROOT="$(mktemp -d /Applications/.PiPing-source-uninstall.XXXXXX)"
chmod 700 "$TRANSACTION_ROOT"
QUARANTINED_APP="$TRANSACTION_ROOT/Previous.payload"
BACKUP_STAGE="$(mktemp -d "${TMPDIR:-/tmp}/piping-source-uninstall-backup.XXXXXX")"
chmod 700 "$BACKUP_STAGE"
quarantined_identity=""
package_removed=false
completed=false
backup=""
backup_temp=""

cleanup() {
  local preserve_transaction=false restored_package_state=""
  [[ -z "$backup_temp" ]] || rm -f "$backup_temp"
  "$LSREGISTER" -u "$QUARANTINED_APP" 2>/dev/null || true
  "$LSREGISTER" -u "$BACKUP_STAGE/PiPing.app" 2>/dev/null || true
  rm -rf "$BACKUP_STAGE"
  if [[ "$completed" == false && -d "$QUARANTINED_APP" ]]; then
    if [[ "$(path_identity "$QUARANTINED_APP")" != "$quarantined_identity" ]]; then
      echo "Recovery preserved a changed quarantined app for manual inspection." >&2
      preserve_transaction=true
    elif [[ ! -e "$CANONICAL_APP" && ! -L "$CANONICAL_APP" ]]; then
      mv "$QUARANTINED_APP" "$CANONICAL_APP"
      if [[ "$(path_identity "$CANONICAL_APP")" == "$quarantined_identity" ]] \
        && "$ROOT_DIR/script/validate_source_local_app.sh" "$CANONICAL_APP" >/dev/null 2>&1; then
        "$LSREGISTER" -f "$CANONICAL_APP" 2>/dev/null || true
        open "$CANONICAL_APP" 2>/dev/null || true
      else
        echo "Recovery could not validate the restored canonical app." >&2
        preserve_transaction=true
      fi
    else
      echo "Recovery was blocked by an unexpected canonical path; the app was preserved." >&2
      preserve_transaction=true
    fi
    if [[ "$local_package" == true ]]; then
      restored_package_state="$(local_package_present 2>/dev/null || printf 'unknown')"
      if [[ "$restored_package_state" != true ]]; then
        if ! (cd "$ROOT_DIR" && PATH="$(dirname "$PI_COMMAND"):$PATH" "$PI_COMMAND" install . >/dev/null); then
          echo "Recovery could not restore the local Pi package." >&2
          preserve_transaction=true
        fi
      fi
    fi
  fi
  if [[ "$preserve_transaction" == false ]]; then
    rm -rf "$TRANSACTION_ROOT"
  else
    echo "Preserved interrupted uninstall transaction for recovery: $TRANSACTION_ROOT" >&2
  fi
}
trap cleanup EXIT

mv "$CANONICAL_APP" "$QUARANTINED_APP"
quarantined_identity="$(path_identity "$QUARANTINED_APP")"
if [[ -z "$quarantined_identity" ]] \
  || ! "$ROOT_DIR/script/validate_source_local_app.sh" "$QUARANTINED_APP" >/dev/null 2>&1; then
  echo "The atomically quarantined app failed validation." >&2
  exit 1
fi

if [[ "$PID_COUNT" -eq 1 ]]; then
  kill "$PIDS" 2>/dev/null || true
  for _ in {1..20}; do
    sleep 0.25
    if ! pgrep -x PiPing >/dev/null 2>&1; then break; fi
  done
  if pgrep -x PiPing >/dev/null 2>&1; then
    echo "PiPing process did not exit within five seconds." >&2
    exit 1
  fi
fi
"$LSREGISTER" -u "$CANONICAL_APP" 2>/dev/null || true
"$LSREGISTER" -u "$QUARANTINED_APP" 2>/dev/null || true

BACKUP_DIR="$ROOT_DIR/.build/source-uninstall-backups"
mkdir -p "$BACKUP_DIR"
backup="$BACKUP_DIR/PiPing-removed-$(date +%Y%m%dT%H%M%S)-$$.app.zip"
backup_temp="$BACKUP_DIR/.PiPing-removed-$$.tmp.zip"
BACKUP_APP="$BACKUP_STAGE/PiPing.app"
ditto "$QUARANTINED_APP" "$BACKUP_APP"
"$ROOT_DIR/script/validate_source_local_app.sh" "$BACKUP_APP" >/dev/null
ditto -c -k --keepParent "$BACKUP_APP" "$backup_temp"
"$ROOT_DIR/script/validate_source_local_archive.sh" "$backup_temp" >/dev/null
"$LSREGISTER" -u "$BACKUP_APP" 2>/dev/null || true
rm -rf "$BACKUP_STAGE"
mv "$backup_temp" "$backup"
backup_temp=""
retained=1
while IFS= read -r archived_app; do
  [[ "$archived_app" != "$backup" ]] || continue
  retained=$((retained + 1))
  if [[ "$retained" -gt 3 ]]; then rm -f "$archived_app"; fi
done < <(find "$BACKUP_DIR" -type f -name 'PiPing-removed-*.app.zip' -print | sort -r)

if [[ "$local_package" == true ]]; then
  (cd "$ROOT_DIR" && PATH="$(dirname "$PI_COMMAND"):$PATH" "$PI_COMMAND" remove .)
  package_removed=true
  if [[ "$(local_package_present)" != false ]]; then
    echo "The exact local Pi package remains after removal." >&2
    exit 1
  fi
fi

if [[ "$runtime_removable" == true ]]; then
  if ! runtime_is_removable; then
    echo "The PiPing runtime changed after preflight; it was not removed." >&2
    exit 1
  fi
  if [[ -p "$FIFO" ]]; then rm "$FIFO"; fi
  if [[ -d "$RUNTIME_DIR" ]]; then rmdir "$RUNTIME_DIR"; fi
elif [[ -e "$RUNTIME_DIR" ]]; then
  echo "Preserved the runtime because it contains unexpected state." >&2
fi

if pgrep -x PiPing >/dev/null 2>&1; then
  echo "A PiPing process remains after uninstall." >&2
  exit 1
fi
if [[ -e "$CANONICAL_APP" || -L "$CANONICAL_APP" ]]; then
  echo "An unexpected canonical PiPing path appeared during uninstall." >&2
  exit 1
fi
if [[ -n "$(launchservices_paths)" ]]; then
  echo "A PiPing LaunchServices path remains after unregistering the app." >&2
  exit 1
fi
if [[ "$package_removed" == true && "$(local_package_present)" != false ]]; then
  echo "The local Pi package remains after uninstall." >&2
  exit 1
fi

defaults delete "$PUBLIC_BUNDLE_IDENTIFIER" >/dev/null 2>&1 || true
if [[ "$(path_identity "$QUARANTINED_APP")" != "$quarantined_identity" ]]; then
  echo "Quarantined app identity changed before final deletion." >&2
  exit 1
fi
# All absence checks and recovery-archive validation have committed the
# uninstall. Mark it complete before deleting the quarantined payload so an
# interruption cannot restore a partially deleted bundle.
completed=true
rm -rf "$QUARANTINED_APP"

echo "Removed the source-local PiPing app and safe app-owned local state."
echo "Compressed recovery copy: $backup"
echo "macOS notification authorization/history remains under Apple control."
if [[ "$local_package" == false ]]; then
  echo "If PiPing was installed from Git or another source, remove that exact source with pi remove."
fi
