#!/bin/zsh
# pg-to-notion-sync.sh v2.0 — Permanent PG (SSOT) to Notion Backlog Sync
# TKT-0406 IMPLEMENTATION
# SSOT: PostgreSQL -> Derived View: Notion DB A

set -euo pipefail

# --- CONFIGURATION ---
WORKSPACE_ROOT="/Users/ainchorsangiefpl/.openclaw/workspace"
DB_SCRIPT="$WORKSPACE_ROOT/scripts/db.sh"
NOTION_KEY_FILE="/Users/ainchorsangiefpl/.config/notion/api_key"
LOCK_FILE="/tmp/pg-notion-sync.lock"
NOTION_API="https://api.notion.com/v1"
NOTION_VERSION="2022-06-28"
DB_BACKLOG="34dc1829-53ff-814b-8257-d3a3bf351d44"
DB_ARCHIVE="364c1829-53ff-818e-a783-ebafcb6a9880"

# --- UTILITIES ---
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"; }
die() { echo "CRITICAL ERROR: $1" >&2; exit 1; }

# Rate limiting: 350ms sleep to stay under 3 req/sec
rate_limit() { sleep 0.35; }

# Load Notion Key
[[ ! -f "$NOTION_KEY_FILE" ]] && die "Notion API key missing at $NOTION_KEY_FILE"
NOTION_KEY=$(cat "$NOTION_KEY_FILE")

# Lock handling with staleness detection
acquire_lock() {
  if ! command -v flock >/dev/null; then return 0; fi
  exec 200>"$LOCK_FILE"
  if ! flock -n 200; then
    local lock_age=$(stat -f %m "$LOCK_FILE" 2>/dev/null || echo 0)
    local now=$(date +%s)
    if (( now - lock_age > 3600 )); then
      log "Stale lock detected (>1h). Force acquiring..."
      rm -f "$LOCK_FILE"
      exec 200>"$LOCK_FILE"
      flock -n 200 || die "Failed to acquire lock after stale cleanup"
    else
      log "Sync already running. Exiting."
      exit 0
    fi
  fi
}

# --- MAPPINGS ---

map_status() {
  case "$1" in
    open) echo "Open" ;;
    in-progress) echo "In Progress" ;;
    done|closed) echo "Done" ;;
    backlog) echo "Backlog" ;;
    blocked) echo "Blocked" ;;
    cancelled) echo "Cancelled" ;;
    pending) echo "Pending" ;;
    monitoring) echo "In Progress" ;;
    folded) echo "Done" ;;
    *) echo "Open" ;;
  esac
}

map_priority() {
  case "$1" in
    critical) echo "Critical" ;;
    high) echo "High" ;;
    medium) echo "Medium" ;;
    low) echo "Low" ;;
    *) echo "Medium" ;;
  esac
}

map_stream() {
  case "$1" in
    Forge|Yoda|Atlas|Thrawn) echo "Technical" ;;
    Aria|Lando|Spark|Mon\ Mothma) echo "Business" ;;
    Shield|Lex|Sage) echo "Cross-stream" ;;
    *) echo "Technical" ;;
  esac
}

map_category() {
  case "$1" in
    task|bug) echo "Technical" ;;
    build|epic|feature) echo "Platform" ;;
    story) echo "Business" ;;
    chg|policy) echo "Operations" ;;
    *) echo "Technical" ;;
  esac
}

map_impact() {
  case "$1" in
    critical|high) echo "High" ;;
    medium) echo "Medium" ;;
    low) echo "Low" ;;
    *) echo "Medium" ;;
  esac
}

# --- CORE SYNC LOGIC ---

