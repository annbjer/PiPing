#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ $# -ne 1 ]]; then
  echo "usage: $0 path/to/SettleBell.app" >&2
  exit 2
fi

# Shared by both installation classes, including prior-app acceptance, staging,
# backups and rollback. Reject unsafe metadata; never normalize untrusted input.
python3 "$ROOT_DIR/script/validate_local_app_tree.py" "$1"
