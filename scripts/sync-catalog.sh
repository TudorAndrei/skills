#!/usr/bin/env bash
# Regenerate .claude-plugin/marketplace.json from skills/ and the vendored lock.
# Authored skills (no lock entry) land in Essentials; vendored ones in Third-Party.
set -euo pipefail

# shellcheck source=scripts/vendor-lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/vendor-lib.sh"

ensure_files
sync_marketplace
sync_hk_excludes
note "wrote .claude-plugin/marketplace.json"
