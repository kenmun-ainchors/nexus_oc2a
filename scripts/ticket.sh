#!/bin/zsh
# AInchors Ticket System — TKT-NNNN
# Every ad-hoc request or action without an INC/US/CHG reference MUST have a TKT first.
# Notion AKB Backlog is the single source of truth — every new/update/close syncs automatically.
#
# Usage:
#   ticket.sh new --title "Title" --type TYPE --priority PRIORITY [--description "..."] [--requester "..."]
#   ticket.sh list [--status STATUS] [--priority PRIORITY]
#   ticket.sh show TKT-NNNN
#   ticket.sh update TKT-NNNN --status STATUS [--notes "..."] [--resolution "..."]
#   ticket.sh link TKT-NNNN --us US-NN | --inc INC-ID | --chg CHG-ID
#   ticket.sh close TKT-NNNN --resolution "..."
#   ticket.sh notion-sync TKT-NNNN
#
# Types:    request | task | incident | question | bug | change
# Priority: critical | high | medium | low
# Status:   open | in-progress | pending | resolved | closed | cancelled

set -u

TICKET_FILE="/Users/ainchorsangiefpl/.openclaw/workspace/state/tickets.json"
CHANGELOG_HELPER="/Users/ainchorsangiefpl/.openclaw/workspace/scripts/changelog-append.sh"
NOTION_DB_BACKLOG="34dc1829-53ff-814b-8257-d3a3bf351d44"
NOTION_DB_AUTOHEAL="364c1829-53ff-81c0-9dbd-ff2c907d1a6b"
NOTION_DB_ARCHIVE="364c1829-53ff-818e-a783-ebafcb6a9880"
NOTION_DB_ID="$NOTION_DB_BACKLOG"
NOTION_KEY_FILE="$HOME/.config/notion/api_key"

die() { echo "ERROR: $1" >&2; exit 1; }

# ──────────────────────────────────────────
# STATE CHECKING PATTERN (TKT-0182)
# ──────────────────────────────────────────
get_ticket_state() {
  local tkt_id="$1"
  local status
  status=$(psql -At -c "SELECT status FROM state_tickets WHERE id = '$tkt_id';" 2>/dev/null || \
           jq -r --arg id "$tkt_id" '.tickets[] | select(.id == $id) | .status' "$TICKET_FILE" 2>/dev/null)
  echo "$status"
}

validate_transition() {
  local current="$1"
  local target="$2"
  [[ -z "$current" || "$current" == "null" ]] && return 0
  if [[ "$current" == "closed" || "$current" == "cancelled" ]]; then
    echo "INVALID TRANSITION: Cannot move from $current to $target. Ticket is terminal." >&2
    return 1
  fi
  return 0
}

verify_state_update() {
  local tkt_id="$1" expected_status="$2"
  local actual
  actual=$(get_ticket_state "$tkt_id")
  if [[ "$actual" != "$expected_status" ]]; then
    echo "VERIFICATION FAILED: Expected $expected_status but found $actual for $tkt_id" >&2
    return 1
  fi
  return 0
}

atomic_write() {
  local file="$1"
  local content="$2"
  local tmp_file="${file}.tmp.$RANDOM"
  local bak_file="${file}.bak-$(date +%Y%m%d%H%M%S)"
  [[ -z "${content// }" ]] && { echo "CRITICAL: atomic_write blocked empty content for $file — ABORTED" >&2; return 1; }
  if [[ -f "$file" ]]; then cp "$file" "$bak_file" 2>/dev/null || true; fi
  if [[ "$file" == *.json ]]; then
    printf '%s' "$content" > "$tmp_file"
    /opt/homebrew/bin/jq . "$tmp_file" > /dev/null 2>&1 || { echo "CRITICAL: atomic_write blocked invalid JSON for $file — ABORTED" >&2; rm -f "$tmp_file"; return 1; }
  fi
  printf '%s' "$content" > "$tmp_file" 2>/dev/null || return 1
  [[ ! -s "$tmp_file" ]] && return 1
  mv "$tmp_file" "$file" || return 1
  return 0
}

