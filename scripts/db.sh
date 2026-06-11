#!/bin/bash
# db.sh — Skill-Gated PostgreSQL Access Wrapper
# TKT-0406: Structural fix — all direct PG access requires skill-gate.
#
# Usage: db.sh -c "SELECT count(*) FROM state_tickets"
#        db.sh -f /path/to/script.sql
#
# This is the ONLY entry point for PG queries from operational scripts.
# Raw access (db-raw.sh) is reserved for infrastructure scripts only.
#
# SKILL GATE: pg-sprint-backlog skill MUST be loaded before use.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/skill-gate.sh" "pg-sprint-backlog" || exit $?

# PG connection
export PGHOST=/tmp
export PGPORT=5432
export PGUSER=ainchorsangiefpl
export PGDATABASE=ainchors_nexus
export PGOPTIONS="--client-min-messages=warning"

exec /opt/homebrew/bin/psql -t -A "$@"
