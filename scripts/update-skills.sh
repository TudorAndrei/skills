#!/usr/bin/env bash
# Refresh vendored snapshots in skills/ from their declared upstream sources.
#
# Usage:
#   scripts/update-skills.sh [names...] [--yes]   advance to each tracked ref head
#   scripts/update-skills.sh --locked [names...]  reproduce the pinned commits
#   scripts/update-skills.sh --relock [names...]  keep pinned commits and accept overlay changes
#
# Advancing shows one preview of every commit and hash change and asks once.
# --locked never advances: it re-fetches the commit already in the lock and
# fails if the result does not reproduce the locked hash.
# --relock also keeps the pinned commit, but it updates the hash after a reviewed
# overlay change.
#
# Every requested snapshot is staged and validated before anything is replaced,
# so a failure part-way through leaves the working tree untouched.
set -euo pipefail

# shellcheck source=scripts/vendor-lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/vendor-lib.sh"

ensure_files

locked=0
relock=0
assume_yes=0
declare -a requested=()

while [ $# -gt 0 ]; do
  case "$1" in
    --locked) locked=1 ;;
    --relock) relock=1 ;;
    --yes | -y) assume_yes=1 ;;
    -*) die "unknown option: $1" ;;
    *) requested+=("$1") ;;
  esac
  shift
done

[ "$locked" -eq 0 ] || [ "$relock" -eq 0 ] || die "--locked and --relock cannot be used together"

if [ "${#requested[@]}" -eq 0 ]; then
  while IFS= read -r n; do [ -n "$n" ] && requested+=("$n"); done < <(manifest_names)
fi
[ "${#requested[@]}" -gt 0 ] || {
  note "no vendored skills declared in skills/sources.json"
  exit 0
}

stage_root="$(mktemp -d)"
trap 'rm -rf "$stage_root"' EXIT

declare -a names=() commits=() hashes=() preview=() targets=()
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

  if [ "$locked" -eq 1 ] || [ "$relock" -eq 1 ]; then
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
      hint="vendor-overlays/$name changed since the lock was written - run 'mise run relock $name'"
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
  # A snapshot sitting anywhere but its publisher directory counts as work too.
  target="$(skill_dir "$name")"
  targets+=("$target")
  on_disk="$(find_skill_dirs "$name" | paste -sd, -)"
  disk_hash=""
  [ "$on_disk" = "$target" ] && disk_hash="$(snapshot_hash "$target")"

  if [ "$new_hash" = "$disk_hash" ] &&
    { [ "$relock" -eq 0 ] || [ "$new_hash" = "$old_hash" ]; }; then
    preview+=("  $name  unchanged (${FETCHED_COMMIT:0:12})")
  else
    changed=1
    if [ "$new_hash" = "$disk_hash" ] && [ "$new_hash" != "$old_hash" ]; then
      preview+=("  $name  ${FETCHED_COMMIT:0:12}  [lock refreshed]")
    elif [ -n "$on_disk" ] && [ -z "$disk_hash" ]; then
      preview+=("  $name  ${FETCHED_COMMIT:0:12}  [-> $(skill_rel "$target")]")
    elif [ -z "$disk_hash" ]; then
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
    if [ "$relock" -eq 1 ]; then
      note "every snapshot already matches its pinned commit and current overlay"
    else
      note "everything already at the tracked head; nothing to do"
    fi
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

declare -a backups=() stale_from=() stale_to=()
restore() {
  local i
  for ((i = 0; i < ${#backups[@]}; i++)); do
    [ -n "${backups[$i]}" ] && [ -d "${backups[$i]}" ] || continue
    rm -rf "${targets[$i]:?}"
    mv "${backups[$i]}" "${targets[$i]}"
  done
  for ((i = 0; i < ${#stale_to[@]}; i++)); do
    [ -d "${stale_to[$i]}" ] || continue
    mkdir -p "$(dirname "${stale_from[$i]}")"
    mv "${stale_to[$i]}" "${stale_from[$i]}"
  done
  die "swap failed, rolled back"
}

for ((i = 0; i < ${#names[@]}; i++)); do
  name="${names[$i]}"
  target="${targets[$i]}"

  # A copy left at an old location - flat, or under a previous attribution.
  while IFS= read -r old; do
    [ -n "$old" ] && [ "$old" != "$target" ] || continue
    aside="$stage_root/.stale-${#stale_to[@]}"
    mv "$old" "$aside" || restore
    stale_from+=("$old")
    stale_to+=("$aside")
    note "  moved $(skill_rel "$old") -> $(skill_rel "$target")"
  done < <(find_skill_dirs "$name")

  if [ -d "$target" ]; then
    backup="$stage_root/.bak-$name"
    mv "$target" "$backup" || restore
    backups+=("$backup")
  else
    backups+=("")
  fi
  mkdir -p "$(dirname "$target")" || restore
  mv "$stage_root/$name" "$target" || restore
done

find "$SKILLS_DIR" -mindepth 1 -maxdepth 1 -type d -empty -delete

for ((i = 0; i < ${#names[@]}; i++)); do
  lock_put "${names[$i]}" "${commits[$i]}" "${hashes[$i]}"
done

sync_hk_excludes
note "updated ${#names[@]} snapshot(s); review 'git diff skills/sources.lock.json'"
