#!/bin/zsh
# notion-status-sync.sh — Idempotent Status Reconciliation: PG (SSOT) → Notion
# TKT-0392-A: Fix all PG/Notion status mismatches. PG wins every conflict.
#
# Usage: ./scripts/notion-status-sync.sh [--dry-run]
#
# Flags:
#   --dry-run   Only audit, do not PATCH anything

set -u

# --- SKILL GATE: notion ---
source "${SCRIPT_DIR:-$(dirname "$0")}/skill-gate.sh" "notion" || exit $?

WORKSPACE_ROOT="/Users/ainchorsangiefpl/.openclaw/workspace"
NOTION_KEY_FILE="$HOME/.config/notion/api_key"
DB_BACKLOG="34dc1829-53ff-814b-8257-d3a3bf351d44"
SUMMARY_FILE="$WORKSPACE_ROOT/state/notion-status-recon-2026-06-10.json"

NOTION_API="https://api.notion.com/v1"
NOTION_VERSION="2022-06-28"

# Rate limiting: max 3 req/sec
RATE_LIMIT_US=333333  # microseconds between requests (slightly over 3/sec to be safe)

DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

# ─── Utilities ───────────────────────────────────────────────────────────────
log()  { echo "[$(date '+%H:%M:%S')] $1"; }
die()  { echo "FATAL: $1" >&2; exit 1; }

# Load Notion API key
[[ ! -f "$NOTION_KEY_FILE" ]] && die "Notion API key missing at $NOTION_KEY_FILE"
NOTION_KEY=$(cat "$NOTION_KEY_FILE")

# ─── Status Mapping: PG → Notion ───────────────────────────────────────────
# Based on Notion Backlog DB Status select options observed:
#   Backlog, In Sprint, In Progress, Done, Blocked, Deferred, Open,
#   Cancelled, Pending, In-progress, Closed
#
# NOTE: Notion has BOTH "In Progress" (yellow) and "In-progress" (default color).
# The PG status "in-progress" maps to "In Progress" (the intended active status).
map_pg_to_notion_status() {
  case "$1" in
    backlog)      echo "Backlog" ;;
    open)         echo "Open" ;;
    in-progress)  echo "In Progress" ;;
    review)       echo "In Progress" ;;    # PG review → Notion In Progress
    done)         echo "Done" ;;
    closed)       echo "Closed" ;;
    folded)       echo "Done" ;;            # folded = done semantically
    pending)      echo "Pending" ;;
    cancelled)    echo "Cancelled" ;;
    blocked)      echo "Blocked" ;;
    grooming)     echo "Backlog" ;;         # grooming is a backlog activity
    monitoring)   echo "In Progress" ;;     # active monitoring = in progress
    *)            echo "" ;;                 # UNKNOWN — return empty
  esac
}

# ─── Fetch Notion Page Status ────────────────────────────────────────────────
# Returns the current Status select name from Notion, or "UNKNOWN" on error.
fetch_notion_status() {
  local page_id="$1"
  local resp
  resp=$(curl -s -X GET "$NOTION_API/pages/$page_id" \
    -H "Authorization: Bearer $NOTION_KEY" \
    -H "Notion-Version: $NOTION_VERSION")
  
  local status
  status=$(echo "$resp" | jq -r '.properties.Status.select.name // "UNSET"')
  
  # If the page doesn't exist or API error
  local obj
  obj=$(echo "$resp" | jq -r '.object // empty')
  if [[ "$obj" == "error" ]]; then
    echo "ERROR:$(echo "$resp" | jq -r '.message')"
    return 0
  fi
  
  echo "$status"
}

# ─── Patch Notion Page Status ────────────────────────────────────────────────
patch_notion_status() {
  local page_id="$1"
  local target_status="$2"
  
  local payload
  payload=$(jq -n --arg sta "$target_status" \
    '{properties: {"Status": {"select": {"name": $sta}}}}')
  
  local resp
  resp=$(curl -s -X PATCH "$NOTION_API/pages/$page_id" \
    -H "Authorization: Bearer $NOTION_KEY" \
    -H "Notion-Version: $NOTION_VERSION" \
    -H "Content-Type: application/json" \
    --data "$payload")
  
  local obj
  obj=$(echo "$resp" | jq -r '.object // empty')
  
  if [[ "$obj" == "error" ]]; then
    echo "FAILED:$(echo "$resp" | jq -r '.message')"
    return 1
  fi
  
  echo "OK"
}

# ─── Rate Limiter ────────────────────────────────────────────────────────────
LAST_CALL=0
throttle() {
  local now
  now=$(python3 -c 'import time; print(int(time.time() * 1000000))')
  local elapsed=$(( now - LAST_CALL ))
  if (( elapsed < RATE_LIMIT_US )); then
    local sleep_us=$(( RATE_LIMIT_US - elapsed ))
    # sleep in microseconds via python for precision
    python3 -c "import time; time.sleep($sleep_us / 1000000.0)" 2>/dev/null
  fi
  LAST_CALL=$(python3 -c 'import time; print(int(time.time() * 1000000))')
}

# ─── Main ────────────────────────────────────────────────────────────────────
log "=== TKT-0392-A Notion Status Reconciliation ==="
$DRY_RUN && log "*** DRY RUN — no patches will be applied ***"

