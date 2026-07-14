#!/bin/bash
# db-read.sh — Read from Postgres PRIMARY, file FALLBACK
# Usage: db-read.sh <table> [key] [value]
#   db-read.sh state_tickets          => all rows
#   db-read.sh state_tickets id TKT-0001 => single row
# SQL pass-through: if $1 starts with SELECT, execute as raw SQL directly
#   db-read.sh "SELECT 1 AS test"

# Resolve workspace from script location (migration 2026-07-14: no hard-coded user home).
# Allow env override: WORKSPACE_ROOT, SCRIPT_DIR.
SCRIPT_DIR_READ="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="${WORKSPACE_ROOT:-$(cd "$SCRIPT_DIR_READ/.." && pwd)}"
DB="${DB_RAW:-$SCRIPT_DIR_READ/db-raw.sh}"
WORKSPACE="$WORKSPACE_ROOT"
# Default DB user to current OS user; env override preserved.
export PGUSER="${PGUSER:-$(whoami)}"
TABLE="$1"; KEY="${2:-}"; VALUE="${3:-}"

# SQL pass-through mode: raw SQL if $TABLE starts with SELECT (case-insensitive)
if [[ "${TABLE:0:6}" == "SELECT" || "${TABLE:0:6}" == "select" ]]; then
  RESULT=$(bash "$DB" -c "$TABLE" 2>/dev/null)
  if [[ -n "$RESULT" ]]; then
    echo "$RESULT"
    exit 0
  fi
  echo '{"error":"no data from any source","table":"'$TABLE'"}' 1>&2
  exit 1
fi

# Step 1: Try Postgres (PRIMARY)
if [[ -n "$KEY" && -n "$VALUE" ]]; then
  RESULT=$(bash "$DB" -c "SELECT row_to_json(t)::text FROM \"$TABLE\" t WHERE \"$KEY\"='$VALUE' LIMIT 1" 2>/dev/null)
else
  RESULT=$(bash "$DB" -c "SELECT jsonb_agg(row_to_json(t)) FROM \"$TABLE\" t" 2>/dev/null)
fi

if [[ -n "$RESULT" && "$RESULT" != "null" && "$RESULT" != "" ]]; then
  echo "$RESULT"
  exit 0
fi

# Step 2: Fallback to state_v view
RESULT=$(bash "$DB" -c "SELECT data FROM state_v.\"$TABLE\"" 2>/dev/null)
if [[ -n "$RESULT" && "$RESULT" != "null" && "$RESULT" != "" ]]; then
  echo "$RESULT"
  exit 0
fi

# Step 3: File fallback (last resort)
FILE_PATH="$WORKSPACE/state/${TABLE}.json"
if [[ -f "$FILE_PATH" ]]; then
  if [[ -n "$KEY" && -n "$VALUE" ]]; then
    python3 -c "
import json
with open('$FILE_PATH') as f:
    data = json.load(f)
items = data if isinstance(data, list) else data.get(data.keys()[0], [])
for item in items:
    if str(item.get('$KEY','')) == '$VALUE':
        print(json.dumps(item))
        break
" 2>/dev/null
  else
    cat "$FILE_PATH"
  fi
  exit 0
fi

echo '{"error":"no data from any source","table":"'$TABLE'"}' 1>&2
exit 1
