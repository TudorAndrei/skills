#!/usr/bin/env bash
# Offline, non-writing integrity check of the vendored skills.
#
# Usage: scripts/verify-skills.sh
#
# Verifies the manifest, the lock, that every snapshot sits under its publisher
# directory at the locked hash, and its provenance and license attribution.
# Touches the network never and the working tree never; exits non-zero on any
# error.
set -euo pipefail

# shellcheck source=scripts/vendor-lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/vendor-lib.sh"

errors=0
warns=0
err() {
  printf 'FAIL  %s\n' "$*"
  errors=$((errors + 1))
}
wrn() {
  printf 'WARN  %s\n' "$*"
  warns=$((warns + 1))
}
ok() { printf 'ok    %s\n' "$*"; }

[ -f "$MANIFEST" ] || die "missing $MANIFEST"
[ -f "$LOCK" ] || die "missing $LOCK"
jq -e . "$MANIFEST" >/dev/null || die "$MANIFEST is not valid JSON"
jq -e . "$LOCK" >/dev/null || die "$LOCK is not valid JSON"

# --- manifest --------------------------------------------------------------

missing_fields="$(jq -r '
  .skills[]
  | select((.name // "") == "" or (.repo // "") == ""
           or (.path // "") == "" or (.ref // "") == "")
  | .name // "<unnamed>"' "$MANIFEST")"
[ -n "$missing_fields" ] && err "manifest entries missing required fields: $missing_fields"

dupes="$(manifest_names | uniq -d)"
[ -n "$dupes" ] && err "duplicate manifest entries: $dupes"

# --- per-skill -------------------------------------------------------------

declare -a declared=()
while IFS= read -r n; do [ -n "$n" ] && declared+=("$n"); done < <(manifest_names)

for name in ${declared[@]+"${declared[@]}"}; do
  dir="$(skill_dir "$name")"

  # A copy at any other path is a leftover the tooling would ignore, and the
  # `skills` CLI would install it as a second skill of the same name.
  while IFS= read -r other; do
    [ -n "$other" ] && [ "$other" != "$dir" ] || continue
    err "$name: a stray copy sits at $(skill_rel "$other"); it belongs at $(skill_rel "$dir")
        (run 'mise run restore $name' to move it)"
  done < <(find_skill_dirs "$name")

  if [ ! -d "$dir" ]; then
    err "$name: declared in the manifest but $(skill_rel "$dir") does not exist"
    continue
  fi
  [ -f "$dir/SKILL.md" ] || err "$name: no SKILL.md"

  commit="$(locked_commit "$name")"
  want_hash="$(locked_hash "$name")"
  if [ -z "$commit" ] || [ -z "$want_hash" ]; then
    err "$name: no lock entry (run 'mise run update $name')"
    continue
  fi
  [[ "$commit" =~ ^[0-9a-f]{40}$ ]] || err "$name: locked commit is not a full SHA-1"
  [[ "$want_hash" =~ ^[0-9a-f]{64}$ ]] || err "$name: locked hash is not a SHA-256 digest"

  if find "$dir" -type l -print -quit | grep -q .; then
    wrn "$name: contains symlinks, which the snapshot hash does not cover"
  fi

  have_hash="$(snapshot_hash "$dir")"
  if [ "$have_hash" != "$want_hash" ]; then
    err "$name: snapshot hash drift
        expected $want_hash
        found    $have_hash
        (hand-edited? run 'mise run restore $name' to reproduce the pinned commit)"
    continue
  fi

  [ -f "$dir/UPSTREAM.md" ] || err "$name: missing UPSTREAM.md provenance"
  if [ -f "$dir/LICENSE.upstream" ]; then
    [ "$(manifest_field "$name" 'license')" = "" ] && wrn "$name: manifest records no license"
  else
    wrn "$name: no LICENSE.upstream - upstream ships no license file, so redistribution here may not be permitted"
  fi

  ok "$name  ${commit:0:12}"
done

# --- stragglers ------------------------------------------------------------

while IFS= read -r n; do
  [ -n "$n" ] || continue
  manifest_has "$n" || err "$n: present in the lock but not the manifest"
done < <(jq -r '.skills | keys[]' "$LOCK")

# Every skill here, authored or vendored, has to be loadable by an agent, and
# its name has to be unique - agents key on the frontmatter name, so a duplicate
# under a second publisher shadows rather than coexists.
declare -a seen_names=()
while IFS= read -r dir; do
  [ -n "$dir" ] || continue
  n="$(basename "$dir")"
  seen_names+=("$n")
  problem="$(description_problem "$dir/SKILL.md" "$n")"
  [ -z "$problem" ] || err "$problem"
done < <(each_skill_dir)

dupe_dirs="$(printf '%s\n' ${seen_names[@]+"${seen_names[@]}"} | LC_ALL=C sort | uniq -d)"
[ -z "$dupe_dirs" ] || err "more than one skill directory shares a name: $(printf '%s' "$dupe_dirs" | tr '\n' ' ')"

shopt -s nullglob
for marker in "$SKILLS_DIR"/*/.skill-source "$SKILLS_DIR"/*/*/.skill-source; do
  err "$(basename "$(dirname "$marker")"): legacy .skill-source marker still present"
done
for overlay in "$ROOT"/vendor-overlays/*/; do
  n="$(basename "$overlay")"
  manifest_has "$n" ||
    err "$n: vendor-overlays/$n exists but no skill of that name is vendored"
done
for snapshot in "$SKILLS_DIR"/*/.git "$SKILLS_DIR"/*/*/.git; do
  err "$(basename "$(dirname "$snapshot")"): a .git directory was vendored into the snapshot"
done
shopt -u nullglob

# --- hk excludes -----------------------------------------------------------

if ! diff -q <(sed -n '/^globs/,$p' "$ROOT/hk-vendored.pkl") \
  <(printf 'globs: List<String> = List(\n%s\n)\n' "$(render_hk_globs | sed '$!s/$/,/')") >/dev/null; then
  err "hk-vendored.pkl does not match the current snapshot paths
        (run 'mise run hk-excludes' to regenerate)"
else
  ok "hk-vendored.pkl matches the vendored snapshot paths"
fi

printf '\n%d skill(s) declared, %d error(s), %d warning(s)\n' \
  "${#declared[@]}" "$errors" "$warns"
[ "$errors" -eq 0 ] || exit 1
