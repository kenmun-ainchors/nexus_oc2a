#!/bin/bash
# sync-check.sh — Compare Postgres row counts vs JSON file record counts
# Usage: bash scripts/sync-check.sh
DB="/Users/ainchorsangiefpl/.openclaw/workspace/scripts/db.sh"
WORKSPACE="/Users/ainchorsangiefpl/.openclaw/workspace"

echo "=== PG vs File Sync Check $(date) ==="

check_table() {
  local table="$1"
  local file="$2"
  local pg_count=$(bash "$DB" -c "SELECT count(*) FROM $table" 2>/dev/null | tr -d '[:space:]')
  pg_count=${pg_count:-0}
  
  if [[ -f "$file" ]]; then
    local file_count=$(python3 -c "
import json
with open('$file') as f:
    data = json.load(f)
if isinstance(data, list):
    print(len(data))
elif isinstance(data, dict):
    for k in ['tickets','tasks','checks','history','items']:
        if k in data and isinstance(data[k], list):
            print(len(data[k]))
            break
    else:
        print(1)
" 2>/dev/null | tr -d '[:space:]')
    file_count=${file_count:-0}
    if [[ "$pg_count" != "$file_count" ]]; then
      echo "❌ $table: PG=$pg_count FILE=$file_count — MISMATCH"
      return 1
    else
      echo "✅ $table: PG=$pg_count FILE=$file_count"
    fi
  else
    echo "⚠️  $table: PG=$pg_count FILE=NOT_FOUND"
  fi
  return 0
}

ALL_OK=true
check_table "state_tickets" "$WORKSPACE/state/tickets.json" || ALL_OK=false
check_table "state_linkedin" "$WORKSPACE/state/archive/linkedin-queue.json" || ALL_OK=false
check_table "state_sprints" "$WORKSPACE/state/archive/sprint-current.json" || ALL_OK=false
check_table "state_standups" "$WORKSPACE/state/archive/standup-state.json" || ALL_OK=false

$ALL_OK && echo "ALL CLEAN ✅" || echo "ISSUES DETECTED ❌"
