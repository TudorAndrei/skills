#!/usr/bin/env bash
# Shared helpers for vendoring external skills into skills/.
#
# Model (ported from gabimoncha/skills):
#   skills/sources.json           declared intent  - repo, upstream path, tracked ref, license
#   skills/sources.lock.json      resolved state   - pinned commit + snapshot hash
#   skills/<publisher>/<name>/    generated snapshot + UPSTREAM.md + LICENSE.upstream
#
# Vendored snapshots are grouped by publisher; skills authored here stay flat at
# skills/<name>/. Skill names are still globally unique - the publisher directory
# organizes the tree, it does not namespace the skill, since agents load skills
# by the `name` in their frontmatter.
#
# Vendoring talks to git directly; the `skills` CLI is only used to install and
# sync what lands here. Sourced by vendor-skill.sh, update-skills.sh and
# verify-skills.sh.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS_DIR="$ROOT/skills"
MANIFEST="$SKILLS_DIR/sources.json"
LOCK="$SKILLS_DIR/sources.lock.json"

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}
note() { printf '==> %s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }

for _tool in git jq shasum; do
  command -v "$_tool" >/dev/null 2>&1 || die "missing required tool: $_tool"
done

# --- manifest / lock -------------------------------------------------------

ensure_files() {
  [ -f "$MANIFEST" ] || printf '{\n  "version": 1,\n  "skills": []\n}\n' >"$MANIFEST"
  [ -f "$LOCK" ] || printf '{\n  "version": 1,\n  "skills": {}\n}\n' >"$LOCK"
}

manifest_names() { jq -r '.skills[].name' "$MANIFEST" | LC_ALL=C sort; }
manifest_field() {
  jq -r --arg n "$1" --arg f "$2" '.skills[] | select(.name==$n) | .[$f] // ""' "$MANIFEST"
}
manifest_has() { jq -e --arg n "$1" 'any(.skills[]; .name==$n)' "$MANIFEST" >/dev/null; }
locked_commit() { jq -r --arg n "$1" '.skills[$n].commit // ""' "$LOCK"; }
locked_hash() { jq -r --arg n "$1" '.skills[$n].hash // ""' "$LOCK"; }

# manifest_put <entry-json> - replaces any entry of the same name, keeps sorted
manifest_put() {
  local tmp
  tmp="$(mktemp)"
  jq --argjson e "$1" '
    .version = 1
    | .skills = ((((.skills // []) | map(select(.name != $e.name))) + [$e]) | sort_by(.name))
  ' "$MANIFEST" >"$tmp"
  mv "$tmp" "$MANIFEST"
}

# lock_put <name> <commit> <hash>
lock_put() {
  local tmp
  tmp="$(mktemp)"
  jq --arg n "$1" --arg c "$2" --arg h "$3" '
    .version = 1
    | .skills[$n] = { commit: $c, hash: $h }
    | .skills |= (to_entries | sort_by(.key) | from_entries)
  ' "$LOCK" >"$tmp"
  mv "$tmp" "$LOCK"
}

# --- layout ----------------------------------------------------------------

# publisher_slug <author> - directory-safe form of an attribution string, so a
# manifest author of "Matt Pocock" and one of "mattpocock" cannot land in two
# different directories.
publisher_slug() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' |
    sed -e 's/[^a-z0-9._-]\{1,\}/-/g' -e 's/^-*//' -e 's/-*$//'
}

# skill_publisher <name> - publisher directory for a vendored skill, empty for a
# skill authored here. Falls back to the repo owner when the manifest records no
# author, so an entry written before --author existed still resolves.
skill_publisher() {
  local author
  manifest_has "$1" 2>/dev/null || return 0
  author="$(manifest_field "$1" author)"
  [ -n "$author" ] || author="$(repo_slug "$(manifest_field "$1" repo)")"
  author="${author%%/*}"
  publisher_slug "$author"
}

# skill_dir <name> - where the snapshot for <name> belongs.
skill_dir() {
  local pub
  pub="$(skill_publisher "$1")"
  if [ -n "$pub" ]; then printf '%s/%s/%s' "$SKILLS_DIR" "$pub" "$1"; else printf '%s/%s' "$SKILLS_DIR" "$1"; fi
}

# skill_rel <dir> - path relative to the repo root, for messages.
skill_rel() { printf '%s' "${1#"$ROOT"/}"; }

# find_skill_dirs <name> - every directory currently holding a skill of this
# name, flat or under a publisher. More than one means a stale copy is left over
# from a rename, which the callers clean up.
find_skill_dirs() {
  local d
  shopt -s nullglob
  for d in "$SKILLS_DIR/$1" "$SKILLS_DIR"/*/"$1"; do
    [ -f "$d/SKILL.md" ] && printf '%s\n' "$d"
  done
  shopt -u nullglob
}

# each_skill_dir - every skill directory in the tree, authored or vendored, one
# per line. A publisher directory holds no SKILL.md of its own, so the two globs
# cannot both match the same path.
each_skill_dir() {
  local d
  shopt -s nullglob
  for d in "$SKILLS_DIR"/*/ "$SKILLS_DIR"/*/*/; do
    [ -f "${d}SKILL.md" ] && printf '%s\n' "${d%/}"
  done
  shopt -u nullglob
}

# --- hashing ---------------------------------------------------------------

# snapshot_hash <dir> - deterministic digest over relative path, exec bit and
# contents of every regular file. Path-independent, so a staged copy and the
# committed snapshot hash identically. Covers the generated UPSTREAM.md and
# LICENSE.upstream too, since those are part of what must reproduce.
snapshot_hash() {
  (
    cd "$1" || exit 1
    find . -type f -print0 | LC_ALL=C sort -z | while IFS= read -r -d '' f; do
      if [ -x "$f" ]; then printf '100755 %s ' "$f"; else printf '100644 %s ' "$f"; fi
      shasum -a 256 "$f" | cut -d' ' -f1
    done
  ) | shasum -a 256 | cut -d' ' -f1
}

# --- upstream --------------------------------------------------------------

# normalize_repo <owner/repo | url> -> https clone url
normalize_repo() {
  local spec="$1"
  case "$spec" in
    http://* | https://* | git@*) ;;
    */*) spec="https://github.com/$spec" ;;
    *) die "cannot parse repo spec: $spec" ;;
  esac
  [ "${spec%.git}" = "$spec" ] && spec="$spec.git"
  printf '%s' "$spec"
}

# parse_github_link <web url> - split a github.com /blob/ or /tree/ link into
# LINK_REPO, LINK_REF and LINK_PATH. A ref containing a slash is indistinguishable
# from the path here; pass --ref explicitly for those.
parse_github_link() {
  local rest="${1%/}" owner repo
  rest="${rest#*://*/}"
  owner="${rest%%/*}"
  rest="${rest#*/}"
  repo="${rest%%/*}"
  rest="${rest#*/}"
  rest="${rest#*/}" # blob | tree
  LINK_REF="${rest%%/*}"
  LINK_PATH="${rest#*/}"
  LINK_REPO="https://github.com/$owner/$repo"
  [ -n "$owner" ] && [ -n "$repo" ] && [ -n "$LINK_REF" ] && [ -n "$LINK_PATH" ] ||
    die "cannot parse github link: $1"
}

# repo_slug <url> -> owner/repo
repo_slug() {
  local s="${1%.git}"
  s="${s#*github.com[:/]}"
  s="${s#https://github.com/}"
  s="${s#git@github.com:}"
  printf '%s' "$s"
}

# default_ref <url> - the remote's HEAD branch
default_ref() {
  git ls-remote --symref "$1" HEAD 2>/dev/null |
    awk '/^ref:/ { sub("refs/heads/", "", $2); print $2; exit }'
}

# discover_path <url> <ref> <skill-name> - locate <name>/SKILL.md upstream
discover_path() {
  local url="$1" ref="$2" name="$3" work found
  work="$(mktemp -d)"
  git init -q "$work"
  git -C "$work" remote add origin "$url"
  git -C "$work" fetch -q --depth 1 --filter=blob:none origin "$ref" ||
    die "cannot fetch $url at $ref"
  found="$(git -C "$work" ls-tree -r --name-only FETCH_HEAD |
    grep -E "(^|/)${name}/SKILL\.md$" | head -n1 || true)"
  if [ -z "$found" ] && git -C "$work" ls-tree --name-only FETCH_HEAD | grep -qx 'SKILL.md'; then
    found="SKILL.md"
  fi
  rm -rf "$work"
  [ -n "$found" ] || die "no '$name/SKILL.md' found in $url@$ref"
  local dir="${found%/SKILL.md}"
  [ "$dir" = "SKILL.md" ] && dir="."
  printf '%s' "$dir"
}

# lexical_path <path> - collapse "." and ".." segments without touching disk.
lexical_path() {
  local out=() seg
  local IFS=/
  for seg in $1; do
    case "$seg" in
      '' | .) ;;
      ..) [ ${#out[@]} -gt 0 ] && unset 'out[${#out[@]}-1]' ;;
      *) out+=("$seg") ;;
    esac
  done
  printf '/%s' "${out[@]}"
}

# widen_for_symlinks <workdir> <upstream-path> - a skill directory may symlink
# into sibling directories of the upstream repo (shared reference docs), which
# the sparse checkout left out. Pull those targets in so the tar below has real
# content to dereference. Iterates, since a target can itself be a symlink.
widen_for_symlinks() {
  local work="$1" path="$2" pass link target rel widened
  for pass in 1 2 3; do
    widened=0
    while IFS= read -r link; do
      [ -n "$link" ] && [ ! -e "$link" ] || continue
      target="$(readlink "$link")"
      case "$target" in
        /*) die "$path: '${link#"$work"/}' is an absolute symlink - cannot vendor" ;;
      esac
      rel="$(lexical_path "${link%/*}/$target")"
      rel="${rel#"$(lexical_path "$work")"/}"
      case "$rel" in
        /*) die "$path: '${link#"$work"/}' points outside the repository" ;;
      esac
      SPARSE_PATTERNS+=("/$rel" "/$rel/")
      widened=1
    done < <(find "$work/$path" -type l)
    [ "$widened" -eq 1 ] || return 0
    git -C "$work" sparse-checkout set --no-cone "${SPARSE_PATTERNS[@]}" >/dev/null
    git -C "$work" checkout -q FETCH_HEAD
  done
  link="$(find "$work/$path" -type l ! -exec test -e {} \; -print -quit)"
  [ -z "$link" ] || die "$path: '${link#"$work"/}' still dangles after widening the checkout"
}

# fetch_snapshot <url> <ref-or-commit> <upstream-path> <dest-dir>
# Populates dest with the upstream skill directory. Sets FETCHED_COMMIT and
# FETCHED_LICENSE (path to an upstream license file, or empty).
#
# The path may also name a single upstream .md file, for sources that publish
# skill-shaped prose without packaging it as a skill. That file becomes
# SKILL.md; an overlay in vendor-overlays/<name>/ supplies the frontmatter.
fetch_snapshot() {
  local url="$1" ref="$2" path="$3" dest="$4" work
  work="$(mktemp -d)"
  git init -q "$work"
  git -C "$work" remote add origin "$url"
  git -C "$work" config core.sparseCheckout true
  git -C "$work" fetch -q --depth 1 --filter=blob:none origin "$ref" ||
    die "cannot fetch $url at $ref"
  FETCHED_COMMIT="$(git -C "$work" rev-parse FETCH_HEAD)"

  if [ "$path" = "." ]; then
    git -C "$work" checkout -q FETCH_HEAD
  else
    SPARSE_PATTERNS=("/$path" "/$path/" "/LICENSE*" "/COPYING*")
    git -C "$work" sparse-checkout set --no-cone "${SPARSE_PATTERNS[@]}" >/dev/null
    git -C "$work" checkout -q FETCH_HEAD
    widen_for_symlinks "$work" "$path"
  fi

  mkdir -p "$dest"
  if [ -d "$work/$path" ]; then
    [ -f "$work/$path/SKILL.md" ] || die "$url@$ref: no SKILL.md at '$path'"
    # -h dereferences symlinks: a skill that links to a sibling directory
    # upstream must still be self-contained once snapshotted here, and the
    # snapshot hash only covers file content.
    # --exclude matters when path is "." : the checkout's own .git would
    # otherwise be vendored, and its contents differ between fetches, breaking
    # reproduction.
    (cd "$work/$path" && tar chf - --exclude='./.git' --exclude='./.git/*' .) |
      (cd "$dest" && tar xf -)
    rm -f "$dest/.skill-source"
  elif [ -f "$work/$path" ]; then
    case "$path" in
      *.md) ;;
      *) die "$url@$ref: '$path' is a file but not markdown - cannot be a SKILL.md" ;;
    esac
    cp "$work/$path" "$dest/SKILL.md"
  else
    die "$url@$ref: nothing at '$path'"
  fi

  FETCHED_LICENSE=""
  local candidate
  for candidate in "$work/$path"/LICENSE* "$work/$path"/COPYING* \
    "$work"/LICENSE* "$work"/COPYING*; do
    if [ -f "$candidate" ]; then
      case "$candidate" in *.upstream) continue ;; esac
      FETCHED_LICENSE="$candidate"
      break
    fi
  done
  FETCH_WORKDIR="$work"
}

# apply_overlay <name> <dest> - re-apply local customizations on top of a fetched
# snapshot. Upstream content stays authoritative; the overlay is the small,
# versioned delta this repo owns.
#
#   vendor-overlays/<name>/*.patch   applied with `patch -p1`, in sorted order
#   vendor-overlays/<name>/files/**  copied over the result afterwards
#
# A patch that no longer applies is a hard error: upstream moved under the
# customization and that needs a human, not a silent drop.
apply_overlay() {
  local name="$1" dest="$2" ov="$ROOT/vendor-overlays/$name" p
  OVERLAY_APPLIED=0
  [ -d "$ov" ] || return 0

  local had=0
  shopt -s nullglob
  for p in "$ov"/*.patch; do
    had=1
    (cd "$dest" && patch -p1 --silent --forward -i "$p") ||
      die "$name: overlay patch $(basename "$p") no longer applies to the fetched snapshot.
  Upstream has changed underneath it. Refresh the patch in vendor-overlays/$name/ and retry."
  done
  shopt -u nullglob

  if [ -d "$ov/files" ]; then
    had=1
    (cd "$ov/files" && tar cf - .) | (cd "$dest" && tar xf -)
  fi

  OVERLAY_APPLIED="$had"
  [ "$had" -eq 1 ] && note "  applied overlay vendor-overlays/$name"
  return 0
}

# validate_skill <dest> <name> - a staged snapshot must be a loadable skill.
# Run after the overlay, since the overlay is what supplies the frontmatter when
# the upstream source is a bare markdown file.
validate_skill() {
  local dest="$1" name="$2"
  [ -f "$dest/SKILL.md" ] || die "$name: staged snapshot has no SKILL.md"
  awk '
    NR == 1 { if ($0 != "---") exit; next }
    $0 == "---" { closed = 1; exit }
    /^name:[ \t]*[^ \t]/ { seen_name = 1 }
    /^description:[ \t]*[^ \t]/ { seen_desc = 1 }
    END { exit (closed && seen_name && seen_desc) ? 0 : 1 }
  ' "$dest/SKILL.md" || die "$name: SKILL.md has no frontmatter with a name and description.
  If upstream ships plain markdown, add one in vendor-overlays/$name/."
  local problem
  problem="$(description_problem "$dest/SKILL.md" "$name")"
  [ -z "$problem" ] || die "$problem"
}

# description_problem <skill.md> <name> - print why the frontmatter description
# would not load, or nothing if it is fine. Both failure modes below have
# actually shipped from here: an agent that skips the skill reports nothing at
# load time, so the check belongs in the tooling.
DESCRIPTION_LIMIT=1024
description_problem() {
  local file="$1" name="$2" parsed style desc len
  parsed="$(awk '
    NR == 1 { if ($0 != "---") exit; next }
    NR > 1 && $0 == "---" { done = 1; exit }
    /^description:[ \t]*/ && !in_desc {
      v = $0
      sub(/^description:[ \t]*/, "", v)
      if (v == "" || v == "|" || v == "|-" || v == ">" || v == ">-" || v == "|+" || v == ">+") {
        in_desc = 1
        style = "block"
        next
      }
      style = (v ~ /^["'"'"']/) ? "quoted" : "plain"
      text = v
      done = 1
      exit
    }
    # A block scalar runs until the indentation stops; blank lines fold to a space.
    in_desc && /^[ \t]*$/ { text = text " "; next }
    in_desc && /^[ \t]+/ {
      t = $0
      gsub(/^[ \t]+|[ \t]+$/, "", t)
      text = text (text == "" || text ~ / $/ ? "" : " ") t
      next
    }
    in_desc { done = 1; exit }
    END { if (style != "") printf "%s\t%s\n", style, text }
  ' "$file")"
  style="${parsed%%$'\t'*}"
  desc="${parsed#*$'\t'}"
  [ -n "$style" ] || return 0

  # An unquoted plain scalar cannot contain ": " - YAML reads it as a nested
  # mapping and the whole file fails to parse.
  if [ "$style" = plain ] && printf '%s' "$desc" | grep -q ': '; then
    printf '%s: SKILL.md description is an unquoted scalar containing ": ", which YAML parses
  as a nested mapping, so the skill fails to load. Use a folded block scalar
  (description: >-) or quote the value.' "$name"
    return 0
  fi

  len="$(printf '%s' "$desc" | wc -m | tr -d ' ')"
  if [ "$len" -gt "$DESCRIPTION_LIMIT" ]; then
    printf '%s: SKILL.md description is %s characters; the limit is %s. Trim it' \
      "$name" "$len" "$DESCRIPTION_LIMIT"
    [ -d "$ROOT/vendor-overlays/$name" ] || [ -n "$(locked_commit "$name" 2>/dev/null)" ] &&
      printf ' in vendor-overlays/%s/' "$name"
    printf '.'
  fi
}

# spdx_guess <license-file> - best-effort identifier, "UNKNOWN" if unclear
spdx_guess() {
  [ -f "$1" ] || {
    printf 'UNKNOWN'
    return
  }
  local head
  head="$(head -c 4000 "$1")"
  case "$head" in
    *"MIT License"* | *"Permission is hereby granted, free of charge"*) printf 'MIT' ;;
    *"Apache License"*"Version 2.0"*) printf 'Apache-2.0' ;;
    *"GNU AFFERO GENERAL PUBLIC LICENSE"*) printf 'AGPL-3.0' ;;
    *"GNU GENERAL PUBLIC LICENSE"*) printf 'GPL-3.0' ;;
    *"Redistribution and use in source and binary forms"*"3. "*) printf 'BSD-3-Clause' ;;
    *"Redistribution and use in source and binary forms"*) printf 'BSD-2-Clause' ;;
    *"Mozilla Public License"*) printf 'MPL-2.0' ;;
    *"CC0"* | *"Creative Commons"*) printf 'CC0-1.0' ;;
    *) printf 'UNKNOWN' ;;
  esac
}