SPRINT_FILE="/Users/ainchorsangiefpl/.openclaw/workspace/state/sprint-current.json"
sprint_sync() {
  local tkt_id="$1" new_status="$2"
  [[ ! -f "$SPRINT_FILE" ]] && return 0
  local in_sprint=$(jq -r --arg id "$tkt_id" '.items[] | select(.tkt == $id) | .tkt' "$SPRINT_FILE" 2>/dev/null)
  [[ -z "$in_sprint" ]] && return 0
  local now_local=$(date '+%Y-%m-%dT%H:%M:%S+10:00')
  local sprint_status="$new_status"
  case "$new_status" in closed|resolved) sprint_status="done" ;; esac
  local tmp=$(jq --arg id "$tkt_id" --arg st "$sprint_status" --arg ts "$now_local" '(.items[] | select(.tkt == $id)) |= (.status = $st | if $st == "done" then .completedAt = $ts else . end) | .velocity.done = ([.items[] | select(.status == "done")] | length) | .velocity.inProgress = ([.items[] | select(.status == "in-progress")] | length) | .velocity.pending = ([.items[] | select(.status == "pending")] | length) | .velocity.lastUpdated = $ts' "$SPRINT_FILE")
  atomic_write "$SPRINT_FILE" "$tmp"
}

notion_status() {
  case "$1" in open|pending) echo "Backlog" ;; in-progress) echo "In Progress" ;; done|resolved|closed) echo "Done" ;; cancelled) echo "Deferred" ;; *) echo "Backlog" ;; esac
}

notion_priority() {
  case "$1" in critical) echo "Critical" ;; high) echo "High" ;; medium) echo "Medium" ;; low) echo "Low" ;; *) echo "Medium" ;; esac
}

notion_create_ticket() {
  sleep 0.4
  local tkt_id="$1" title="$2" tkt_status="$3" priority="$4" created_date="$5" notes="${6:-}" sprint="${7:-}" planned_date="${8:-}" delivered_date="${9:-}"
  [[ ! -f "$NOTION_KEY_FILE" ]] && echo "NOTION_SKIP" && return
  local key; key=$(cat "$NOTION_KEY_FILE")
  local n_status; n_status=$(notion_status "$tkt_status")
  local n_priority; n_priority=$(notion_priority "$priority")
  local n_title="[${tkt_id}] ${title}"
  notes="${notes:0:2000}"
  local existing_page_id=$(curl -s -X POST "https://api.notion.com/v1/search" -H "Authorization: Bearer $key" -H "Notion-Version: 2025-09-03" -H "Content-Type: application/json" -d "{\"query\": \"[${tkt_id}]\", \"page_size\": 5}" 2>/dev/null | jq -r '.results[0].id // ""' 2>/dev/null)
  if [[ -n "$existing_page_id" && "$existing_page_id" != "null" && "$existing_page_id" != "" ]]; then echo "$existing_page_id"; return 0; fi
  local payload=$(jq -n --arg db "$NOTION_DB_ID" --arg ttl "$n_title" --arg sta "$n_status" --arg pri "$n_priority" --arg cdt "$created_date" --arg nts "$notes" --arg spr "$sprint" --arg pdt "$planned_date" --arg ddt "$delivered_date" '{parent: {database_id: $db}, properties: {"US Title": {title: [{text: {content: $ttl}}]}, "Status": {select: {name: $sta}}, "Type": {select: {name: "TKT"}}, "Priority": {select: {name: $pri}}, "Created Date": {date: {start: $cdt}}, "Notes": {rich_text: (if $nts != "" then [{text: {content: $nts}}] else [] end)}, "Sprint": (if $spr != "" then {select: {name: $spr}} else {select: null} end), "Planned Date": (if $pdt != "" then {date: {start: $pdt}} else {date: null} end), "Delivered Date": (if $ddt != "" then {date: {start: $ddt}} else {date: null} end)}}' 2>/dev/null)
  [[ -z "$payload" ]] && echo "NOTION_SKIP" && return
  local resp=$(curl -s -X POST "https://api.notion.com/v1/pages" -H "Authorization: Bearer $key" -H "Notion-Version: 2025-09-03" -H "Content-Type: application/json" --data "$payload" 2>/dev/null)
  local page_id=$(echo "$resp" | jq -r '.id // ""' 2>/dev/null)
  [[ -n "$page_id" && "$page_id" != "null" && "$page_id" != "" ]] && echo "$page_id" || echo "NOTION_SKIP"
}

