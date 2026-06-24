#!/bin/bash
# next-ticket-tracker-override.sh
#
# ═══════════════════════════════════════════════════════════════════════════════
# ONE-OFF WRAPPER — CRESTv2-P1 tracker override for next-ticket (CHG-0759/TKT-0728)
#
# Purpose:  Temporarily override the canonical db-sprint.sh next-ticket result
#           using the locked_execution_order from state/crestv2-p1-tracker.json.
#
# Behavior: Calls db-sprint.sh next-ticket to get the base candidate set, then
#           checks the tracker file for a higher-priority ticket to return.
#           The tracker's locked_execution_order defines the canonical execution
#           sequence for CRESTv2-P1 tickets.
#
# Deletable: YES — once the CRESTv2-P1 tracker is retired, delete this script.
#            Do NOT merge its logic into db-sprint.sh or pg-sprint-backlog skill.
# ═══════════════════════════════════════════════════════════════════════════════

set -u

WORKSPACE_ROOT="/Users/ainchorsangiefpl/.openclaw/workspace"
DB_SPRINT="$WORKSPACE_ROOT/scripts/db-sprint.sh"
DB_SCRIPT="$WORKSPACE_ROOT/scripts/db.sh"
TRACKER_FILE="$WORKSPACE_ROOT/state/crestv2-p1-tracker.json"
OVERRIDE_OUTPUT="$WORKSPACE_ROOT/state/next-ticket-override.json"
JQ="/opt/homebrew/bin/jq"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] next-ticket-tracker-override: $1" >&2; }
die() { echo "ERROR: $1" >&2; exit 1; }

# ── Parse args ──
AGENT_FILTER=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --agent)
      AGENT_FILTER="$2"
      shift 2
      ;;
    --help|-h)
      cat <<'HELP'
Usage: next-ticket-tracker-override.sh [--agent <name>]

  Returns the next ticket to work, considering the CRESTv2-P1 tracker override.

  --agent <name>  Filter to tickets for this agent (optional).
                  For yoda: matches yoda, unassigned, or null agent.
                  For other agents: strict match only.

  If the tracker file is missing, invalid, or has no eligible tickets,
  falls back to the canonical db-sprint.sh next-ticket result.

  Writes result to state/next-ticket-override.json.
HELP
      exit 0
      ;;
    *)
      die "Unknown flag: $1. Use --agent <name>"
      ;;
  esac
done

# ── Agent matching helper ──
# Returns 0 if ticket_agent matches the filter, 1 otherwise.
# For yoda: lenient — matches yoda, unassigned, null, or empty.
# For other agents: strict match only.
agent_matches() {
  local ticket_agent="$1"
  local filter="$2"

  if [[ -z "$filter" ]]; then
    return 0
  fi

  if [[ "$filter" == "yoda" ]]; then
    if [[ -z "$ticket_agent" || "$ticket_agent" == "null" || "$ticket_agent" == "yoda" ]]; then
      return 0
    fi
    return 1
  fi

  if [[ "$ticket_agent" == "$filter" ]]; then
    return 0
  fi
  return 1
}

# ── Step 1: Get base canonical result ──
log "Getting base next-ticket result (agent filter: ${AGENT_FILTER:-none})"

BASE_RESULT=""
if [[ -n "$AGENT_FILTER" ]]; then
  BASE_RESULT=$(bash "$DB_SPRINT" next-ticket --agent "$AGENT_FILTER" 2>/dev/null)
else
  BASE_RESULT=$(bash "$DB_SPRINT" next-ticket 2>/dev/null)
fi

if [[ -z "$BASE_RESULT" ]]; then
  die "Base next-ticket call failed — no result returned"
fi

if ! echo "$BASE_RESULT" | $JQ empty 2>/dev/null; then
  die "Base next-ticket returned invalid JSON: $BASE_RESULT"
fi

# ── Step 2: Read tracker file ──
if [[ ! -f "$TRACKER_FILE" ]]; then
  log "WARNING: Tracker file not found at $TRACKER_FILE — falling back to base next-ticket"
  echo "$BASE_RESULT" | tee "$OVERRIDE_OUTPUT"
  exit 0
fi

TRACKER_JSON=$(cat "$TRACKER_FILE" 2>/dev/null)
if ! echo "$TRACKER_JSON" | $JQ empty 2>/dev/null; then
  log "WARNING: Tracker file contains invalid JSON — falling back to base next-ticket"
  echo "$BASE_RESULT" | tee "$OVERRIDE_OUTPUT"
  exit 0
fi

# ── Step 3: Extract locked_execution_order tickets in order ──
TRACKER_TICKETS=$(
  echo "$TRACKER_JSON" | $JQ -r '
    .locked_execution_order[]
    | .tickets[]
  ' 2>/dev/null
)

if [[ -z "$TRACKER_TICKETS" ]]; then
  log "WARNING: No tickets in locked_execution_order — falling back to base next-ticket"
  echo "$BASE_RESULT" | tee "$OVERRIDE_OUTPUT"
  exit 0
fi

