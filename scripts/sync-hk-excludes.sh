#!/usr/bin/env bash
# Regenerate hk-vendored.pkl from skills/sources.lock.json, so hk's fixers stay
# off the hash-verified snapshots wherever their publisher directory puts them.
set -euo pipefail

# shellcheck source=scripts/vendor-lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/vendor-lib.sh"

ensure_files
sync_hk_excludes
note "wrote hk-vendored.pkl"
