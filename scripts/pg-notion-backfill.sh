#!/bin/bash
# pg-notion-backfill.sh — Backfill all PG state_tickets to Notion DB A
# TKT-0406 Phase 4: Full backfill orchestration
# Relies on pg-to-notion-sync.sh v2.0 for per-ticket sync (all 15 properties)
#
# Modes:
#   --dry-run        Log what would happen, don't execute
#   --pilot N        Process N tickets, pause for verification
#   --resume         Resume from last successful ticket in state file
#   (no flag)        Full backfill — process all tickets

set -euo pipefail

# --- CONFIGURATION ---
WORKSPACE_ROOT="/Users/ainchorsangiefpl/.openclaw/workspace"
SYNC_SCRIPT="$WORKSPACE_ROOT/scripts/pg-to-notion-sync.sh"
DB_SCRIPT="$WORKSPACE_ROOT/scripts/db.sh"
STATE_FILE="$WORKSPACE_ROOT/state/pg-notion-backfill-state.json"
SNAPSHOT_DIR="$WORKSPACE_ROOT/state/pg-notion-backfill-snapshots"
NOTION_KEY_FILE="/Users/ainchorsangiefpl/.config/notion/api_key"
NOTION_API="https://api.notion.com/v1"
NOTION_VERSION="2022-06-28"
DB_BACKLOG="34dc1829-53ff-814b-8257-d3a3bf351d44"
BATCH_SIZE=50
BATCH_PAUSE=5
# macOS doesn't have GNU timeout by default; sync script handles its own HTTP timeouts

# --- UTILITIES ---
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] BACKFILL: $1"; }
err()  { echo "[$(date '+%Y-%m-%d %H:%M:%S')] BACKFILL ERROR: $1" >&2; }
die()  { err "$1"; exit 1; }

# --- CHECK PREREQUISITES ---
[[ ! -f "$SYNC_SCRIPT" ]] && die "Sync script not found: $SYNC_SCRIPT"
[[ ! -f "$DB_SCRIPT" ]] && die "DB script not found: $DB_SCRIPT"
[[ ! -f "$NOTION_KEY_FILE" ]] && die "Notion API key not found: $NOTION_KEY_FILE"

NOTION_KEY=$(cat "$NOTION_KEY_FILE")

# --- SNAPSHOT: Save current Notion page properties before modifying ---
snapshot_page() {
  local notion_id="$1"
  local tkt_id="$2"
  
  mkdir -p "$SNAPSHOT_DIR"
  local snap_file="$SNAPSHOT_DIR/${notion_id}.json"
  
  # Skip if snapshot already exists (already processed once)
  [[ -f "$snap_file" ]] && return 0
  
  local resp=$(curl -s --max-time 10 \
    "$NOTION_API/pages/$notion_id" \
    -H "Authorization: Bearer $NOTION_KEY" \
    -H "Notion-Version: $NOTION_VERSION")
  
  if echo "$resp" | jq -e '.properties' > /dev/null 2>&1; then
    echo "$resp" | jq '{id: .id, properties: .properties, last_edited_time: .last_edited_time}' > "$snap_file"
    log "Snapshot saved for $tkt_id → $snap_file"
    return 0
  else
    err "Failed to snapshot $tkt_id (page $notion_id): $(echo "$resp" | jq -r '.message // "unknown error"')"
    return 1
  fi
  
  sleep 0.35  # rate limit
}

# --- STATE MANAGEMENT ---
load_state() {
  if [[ -f "$STATE_FILE" ]]; then
    cat "$STATE_FILE"
  else
    echo '{"last_processed": null, "processed_count": 0, "total": 0, "errors": []}'
  fi
}

save_state() {
  local last="$1"
  local count="$2"
  local total="$3"
  local errors="$4"
  
  mkdir -p "$(dirname "$STATE_FILE")"
  jq -n \
    --arg last "$last" \
    --argjson count "$count" \
    --argjson total "$total" \
    --argjson errors "$errors" \
    '{last_processed: $last, processed_count: $count, total: $total, errors: $errors}' \
    > "$STATE_FILE"
}

# --- QUERY: Get Notion page by TKT-ID title search ---
find_notion_page() {
  local tkt_id="$1"
  local search_query=$(jq -n --arg t "$tkt_id" \
    '{"filter": {"property": "US Title", "title": {"contains": $t}}, "page_size": 5}')
  
  local resp=$(curl -s --max-time 10 \
    -X POST "$NOTION_API/databases/$DB_BACKLOG/query" \
    -H "Authorization: Bearer $NOTION_KEY" \
    -H "Notion-Version: $NOTION_VERSION" \
    -H "Content-Type: application/json" \
    --data "$search_query")
  
  echo "$resp" | jq -r '.results[0].id // empty'
  sleep 0.35
}