notion_update_ticket() {
  local page_id="$1" tkt_status="$2" priority="$3" notes="${4:-}" sprint="${5:-}" planned_date="${6:-}" delivered_date="${7:-}" stream="${8:-}" tkt_type="${9:-}" tkt_id="${10:-}"
  [[ -z "$page_id" || "$page_id" == "null" || "$page_id" == "NOTION_SKIP" ]] && return
  [[ ! -f "$NOTION_KEY_FILE" ]] && return
  local key; key=$(cat "$NOTION_KEY_FILE")
  local n_status; n_status=$(notion_status "$tkt_status")
  local n_priority; n_priority=$(notion_priority "$priority")
  notes="${notes:0:2000}"
  # Build title: [TKT-XXXX] original_title (strip existing prefix if present)
  local display_title="${tkt_id:+[$tkt_id] }${notes:0:120}"
  local payload=$(/usr/bin/python3 -c "
import json, sys
sta=sys.argv[1]; pri=sys.argv[2]; nts=sys.argv[3]; spr=sys.argv[4]; pdt=sys.argv[5]; ddt=sys.argv[6]; stm=sys.argv[7] if len(sys.argv)>7 else ''; typ=sys.argv[8] if len(sys.argv)>8 else ''; ttl=sys.argv[9] if len(sys.argv)>9 else ''
props = {'Status': {'select': {'name': sta}}, 'Priority': {'select': {'name': pri}}, 'Notes': {'rich_text': [{'text': {'content': nts}}] if nts else []}}
if ttl: props['US Title'] = {'title': [{'text': {'content': ttl}}]}
if spr: props['Sprint'] = {'select': {'name': spr}}
if pdt: props['Planned Date'] = {'date': {'start': pdt}}
if ddt: props['Delivered Date'] = {'date': {'start': ddt}}
if stm: props['Stream'] = {'select': {'name': stm}}
if typ: props['Type'] = {'select': {'name': typ.upper()}}
print(json.dumps({'properties': props}))" "$n_status" "$n_priority" "$notes" "$sprint" "$planned_date" "$delivered_date" "$stream" "$tkt_type" "$display_title" 2>/dev/null)
  curl -s -X PATCH "https://api.notion.com/v1/pages/${page_id}" -H "Authorization: Bearer $key" -H "Notion-Version: 2025-09-03" -H "Content-Type: application/json" --data "$payload" > /dev/null 2>&1 || true
}

notion_close_ticket() {
  local page_id="$1" delivered_date="${2:-}"
  local tkt_id="${3:-}" resolution="${4:-}" priority="${5:-}" tkt_type="${6:-}"
  [[ -z "$page_id" || "$page_id" == "null" || "$page_id" == "NOTION_SKIP" ]] && return
  [[ ! -f "$NOTION_KEY_FILE" ]] && return
  local key; key=$(cat "$NOTION_KEY_FILE")
  
  # Step 1: Mark Done in DB A
  local payload=$(jq -n --arg ddt "$delivered_date" '{"properties": {"Status": {"select": {"name": "Done"}}, "Delivered Date": (if $ddt != "" then {"date": {"start": $ddt}} else {} end)}}')
  curl -s -X PATCH "https://api.notion.com/v1/pages/${page_id}" -H "Authorization: Bearer $key" -H "Notion-Version: 2025-09-03" -H "Content-Type: application/json" --data "$payload" > /dev/null 2>&1 || true
  
  # Step 2: Copy to DB C (Archive) — CHG-0402 (best-effort, DB C schema may need setup)
  if [[ -n "$NOTION_DB_ARCHIVE" && "$NOTION_DB_ARCHIVE" != "null" ]]; then
    local n_title="[${tkt_id}] ${resolution:0:80}"
    local n_priority; n_priority=$(notion_priority "$priority")
    local n_type="${tkt_type:-task}"
    local archive_payload=$(jq -n --arg db "$NOTION_DB_ARCHIVE" --arg ttl "$n_title" --arg pri "$n_priority" --arg typ "$n_type" --arg cdt "$delivered_date" --arg res "$resolution" '{
      parent: {database_id: $db},
      properties: {
        "US Title": {title: [{text: {content: $ttl}}]},
        "Status": {select: {name: "Archived"}},
        "Type": {select: {name: ($typ | ascii_upcase)}},
        "Priority": {select: {name: $pri}},
        "Created Date": {date: {start: $cdt}},
        "Resolution": {rich_text: [{text: {content: $res}}]}
      }
    }' 2>/dev/null)
    if [[ -n "$archive_payload" ]]; then
      curl -s -X POST "https://api.notion.com/v1/pages" -H "Authorization: Bearer $key" -H "Notion-Version: 2025-09-03" -H "Content-Type: application/json" --data "$archive_payload" > /dev/null 2>&1 || true
    fi
  fi
  
  # Step 3: Archive the original page in DB A (remove from active view) — ALWAYS runs
  curl -s -X PATCH "https://api.notion.com/v1/pages/${page_id}" -H "Authorization: Bearer $key" -H "Notion-Version: 2025-09-03" -H "Content-Type: application/json" -d '{"archived": true}' > /dev/null 2>&1 || true
}

SUBCOMMAND="${1:-help}"
shift || true

if [[ "$SUBCOMMAND" == "new" ]]; then
  TITLE=""; TYPE="task"; PRIORITY="medium"; DESC=""; REQUESTER="Ken"; ASSIGNEE="Yoda"
  while (( $# > 0 )); do
    case "$1" in --title) TITLE="$2"; shift 2 ;; --type) TYPE="$2"; shift 2 ;; --priority) PRIORITY="$2"; shift 2 ;; --description) DESC="$2"; shift 2 ;; --requester) REQUESTER="$2"; shift 2 ;; --assignee) ASSIGNEE="$2"; shift 2 ;; *) die "Unknown arg: $1" ;; esac
  done
  [[ -z "$TITLE" ]] && die "--title is required"
  SEQ=$(jq '.sequence' "$TICKET_FILE")
  TKT_ID=$(printf "TKT-%04d" "$SEQ")
  NOW_LOCAL=$(date '+%Y-%m-%dT%H:%M:%S+10:00')
  TODAY=$(date '+%Y-%m-%d')
  TMP=$(jq --arg id "$TKT_ID" --arg title "$TITLE" --arg type "$TYPE" --arg priority "$PRIORITY" --arg status "open" --arg requester "$REQUESTER" --arg assignee "$ASSIGNEE" --arg created "$NOW_LOCAL" --arg updated "$NOW_LOCAL" --arg desc "$DESC" '.sequence += 1 | .tickets += [{id: $id, title: $title, type: $type, priority: $priority, status: $status, requester: $requester, assignee: $assignee, created: $created, updated: $updated, description: $desc, resolution: null, linked: {us: [], inc: [], chg: []}, notes: "", notionPageId: null}]' "$TICKET_FILE")
  atomic_write "$TICKET_FILE" "$TMP"
  echo "✅ Ticket created: $TKT_ID"
  NOTION_PAGE_ID=$(notion_create_ticket "$TKT_ID" "$TITLE" "open" "$PRIORITY" "$TODAY" "$DESC" 2>/dev/null || echo "NOTION_SKIP")
  if [[ -n "$NOTION_PAGE_ID" && "$NOTION_PAGE_ID" != "NOTION_SKIP" ]]; then
    TMP2=$(jq --arg id "$TKT_ID" --arg npid "$NOTION_PAGE_ID" '(.tickets[] | select(.id == $id)) |= (.notionPageId = $npid)' "$TICKET_FILE")
    atomic_write "$TICKET_FILE" "$TMP2"
  fi

