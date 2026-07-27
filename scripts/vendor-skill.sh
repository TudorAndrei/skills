#!/usr/bin/env bash
# Vendor an external skill into skills/ as a pinned, generated snapshot.
#
# Usage:
#   scripts/vendor-skill.sh <owner/repo | owner/repo@skill | url> [options]
#
# A github.com /blob/ or /tree/ link works too: the ref and path are read from
# the link. The path may name a single .md file, for upstreams that publish
# skill-shaped prose without packaging it as a skill - it becomes SKILL.md and
# vendor-overlays/<name>/ supplies the frontmatter.
#
# Options:
#   --skill <a,b>    skill name(s) to vendor (default: inferred from the spec)
#   --ref <branch>   branch to track (default: the remote's HEAD branch)
#   --path <p>       upstream directory or .md file, skips discovery (single skill only)
#   --author <a>     attribution recorded in UPSTREAM.md (default: repo owner)
#   --homepage <u>   homepage recorded in UPSTREAM.md
#
# Examples:
#   scripts/vendor-skill.sh shadcn/improve
#   scripts/vendor-skill.sh heygen-com/hyperframes --skill hyperframes,gsap
#   scripts/vendor-skill.sh github/awesome-copilot --skill postgresql-optimization
#   scripts/vendor-skill.sh https://github.com/macton/nagent/blob/main/context/data-oriented-design.md
#
# Fetches with git directly, stages and validates every requested skill, then
# swaps them in with rollback. The manifest, lock and marketplace are written
# only after every snapshot has staged successfully.
set -euo pipefail

# shellcheck source=scripts/vendor-lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/vendor-lib.sh"

[ $# -ge 1 ] || die "usage: vendor-skill.sh <owner/repo | url> [--skill <name>] [--ref <branch>]"

spec="$1"
shift
skill_arg=""
ref=""
path_arg=""
author=""
homepage=""

while [ $# -gt 0 ]; do
  case "$1" in
    --skill | -s)
      skill_arg="$2"
      shift 2
      ;;
    --ref)
      ref="$2"
      shift 2
      ;;
    --path)
      path_arg="$2"
      shift 2
      ;;
    --author)
      author="$2"
      shift 2
      ;;
    --homepage)
      homepage="$2"
      shift 2
      ;;
    *) die "unknown option: $1" ;;
  esac
done

# A github.com /blob/ or /tree/ link carries the ref and path already; an
# explicit --ref or --path still wins.
link_name=""
case "$spec" in
  *://*/blob/* | *://*/tree/*)
    parse_github_link "$spec"
    spec="$LINK_REPO"
    [ -n "$ref" ] || ref="$LINK_REF"
    [ -n "$path_arg" ] || path_arg="$LINK_PATH"
    link_name="$(basename "$LINK_PATH")"
    link_name="${link_name%.md}"
    ;;
esac

# owner/repo@skill
case "$spec" in
  git@* | *://*) ;;
  *@*)
    [ -n "$skill_arg" ] || skill_arg="${spec##*@}"
    spec="${spec%@*}"
    ;;
esac

url="$(normalize_repo "$spec")"
slug="$(repo_slug "$url")"
owner="${slug%%/*}"
reponame="${slug##*/}"
[ -n "$skill_arg" ] || skill_arg="${link_name:-$reponame}"
[ -n "$author" ] || author="$owner"
[ -n "$homepage" ] || homepage="https://github.com/$slug"

ensure_files

if [ -z "$ref" ]; then
  ref="$(default_ref "$url")"
  [ -n "$ref" ] || die "cannot resolve default branch for $url"
fi

IFS=',' read -r -a wanted <<<"$skill_arg"
if [ -n "$path_arg" ] && [ "${#wanted[@]}" -gt 1 ]; then
  die "--path supports a single --skill"
fi

stage_root="$(mktemp -d)"
trap 'rm -rf "$stage_root"' EXIT

declare -a staged_names=() staged_commits=() staged_hashes=() staged_paths=()

for name in "${wanted[@]}"; do
  [ -n "$name" ] || continue
  note "staging $name from $slug@$ref"

  if [ -n "$path_arg" ]; then
    upstream_path="$path_arg"
  else
    upstream_path="$(discover_path "$url" "$ref" "$name")"
  fi

  dest="$stage_root/$name"
  fetch_snapshot "$url" "$ref" "$upstream_path" "$dest"

  if [ -n "$FETCHED_LICENSE" ]; then
    cp "$FETCHED_LICENSE" "$dest/LICENSE.upstream"
    spdx="$(spdx_guess "$dest/LICENSE.upstream")"
  else
    spdx="UNKNOWN"
    warn "$name: no license file found in $slug - redistribution may not be permitted"
  fi
  rm -rf "$FETCH_WORKDIR"

  apply_overlay "$name" "$dest"
  validate_skill "$dest" "$name"
  write_provenance "$dest" "$name" "$url" "$upstream_path" "$ref" \
    "$FETCHED_COMMIT" "$author" "$homepage" "$spdx"

  staged_names+=("$name")
  staged_commits+=("$FETCHED_COMMIT")
  staged_hashes+=("$(snapshot_hash "$dest")")
  staged_paths+=("$upstream_path")
  printf '    %s  %s  %s\n' "$upstream_path" "${FETCHED_COMMIT:0:12}" "$spdx"
done

[ "${#staged_names[@]}" -gt 0 ] || die "nothing staged"

# Swap in, rolling every directory back if any single move fails.
declare -a backups=()
restore() {
  local i
  for ((i = 0; i < ${#backups[@]}; i++)); do
    [ -n "${backups[$i]}" ] && [ -d "${backups[$i]}" ] || continue
    rm -rf "${SKILLS_DIR:?}/${staged_names[$i]}"
    mv "${backups[$i]}" "$SKILLS_DIR/${staged_names[$i]}"
  done
  die "swap failed, rolled back"
}

for ((i = 0; i < ${#staged_names[@]}; i++)); do
  name="${staged_names[$i]}"
  if [ -d "$SKILLS_DIR/$name" ]; then
    backup="$stage_root/.bak-$name"
    mv "$SKILLS_DIR/$name" "$backup" || restore
    backups+=("$backup")
  else
    backups+=("")
  fi
  mv "$stage_root/$name" "$SKILLS_DIR/$name" || restore
done

for ((i = 0; i < ${#staged_names[@]}; i++)); do
  name="${staged_names[$i]}"
  spdx="$(spdx_guess "$SKILLS_DIR/$name/LICENSE.upstream")"
  entry="$(jq -n \
    --arg name "$name" --arg repo "$url" --arg path "${staged_paths[$i]}" \
    --arg ref "$ref" --arg author "$author" --arg homepage "$homepage" \
    --arg spdx "$spdx" \
    '{ name: $name, repo: $repo, path: $path, ref: $ref,
       author: $author, homepage: $homepage, license: { spdx: $spdx } }')"
  manifest_put "$entry"
  lock_put "$name" "${staged_commits[$i]}" "${staged_hashes[$i]}"
  note "vendored skills/$name  (${slug}@${staged_commits[$i]:0:12})"
done

sync_marketplace
sync_hk_excludes
note "updated skills/sources.json, skills/sources.lock.json and .claude-plugin/marketplace.json"
