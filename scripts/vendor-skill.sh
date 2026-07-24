#!/usr/bin/env bash
# Vendor a remote skill into skills/ (the globally-synced source of truth) and
# record where it came from so it can be refreshed later with `mise run update`.
#
# Usage: scripts/vendor-skill.sh <owner/repo | github-url> [--skill <name[,name...]>]
#   e.g. scripts/vendor-skill.sh shadcn/improve
#        scripts/vendor-skill.sh github/awesome-copilot --skill postgresql-optimization
#
# It leans on the `skills` CLI to clone + locate the skill (into .agents/skills),
# then relocates each copy into skills/<name>/, writes a .skill-source marker
# ("<repo> --skill <name>", so updates re-fetch exactly that skill), and removes
# the CLI's lock entry/symlink (skills/ externals are tracked by marker).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

repo="${1:?usage: vendor-skill.sh <owner/repo | github-url> [--skill <name>]}"
shift || true

lock_keys() {
  node -e "const fs=require('fs');const p='skills-lock.json';const j=fs.existsSync(p)?JSON.parse(fs.readFileSync(p)):{skills:{}};process.stdout.write(Object.keys(j.skills||{}).sort().join('\n'))"
}

before="$(lock_keys)"
npx --yes skills add "$repo" "$@" --agent codex --yes
after="$(lock_keys)"

new="$(comm -13 <(printf '%s' "$before") <(printf '%s' "$after"))"
if [ -z "$new" ]; then
  echo "vendor-skill: no new skill added from '$repo $*' (already vendored in skills/?)." >&2
  echo "              re-vendoring an existing skill is what 'mise run update' does." >&2
  exit 1
fi

while IFS= read -r name; do
  [ -n "$name" ] || continue
  [ -d ".agents/skills/$name" ] || { echo "vendor-skill: expected .agents/skills/$name to exist" >&2; exit 1; }
  rm -rf "skills/$name"
  mv ".agents/skills/$name" "skills/$name"
  printf '%s --skill %s\n' "$repo" "$name" > "skills/$name/.skill-source"
  rm -f ".claude/skills/$name"
  node -e "const fs=require('fs');const p='skills-lock.json';const j=JSON.parse(fs.readFileSync(p));delete j.skills['$name'];fs.writeFileSync(p,JSON.stringify(j,null,2)+'\n')"
  echo "vendored: skills/$name  (source: $repo)"
done <<< "$new"
