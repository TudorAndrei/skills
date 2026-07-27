#!/usr/bin/env bash
# Refresh vendored snapshots in skills/ from their declared upstream sources.
#
# Usage:
#   scripts/update-skills.sh [names...] [--yes]   advance to each tracked ref head
#   scripts/update-skills.sh --locked [names...]  reproduce the pinned commits
#
# Advancing shows one preview of every commit and hash change and asks once.
# --locked never advances: it re-fetches the commit already in the lock and
# fails if the result does not reproduce the locked hash.
#
# Every requested snapshot is staged and validated before anything is replaced,
# so a failure part-way through leaves the working tree untouched.
set -euo pipefail

# shellcheck source=scripts/vendor-lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/vendor-lib.sh"

ensure_files

locked=0
assume_yes=0
declare -a requested=()

while [ $# -gt 0 ]; do
  case "$1" in
    --locked) locked=1 ;;
    --yes | -y) assume_yes=1 ;;
    -*) die "unknown option: $1" ;;
    *) requested+=("$1") ;;
  esac
  shift
done

if [ "${#requested[@]}" -eq 0 ]; then
  while IFS= read -r n; do [ -n "$n" ] && requested+=("$n"); done < <(manifest_names)
fi
[ "${#requested[@]}" -gt 0 ] || {
  note "no vendored skills declared in skills/sources.json"
  exit 0
}

stage_root="$(mktemp -d)"
trap 'rm -rf "$stage_root"' EXIT

declare -a names=() commits=() hashes=() preview=()
changed=0

for name in "${requested[@]}"; do
  manifest_has "$name" || die "$name is not declared in skills/sources.json"

  url="$(manifest_field "$name" repo)"
  upstream_path="$(manifest_field "$name" path)"
  ref="$(manifest_field "$name" ref)"
  author="$(manifest_field "$name" author)"
  homepage="$(manifest_field "$name" homepage)"
  old_commit="$(locked_commit "$name")"
  old_hash="$(locked_hash "$name")"

  if [ "$locked" -eq 1 ]; then
    [ -n "$old_commit" ] || die "$name has no locked commit to reproduce"
    target="$old_commit"
  else
    target="$ref"
  fi

  dest="$stage_root/$name"
  fetch_snapshot "$url" "$target" "$upstream_path" "$dest"

  if [ -n "$FETCHED_LICENSE" ]; then
    cp "$FETCHED_LICENSE" "$dest/LICENSE.upstream"
    spdx="$(spdx_guess "$dest/LICENSE.upstream")"
  else
    spdx="UNKNOWN"
    warn "$name: no license file found upstream"
  fi
  rm -rf "$FETCH_WORKDIR"

  apply_overlay "$name" "$dest"
  validate_skill "$dest" "$name"
  write_provenance "$dest" "$name" "$url" "$upstream_path" "$ref" \
    "$FETCHED_COMMIT" "$author" "$homepage" "$spdx"
  new_hash="$(snapshot_hash "$dest")"

  if [ "$locked" -eq 1 ] && [ "$new_hash" != "$old_hash" ]; then
    hint="upstream may have been force-pushed, or the fetch is not deterministic"
    [ -d "$ROOT/vendor-overlays/$name" ] &&
      hint="vendor-overlays/$name changed since the lock was written - run 'mise run update $name' to re-lock"
    die "$name: locked commit ${old_commit:0:12} does not reproduce the locked hash
  expected $old_hash
  found    $new_hash
  $hint"
  fi

  names+=("$name")
  commits+=("$FETCHED_COMMIT")
  hashes+=("$new_hash")

  # Whether work is needed is decided against the working tree, not the lock:
  # a hand-edited snapshot still matches its lock entry but must be replaced.
  disk_hash=""
  [ -d "$SKILLS_DIR/$name" ] && disk_hash="$(snapshot_hash "$SKILLS_DIR/$name")"

  if [ "$new_hash" = "$disk_hash" ]; then
    preview+=("  $name  unchanged (${FETCHED_COMMIT:0:12})")
  else
    changed=1
    if [ -z "$disk_hash" ]; then
      preview+=("  $name  missing -> ${FETCHED_COMMIT:0:12}  [restored]")
    elif [ "$FETCHED_COMMIT" = "$old_commit" ]; then
      preview+=("  $name  ${FETCHED_COMMIT:0:12}  [local edits discarded]")
    else
      preview+=("  $name  ${old_commit:0:12} -> ${FETCHED_COMMIT:0:12}  [contents changed]")
    fi
  fi
done

printf '\n'
printf '%s\n' "${preview[@]}"
printf '\n'

if [ "$changed" -eq 0 ]; then
  if [ "$locked" -eq 1 ]; then
    note "every snapshot already reproduces its pinned commit"
  else
    note "everything already at the tracked head; nothing to do"
  fi
  exit 0
fi

if [ "$locked" -eq 0 ] && [ "$assume_yes" -eq 0 ]; then
  if [ -t 0 ]; then
    read -r -p "apply these updates? [y/N] " answer
    case "$answer" in [yY] | [yY][eE][sS]) ;; *) die "aborted" ;; esac
  else
    die "refusing to update non-interactively without --yes"
  fi
fi

declare -a backups=()
restore() {
  local i
  for ((i = 0; i < ${#backups[@]}; i++)); do
    [ -n "${backups[$i]}" ] && [ -d "${backups[$i]}" ] || continue
    rm -rf "${SKILLS_DIR:?}/${names[$i]}"
    mv "${backups[$i]}" "$SKILLS_DIR/${names[$i]}"
  done
  die "swap failed, rolled back"
}

for ((i = 0; i < ${#names[@]}; i++)); do
  name="${names[$i]}"
  if [ -d "$SKILLS_DIR/$name" ]; then
    backup="$stage_root/.bak-$name"
    mv "$SKILLS_DIR/$name" "$backup" || restore
    backups+=("$backup")
  else
    backups+=("")
  fi
  mv "$stage_root/$name" "$SKILLS_DIR/$name" || restore
done

for ((i = 0; i < ${#names[@]}; i++)); do
  lock_put "${names[$i]}" "${commits[$i]}" "${hashes[$i]}"
done

sync_marketplace
sync_hk_excludes
note "updated ${#names[@]} snapshot(s); review 'git diff skills/sources.lock.json'"
