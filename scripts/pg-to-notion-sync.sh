#!/bin/zsh
# pg-to-notion-sync.sh — Idempotent Sync from Postgres (SSOT) to Notion Backlog
# TKT-0297 IMPLEMENTATION

set -u

# --- CONFIGURATION ---
WORKSPACE_ROOT="/Users/ainchorsangiefpl/.openclaw/workspace"
DB_READ_SCRIPT="$WORKSPACE_ROOT/scripts/db-read.sh"
DB_WRITE_SCRIPT="$WORKSPACE_ROOT/scripts/db-write.sh"
NOTION_KEY_FILE="$HOME/.config/notion/api_key"
LOCK_FILE="/tmp/pg-notion-sync.lock"

# Database IDs
DB_BACKLOG="34dc1829-53ff-814b-8257-d3a3bf351d44"
DB_ARCHIVE="364c1829-53ff-818e-a783-ebafcb6a9880"

# Notion API Base
NOTION_API="https://api.notion.com/v1"
NOTION_VERSION="2022-06-28"

# --- UTILITIES ---
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"; }

die() { echo "CRITICAL ERROR: $1" >&2; exit 1; }

# File lock to prevent concurrent runs
if ! command -v flock >/dev/null; then
  log "flock not found, skipping lock"
else
  exec 200>"$LOCK_FILE"
  if ! flock -n 200; then
    log "Sync already running. Exiting."
    exit 0
  fi
fi

# Load Notion Key
[[ ! -f "$NOTION_KEY_FILE" ]] && die "Notion API key missing at $NOTION_KEY_FILE"
NOTION_KEY=$(cat "$NOTION_KEY_FILE")

# Map PG status to Notion status
map_status() {
  case "$1" in
    open|pending) echo "Backlog" ;;
    in-progress) echo "In Progress" ;;
    done|resolved|closed) echo "Done" ;;
    cancelled) echo "Deferred" ;;
    *) echo "Backlog" ;;
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

# --- SYNC LOGIC ---

TIMESTAMP_FILE="$WORKSPACE_ROOT/state/pg-notion-last-sync.txt"
LAST_SYNC=$(cat "$TIMESTAMP_FILE" 2>/dev/null || echo "1970-01-01T00:00:00Z")
CURRENT_SYNC=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

log "Starting sync. Last sync: $LAST_SYNC"

# Use db.sh for consistent output
PG_DATA=$(/Users/ainchorsangiefpl/.openclaw/workspace/scripts/db.sh -c "SELECT id, title, status, priority, notionpageid, updated_at FROM state_tickets WHERE updated_at > '$LAST_SYNC';" | grep "TKT-")

if [[ -z "$PG_DATA" ]]; then
  log "No updates found in PG. Nothing to sync."
  echo "$CURRENT_SYNC" > "$TIMESTAMP_FILE"
  exit 0
fi

CREATED=0
UPDATED=0
ARCHIVED=0

while IFS='|' read -r id title t_status priority notionid updated_at; do
  [[ -z "$id" ]] && continue
  
  n_status=$(map_status "$t_status")
  n_priority=$(map_priority "$priority")
  n_title="[$id] $title"
  
  if [[ -z "$notionid" || "$notionid" == "null" ]]; then
    payload=$(jq -n \
      --arg db "$DB_BACKLOG" \
      --arg ttl "$n_title" \
      --arg sta "$n_status" \
      --arg pri "$n_priority" \
      --arg typ "TKT" \
      '{parent: {database_id: $db}, properties: {"US Title": {title: [{text: {content: $ttl}}]}, "Status": {select: {name: $sta}}, "Type": {select: {name: $typ}}, "Priority": {select: {name: $pri}}}}')
    
    resp=$(curl -s -X POST "$NOTION_API/pages" \
      -H "Authorization: Bearer $NOTION_KEY" \
      -H "Notion-Version: $NOTION_VERSION" \
      -H "Content-Type: application/json" \
      --data "$payload")
    
    page_id=$(echo "$resp" | jq -r '.id // empty')
    
    if [[ -n "$page_id" ]]; then
      $DB_WRITE_SCRIPT state_tickets "{\"notionpageid\":\"$page_id\"}" "$id" > /dev/null
      log "Created Notion page for $id: $page_id"
      ((CREATED++))
    else
      log "Failed to create Notion page for $id: $resp"
    fi
  else
    payload=$(jq -n \
      --arg sta "$n_status" \
      --arg pri "$n_priority" \
      --arg ttl "$n_title" \
      '{properties: {"Status": {select: {name: $sta}}, "Priority": {select: {name: $pri}}, "US Title": {title: [{text: {content: $ttl}}]}}}')
    
    resp=$(curl -s -X PATCH "$NOTION_API/pages/$notionid" \
      -H "Authorization: Bearer $NOTION_KEY" \
      -H "Notion-Version: $NOTION_VERSION" \
      -H "Content-Type: application/json" \
      --data "$payload")
    
    if [[ "$resp" == *"id"* ]]; then
      log "Updated Notion page for $id"
      ((UPDATED++))
    else
      log "Failed to update Notion page for $id: $resp"
    fi
  fi
done <<< "$PG_DATA"

log "Checking for orphans..."
ALL_PG_IDS=$(/Users/ainchorsangiefpl/.openclaw/workspace/scripts/db.sh -c "SELECT id FROM state_tickets;" | grep "TKT-" | tr '\n' ' ')

NOTION_PAGES=$(curl -s -X POST "$NOTION_API/databases/$DB_BACKLOG/query" \
  -H "Authorization: Bearer $NOTION_KEY" \
  -H "Notion-Version: $NOTION_VERSION" \
  -H "Content-Type: application/json")

echo "$NOTION_PAGES" | jq -r '.results[] | "\(.id)|\(.properties["US Title"].title[0].plain_text // "")"' | while IFS='|' read -r pid ptitle; do
  [[ -z "$pid" ]] && continue
  tkt_id=$(echo "$ptitle" | grep -o "TKT-[0-9]\{4\}")
  if [[ -z "$tkt_id" || ! " $ALL_PG_IDS " =~ " $tkt_id " ]]; then
    log "Orphan detected: $pid ($ptitle). Archiving..."
    archive_payload=$(jq -n \
      --arg db "$DB_ARCHIVE" \
      --arg ttl "$ptitle" \
      '{parent: {database_id: $db}, properties: {"US Title": {title: [{text: {content: $ttl}}]}, "Status": {select: {name: "Archived"}}, "Type": {select: {name: "TKT"}}, "Priority": {select: {name: "Medium"}}}}')
    curl -s -X POST "$NOTION_API/pages" \
      -H "Authorization: Bearer $NOTION_KEY" \
      -H "Notion-Version: $NOTION_VERSION" \
      -H "Content-Type: application/json" \
      --data "$archive_payload" > /dev/null
    curl -s -X PATCH "$NOTION_API/pages/$pid" \
      -H "Authorization: Bearer $NOTION_KEY" \
      -H "Not la-Version: $NOTION_VERSION" \
      -H "Content-Type: application/json" \
      -d '{"archived": true}' > /dev/null
    ((ARCHIVED++))
  fi
done

echo "$CURRENT_SYNC" > "$TIMESTAMP_FILE"
log "Sync Complete. Created: $CREATED, Updated: $UPDATED, Archived: $ARCHIVED"
echo "Created $CREATED, Updated $UPDATED, Archived $ARCHIVED"
