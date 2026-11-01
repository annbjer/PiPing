#!/usr/bin/env bash
# Shared by guarded local install/uninstall transactions. The caller must use
# set -euo pipefail and pass only repository-owned ignored backup directories.

guarded_path_has_extended_acl() {
  ls -lde "$1" 2>/dev/null | awk 'NR > 1 {found=1} END {exit found ? 0 : 1}'
}

guarded_prepare_private_directory() {
  local directory="$1"
  if [[ -L "$directory" || ( -e "$directory" && ! -d "$directory" ) ]]; then
    echo "Guarded backup path is not a real directory: $directory" >&2
    return 1
  fi
  if [[ ! -e "$directory" ]]; then
    mkdir -m 700 "$directory"
  fi
  if [[ "$(stat -f %Su "$directory")" != "$(id -un)" ]] \
    || guarded_path_has_extended_acl "$directory"; then
    echo "Guarded backup directory has unexpected ownership or ACL: $directory" >&2
    return 1
  fi
  chmod 700 "$directory"
  if [[ "$(stat -f %Lp "$directory")" != 700 ]]; then
    echo "Guarded backup directory is not mode 0700: $directory" >&2
    return 1
  fi
}

guarded_validate_existing_archives() {
  local directory="$1"
  local pattern="$2"
  local validator="$3"
  local archive
  while IFS= read -r archive; do
    [[ -n "$archive" ]] || continue
    if [[ -L "$archive" || ! -f "$archive" ]]; then
      echo "Guarded backup entry is not a regular archive: $archive" >&2
      return 1
    fi
    "$validator" "$archive" >/dev/null
  done < <(find "$directory" -maxdepth 1 -name "$pattern" -print | sort)
}

guarded_prune_validated_archives() {
  local directory="$1"
  local pattern="$2"
  local current="$3"
  local validator="$4"
  local archive retained=1
  if [[ -L "$current" || ! -f "$current" ]]; then
    echo "Current guarded recovery archive is not a regular file: $current" >&2
    return 1
  fi
  "$validator" "$current" >/dev/null
  while IFS= read -r archive; do
    [[ -n "$archive" && "$archive" != "$current" ]] || continue
    "$validator" "$archive" >/dev/null
    retained=$((retained + 1))
    if [[ "$retained" -gt 3 ]]; then
      rm -f "$archive"
    fi
  done < <(find "$directory" -maxdepth 1 -type f -name "$pattern" -print | sort -r)
}
