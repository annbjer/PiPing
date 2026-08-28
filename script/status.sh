#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STABLE_DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"

if [[ ! -x "$STABLE_DEVELOPER_DIR/usr/bin/xcodebuild" ]]; then
  echo "Stable Xcode is required at $STABLE_DEVELOPER_DIR" >&2
  exit 1
fi
export DEVELOPER_DIR="$STABLE_DEVELOPER_DIR"

echo "PiPing development status"
xcodebuild -version
printf "Pi: "
pi --version
echo "Public CloudKit default: disabled"
if [[ -f "$ROOT_DIR/Config/Local.xcconfig" ]]; then
  if git -C "$ROOT_DIR" check-ignore -q "Config/Local.xcconfig"; then
    echo "Private local override: present and ignored (values hidden)"
  else
    echo "Private local override: PRESENT BUT NOT IGNORED"
  fi
else
  echo "Private local override: absent"
fi
echo "Phase 2 controls: disabled in source"
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

CANONICAL_APP="/Applications/PiPing.app"
if [[ -d "$CANONICAL_APP" ]]; then
  echo "Canonical installation:"
  "$ROOT_DIR/script/check_installation.sh"
else
  echo "Canonical installation: absent"
fi