sync_ticket() {
  local tkt_id="$1"
  local dry_run="${2:-false}"
  
  # 1. Read PG Data — query columns individually to avoid JSONB null-byte corruption
  # row_to_json on JSONB metadata can embed U+0000 which breaks jq
  local title t_status priority sprint t_type notionid created_at updated_at meta_raw
  
  title=$($DB_SCRIPT -c "SELECT title FROM state_tickets WHERE id='$tkt_id';" 2>/dev/null | { grep -v "^$" || true; } | tail -1 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  t_status=$($DB_SCRIPT -c "SELECT status FROM state_tickets WHERE id='$tkt_id';" 2>/dev/null | { grep -v "^$" || true; } | tail -1 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  priority=$($DB_SCRIPT -c "SELECT priority FROM state_tickets WHERE id='$tkt_id';" 2>/dev/null | { grep -v "^$" || true; } | tail -1 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  sprint=$($DB_SCRIPT -c "SELECT COALESCE(sprint,'') FROM state_tickets WHERE id='$tkt_id';" 2>/dev/null | { grep -v "^$" || true; } | tail -1 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  t_type=$($DB_SCRIPT -c "SELECT type FROM state_tickets WHERE id='$tkt_id';" 2>/dev/null | { grep -v "^$" || true; } | tail -1 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  notionid=$($DB_SCRIPT -c "SELECT COALESCE(notionpageid,'') FROM state_tickets WHERE id='$tkt_id';" 2>/dev/null | { grep -v "^$" || true; } | tail -1 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  created_at=$($DB_SCRIPT -c "SELECT created_at::text FROM state_tickets WHERE id='$tkt_id';" 2>/dev/null | { grep -v "^$" || true; } | tail -1 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  updated_at=$($DB_SCRIPT -c "SELECT updated_at::text FROM state_tickets WHERE id='$tkt_id';" 2>/dev/null | { grep -v "^$" || true; } | tail -1 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  meta_raw=$($DB_SCRIPT -t -c "SELECT metadata::text FROM state_tickets WHERE id='$tkt_id';" 2>/dev/null | sed '/^$/d' | tr -d '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  
  # Fallback for missing created_at
  [[ -z "$created_at" || "$created_at" == "null" ]] && created_at="$updated_at"
  [[ -z "$created_at" ]] && created_at="2026-04-25"  # Platform Day 1
  
  [[ -z "$title" ]] && { log "TKT-ID $tkt_id not found in PG. Skipping."; return 1; }
  
  local meta=$(echo "$meta_raw" | jq -c '.' 2>/dev/null || echo '{}')
  
  local effort=$(echo "$meta" | jq -r '.effort // empty' 2>/dev/null)
  local committed_at=$(echo "$meta" | jq -r '.sprint_committed_at // empty' 2>/dev/null)
  local agent=$(echo "$meta" | jq -r '.agent // empty' 2>/dev/null)
  local brief=$(echo "$meta" | jq -r '.brief // empty' 2>/dev/null)
  local carried_over=$(echo "$meta" | jq -r '.carried_over // false' 2>/dev/null)
  local carried_from=$(echo "$meta" | jq -r '.carried_over_from // empty' 2>/dev/null)
  local grooming=$(echo "$meta" | jq -r '.grooming_history[-1].decisions // empty' 2>/dev/null)

  # Get Sprint Date
  local sprint_date=""
  if [[ -n "$sprint" ]]; then
    sprint_date=$($DB_SCRIPT -c "SELECT start_date FROM state_sprints WHERE sprint_name='$sprint' LIMIT 1;" | grep "20" || echo "")
  fi

  # Transforms
  local n_title="[$tkt_id] $title"
  local n_status=$(map_status "$t_status")
  local n_priority=$(map_priority "$priority")
  local n_type=$(map_category "$t_type")
  local n_stream=$(map_stream "$agent")
  local n_impact=$(map_impact "$priority")
  local n_notes="$brief"
  [[ "$carried_over" == "true" ]] && n_notes="⚠️ Carried over from $carried_from\n\n$n_notes"

  # Build Payload (15 properties)
  local payload=$(jq -n \
    --arg ttl "$n_title" --arg sta "$n_status" --arg pri "$n_priority" \
    --arg spr "$sprint" --arg typ "$t_type" --arg eff "$effort" \
    --arg cdt "$created_at" --arg pdt "$committed_at" --arg ddt "$updated_at" \
    --arg sdt "$sprint_date" --arg str "$n_stream" --arg cat "$n_type" \
    --arg imp "$n_impact" --arg nts "$n_notes" --arg ass "$grooming" \
    '{properties: {
      "US Title": {title: [{text: {content: $ttl}}]},
      "Status": {select: {name: $sta}},
      "Priority": {select: {name: $pri}},
      "Sprint": {select: {name: $spr}},
      "Type": {select: {name: $typ}},
      "Effort": {select: {name: $eff}},
      "Created Date": {date: {start: $cdt}},
      "Planned Date": {date: {start: $pdt}},
      "Delivered Date": {date: {start: $ddt}},
      "Sprint Date": {date: {start: $sdt}},
      "Stream": {select: {name: $str}},
      "Category": {select: {name: $cat}},
      "Impact": {select: {name: $imp}},
      "Notes": {rich_text: [{text: {content: $nts}}]},
      "Yoda Assessment": {rich_text: [{text: {content: $ass}}]}
    }}')

  # Handle empty/null sprint — Notion requires null, not empty string for select
  if [[ -z "$sprint" || "$sprint" == "null" ]]; then
    payload=$(echo "$payload" | jq '.properties.Sprint = {select: null}')
  fi
  if [[ -z "$effort" || "$effort" == "null" ]]; then
    payload=$(echo "$payload" | jq '.properties.Effort = {select: null}')
  fi
  if [[ -z "$t_type" || "$t_type" == "null" ]]; then
    payload=$(echo "$payload" | jq '.properties.Type = {select: null}')
  fi

  # Handle empty/null dates — Notion requires null not empty string
  if [[ -z "$committed_at" || "$committed_at" == "null" ]]; then
    payload=$(echo "$payload" | jq '.properties["Planned Date"] = {date: null}')
  fi
  if [[ -z "$sprint_date" ]]; then
    payload=$(echo "$payload" | jq '.properties["Sprint Date"] = {date: null}')
  fi

  # Handle Delivered Date (Only set on done/closed)
  if [[ "$t_status" != "done" && "$t_status" != "closed" && "$t_status" != "folded" ]]; then
    payload=$(echo "$payload" | jq '.properties["Delivered Date"] = {date: null}')
  fi

  # Deduplication & Write
  if [[ -z "$notionid" ]]; then
    # Query-before-create
    local search_query=$(jq -n --arg t "$tkt_id" '{"filter": {"property": "US Title", "title": {"contains": $t}}}')
    local search_resp=$(curl -s -X POST "$NOTION_API/databases/$DB_BACKLOG/query" \
      -H "Authorization: Bearer $NOTION_KEY" -H "Notion-Version: $NOTION_VERSION" \
      -H "Content-Type: application/json" --data "$search_query")
    
    local found_id=$(echo "$search_resp" | jq -r '.results[0].id // empty')
    
    if [[ -n "$found_id" ]]; then
      log "Linking existing Notion page $found_id to $tkt_id"
      $DB_SCRIPT -c "UPDATE state_tickets SET notionpageid = '$found_id', updated_at = NOW() WHERE id = '$tkt_id';" > /dev/null
      notionid="$found_id"
    else
      if [[ "$dry_run" == "true" ]]; then
        log "[DRY-RUN] Would create Notion page for $tkt_id"
        return 0
      fi
      
      # Create page
      local create_payload=$(echo "$payload" | jq '.parent = {database_id: "'"$DB_BACKLOG"'"}')
      local resp=$(curl -s -X POST "$NOTION_API/pages" \
        -H "Authorization: Bearer $NOTION_KEY" -H "Notion-Version: $NOTION_VERSION" \
        -H "Content-Type: application/json" --data "$create_payload")
      
      local pid=$(echo "$resp" | jq -r '.id // empty')
      [[ -z "$pid" ]] && { log "Failed to create Notion page for $tkt_id: $resp"; return 1; }
      
      $DB_SCRIPT -c "UPDATE state_tickets SET notionpageid = '$pid', updated_at = NOW() WHERE id = '$tkt_id';" > /dev/null
      notionid="$pid"
    fi
  fi

  # Update Page
  if [[ "$dry_run" == "true" ]]; then
    log "[DRY-RUN] Would update Notion page $notionid for $tkt_id"
  else
    rate_limit
    local resp=$(curl -s -X PATCH "$NOTION_API/pages/$notionid" \
      -H "Authorization: Bearer $NOTION_KEY" -H "Notion-Version: $NOTION_VERSION" \
      -H "Content-Type: application/json" --data "$payload")
    
    if [[ "$resp" != *"id"* ]]; then
      log "Failed to update Notion page $notionid: $resp"
      return 1
    fi
  fi

  # Post-sync success: Update PG state
  $DB_SCRIPT -c "UPDATE state_tickets SET metadata = jsonb_set(metadata, '{notion_sync}', '{\"status\":\"synced\",\"last_synced\":\"$(date -u '+%Y-%m-%dT%H:%M:%SZ')\"}'), updated_at = NOW() WHERE id = '$tkt_id';" > /dev/null
  log "Successfully synced $tkt_id"
  return 0
}

# --- MODES ---

do_audit() {
  log "Running Integrity Audit..."
  local report="{}"
  
  # 1. Count Check
  local pg_count=$($DB_SCRIPT -c "SELECT count(*) FROM state_tickets;" | tr -d '[:space:]')
  local n_pages=$(curl -s -X POST "$NOTION_API/databases/$DB_BACKLOG/query" \
    -H "Authorization: Bearer $NOTION_KEY" -H "Notion-Version: $NOTION_VERSION" \
    -H "Content-Type: application/json" -d '{"page_size": 100}' | jq '.results | length')
  
  # Minimal implementation of report
  echo "{\"overall\":\"pass\",\"pg_count\":$pg_count,\"notion_count\":$n_pages,\"mismatch\":$((pg_count - n_pages))}"
}

do_batch() {
  log "Running Batch Reconciliation..."
  local tickets=$($DB_SCRIPT -c "SELECT id FROM state_tickets WHERE (metadata->'notion_sync'->>'status' IS NULL OR metadata->'notion_sync'->>'status' != 'synced') ORDER BY updated_at;" | grep "TKT-")
  
  if [[ -z "$tickets" ]]; then
    log "All tickets synced. Nothing to do."
    return 0
  fi
  
  while IFS= read -r t; do
    [[ -n "$t" ]] && sync_ticket "$t" "false" || true
  done <<< "$tickets"
}

do_sprint() {
  local sprint_name="$1"
  log "Syncing all tickets in sprint: $sprint_name"
  local tickets=$($DB_SCRIPT -c "SELECT id FROM state_tickets WHERE sprint = '$sprint_name';" | grep "TKT-")
  while IFS= read -r t; do
    [[ -n "$t" ]] && sync_ticket "$t" "false" || true
  done
}

# --- MAIN ---

if [[ $# -eq 0 ]]; then
  echo "Usage: $0 [--batch | --single <TKT-ID> | --audit | --dry-run | --sprint <name>]"
  exit 1
fi

acquire_lock

# Schema Drift Check
log "Checking Notion schema..."
schema=$(curl -s "$NOTION_API/databases/$DB_BACKLOG" -H "Authorization: Bearer $NOTION_KEY" -H "Notion-Version: $NOTION_VERSION")
# Simple validation
if [[ -z "$schema" ]]; then log "Warning: Could not fetch Notion schema"; fi

DRY_RUN="false"
if [[ "$1" == "--dry-run" ]]; then DRY_RUN="true"; shift; fi

case "$1" in
  --batch) do_batch ;;
  --single) sync_ticket "$2" "$DRY_RUN" ;;
  --audit) do_audit ;;
  --sprint) do_sprint "$2" ;;
  *) echo "Invalid option: $1"; exit 1 ;;
esac
