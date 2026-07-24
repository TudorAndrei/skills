#!/usr/bin/env bash
# Refresh every vendored external skill from its recorded source.
#   - skills/<name>/  (global scope) : re-fetched via its .skill-source marker
#   - .agents/skills/ (project scope): refreshed via the `skills` CLI lockfile
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
shopt -s nullglob

found=0
for src in skills/*/.skill-source; do
  found=1
  name="$(basename "$(dirname "$src")")"
  spec="$(head -n1 "$src")"
  echo "==> updating skills/$name  (source: $spec)"
  # shellcheck disable=SC2086  # spec is a trusted "<repo> --skill <name>" line
  "$ROOT/scripts/vendor-skill.sh" $spec
done
[ "$found" -eq 0 ] && echo "No vendored external skills in skills/ (none carry a .skill-source marker)."

echo "==> updating project-only skills in .agents/skills via the skills CLI"
npx --yes skills update --project --yes || true