# ── Step 4: For each tracker ticket, check eligibility ──
# Pre-fetch active and next sprint names (they don't change per ticket)
ACTIVE_SPRINT=$(bash "$DB_SCRIPT" -c "SELECT sprint_name FROM state_sprints WHERE status='in_progress' AND sprint_number > 0 ORDER BY sprint_number DESC LIMIT 1;" 2>/dev/null | head -1)
NEXT_SPRINT=$(bash "$DB_SCRIPT" -c "SELECT sprint_name FROM state_sprints WHERE status='committed' AND start_date > CURRENT_DATE AND sprint_number > 0 ORDER BY start_date ASC LIMIT 1;" 2>/dev/null | head -1)

SELECTED_TICKET=""

while IFS= read -r tkt_id; do
  [[ -z "$tkt_id" ]] && continue

  log "Checking tracker ticket: $tkt_id"

  # Query PG for ticket status, sprint, and agent
  ROW=$(bash "$DB_SCRIPT" -c "SELECT id, status, sprint, metadata->>'sprint_agent' as agent FROM state_tickets WHERE id='$tkt_id';" 2>/dev/null | head -1)

  if [[ -z "$ROW" ]]; then
    log "  Ticket $tkt_id not found in PG — skipping"
    continue
  fi

  # Parse row (format: id|status|sprint|agent)
  TKT_STATUS=""
  TKT_SPRINT=""
  TKT_AGENT=""
  IFS='|' read -r _ TKT_STATUS TKT_SPRINT TKT_AGENT <<< "$ROW"

  # Check status: must be open or in_progress
  if [[ "$TKT_STATUS" != "open" && "$TKT_STATUS" != "in_progress" && "$TKT_STATUS" != "in-progress" ]]; then
    log "  Ticket $tkt_id status is '$TKT_STATUS' — not eligible (skipping)"
    continue
  fi

  # Check sprint: must be in active or next committed sprint
  IN_VALID_SPRINT=false
  if [[ -n "$TKT_SPRINT" && "$TKT_SPRINT" != "null" ]]; then
    if [[ "$TKT_SPRINT" == "$ACTIVE_SPRINT" || "$TKT_SPRINT" == "$NEXT_SPRINT" ]]; then
      IN_VALID_SPRINT=true
    fi
  fi

  if [[ "$IN_VALID_SPRINT" != "true" ]]; then
    log "  Ticket $tkt_id sprint is '$TKT_SPRINT' — not in active/next sprint (skipping)"
    continue
  fi

  # Check agent filter
  if ! agent_matches "$TKT_AGENT" "$AGENT_FILTER"; then
    log "  Ticket $tkt_id agent is '$TKT_AGENT' — does not match filter '$AGENT_FILTER' (skipping)"
    continue
  fi

  # Eligible!
  SELECTED_TICKET="$tkt_id"
  log "  Selected tracker ticket: $tkt_id (status=$TKT_STATUS, sprint=$TKT_SPRINT, agent=$TKT_AGENT)"
  break

done <<< "$TRACKER_TICKETS"

# ── Step 5: Build output ──
if [[ -z "$SELECTED_TICKET" ]]; then
  log "No eligible tracker ticket found — falling back to base next-ticket"
  echo "$BASE_RESULT" | tee "$OVERRIDE_OUTPUT"
  exit 0
fi

# Get full ticket details from PG
FULL_TICKET_JSON=$(
  bash "$DB_SCRIPT" -c "
    SELECT row_to_json(t)::text FROM state_tickets t WHERE id='$SELECTED_TICKET';
  " 2>/dev/null
)

if [[ -z "$FULL_TICKET_JSON" || "$FULL_TICKET_JSON" == "null" ]]; then
  log "WARNING: Could not get full ticket details for $SELECTED_TICKET — falling back to base"
  echo "$BASE_RESULT" | tee "$OVERRIDE_OUTPUT"
  exit 0
fi

# Extract sprint context from base result
CURRENT_SPRINT_JSON=$(echo "$BASE_RESULT" | $JQ '.current_sprint' 2>/dev/null)
NEXT_SPRINT_JSON=$(echo "$BASE_RESULT" | $JQ '.next_sprint' 2>/dev/null)

# Build the output JSON in the same shape as db-sprint.sh next-ticket
RESULT=$(
  echo "$FULL_TICKET_JSON" | $JQ \
    --argjson current_sprint "$CURRENT_SPRINT_JSON" \
    --argjson next_sprint "$NEXT_SPRINT_JSON" \
    '{
      ticket: .id,
      sprint: .sprint,
      sprint_seq: (.sprint_seq // null),
      status: .status,
      priority: .priority,
      effort: (.metadata.sprint_effort // .metadata.effort // null),
      agent: (.metadata.sprint_agent // .metadata.agent // null),
      reason: "tracker-override",
      current_sprint: $current_sprint,
      next_sprint: $next_sprint
    }' 2>/dev/null
)

if [[ -z "$RESULT" || "$RESULT" == "null" ]]; then
  log "WARNING: Failed to build output JSON — falling back to base"
  echo "$BASE_RESULT" | tee "$OVERRIDE_OUTPUT"
  exit 0
fi

echo "$RESULT" | tee "$OVERRIDE_OUTPUT"
