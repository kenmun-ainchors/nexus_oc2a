#!/bin/bash
# scripts/migrate-changelog-to-pg.sh
# TKT-0721: Migrate markdown CHGs into PG state_changes + link them.
# Wrapper around the Python driver (avoids shell escaping issues).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
python3 "${SCRIPT_DIR}/migrate-changelog-to-pg.py" "$@"