elif [[ "$SUBCOMMAND" == "update" ]]; then
  TKT_ID="${1:-}"
  [[ -z "$TKT_ID" ]] && die "Usage: ticket.sh update TKT-NNNN --status STATUS [--notes \"...\"]"
  shift
  STATUS=""; NOTES=""
  while (( $# > 0 )); do
    case "$1" in --status) STATUS="$2"; shift 2 ;; --notes) NOTES="$2"; shift 2 ;; *) die "Unknown arg: $1" ;; esac
  done
  [[ -z "$STATUS" ]] && die "--status is required"

  # TKT-0182: State Checking Pattern
  CURRENT_STATE=$(get_ticket_state "$TKT_ID")
  validate_transition "$CURRENT_STATE" "$STATUS" || die "State transition validation failed."

  NOW_LOCAL=$(date '+%Y-%m-%dT%H:%M:%S+10:00')
  TICKET_JSON=$(jq -r --arg id "$TKT_ID" '.tickets[] | select(.id == $id)' "$TICKET_FILE")
  [[ -z "$TICKET_JSON" ]] && die "Ticket $TKT_ID not found"
  
  T_PRIORITY=$(echo "$TICKET_JSON" | jq -r '.priority')
  T_NOTION_ID=$(echo "$TICKET_JSON" | jq -r '.notionPageId // ""')
  T_STREAM=$(echo "$TICKET_JSON" | jq -r '.stream // ""')
  T_TYPE=$(echo "$TICKET_JSON" | jq -r '.type // "task"')

  TMP=$(jq --arg id "$TKT_ID" --arg st "$STATUS" --arg nt "$NOTES" --arg ts "$NOW_LOCAL" '(.tickets[] | select(.id == $id)) |= (.status = $st | .updated = $ts | .notes += (if $nt != "" then "\n" + $nt else "" end))' "$TICKET_FILE")
  atomic_write "$TICKET_FILE" "$TMP"

  sprint_sync "$TKT_ID" "$STATUS"
  if [[ -n "$T_NOTION_ID" && "$T_NOTION_ID" != "null" && "$T_NOTION_ID" != "NOTION_SKIP" ]]; then
    notion_update_ticket "$T_NOTION_ID" "$STATUS" "$T_PRIORITY" "$NOTES" "" "" "" "$T_STREAM" "$T_TYPE" "$TKT_ID"
  fi
  
  verify_state_update "$TKT_ID" "$STATUS" || echo "⚠️  Post-write verification failed"
  echo "✅ Ticket $TKT_ID updated to $STATUS"

