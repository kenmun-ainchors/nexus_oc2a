#!/bin/bash
# db.sh — Agent postgres access wrapper
# Usage: db.sh -c "SELECT count(*) FROM state_tickets"
#        db.sh -f /path/to/script.sql
# Resolve psql binary (migration 2026-07-14: no longer hard-coded to /opt/homebrew/bin)
PSQL_BIN="${PSQL_BIN:-$(command -v psql 2>/dev/null)}"
if [[ -z "$PSQL_BIN" && -x "$(brew --prefix 2>/dev/null)/bin/psql" ]]; then
  PSQL_BIN="$(brew --prefix)/bin/psql"
fi
if [[ -z "$PSQL_BIN" ]]; then
  echo "ERROR: psql not found" >&2
  exit 127
fi

export PGHOST="${PGHOST:-/tmp}"
export PGPORT="${PGPORT:-5432}"
export PGUSER="${PGUSER:-$(whoami)}"
export PGDATABASE="${PGDATABASE:-ainchors_nexus}"
export PGOPTIONS="${PGOPTIONS:---client-min-messages=warning}"

exec "$PSQL_BIN" -t -A "$@"
