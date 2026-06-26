#!/bin/bash
# scripts/migrate-lessons-to-pg.sh
# TKT-0362: Migrate markdown lessons into PG state_lessons + link them.
# Wrapper around the Python driver.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
python3 "${SCRIPT_DIR}/migrate-lessons-to-pg.py" "$@"