# write_provenance <dest> <name> <url> <path> <ref> <commit> <author> <homepage> <spdx>
write_provenance() {
  local dest="$1" name="$2" url="$3" path="$4" ref="$5" commit="$6"
  local author="$7" homepage="$8" spdx="$9"
  {
    printf '# Upstream provenance\n\n'
    printf 'This directory is a generated snapshot. Do not edit it by hand;\n'
    printf 'change `skills/sources.json` upstream and run `mise run update %s`.\n\n' "$name"
    printf -- '- Skill: `%s`\n' "$name"
    [ -n "$author" ] && printf -- '- Author: %s\n' "$author"
    printf -- '- Repository: %s\n' "$url"
    [ -n "$homepage" ] && printf -- '- Homepage: %s\n' "$homepage"
    printf -- '- Upstream path: `%s`\n' "$path"
    printf -- '- Tracked ref: `%s`\n' "$ref"
    printf -- '- Resolved commit: `%s`\n' "$commit"
    if [ -f "$dest/LICENSE.upstream" ]; then
      printf -- '- License: %s (see `LICENSE.upstream`)\n' "$spdx"
    else
      printf -- '- License: %s (no license file found upstream)\n' "$spdx"
    fi
    if [ "${OVERLAY_APPLIED:-0}" -eq 1 ]; then
      printf -- '- Local overlay: `vendor-overlays/%s/` applied on top of upstream\n' "$name"
    fi
  } >"$dest/UPSTREAM.md"
}