# --- MAIN BACKFILL LOOP ---
run_backfill() {
  local mode="${1:-full}"
  local pilot_count="${2:-0}"
  
  # Get all tickets
  local all_tickets=$($DB_SCRIPT -c "SELECT id, notionpageid FROM state_tickets ORDER BY id;" 2>&1)
  local total_tickets=$(echo "$all_tickets" | grep -c "TKT-" || echo "0")
  
  log "Backfill mode: $mode | Total tickets in PG: $total_tickets"
  
  # Load previous state for resume
  local state=$(load_state)
  local last_processed=$(echo "$state" | jq -r '.last_processed // empty')
  local processed_count=$(echo "$state" | jq -r '.processed_count // 0')
  local errors_json=$(echo "$state" | jq -c '.errors // []')
  local resume_encountered=false
  
  if [[ "$mode" == "resume" ]]; then
    [[ -z "$last_processed" ]] && die "No previous state found. Run without --resume first."
    log "Resuming from: $last_processed (already processed: $processed_count/$total_tickets)"
    resume_encountered=false
  fi
  
  local batch_count=0
  local skipped_count=0
  
  # Process each ticket from pg output
  while IFS='|' read -r tkt_id notionid; do
    # Strip whitespace
    tkt_id=$(echo "$tkt_id" | tr -d '[:space:]')
    notionid=$(echo "$notionid" | tr -d '[:space:]')
    
    [[ -z "$tkt_id" ]] && continue
    [[ "$tkt_id" != TKT-* ]] && continue
    
    # --- RESUME LOGIC ---
    if [[ "$mode" == "resume" && "$resume_encountered" == false ]]; then
      if [[ "$tkt_id" == "$last_processed" ]]; then
        resume_encountered=true
        continue  # Skip the last-processed ticket (it was already done)
      else
        continue  # Skip until we hit the resume point
      fi
    fi
    
    processed_count=$((processed_count + 1))
    log "Processing [$processed_count/$total_tickets]: $tkt_id"
    
    # --- SNAPSHOT PHASE ---
    if [[ -n "$notionid" && "$notionid" != "null" && ${#notionid} -eq 36 ]]; then
      snapshot_page "$notionid" "$tkt_id" || true
    fi
    
    # --- SYNC PHASE ---
    if [[ "$mode" == "dry-run" ]]; then
      if [[ -n "$notionid" && "$notionid" != "null" ]]; then
        log "[DRY-RUN] Would PATCH update Notion page $notionid for $tkt_id (has notionpageid)"
      else
        # Check if exists in Notion
        local found_id=$(find_notion_page "$tkt_id")
        if [[ -n "$found_id" ]]; then
          log "[DRY-RUN] Would link existing Notion page $found_id AND PATCH update for $tkt_id"
        else
          log "[DRY-RUN] Would CREATE Notion page + sync for $tkt_id (no notionpageid, no match)"
        fi
      fi
      save_state "$tkt_id" "$processed_count" "$total_tickets" "$errors_json"
    else
      local sync_output
      if sync_output=$(bash "$SYNC_SCRIPT" --single "$tkt_id" 2>&1); then
        log "✓ $tkt_id synced successfully"
      else
        err "✗ $tkt_id sync failed: $sync_output"
        errors_json=$(echo "$errors_json" | jq ". + [{\"ticket\": \"$tkt_id\", \"error\": \"$sync_output\", \"timestamp\": \"$(date -u '+%Y-%m-%dT%H:%M:%SZ')\"}]")
      fi
      
      save_state "$tkt_id" "$processed_count" "$total_tickets" "$errors_json"
    fi
    
    # --- PILOT CHECK ---
    if [[ "$mode" == "pilot" && "$pilot_count" -gt 0 && "$processed_count" -ge "$pilot_count" ]]; then
      log "PILOT COMPLETE: Processed $processed_count tickets"
      break
    fi
    
    # --- BATCH PAUSE ---
    batch_count=$((batch_count + 1))
    if [[ $((batch_count % BATCH_SIZE)) -eq 0 ]]; then
      if [[ "$mode" != "dry-run" && "$mode" != "pilot" && "$batch_count" -lt "$total_tickets" ]]; then
        log "Batch pause: $batch_count/$total_tickets tickets processed. Sleeping ${BATCH_PAUSE}s..."
        sleep "$BATCH_PAUSE"
      fi
    fi
    
  done <<< "$(echo "$all_tickets" | grep "TKT-")"
  
  # --- FINAL SUMMARY ---
  local error_count=$(echo "$errors_json" | jq 'length // 0')
  log "============================================"
  log "BACKFILL COMPLETE"
  log "Processed: $processed_count / $total_tickets"
  log "Errors:    $error_count"
  log "State:     $STATE_FILE"
  log "Snapshots: $SNAPSHOT_DIR"
  log "============================================"
  
  if [[ "$error_count" -gt 0 ]]; then
    err "Errors encountered:"
    echo "$errors_json" | jq -r '.[] | "  - \(.ticket): \(.error)"' 2>/dev/null || echo "$errors_json"
  fi
}

# --- ARGUMENT PARSING ---
DRY_RUN=false
MODE="full"
PILOT_COUNT=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=true
      MODE="dry-run"
      shift
      ;;
    --pilot)
      MODE="pilot"
      PILOT_COUNT="$2"
      shift 2
      ;;
    --resume)
      MODE="resume"
      shift
      ;;
    --help|-h)
      echo "Usage: $0 [--dry-run | --pilot N | --resume]"
      echo ""
      echo "Backfill all PG state_tickets to Notion DB A."
      echo ""
      echo "Modes:"
      echo "  --dry-run    Log what would happen, don't execute syncs"
      echo "  --pilot N    Process N tickets, pause for verification"
      echo "  --resume     Resume from last successful ticket in state file"
      echo "  (no flag)    Full backfill — process all tickets"
      exit 0
      ;;
    *)
      die "Unknown argument: $1 (use --help)"
      ;;
  esac
done

# --- EXECUTE ---
log "pg-notion-backfill.sh — TKT-0406 Phase 4"
log "Mode: $MODE | Dry run: $DRY_RUN | Pilot count: $PILOT_COUNT"
mkdir -p "$(dirname "$STATE_FILE")"
mkdir -p "$SNAPSHOT_DIR"
run_backfill "$MODE" "$PILOT_COUNT"
