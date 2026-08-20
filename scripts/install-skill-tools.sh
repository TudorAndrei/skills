#!/usr/bin/env bash
# Install the mise tools declared in SKILL.md frontmatter.
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(dirname "$script_dir")"
skills_dir="$repo_root/skills"
mode="install"

case "${1:-}" in
  "") ;;
  --check) mode="check" ;;
  --list) mode="list" ;;
  *)
    printf 'Usage: %s [--check|--list]\n' "$0" >&2
    exit 2
    ;;
esac

command -v yq >/dev/null 2>&1 || {
  printf 'ERROR: yq is required. Run this task through mise.\n' >&2
  exit 1
}
command -v jq >/dev/null 2>&1 || {
  printf 'ERROR: jq is required. Run this task through mise.\n' >&2
  exit 1
}

task_tmp="$(mktemp -d "${TMPDIR:-/tmp}/skill-tools.XXXXXX")"
trap 'rm -rf "$task_tmp"' EXIT
records="$task_tmp/records.tsv"
: >"$records"

while IFS= read -r skill_file; do
  relative_file="${skill_file#"$repo_root"/}"
  yq --front-matter=extract -o=json '.metadata.tools // []' "$skill_file" |
    jq -r --arg file "$relative_file" '
      if type != "array" then
        error("metadata.tools must be a list in " + $file)
      else
        .[] |
        if type != "object" then
          error("each metadata.tools item must be an object in " + $file)
        elif .source != "mise" then
          error("unsupported tool source in " + $file + ": " + (.source // "<missing>" | tostring))
        elif (.command | type) != "string" or .command == "" then
          error("tool command must be a non-empty string in " + $file)
        elif (.spec | type) != "string" or .spec == "" then
          error("tool spec must be a non-empty string in " + $file)
        elif (.command | test("^[A-Za-z0-9][A-Za-z0-9._+-]*$")) | not then
          error("invalid tool command in " + $file + ": " + .command)
        elif (.spec | test("^[^[:space:]]+@[^[:space:]@]+$")) | not then
          error("mise tool spec must contain a fixed version in " + $file + ": " + .spec)
        else
          [.command, .spec, $file] | @tsv
        end
      end
    ' >>"$records"
done < <(find "$skills_dir" -name SKILL.md -type f -print | LC_ALL=C sort)

if [ ! -s "$records" ]; then
  printf 'No skill tools are declared.\n'
  exit 0
fi

LC_ALL=C sort -u "$records" -o "$records"

awk -F '\t' '
  {
    if ($1 in specs && specs[$1] != $2) {
      printf "ERROR: command %s has conflicting mise specs:\n  %s (%s)\n  %s (%s)\n", \
        $1, specs[$1], files[$1], $2, $3 > "/dev/stderr"
      failed = 1
    }
    specs[$1] = $2
    files[$1] = $3
  }
  END { exit failed }
' "$records"

if [ "$mode" = "list" ]; then
  printf 'COMMAND\tMISE SPEC\tSKILL FILE\n'
  cat "$records"
  exit 0
fi

if [ "$mode" = "check" ]; then
  missing=0
  previous_command=""
  while IFS=$'\t' read -r command _spec _file; do
    [ "$command" != "$previous_command" ] || continue
    previous_command="$command"
    if ! command -v "$command" >/dev/null 2>&1; then
      printf 'Skill tool is not available: %s\n' "$command"
      missing=1
    fi
  done <"$records"
  if [ "$missing" -eq 1 ]; then
    printf 'Run mise run install-skill-tools from %s.\n' "$repo_root"
  fi
  exit 0
fi

specs_file="$task_tmp/specs"
cut -f2 "$records" | LC_ALL=C sort -u >"$specs_file"

printf 'The global mise config will receive these skill tools:\n'
while IFS= read -r spec; do
  printf '  %s\n' "$spec"
done <"$specs_file"

tool_specs=()
while IFS= read -r spec; do
  tool_specs+=("$spec")
done <"$specs_file"

mise use --global --pin "${tool_specs[@]}"