# Track counts
TOTAL=0
MATCH=0
PATCHED=0
SKIPPED=0
FAILED=0
UNMAPPED=0

# Results accumulator
CHANGES="[]"

# Start timing
START_TS=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

# 1. Query PG for all tickets with notionpageid
log "Querying PG for tickets with Notion page IDs..."
PG_DATA=$(/Users/ainchorsangiefpl/.openclaw/workspace/scripts/db.sh -c \
  "SELECT id, status, notionpageid FROM state_tickets WHERE notionpageid IS NOT NULL AND notionpageid != '' ORDER BY id;" 2>&1 | grep -v "^id|" | grep -v "^$" || true)

if [[ -z "$PG_DATA" ]]; then
  log "No PG tickets with notionpageid found. Nothing to reconcile."
  echo '{"timestamp":"'$START_TS'","total":0,"matched":0,"patched":0,"skipped":0,"failed":0,"unmapped":0,"changes":[]}' > "$SUMMARY_FILE"
  exit 0
fi

# 2. Process each ticket
TICKET_COUNT=$(echo "$PG_DATA" | wc -l | tr -d ' ')
log "Processing $TICKET_COUNT tickets..."

while IFS='|' read -r id pg_status notion_id; do
  # Skip empty lines or lines that don't parse as TKT*
  [[ -z "$id" ]] && continue
  [[ "$id" != *"TKT-"* ]] && continue
  
  TOTAL=$((TOTAL + 1))
  
  # Map PG status to Notion status
  target_status=$(map_pg_to_notion_status "$pg_status")
  
  if [[ -z "$target_status" ]]; then
    log "WARNING: $id: PG status '$pg_status' has no Notion equivalent — skipping"
    UNMAPPED=$((UNMAPPED + 1))
    continue
  fi
  
  # Clean notion_id (strip whitespace/newlines)
  notion_id=$(echo "$notion_id" | tr -d '[:space:]')
  
  # Throttle before API call
  throttle
  
  # Fetch current Notion status
  current_status=$(fetch_notion_status "$notion_id")
  
  # Check for errors
  if [[ "$current_status" == ERROR:* ]]; then
    log "ERROR: $id: API error for page $notion_id: ${current_status#ERROR:}"
    FAILED=$((FAILED + 1))
    continue
  fi
  
  # Compare
  if [[ "$current_status" == "$target_status" ]]; then
    MATCH=$((MATCH + 1))
    continue
  fi
  
  # Mismatch — patch it
  log "MISMATCH: $id: PG=$pg_status → Notion:Status should be '$target_status' (currently '$current_status')"
  
  if ! $DRY_RUN; then
    throttle
    result=$(patch_notion_status "$notion_id" "$target_status")
    
    if [[ "$result" == "OK" ]]; then
      log "  ✅ Patched $id: '$current_status' → '$target_status'"
      PATCHED=$((PATCHED + 1))
      
      # Record change
      CHANGE=$(jq -n \
        --arg id "$id" \
        --arg pg "$pg_status" \
        --arg old "$current_status" \
        --arg new "$target_status" \
        --arg nid "$notion_id" \
        '{ticket: $id, pg_status: $pg, notion_was: $old, notion_now: $new, notion_page_id: $nid}')
      CHANGES=$(echo "$CHANGES" | jq ". + [$CHANGE]")
    else
      log "  ❌ Failed to patch $id: ${result#FAILED:}"
      FAILED=$((FAILED + 1))
    fi
  else
    log "  (dry-run) Would patch '$current_status' → '$target_status'"
    SKIPPED=$((SKIPPED + 1))
  fi
  
done <<< "$PG_DATA"

END_TS=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
DURATION=$(python3 -c "
import datetime
s = datetime.datetime.fromisoformat('$START_TS'.replace('Z','+00:00'))
e = datetime.datetime.fromisoformat('$END_TS'.replace('Z','+00:00'))
d = (e - s).total_seconds()
print(f'{d:.1f}s')
" 2>/dev/null || echo "unknown")

# Build summary
SUMMARY=$(jq -n \
  --arg ts "$END_TS" \
  --arg dur "$DURATION" \
  --argjson total "$TOTAL" \
  --argjson matched "$MATCH" \
  --argjson patched "$PATCHED" \
  --argjson skipped "$SKIPPED" \
  --argjson failed "$FAILED" \
  --argjson unmapped "$UNMAPPED" \
  --argjson dry "$DRY_RUN" \
  --argjson changes "$CHANGES" \
  '{timestamp: $ts, duration: $dur, dry_run: $dry, total_checked: $total, already_matched: $matched, patches_applied: $patched, skipped_dry_run: $skipped, failed: $failed, unmapped_statuses: $unmapped, total_changes: ($patched + $skipped + $failed), changes: $changes}')

echo "$SUMMARY" > "$SUMMARY_FILE"

log ""
log "=== Summary ==="
log "Total checked:  $TOTAL"
log "Already matched:$MATCH"
log "Patched:        $PATCHED"
if $DRY_RUN; then
  log "Would patch:    $SKIPPED (dry-run)"
fi
log "Failed:         $FAILED"
log "Unmapped:       $UNMAPPED"
log "Duration:       $DURATION"
log "Summary saved:  $SUMMARY_FILE"
log "=== Done ==="

exit 0