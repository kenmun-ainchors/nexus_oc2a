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

# Resolve psql binary (migration 2026-07-14: no longer hard-coded to /opt/homebrew/bin)
PSQL_BIN="${PSQL_BIN:-$(command -v psql 2>/dev/null)}"
if [[ -z "$PSQL_BIN" && -x "$(brew --prefix 2>/dev/null)/bin/psql" ]]; then
  PSQL_BIN="$(brew --prefix)/bin/psql"
fi
if [[ -z "$PSQL_BIN" ]]; then
  echo "ERROR: psql not found" >&2
  exit 127
fi

# PG connection (env overrides preserved)
export PGHOST="${PGHOST:-/tmp}"
export PGPORT="${PGPORT:-5432}"
export PGUSER="${PGUSER:-$(whoami)}"
export PGDATABASE="${PGDATABASE:-ainchors_nexus}"
export PGOPTIONS="${PGOPTIONS:---client-min-messages=warning}"

exec "$PSQL_BIN" -t -A "$@"
