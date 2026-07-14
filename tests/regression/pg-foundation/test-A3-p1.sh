#!/bin/bash
# PG row counts match expected minimums
set -e
declare -A EXPECTED=( [state_tickets]=190 [state_cost]=3 [state_task_queue]=3 [state_sprints]=1 [state_linkedin]=5 [state_standups]=3 )
for t in "${!EXPECTED[@]}"; do
  COUNT=$(bash /Users/ainchorsoc2a/.openclaw/workspace/scripts/db-read.sh "$t" 2>&1 | $(command -v jq 2>/dev/null || brew --prefix 2>/dev/null)/bin/jq 'length' 2>/dev/null)
  MIN="${EXPECTED[$t]}"
  if [ "${COUNT:-0}" -lt "$MIN" ]; then
    echo "TABLE $t: $COUNT < expected $MIN"
    exit 1
  fi
done
exit 0