elif [[ "$SUBCOMMAND" == "close" ]]; then
  TKT_ID="${1:-}"
  [[ -z "$TKT_ID" ]] && die "Usage: ticket.sh close TKT-NNNN --resolution \"...\""
  shift
  RES=""
  while (( $# > 0 )); do
    case "$1" in --resolution) RES="$2"; shift 2 ;; *) die "Unknown arg: $1" ;; esac
  done
  [[ -z "$RES" ]] && die "--resolution is required"

  # TKT-0182: State Checking Pattern
  CURRENT_STATE=$(get_ticket_state "$TKT_ID")
  validate_transition "$CURRENT_STATE" "closed" || die "State transition validation failed."

  NOW_LOCAL=$(date '+%Y-%m-%dT%H:%M:%S+10:00')
  TICKET_JSON=$(jq -r --arg id "$TKT_ID" '.tickets[] | select(.id == $id)' "$TICKET_FILE")
  [[ -z "$TICKET_JSON" ]] && die "Ticket $TKT_ID not found"
  T_NOTION_ID=$(echo "$TICKET_JSON" | jq -r '.notionPageId // ""')
  T_PRIORITY=$(echo "$TICKET_JSON" | jq -r '.priority')

  TMP=$(jq --arg id "$TKT_ID" --arg st "closed" --arg res "$RES" --arg ts "$NOW_LOCAL" '(.tickets[] | select(.id == $id)) |= (.status = $st | .updated = $ts | .resolution = $res)' "$TICKET_FILE")
  atomic_write "$TICKET_FILE" "$TMP"

  sprint_sync "$TKT_ID" "closed"
  if [[ -n "$T_NOTION_ID" && "$T_NOTION_ID" != "null" && "$T_NOTION_ID" != "NOTION_SKIP" ]]; then
    T_CREATED=$(echo "$TICKET_JSON" | jq -r '(.created // .createdAt // "2026-01-01")[:10]')
    T_TYPE=$(echo "$TICKET_JSON" | jq -r '.type // "task"')
    notion_close_ticket "$T_NOTION_ID" "$NOW_LOCAL" "$TKT_ID" "$RES" "$T_PRIORITY" "$T_TYPE"
  fi
  
  verify_state_update "$TKT_ID" "closed" || echo "⚠️  Post-write verification failed"
  echo "✅ Ticket $TKT_ID closed"

elif [[ "$SUBCOMMAND" == "list" ]]; then
  S=""; P=""
  while (( $# > 0 )); do
    case "$1" in --status) S="$2"; shift 2 ;; --priority) P="$2"; shift 2 ;; *) shift ;; esac
  done
  jq -r '.tickets[] | select((if $S != "" then .status == $S else true end) and (if $P != "" then .priority == $P else true end)) | "\(.id) | \(.status) | \(.priority) | \(.title)"' --arg S "$S" --arg P "$P" "$TICKET_FILE"

elif [[ "$SUBCOMMAND" == "show" ]]; then
  TKT_ID="${1:-}"
  [[ -z "$TKT_ID" ]] && die "Usage: ticket.sh show TKT-NNNN"
  jq -r --arg id "$TKT_ID" '.tickets[] | select(.id == $id)' "$TICKET_FILE"

