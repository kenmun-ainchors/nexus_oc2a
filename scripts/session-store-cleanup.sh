#!/bin/bash
# session-store-cleanup.sh — Thin wrapper around session-store-cleanup.py
#
# CHG-0910: Safe, idempotent retention sweep for OpenClaw session stores.
# - Never touches sessions.json or *.lock files.
# - Never touches files whose UUID is referenced by sessions.json.
# - Always moves (never deletes); archive root is reversible.
# - Refuses to proceed if sessions.json is unparseable or if >50% of a
#   directory would be archived (override with --force).
#
# Usage:
#   bash scripts/session-store-cleanup.sh [--dry-run] [--agent <id> | --all-agents] [--force]
#
# Cron-friendly: exit codes 0=ok, 2=unparseable, 3=safety-guard-tripped.
# All actions are logged to ~/.openclaw/logs/session-store-cleanup.log.
#
# See: state/session-store-cleanup-CHG-0910.md for test/verification steps.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY_SCRIPT="$SCRIPT_DIR/session-store-cleanup.py"

if [[ ! -f "$PY_SCRIPT" ]]; then
    echo "FATAL: companion Python script not found at $PY_SCRIPT" >&2
    exit 5
fi

# Ensure the script is executable; harmless if it already is.
chmod +x "$PY_SCRIPT" 2>/dev/null || true

exec python3 "$PY_SCRIPT" "$@"

