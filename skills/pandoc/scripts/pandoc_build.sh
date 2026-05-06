#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf 'Usage: %s <pdf|beamer|docx|html|pptx|epub> <input.md> [output] [extra pandoc args...]\n' "$0" >&2
}

if [[ $# -lt 2 ]]; then
  usage
  exit 64
fi

profile="$1"
input="$2"
output="${3:-}"

if [[ $# -ge 3 ]]; then
  shift 3
else
  shift 2
fi

if ! command -v pandoc >/dev/null 2>&1; then
  printf 'pandoc was not found on PATH.\n' >&2
  exit 127
fi

skill_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

case "$profile" in
  pdf)
    defaults="$skill_dir/assets/defaults/business-pdf.yaml"
    default_ext="pdf"
    ;;
  beamer)
    defaults="$skill_dir/assets/defaults/beamer.yaml"
    default_ext="pdf"
    ;;
  docx)
    defaults="$skill_dir/assets/defaults/docx.yaml"
    default_ext="docx"
    ;;
  html)
    defaults="$skill_dir/assets/defaults/html.yaml"
    default_ext="html"
    ;;
  pptx)
    defaults="$skill_dir/assets/defaults/pptx.yaml"
    default_ext="pptx"
    ;;
  epub)
    defaults="$skill_dir/assets/defaults/epub.yaml"
    default_ext="epub"
    ;;
  *)
    usage
    printf 'Unknown profile: %s\n' "$profile" >&2
    exit 64
    ;;
esac

if [[ -z "$output" ]]; then
  base="${input%.*}"
  output="${base}.${default_ext}"
fi

exec pandoc --defaults "$defaults" "$input" -o "$output" "$@"
