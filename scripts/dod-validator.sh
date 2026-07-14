#!/bin/zsh
# AInchors Post-Deliverable Validator — TKT-0237 A3
# Re-checks recently closed tickets for missing/broken deliverables.
# Runs every 2 hours via cron. Owner: Warden | Sprint 4.

set -u

WORKSPACE_ROOT="/Users/ainchorsoc2a/.openclaw/workspace"
DB_READ="$WORKSPACE_ROOT/scripts/db-read.sh"
ALERT_FILE="$WORKSPACE_ROOT/state/dod-validation-alert.json"
CUTOFF_HOURS=24

die() { echo "DOD-VALIDATOR ERROR: $1" >&2; exit 1; }

echo "DoD Validator: Scanning tickets closed in last ${CUTOFF_HOURS}h..."

NOW_EPOCH=$(date +%s)
CUTOFF_MS=$((NOW_EPOCH - CUTOFF_HOURS * 3600))

# Read closed tickets from PG (SSOT) via db-read.sh
TICKETS_JSON=$("$DB_READ" state_tickets 2>/dev/null)
if [[ -z "$TICKETS_JSON" || "$TICKETS_JSON" == "null" ]]; then
  die "Failed to read state_tickets from PG"
fi

# Get recently closed tickets from PG data
CLOSED_TICKETS=$(echo "$TICKETS_JSON" | jq --argjson cutoff "$CUTOFF_MS" '
  [.[] | 
   select(.status == "closed" or .status == "resolved") |
   select(
     ((.updated_at // .updated // "2026-01-01T00:00:00+00:00") 
      | tostring 
      | if test("Z$") then .[:19] + "Z"
        elif test("\\+") then (split("+")[0] + "Z")
        else .[:19] + "Z"
        end
      | fromdate) > $cutoff
   )] |
   sort_by(.updated_at // .updated) | reverse' 2>/dev/null)

if [[ -z "$CLOSED_TICKETS" || "$CLOSED_TICKETS" == "[]" ]]; then
  echo "DoD Validator: No recently closed tickets to check."
  
  # Purge stale alerts (>7 days)
  if [[ -f "$ALERT_FILE" ]]; then
    SEVEN_DAYS_MS=$((NOW_EPOCH - 604800))
    UPDATED=$(jq --argjson cutoff "$SEVEN_DAYS_MS" '
      .alerts |= map(select(
     ((.detectedAt // "2025-01-01T00:00:00+00:00") 
      | tostring 
      | if test("Z$") then .[:19] + "Z"
        elif test("\\+") then (split("+")[0] + "Z")
        else .[:19] + "Z"
        end
      | fromdate) > $cutoff
   ))' "$ALERT_FILE" 2>/dev/null)
    if [[ -n "$UPDATED" && "$UPDATED" != "$(cat "$ALERT_FILE")" ]]; then
      echo "$UPDATED" > "$ALERT_FILE"
      echo "DoD Validator: Purged stale alerts (>7 days)"
    fi
  fi
  exit 0
fi

NEW_ALERTS='{"alerts": []}'
[[ -f "$ALERT_FILE" ]] && NEW_ALERTS=$(cat "$ALERT_FILE")

TICKET_COUNT=$(echo "$CLOSED_TICKETS" | jq 'length')
CHECKED=0; PASSED=0; FAILED=0; FIXED=0

# Check each closed ticket
for i in $(seq 0 $((TICKET_COUNT - 1))); do
  TKT=$(echo "$CLOSED_TICKETS" | jq -r ".[$i]")
  TKT_ID=$(echo "$TKT" | jq -r '.id')
  TKT_TYPE=$(echo "$TKT" | jq -r '.type // "task"')
  TKT_CLOSED=$(echo "$TKT" | jq -r '.updated')
  RESOLUTION=$(echo "$TKT" | jq -r '.resolution // ""')
  
  CHECKED=$((CHECKED + 1))
  
  # Extract deliverable path
  DELIVERABLE_PATH=""
  if echo "$RESOLUTION" | grep -q "^/Users/"; then
    DELIVERABLE_PATH=$(echo "$RESOLUTION" | grep -o "^/Users/[^ ]*" | head -1)
  fi
  if [[ -z "$DELIVERABLE_PATH" ]]; then
    # Use find to avoid glob errors on no-match
    DELIVERABLE_PATH=$(find "$WORKSPACE_ROOT/docs" "$WORKSPACE_ROOT/scripts" "$WORKSPACE_ROOT/state"       -maxdepth 1 -name "${TKT_ID}*" \( -name "*.md" -o -name "*.sh" -o -name "*.json" \) 2>/dev/null | head -1)
  fi
  
  if [[ -n "$DELIVERABLE_PATH" ]]; then
    if verify_before_close "$TKT_ID" "$TKT_TYPE" "$DELIVERABLE_PATH" 2>/dev/null; then
      PASSED=$((PASSED + 1))
    else
      FAILED=$((FAILED + 1))
      EXISTING=$(echo "$NEW_ALERTS" | jq --arg tid "$TKT_ID" '.alerts | map(select(.ticketId == $tid)) | length' 2>/dev/null || echo 0)
      if [[ "$EXISTING" -eq 0 ]]; then
        DT=$(date -Iseconds)
        NEW_ALERTS=$(echo "$NEW_ALERTS" | jq --arg tid "$TKT_ID" --arg chk "deliverable_file_missing" \
          --arg path "$DELIVERABLE_PATH" --arg closed "$TKT_CLOSED" --arg dt "$DT" \
          '.alerts += [{"ticketId": $tid, "failedCheck": $chk, "expectedPath": $path, "closedAt": $closed, "detectedAt": $dt, "acknowledged": false}]')
        echo "  ❌ $TKT_ID: deliverable missing — $DELIVERABLE_PATH"
      else
        echo "  ⚠️ $TKT_ID: alert already active"
      fi
    fi
  else
    PASSED=$((PASSED + 1))
  fi
done

# Check if previously-alerted tickets are now fixed
if [[ -f "$ALERT_FILE" ]]; then
  OLD_ALERTS=$(cat "$ALERT_FILE")
  ALERT_COUNT=$(echo "$OLD_ALERTS" | jq '.alerts | length' 2>/dev/null || echo 0)
  for j in $(seq 0 $((ALERT_COUNT - 1))); do
    ALERT_PATH=$(echo "$OLD_ALERTS" | jq -r ".alerts[$j].expectedPath")
    ALERT_TKT=$(echo "$OLD_ALERTS" | jq -r ".alerts[$j].ticketId")
    if [[ -f "$ALERT_PATH" ]]; then
      FIXED=$((FIXED + 1))
      NEW_ALERTS=$(echo "$NEW_ALERTS" | jq --arg tid "$ALERT_TKT" '.alerts |= map(select(.ticketId != $tid))')
      echo "  ✅ $ALERT_TKT: deliverable restored — alert cleared"
    fi
  done
fi

echo "$NEW_ALERTS" > "$ALERT_FILE"
ACTIVE=$(echo "$NEW_ALERTS" | jq '.alerts | map(select(.acknowledged == false)) | length' 2>/dev/null || echo 0)
echo "DoD Validator: $CHECKED checked | $PASSED passed | $FAILED failed | $FIXED resolved | $ACTIVE active"

[[ "$ACTIVE" -gt 0 ]] && exit 1
exit 0
