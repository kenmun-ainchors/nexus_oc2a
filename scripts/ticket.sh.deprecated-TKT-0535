#!/bin/zsh
# ticket.sh — Unified Ticket Management (PG SSOT)
# TKT-0297 IMPLEMENTATION

set -u

WORKSPACE_ROOT="/Users/ainchorsangiefpl/.openclaw/workspace"
TICKET_FILE="$WORKSPACE_ROOT/state/tickets.json"
DB_READ_SCRIPT="$WORKSPACE_ROOT/scripts/db-read.sh"
DB_WRITE_SCRIPT="$WORKSPACE_ROOT/scripts/db-write.sh"
SYNC_SCRIPT="$WORKSPACE_ROOT/scripts/pg-to-notion-sync.sh"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"; }

# -----------------------------------------------------------------------------
# READ PATH (Atom 2: PG PRIMARY, JSON FALLBACK)
# -----------------------------------------------------------------------------

fetch_pg_data() {
  local query="$1"
  local raw=$(/Users/ainchorsangiefpl/.openclaw/workspace/scripts/db.sh -c "$query")
  echo "$raw" | grep "TKT-" || true
}

get_ticket() {
  local tkt_id="$1"
  local data
  
  data=$(fetch_pg_data "SELECT id, title, status, priority, notionpageid, updated_at FROM state_tickets WHERE id = '$tkt_id';")
  
  if [[ -z "$data" && -f "$TICKET_FILE" ]]; then
    data=$(jq -r --arg id "$tkt_id" '.[] | select(.id == $id) | "\(.id)|\(.title)|\(.status)|\(.priority)|\(.notionpageid)|\(.updated_at)"' "$TICKET_FILE" 2>/dev/null)
  fi

  if [[ -z "$data" ]]; then
    return 1
  fi
  echo "$data"
}

# -----------------------------------------------------------------------------
# WRITE PATH (Atom 4: Trigger sync after PG write)
# -----------------------------------------------------------------------------

write_ticket() {
  local tkt_id="$1"
  local payload="$2"

  # Validate payload is valid JSON before writing
  if ! echo "$payload" | /opt/homebrew/bin/jq empty 2>/dev/null; then
    log "ERROR: Invalid JSON payload. Use: ticket.sh update <TKT-ID> '{\"field\":\"value\"}'"
    return 1
  fi

  $DB_WRITE_SCRIPT state_tickets "$payload" "$tkt_id" > /dev/null
  
  if [[ -f "$TICKET_FILE" ]]; then
    tmp_json=$(mktemp)
    if [[ -s "$TICKET_FILE" ]]; then
        current_content=$(cat "$TICKET_FILE")
        if [[ "$current_content" != "["* ]]; then
           echo "[$current_content]" > "$TICKET_FILE"
        fi
    fi
    jq --arg id "$tkt_id" --argjson patch "$payload" \
       'map(if .id == $id then . + $patch else . end)' "$TICKET_FILE" > "$tmp_json" && mv "$tmp_json" "$TICKET_FILE"
  fi
  
  log "Triggering Notion sync for $tkt_id..."
  $SYNC_SCRIPT > /dev/null 2>&1 &
  
  log "Ticket $tkt_id updated and sync triggered."
}

# -----------------------------------------------------------------------------
# CLI INTERFACE
# -----------------------------------------------------------------------------

case "${1:-}" in
  list)
    log "Listing tickets from PG..."
    fetch_pg_data "SELECT id, title, status FROM state_tickets ORDER BY id ASC;"
    ;;
  show)
    [[ -z "${2:-}" ]] && { echo "Usage: ticket.sh show <TKT-ID>"; exit 1; }
    data=$(get_ticket "$2")
    if [[ $? -eq 0 ]]; then
      echo "$data"
    else
      log "Ticket $2 not found."
      exit 1
    fi
    ;;
  update)
    [[ -z "${2:-}" || -z "${3:-}" ]] && { echo "Usage: ticket.sh update <TKT-ID> '<JSON-PAYLOAD>'"; exit 1; }
    write_ticket "$2" "$3"
    ;;
  close)
    [[ -z "${2:-}" ]] && { echo "Usage: ticket.sh close <TKT-ID>"; exit 1; }
    write_ticket "$2" '{"status": "closed"}'
    ;;
  create)
    # TKT-0313: Safe create — prevents overwriting existing tickets
    [[ -z "${2:-}" || -z "${3:-}" ]] && { echo "Usage: ticket.sh create <TKT-ID> <TITLE> [PRIORITY] [TYPE]"; exit 1; }
    TKT_ID="$2"
    TKT_TITLE="$3"
    TKT_PRIORITY="${4:-medium}"
    TKT_TYPE="${5:-task}"
    TKT_TS=$(date -u '+%Y-%m-%dT%H:%M:%S+10:00')
    log "Creating $TKT_ID: $TKT_TITLE"
    DBWRITE_SAFE_MODE=1 $DB_WRITE_SCRIPT state_tickets "{\"id\":\"$TKT_ID\",\"title\":\"$TKT_TITLE\",\"status\":\"open\",\"priority\":\"$TKT_PRIORITY\",\"type\":\"$TKT_TYPE\",\"created_at\":\"$TKT_TS\",\"notionSynced\":false}" "$TKT_ID"
    RET=$?
    if [ $RET -eq 3 ]; then
      log "COLLISION: $TKT_ID already exists. Use ticket.sh update instead."
      exit 3
    elif [ $RET -eq 0 ]; then
      $SYNC_SCRIPT > /dev/null 2>&1 &
      log "$TKT_ID created and sync triggered."
    fi
    ;;
  sync)
    log "Manual sync trigger..."
    $SYNC_SCRIPT
    ;;
  *)
    echo "Usage: ticket.sh {list|show|update|close|create|sync}"
    exit 1
    ;;
esac
