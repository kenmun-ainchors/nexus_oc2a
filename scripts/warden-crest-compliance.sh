#!/bin/bash
# warden-crest-compliance.sh — Warden compliance check
#
# Flags closed tickets that lack an independent Sage Verify verdict
# (phase=verify, owner=qa, verdict in (pass,fail,needs_human), status=completed)
# in the state_sub_crest table.
#
# Usage:
#   scripts/warden-crest-compliance.sh [--since YYYY-MM-DD] [--dry-run] [--json]
#
# Options:
#   --since YYYY-MM-DD   Check tickets closed on or after this date (default: 30 days ago)
#   --dry-run            Print violations to stdout but do not write results file
#   --json               Output JSON to stdout (implies --dry-run)
#
# Exit codes:
#   0  — No violations found
#   1  — Violations found
#
# Dependencies:
#   scripts/db-raw.sh
#   jq (resolved via PATH or /usr/bin/jq fallback; respects $JQ env override)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JQ="${JQ:-$(command -v jq 2>/dev/null || echo /usr/bin/jq)}"
DB_RAW="${SCRIPT_DIR}/db-raw.sh"
TODAY="$(date +%Y-%m-%d)"

# --- Defaults ---
SINCE="$(date -v-30d +%Y-%m-%d)"
DRY_RUN=false
JSON_MODE=false

# --- Parse flags ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --since)
      SINCE="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --json)
      JSON_MODE=true
      DRY_RUN=true
      shift
      ;;
    *)
      echo "Usage: $0 [--since YYYY-MM-DD] [--dry-run] [--json]" >&2
      exit 2
      ;;
  esac
done

# --- Validate date ---
if ! date -j -f "%Y-%m-%d" "$SINCE" >/dev/null 2>&1; then
  echo "ERROR: Invalid date format: $SINCE (expected YYYY-MM-DD)" >&2
  exit 2
fi

# --- Query closed tickets in window ---
# ticket_number is integer; parent_ticket in state_sub_crest is 'TKT-NNNN' text
CLOSED_TICKETS="$(
  ${DB_RAW} -c "
    SELECT ticket_number, updated_at
    FROM state_tickets
    WHERE status = 'closed'
      AND updated_at >= '${SINCE}'::timestamptz
    ORDER BY ticket_number
  " 2>/dev/null
)"

if [[ -z "$CLOSED_TICKETS" ]]; then
  if $JSON_MODE; then
    cat <<EOF
{"run_date":"${TODAY}","since":"${SINCE}","violations":[],"pass_count":0,"violation_count":0}
EOF
  elif $DRY_RUN; then
    echo "No closed tickets found since ${SINCE}."
  fi
  exit 0
fi

# --- Check each ticket ---
VIOLATIONS="[]"
PASS_COUNT=0

while IFS='|' read -r TICKET_NUM UPDATED_AT; do
  # Trim whitespace
  TICKET_NUM="$(echo "$TICKET_NUM" | xargs)"
  UPDATED_AT="$(echo "$UPDATED_AT" | xargs)"
  [[ -z "$TICKET_NUM" ]] && continue

  # Format as TKT-NNNN (zero-padded to 4 digits)
  PARENT_TKT="TKT-$(printf "%04d" "$TICKET_NUM")"

  # Check for independent Verify verdict
  VERIFY_ROW="$(
    ${DB_RAW} -c "
      SELECT 1 FROM state_sub_crest
      WHERE parent_ticket = '${PARENT_TKT}'
        AND phase = 'Verify'
        AND owner = 'qa'
        AND verdict IN ('pass', 'fail', 'needs_human')
        AND status = 'completed'
      LIMIT 1
    " 2>/dev/null
  )"

  if [[ -n "$VERIFY_ROW" ]]; then
    PASS_COUNT=$((PASS_COUNT + 1))
    continue
  fi

  # Check for exception_approved_by in metadata
  EXCEPTION="$(
    ${DB_RAW} -c "
      SELECT metadata->>'exception_approved_by'
      FROM state_tickets
      WHERE ticket_number = ${TICKET_NUM}
        AND metadata->>'exception_approved_by' IS NOT NULL
        AND metadata->>'exception_approved_by' != ''
      LIMIT 1
    " 2>/dev/null
  )"

  if [[ -n "$EXCEPTION" ]]; then
    # Has exception — count as pass
    PASS_COUNT=$((PASS_COUNT + 1))
    continue
  fi

  # Violation
  VIOLATION="$($JQ -n --arg ticket "$PARENT_TKT" \
    '{ticket: $ticket, reason: "missing independent Verify verdict", exception: false}')"
  VIOLATIONS="$(echo "$VIOLATIONS" | $JQ --argjson v "$VIOLATION" '. + [$v]')"
done <<< "$CLOSED_TICKETS"

VIOLATION_COUNT="$(echo "$VIOLATIONS" | $JQ 'length')"

# --- Output ---
if $JSON_MODE; then
  $JQ -n \
    --arg run_date "$TODAY" \
    --arg since "$SINCE" \
    --argjson violations "$VIOLATIONS" \
    --argjson pass_count "$PASS_COUNT" \
    --argjson violation_count "$VIOLATION_COUNT" \
    '{
      run_date: $run_date,
      since: $since,
      violations: $violations,
      pass_count: $pass_count,
      violation_count: $violation_count
    }'
elif $DRY_RUN; then
  echo "=== Warden CREST Compliance Check ==="
  echo "Since: $SINCE"
  echo "Pass count: $PASS_COUNT"
  echo "Violation count: $VIOLATION_COUNT"
  if [[ "$VIOLATION_COUNT" -gt 0 ]]; then
    echo ""
    echo "Violations:"
    echo "$VIOLATIONS" | $JQ -r '.[] | "  \(.ticket): \(.reason)"'
  fi
else
  # Write results file
  RESULTS_FILE="${SCRIPT_DIR}/../state/warden-crest-compliance-${TODAY}.json"
  $JQ -n \
    --arg run_date "$TODAY" \
    --arg since "$SINCE" \
    --argjson violations "$VIOLATIONS" \
    --argjson pass_count "$PASS_COUNT" \
    --argjson violation_count "$VIOLATION_COUNT" \
    '{
      run_date: $run_date,
      since: $since,
      violations: $violations,
      pass_count: $pass_count,
      violation_count: $violation_count
    }' > "$RESULTS_FILE"
  echo "Results written to: $RESULTS_FILE"
fi

# --- Exit code ---
if [[ "$VIOLATION_COUNT" -gt 0 ]]; then
  exit 1
fi
exit 0
