#!/bin/bash
# run-changelog.sh — Skill-first wrapper for changelog operations.
# Auto-loads the changelog skill, then forwards to changelog-append.sh.
#
# Usage:
#   bash scripts/run-changelog.sh --type TYPE --source SOURCE --title "TITLE" ...

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Auto-load required skill (idempotent)
bash "$SCRIPT_DIR/skill-load.sh" changelog >/dev/null 2>&1 || {
  echo "ERROR: run-changelog.sh could not load changelog skill" >&2
  exit 5
}

exec bash "$SCRIPT_DIR/changelog-append.sh" "$@"