# --- hk excludes -----------------------------------------------------------

# render_hk_globs - one quoted glob per vendored snapshot, at its publisher path.
render_hk_globs() {
  local name
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    printf '    "%s/**"\n' "$(skill_rel "$(skill_dir "$name")")"
  done < <(jq -r '.skills | keys[]' "$LOCK") | LC_ALL=C sort
}

# sync_hk_excludes - keep hk's linters off the hash-verified snapshots. An
# auto-fix there would drift the hash permanently and be discarded by the next
# update anyway; local changes belong in vendor-overlays/.
sync_hk_excludes() {
  local tmp names
  tmp="$(mktemp)"
  # a trailing comma on every line but the last
  names="$(render_hk_globs | sed '$!s/$/,/')"
  {
    printf '// Generated by scripts/sync-hk-excludes.sh - do not edit by hand.\n//\n'
    printf '// Vendored snapshots in skills/ are hash-verified against skills/sources.lock.json.\n'
    printf '// Linters must not rewrite them: an auto-fix would drift the hash permanently and\n'
    printf '// be discarded by the next update anyway. Customize via vendor-overlays/ instead.\n'
    printf 'module hkVendored\n\n'
    if [ -n "$names" ]; then
      printf 'globs: List<String> = List(\n%s\n)\n' "$names"
    else
      printf 'globs: List<String> = List()\n'
    fi
  } >"$tmp"
  mv "$tmp" "$ROOT/hk-vendored.pkl"
}
