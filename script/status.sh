#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STABLE_DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"

if [[ ! -x "$STABLE_DEVELOPER_DIR/usr/bin/xcodebuild" ]]; then
  echo "Stable Xcode is required at $STABLE_DEVELOPER_DIR" >&2
  exit 1
fi
export DEVELOPER_DIR="$STABLE_DEVELOPER_DIR"

echo "SettleBell development status"
xcodebuild -version
printf "Pi: "
pi --version
echo "Public CloudKit default: disabled"
IS_GIT_CHECKOUT=false
if [[ -e "$ROOT_DIR/.git" ]] && git -C "$ROOT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  IS_GIT_CHECKOUT=true
fi
if [[ -f "$ROOT_DIR/Config/Local.xcconfig" ]]; then
  if [[ "$IS_GIT_CHECKOUT" == false ]]; then
    echo "Private local override: present; ignore status unavailable outside Git (values hidden)"
  elif git -C "$ROOT_DIR" check-ignore -q "Config/Local.xcconfig"; then
    echo "Private local override: present and ignored (values hidden)"
  else
    echo "Private local override: PRESENT BUT NOT IGNORED"
  fi
else
  echo "Private local override: absent"
fi
echo "Phase 2 controls: disabled in source"
if [[ "$IS_GIT_CHECKOUT" == true ]]; then
  echo "Prospective public entitlement/config surface:"
  git -C "$ROOT_DIR" ls-files --cached --others --exclude-standard -- \
    '*.entitlements' '*.xcconfig'
  echo "Non-ignored sensitive signing-file candidates:"
  SENSITIVE_FILES="$(git -C "$ROOT_DIR" ls-files --cached --others --exclude-standard -- \
    '*.mobileprovision' '*.provisionprofile' '*.p8' '*.p12' '*.cer' '*.key' '*.pem')"
  if [[ -n "$SENSITIVE_FILES" ]]; then
    printf '%s\n' "$SENSITIVE_FILES"
  else
    echo "none"
  fi
  echo "Working tree:"
  git -C "$ROOT_DIR" status --short
else
  echo "Git-based file inventory and working-tree status: unavailable (not a Git checkout)"
fi

CANONICAL_APP="/Applications/SettleBell.app"
if [[ -e "$CANONICAL_APP" || -L "$CANONICAL_APP" ]]; then
  if "$ROOT_DIR/script/check_local_installation.sh" >/dev/null 2>&1; then
    echo "Canonical installation: valid (private details hidden)"
  else
    echo "Canonical installation: validation failed (private details hidden)" >&2
    exit 1
  fi
else
  echo "Canonical installation: absent"
fi
