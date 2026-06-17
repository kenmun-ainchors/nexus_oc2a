#!/bin/bash
# run-pg-ticket.sh — Skill-first wrapper for PG ticket/sprint operations.
# Auto-loads the pg-sprint-backlog skill, then forwards to db-ticket.sh / db-sprint.sh.
#
# Usage:
#   bash scripts/run-pg-ticket.sh db-ticket [args...]
#   bash scripts/run-pg-ticket.sh db-sprint [args...]
#   bash scripts/run-pg-ticket.sh [db-ticket|db-sprint] [args...]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Auto-load required skill (idempotent)
bash "$SCRIPT_DIR/skill-load.sh" pg-sprint-backlog >/dev/null 2>&1 || {
  echo "ERROR: run-pg-ticket.sh could not load pg-sprint-backlog skill" >&2
  exit 5
}

SUBCMD="${1:-}"
shift || true

case "$SUBCMD" in
  db-ticket|ticket)
    exec bash "$SCRIPT_DIR/db-ticket.sh" "$@"
    ;;
  db-sprint|sprint)
    exec bash "$SCRIPT_DIR/db-sprint.sh" "$@"
    ;;
  *)
    echo "ERROR: run-pg-ticket.sh unknown subcommand: $SUBCMD" >&2
    echo "Usage: run-pg-ticket.sh [db-ticket|db-sprint] [args...]" >&2
    exit 1
    ;;
esac
