#!/bin/zsh
# notion-create-missing.sh — Create Notion pages for PG tickets without notionpageid
# TKT-0392-C: 29 tickets missing in Notion
#
# Uses JSON output from PG to avoid pipe-delimiter issues with titles containing pipes

set -u

# --- SKILL GATE: notion ---
source "${SCRIPT_DIR:-$(dirname "$0")}/skill-gate.sh" "notion" || exit $?

WORKSPACE_ROOT="/Users/ainchorsoc2a/.openclaw/workspace"
DB_SCRIPT="$WORKSPACE_ROOT/scripts/db.sh"
NOTION_KEY_FILE="$HOME/.config/notion/api_key"
DB_BACKLOG="34dc1829-53ff-814b-8257-d3a3bf351d44"

NOTION_API="https://api.notion.com/v1"
NOTION_VERSION="2022-06-28"
RATE_LIMIT_SEC=0.35  # ~3 req/sec

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"; }

[[ ! -f "$NOTION_KEY_FILE" ]] && { echo "Notion API key missing at $NOTION_KEY_FILE"; exit 1; }
NOTION_KEY=$(cat "$NOTION_KEY_FILE")

# Map PG status -> Notion status
map_status() {
  case "$1" in
    open|pending)      echo "Backlog" ;;
    in-progress)       echo "In Progress" ;;
    done|closed|resolved) echo "Done" ;;
    cancelled)         echo "Deferred" ;;
    Grooming)          echo "Backlog" ;;
    *)                 echo "Backlog" ;;
  esac
}

# Map PG priority -> Notion priority (case-insensitive)
map_priority() {
  local p=$(echo "$1" | tr '[:upper:]' '[:lower:]')
  case "$p" in
    critical) echo "Critical" ;;
    high)     echo "High" ;;
    medium)   echo "Medium" ;;
    low)      echo "Low" ;;
    p1)       echo "Critical" ;;
    p2)       echo "P2" ;;
    p3)       echo "P3" ;;
    *)        echo "Medium" ;;
  esac
}

# Determine Notion Type based on ID
map_type() {
  case "$1" in
    task)     echo "task" ;;
    CHG*)     echo "CHG" ;;
    TKT*)     echo "TKT" ;;
    US*)      echo "US" ;;
    *)        echo "TKT" ;;
  esac
}

# Build display title: "[ID] Title" or "[] Title" for blank IDs
build_title() {
  local id="$1"
  local title="$2"
  if [[ -n "$id" ]]; then
    echo "[$id] $title"
  else
    echo "[] $title"
  fi
}

CREATED=0
FAILED=0

log "=== TKT-0392-C: Creating missing Notion pages ==="

# Query PG as JSON array — single call, no pipe issues
RAW_JSON=$(bash "$DB_SCRIPT" -c "SELECT json_agg(json_build_object('id', id, 'title', title, 'status', status, 'priority', priority) ORDER BY id) FROM state_tickets WHERE (notionpageid IS NULL OR notionpageid = '');" 2>/dev/null)

# Extract the JSON array from PG output (it's the only line with [ )
TICKETS_JSON=$(echo "$RAW_JSON" | grep -E '^\s*\[' | head -1)
if [[ -z "$TICKETS_JSON" ]]; then
  log "No tickets JSON returned. Aborting."
  echo "$RAW_JSON" | head -5
  exit 1
fi

COUNT=$(echo "$TICKETS_JSON" | jq length)
log "Found $COUNT tickets to create in Notion."

# Track which IDs were updated (for verification)
UPDATED_IDS=""

for idx in $(seq 0 $((COUNT - 1))); do
  id=$(echo "$TICKETS_JSON" | jq -r ".[$idx].id")
  title=$(echo "$TICKETS_JSON" | jq -r ".[$idx].title")
  t_status=$(echo "$TICKETS_JSON" | jq -r ".[$idx].status")
  priority=$(echo "$TICKETS_JSON" | jq -r ".[$idx].priority")
  
  [[ -z "$title" ]] && { log "Skipping index $idx: empty title"; continue; }
  
  n_status=$(map_status "$t_status")
  n_priority=$(map_priority "$priority")
  n_type=$(map_type "$id")
  n_title=$(build_title "$id" "$title")
  
  log "[$((idx+1))/$COUNT] Creating: $n_title"
  
  payload=$(jq -n \
    --arg db "$DB_BACKLOG" \
    --arg ttl "$n_title" \
    --arg sta "$n_status" \
    --arg pri "$n_priority" \
    --arg typ "$n_type" \
    '{parent: {database_id: $db}, properties: {"US Title": {title: [{text: {content: $ttl}}]}, "Status": {select: {name: $sta}}, "Type": {select: {name: $typ}}, "Priority": {select: {name: $pri}}}}')
  
  resp=$(curl -s -X POST "$NOTION_API/pages" \
    -H "Authorization: Bearer $NOTION_KEY" \
    -H "Notion-Version: $NOTION_VERSION" \
    -H "Content-Type: application/json" \
    --data "$payload")
  
  page_id=$(echo "$resp" | jq -r '.id // empty')
  
  if [[ -n "$page_id" && "$page_id" != "null" ]]; then
    # Escape single quotes for PG
    esc_id=$(echo "$id" | sed "s/'/''/g")
    esc_pid=$(echo "$page_id" | sed "s/'/''/g")
    
    if [[ -n "$id" ]]; then
      bash "$DB_SCRIPT" -c "UPDATE state_tickets SET notionpageid = '$esc_pid', updated_at = NOW() WHERE id = '$esc_id';" > /dev/null 2>&1
    else
      # Empty ID — match by title
      esc_title=$(echo "$title" | sed "s/'/''/g")
      bash "$DB_SCRIPT" -c "UPDATE state_tickets SET notionpageid = '$esc_pid', updated_at = NOW() WHERE (id IS NULL OR id = '') AND title = '$esc_title';" > /dev/null 2>&1
    fi
    
    log "  ✓ Created: $page_id (PG backfilled)"
    UPDATED_IDS="${UPDATED_IDS}${id}|"
    ((CREATED++))
  else
    err_msg=$(echo "$resp" | jq -c '.message // .' | tr -d '\n')
    log "  ✗ FAILED: $err_msg"
    ((FAILED++))
  fi
  
  sleep "$RATE_LIMIT_SEC"
done

log "=== RESULTS ==="
log "Created: $CREATED"
log "Failed:  $FAILED"
echo "Created: $CREATED | Failed: $FAILED"