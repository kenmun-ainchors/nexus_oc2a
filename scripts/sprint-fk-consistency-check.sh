#!/bin/bash
# sprint-fk-consistency-check.sh - Read-only FK consistency guard
# TKT-0348 A6: Compares state_tickets.sprint_id <-> state_sprints.items
# Exit 0: consistent (no divergence)
# Exit 1: divergence detected (alert-only, no auto-mutation)
set -u

WORKSPACE_ROOT="/Users/ainchorsoc2a/.openclaw/workspace"
DB_SCRIPT="$WORKSPACE_ROOT/scripts/db.sh"
JQ_BIN=$(command -v jq 2>/dev/null || true)
if [[ -z "$JQ_BIN" || ! -x "$JQ_BIN" ]]; then
  JQ_BIN="$(brew --prefix 2>/dev/null)/bin/jq"
fi
JQ="$JQ_BIN"
SPRINT_TABLE="state_sprints"
TICKET_TABLE="state_tickets"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] sprint-fk: $1" >&2; }
die() { echo "ERROR: $1" >&2; exit 1; }

pg_query() {
  bash "$DB_SCRIPT" -c "$1" 2>/dev/null
}

pg_query_json() {
  bash "$DB_SCRIPT" -c "$1" -t -A 2>/dev/null
}

sprint_name_to_number() {
  local name="$1"
  echo "$name" | sed 's/[Ss][Pp][Rr][Ii][Nn][Tt][[:space:]]*//' | grep -oE '[0-9]+'
}

check_sprint() {
  local sprint_name="$1"
  local sprint_num=$(sprint_name_to_number "$sprint_name")
  log "Checking FK consistency for $sprint_name (number: $sprint_num)"
  local sprint_id=$(pg_query "SELECT id FROM $SPRINT_TABLE WHERE sprint_number=$sprint_num ORDER BY updated_at DESC LIMIT 1;" 2>/dev/null | head -1)
  if [[ -z "$sprint_id" || "$sprint_id" == "null" ]]; then
    log "Sprint $sprint_name not found in state_sprints"
    return 0
  fi
  local items_tickets=$(pg_query_json "SELECT jsonb_agg(t.tkt ORDER BY t.seq) FROM $SPRINT_TABLE s, jsonb_to_recordset(s.items) AS t(tkt text, seq int) WHERE s.id='$sprint_id';" 2>/dev/null)
  local pg_tickets=$(pg_query_json "SELECT jsonb_agg(t.id ORDER BY t.id) FROM $TICKET_TABLE t WHERE t.sprint_id='$sprint_id';" 2>/dev/null)
  items_tickets="${items_tickets:-[]}"
  pg_tickets="${pg_tickets:-[]}"
  local in_items_not_pg=$(echo "$items_tickets" | $JQ -r --argjson pg "$pg_tickets" '[
    .[] as $item |
    if ($pg | index($item)) == null then $item else empty end
  ]' 2>/dev/null || echo '[]')
  local in_pg_not_items=$(echo "$pg_tickets" | $JQ -r --argjson items "$items_tickets" '[
    .[] as $pg_item |
    if ($items | index($pg_item)) == null then $pg_item else empty end
  ]' 2>/dev/null || echo '[]')
  local items_count=$(echo "$items_tickets" | $JQ 'length' 2>/dev/null || echo 0)
  local pg_count=$(echo "$pg_tickets" | $JQ 'length' 2>/dev/null || echo 0)
  local items_not_pg_count=$(echo "$in_items_not_pg" | $JQ 'length' 2>/dev/null || echo 0)
  local pg_not_items_count=$(echo "$in_pg_not_items" | $JQ 'length' 2>/dev/null || echo 0)
  local consistent="true"
  if [[ "$items_not_pg_count" -gt 0 || "$pg_not_items_count" -gt 0 ]]; then
    consistent="false"
  fi
  local report=$($JQ -n     --arg sprint "$sprint_name"     --arg sprint_id "$sprint_id"     --argjson items_count "$items_count"     --argjson pg_count "$pg_count"     --argjson items_not_pg_count "$items_not_pg_count"     --argjson pg_not_items_count "$pg_not_items_count"     --argjson consistent "$consistent"     --argjson in_items_not_pg "$in_items_not_pg"     --argjson in_pg_not_items "$in_pg_not_items"     '{
      sprint: $sprint,
      sprint_id: $sprint_id,
      items_count: $items_count,
      pg_tickets_count: $pg_count,
      in_items_not_in_pg: $in_items_not_pg,
      in_pg_not_in_items: $in_pg_not_items,
      in_items_not_in_pg_count: $items_not_pg_count,
      in_pg_not_in_items_count: $pg_not_items_count,
      consistent: $consistent,
      check_type: "read-only",
      alert_only: true
    }' 2>/dev/null)
  echo "$report"
}

# Main
check_all="false"
target_sprint=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --sprint) target_sprint="$2"; shift 2 ;;
    --all) check_all="true"; shift ;;
    --help|-h)
      echo "Usage: bash scripts/sprint-fk-consistency-check.sh [--sprint <name>] [--all]"
      echo "  --sprint <name>  Check a specific sprint"
      echo "  --all            Check all sprints"
      echo "  Exit 0: consistent, Exit 1: divergence detected"
      exit 0 ;;
    *) die "Unknown flag: $1. Use --sprint <name> or --all" ;;
  esac
done

if [[ "$check_all" == "true" ]]; then
  sprint_list=$(pg_query "SELECT sprint_name FROM $SPRINT_TABLE WHERE sprint_number > 0 ORDER BY sprint_number;" 2>/dev/null)
  all_reports="[]"
  any_inconsistent="false"
  while IFS= read -r sprint_name; do
    [[ -z "$sprint_name" ]] && continue
    report=$(check_sprint "$sprint_name")
    if [[ -n "$report" ]]; then
      all_reports=$(echo "$all_reports" | $JQ --argjson r "$report" '. + [$r]' 2>/dev/null)
      consistent=$(echo "$report" | $JQ -r '.consistent' 2>/dev/null)
      if [[ "$consistent" == "false" ]]; then
        any_inconsistent="true"
      fi
    fi
  done < <(echo "$sprint_list")
  echo "$all_reports" | $JQ --argjson any_inconsistent "$any_inconsistent" '{
    check_type: "read-only",
    alert_only: true,
    any_inconsistent: $any_inconsistent,
    sprints: .
  }' 2>/dev/null
  if [[ "$any_inconsistent" == "true" ]]; then exit 1; fi
  exit 0
elif [[ -n "$target_sprint" ]]; then
  report=$(check_sprint "$target_sprint")
  echo "$report"
  consistent=$(echo "$report" | $JQ -r '.consistent' 2>/dev/null)
  if [[ "$consistent" == "false" ]]; then exit 1; fi
  exit 0
else
  current_sprint=$(bash "$WORKSPACE_ROOT/scripts/db-sprint.sh" current 2>/dev/null | $JQ -r '.sprint_name' 2>/dev/null)
  if [[ -z "$current_sprint" || "$current_sprint" == "null" ]]; then
    current_sprint="Sprint 10"
  fi
  report=$(check_sprint "$current_sprint")
  echo "$report"
  consistent=$(echo "$report" | $JQ -r '.consistent' 2>/dev/null)
  if [[ "$consistent" == "false" ]]; then exit 1; fi
  exit 0
fi