elif [[ "$SUBCOMMAND" == "link" ]]; then
  TKT_ID="${1:-}"
  [[ -z "$TKT_ID" ]] && die "Usage: ticket.sh link TKT-NNNN --us US-NN | --inc INC-ID | --chg CHG-ID"
  shift
  LTYPE=""; LVAL=""
  while (( $# > 0 )); do
    case "$1" in --us) LTYPE="us"; LVAL="$2"; shift 2 ;; --inc) LTYPE="inc"; LVAL="$2"; shift 2 ;; --chg) LTYPE="chg"; LVAL="$2"; shift 2 ;; *) shift ;; esac
  done
  TMP=$(jq --arg id "$TKT_ID" --arg type "$LTYPE" --arg val "$LVAL" '(.tickets[] | select(.id == $id)) |= (.linked[$type] += [$val])' "$TICKET_FILE")
  atomic_write "$TICKET_FILE" "$TMP"
  echo "✅ Linked $LVAL to $TKT_ID"

elif [[ "$SUBCOMMAND" == "notion-sync" ]]; then
  TKT_ID="${1:-}"
  [[ -z "$TKT_ID" ]] && die "Usage: ticket.sh notion-sync TKT-NNNN"
  TICKET_JSON=$(jq -r --arg id "$TKT_ID" '.tickets[] | select(.id == $id)' "$TICKET_FILE")
  [[ -z "$TICKET_JSON" ]] && die "Ticket $TKT_ID not found"
  T_TITLE=$(echo "$TICKET_JSON" | jq -r '.title')
  T_STATUS=$(echo "$TICKET_JSON" | jq -r '.status')
  T_PRIORITY=$(echo "$TICKET_JSON" | jq -r '.priority')
  T_DESC=$(echo "$TICKET_JSON" | jq -r '.description // ""')
  T_NOTES=$(echo "$TICKET_JSON" | jq -r '.notes // ""')
  T_CREATED=$(echo "$TICKET_JSON" | jq -r '(.created // .createdAt // "2026-01-01")[:10]')
  T_NOTION_ID=$(echo "$TICKET_JSON" | jq -r '.notionPageId // ""')
  T_STREAM=$(echo "$TICKET_JSON" | jq -r '.stream // ""')
  T_TYPE=$(echo "$TICKET_JSON" | jq -r '.type // "task"')
  T_SPRINT_RAW=$(echo "$TICKET_JSON" | jq -r '.sprint // ""')
  if [[ "$T_SPRINT_RAW" =~ ^[0-9]+$ ]]; then T_SPRINT="Sprint $T_SPRINT_RAW"; elif [[ "$T_SPRINT_RAW" == "null" || "$T_SPRINT_RAW" == "None" || -z "$T_SPRINT_RAW" ]]; then T_SPRINT=""; else T_SPRINT="$T_SPRINT_RAW"; fi
  if [[ -n "$T_NOTION_ID" && "$T_NOTION_ID" != "null" && "$T_NOTION_ID" != "NOTION_SKIP" ]]; then
    notion_update_ticket "$T_NOTION_ID" "$T_STATUS" "$T_PRIORITY" "${T_NOTES:-$T_DESC}" "$T_SPRINT" "" "" "$T_STREAM" "$T_TYPE" "$TKT_ID" 2>/dev/null && echo "✅ $TKT_ID synced (updated)" || echo "⚠️ Notion update failed"
  else
    COMBINED_NOTES="${T_DESC}${T_NOTES:+ | $T_NOTES}"
    NOTION_PAGE_ID=$(notion_create_ticket "$TKT_ID" "$T_TITLE" "$T_STATUS" "$T_PRIORITY" "$T_CREATED" "$COMBINED_NOTES" "$T_SPRINT" "" "" 2>/dev/null || echo "NOTION_SKIP")
    if [[ -n "$NOTION_PAGE_ID" && "$NOTION_PAGE_ID" != "NOTION_SKIP" ]]; then
      TMP=$(jq --arg id "$TKT_ID" --arg npid "$NOTION_PAGE_ID" '(.tickets[] | select(.id == $id)) |= (.notionPageId = $npid)' "$TICKET_FILE")
      atomic_write "$TICKET_FILE" "$TMP"
      echo "✅ $TKT_ID synced — page ID: $NOTION_PAGE_ID"
    else
      echo "⚠️ Notion sync failed"
    fi
  fi

else
  echo "AInchors Ticket System"
  echo "Usage: ticket.sh {new|list|show|update|link|close|notion-sync}"
fi
