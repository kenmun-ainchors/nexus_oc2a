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
# Notion DB IDs — CHG-0401 3-DB architecture
NOTION_DB_BACKLOG="34dc1829-53ff-814b-8257-d3a3bf351d44"     # A: Active backlog (open/in-progress tickets)
NOTION_DB_AUTOHEAL="364c1829-53ff-81c0-9dbd-ff2c907d1a6b"   # B: Auto-Heal (AUTO-HEAL items)
NOTION_DB_ARCHIVE="364c1829-53ff-818e-a783-ebafcb6a9880"    # C: Completed-Archived (Done/closed items)

# Legacy alias — used throughout the script, points to active backlog by default
NOTION_DB_ID="$NOTION_DB_BACKLOG"
NOTION_KEY_FILE="$HOME/.config/notion/api_key"

die() { echo "ERROR: $1" >&2; exit 1; }
# Atomic write helper with PRE-WRITE BACKUP + CORRUPTION GUARD
# Creates a backup before every write, validates JSON integrity after write,
# and automatically rolls back on failure.
atomic_write() {
  local file="$1"
  local content="$2"
  local tmp_file="${file}.tmp.$RANDOM"
  local bak_file="${file}.bak-$(date +%Y%m%d%H%M%S)"
  
  # GUARD 0: If content is empty or whitespace-only, ABORT
  [[ -z "${content// }" ]] && { echo "CRITICAL: atomic_write blocked empty content for $file — ABORTED" >&2; return 1; }
  
  # GUARD 1: Create pre-write backup
  if [[ -f "$file" ]]; then
    cp "$file" "$bak_file" 2>/dev/null || true
  fi
  
  # GUARD 2: Validate content is valid JSON before writing (for .json files)
  if [[ "$file" == *.json ]]; then
    printf '%s' "$content" > "$tmp_file"
    /opt/homebrew/bin/jq . "$tmp_file" > /dev/null 2>&1 || {
      echo "CRITICAL: atomic_write blocked invalid JSON for $file — ABORTED" >&2
      echo "First error: $(/opt/homebrew/bin/jq . "$tmp_file" 2>&1 | head -1)" >&2
      rm -f "$tmp_file"
      return 1
    }
  fi
  
  # GUARD 3: Write to temp file, then atomic move
  printf '%s' "$content" > "$tmp_file" 2>/dev/null || {
    echo "CRITICAL: Failed to write temp file $tmp_file — ABORTED" >&2
    return 1
  }
  
  # GUARD 4: Verify temp file is non-empty before moving
  if [[ ! -s "$tmp_file" ]]; then
    echo "CRITICAL: Temp file $tmp_file is empty after write — ABORTED" >&2
    return 1
  fi
  
  mv "$tmp_file" "$file" || {
    echo "CRITICAL: Atomic move failed from $tmp_file to $file — ABORTED" >&2
    return 1
  }
  
  # GUARD 5: Verify target file exists and is non-empty after move
  if [[ ! -s "$file" ]]; then
    echo "CRITICAL: Target file $file is empty after atomic move — ROLLING BACK from $bak_file" >&2
    if [[ -f "$bak_file" ]]; then
      cp "$bak_file" "$file"
      echo "ROLLED BACK: Restored $file from $bak_file" >&2
    fi
    return 1
  fi
  
  return 0
}

SPRINT_FILE="/Users/ainchorsangiefpl/.openclaw/workspace/state/sprint-current.json"

# Auto-sync ticket status into sprint-current.json if TKT is a sprint item
sprint_sync() {
  local tkt_id="$1" new_status="$2"
  [[ ! -f "$SPRINT_FILE" ]] && return 0
  local in_sprint
  in_sprint=$(jq -r --arg id "$tkt_id" '.items[] | select(.tkt == $id) | .tkt' "$SPRINT_FILE" 2>/dev/null)
  [[ -z "$in_sprint" ]] && return 0
  local now_local
  now_local=$(date '+%Y-%m-%dT%H:%M:%S+10:00')
  local sprint_status="$new_status"
  case "$new_status" in
    closed|resolved) sprint_status="done" ;;
  esac
  local tmp
  tmp=$(jq --arg id "$tkt_id" --arg st "$sprint_status" --arg ts "$now_local" '
    (.items[] | select(.tkt == $id)) |= (.status = $st | if $st == "done" then .completedAt = $ts else . end) |
    .velocity.done = ([.items[] | select(.status == "done")] | length) |
    .velocity.inProgress = ([.items[] | select(.status == "in-progress")] | length) |
    .velocity.pending = ([.items[] | select(.status == "pending")] | length) |
    .velocity.lastUpdated = $ts
  ' "$SPRINT_FILE")
  atomic_write "$SPRINT_FILE" "$tmp" || echo "   Sprint:   ⚠️ sprint sync write failed" >&2
  echo "   Sprint:   ✅ sprint-current.json synced → $sprint_status"
}

# ──────────────────────────────────────────
# NOTION HELPERS
# ──────────────────────────────────────────

# Map local status → Notion Status option
notion_status() {
  case "$1" in
    open)        echo "Backlog" ;;
    in-progress) echo "In Progress" ;;
    pending)     echo "Backlog" ;;
    done)        echo "Done" ;;
    resolved)    echo "Done" ;;
    closed)      echo "Done" ;;
    cancelled)   echo "Deferred" ;;
    *)           echo "Backlog" ;;
  esac
}

# Map local priority → Notion Priority option
notion_priority() {
  case "$1" in
    critical) echo "Critical" ;;
    high)     echo "High" ;;
    medium)   echo "Medium" ;;
    low)      echo "Low" ;;
    *)        echo "Medium" ;;
  esac
}

# Create a new Notion page for a ticket. Prints the page ID on success, or "NOTION_SKIP".
# Usage: notion_create_ticket TKT-ID TITLE STATUS PRIORITY CREATED_DATE [NOTES] [SPRINT] [PLANNED_DATE] [DELIVERED_DATE]
notion_create_ticket() {
  sleep 0.4  # Notion rate limit: max 3 req/sec — pace writes
  local tkt_id="$1" title="$2" tkt_status="$3" priority="$4" created_date="$5" notes="${6:-}" sprint="${7:-}" planned_date="${8:-}" delivered_date="${9:-}"
  [[ ! -f "$NOTION_KEY_FILE" ]] && echo "NOTION_SKIP" && return
  local key; key=$(cat "$NOTION_KEY_FILE")
  local n_status; n_status=$(notion_status "$tkt_status")
  local n_priority; n_priority=$(notion_priority "$priority")
  local n_title="[${tkt_id}] ${title}"
  notes="${notes:0:2000}"

  # ── CHG-0372: Check if Notion page already exists ──────────────────────────
  # Prevent duplicates by querying Notion before creating
  local existing_page_id
  existing_page_id=$(curl -s -X POST "https://api.notion.com/v1/search" \
    -H "Authorization: Bearer $key" \
    -H "Notion-Version: 2025-09-03" \
    -H "Content-Type: application/json" \
    -d "{\"query\": \"[${tkt_id}]\", \"page_size\": 5}" 2>/dev/null \
    | jq -r '.results[0].id // ""' 2>/dev/null)
  
  if [[ -n "$existing_page_id" && "$existing_page_id" != "null" && "$existing_page_id" != "" ]]; then
    # Page exists — update it instead of creating duplicate
    echo "$existing_page_id"
    return 0
  fi
  # ── End CHG-0372 duplicate prevention ───────────────────────────────────────

  # Use jq for safe JSON construction — handles all escaping/special chars
  local payload
  payload=$(jq -n \
    --arg db   "$NOTION_DB_ID" \
    --arg ttl  "$n_title" \
    --arg sta  "$n_status" \
    --arg pri  "$n_priority" \
    --arg cdt  "$created_date" \
    --arg nts  "$notes" \
    --arg spr  "$sprint" \
    --arg pdt  "$planned_date" \
    --arg ddt  "$delivered_date" \
    '{
      parent: {database_id: $db},
      properties: {
        "US Title":        {title:  [{text: {content: $ttl}}]},
        "Status":          {select: {name: $sta}},
        "Type":            {select: {name: "TKT"}},
        "Priority":        {select: {name: $pri}},
        "Created Date":    {date:   {start: $cdt}},
        "Notes":           {rich_text: (if $nts != "" then [{text: {content: $nts}}] else [] end)},
        "Sprint":          (if $spr != "" then {select: {name: $spr}} else {select: null} end),
        "Planned Date":    (if $pdt != "" then {date: {start: $pdt}} else {date: null} end),
        "Delivered Date":  (if $ddt != "" then {date: {start: $ddt}} else {date: null} end)
      }
    }' 2>/dev/null)

  [[ -z "$payload" ]] && echo "NOTION_SKIP" && return

  local resp
  resp=$(curl -s -X POST "https://api.notion.com/v1/pages" \
    -H "Authorization: Bearer $key" \
    -H "Notion-Version: 2025-09-03" \
    -H "Content-Type: application/json" \
    --data "$payload" 2>/dev/null)

  local page_id
  page_id=$(echo "$resp" | jq -r '.id // ""' 2>/dev/null)
  if [[ -n "$page_id" && "$page_id" != "null" && "$page_id" != "" ]]; then
    echo "$page_id"
  else
    echo "NOTION_SKIP"
  fi
}

# Update an existing Notion page's Status, Priority, and Notes.
# Usage: notion_update_ticket PAGE_ID STATUS PRIORITY [NOTES] [SPRINT] [PLANNED_DATE] [DELIVERED_DATE]
notion_update_ticket() {
  local page_id="$1" tkt_status="$2" priority="$3" notes="${4:-}" sprint="${5:-}" planned_date="${6:-}" delivered_date="${7:-}" stream="${8:-}" tkt_type="${9:-}"
  [[ -z "$page_id" || "$page_id" == "null" || "$page_id" == "NOTION_SKIP" ]] && return
  [[ ! -f "$NOTION_KEY_FILE" ]] && return
  local key; key=$(cat "$NOTION_KEY_FILE")
  local n_status; n_status=$(notion_status "$tkt_status")
  local n_priority; n_priority=$(notion_priority "$priority")
  notes="${notes:0:2000}"

  # Build payload in Python to avoid jq {} empty-object bug (CHG-0290)
  # Empty sprint/dates must be OMITTED entirely, not sent as {} (corrupts Notion DB)
  local payload
  payload=$(/usr/bin/python3 -c "
import json, sys
sta  = sys.argv[1]; pri = sys.argv[2]; nts = sys.argv[3]
spr  = sys.argv[4]; pdt = sys.argv[5]; ddt = sys.argv[6]
stm  = sys.argv[7] if len(sys.argv) > 7 else ''
typ  = sys.argv[8] if len(sys.argv) > 8 else ''
props = {
    'Status':   {'select': {'name': sta}},
    'Priority': {'select': {'name': pri}},
    'Notes':    {'rich_text': [{'text': {'content': nts}}] if nts else []},
}
if spr: props['Sprint']         = {'select': {'name': spr}}
if pdt: props['Planned Date']   = {'date': {'start': pdt}}
if ddt: props['Delivered Date'] = {'date': {'start': ddt}}
if stm: props['Stream']         = {'select': {'name': stm}}
if typ: props['Type']           = {'select': {'name': typ.upper()}}
print(json.dumps({'properties': props}))
" "$n_status" "$n_priority" "$notes" "$sprint" "$planned_date" "$delivered_date" 2>/dev/null)
  [[ -z "$payload" ]] && return

  curl -s -X PATCH "https://api.notion.com/v1/pages/${page_id}" \
    -H "Authorization: Bearer $key" \
    -H "Notion-Version: 2025-09-03" \
    -H "Content-Type: application/json" \
    --data "$payload" > /dev/null 2>&1 || true
}

# Set Notion page Status to Done (used by close).
# Usage: notion_close_ticket PAGE_ID [DELIVERED_DATE]
notion_close_ticket() {
  local page_id="$1" delivered_date="${2:-}"
  [[ -z "$page_id" || "$page_id" == "null" || "$page_id" == "NOTION_SKIP" ]] && return
  [[ ! -f "$NOTION_KEY_FILE" ]] && return
  local key; key=$(cat "$NOTION_KEY_FILE")
  local payload
  payload=$(jq -n --arg ddt "$delivered_date" '{
    "properties": {
      "Status": {"select": {"name": "Done"}},
      "Delivered Date": (if $ddt != "" then {"date": {"start": $ddt}} else {} end)
    }
  }')
  curl -s -X PATCH "https://api.notion.com/v1/pages/${page_id}" \
    -H "Authorization: Bearer $key" \
    -H "Notion-Version: 2025-09-03" \
    -H "Content-Type: application/json" \
    --data "$payload" \
    > /dev/null 2>&1 || true
}

SUBCOMMAND="${1:-help}"
shift || true

# ──────────────────────────────────────────
# NEW
# ──────────────────────────────────────────
if [[ "$SUBCOMMAND" == "new" ]]; then
  TITLE=""; TYPE="task"; PRIORITY="medium"; DESC=""; REQUESTER="Ken"; ASSIGNEE="Yoda"
  while (( $# > 0 )); do
    case "$1" in
      --title)       TITLE="$2"; shift 2 ;;
      --type)        TYPE="$2"; shift 2 ;;
      --priority)    PRIORITY="$2"; shift 2 ;;
      --description) DESC="$2"; shift 2 ;;
      --requester)   REQUESTER="$2"; shift 2 ;;
      --assignee)    ASSIGNEE="$2"; shift 2 ;;
      *) die "Unknown arg: $1" ;;
    esac
  done
  [[ -z "$TITLE" ]] && die "--title is required"
  case "$TYPE" in request|task|incident|question|bug|change) ;; *) die "Invalid --type" ;; esac
  case "$PRIORITY" in critical|high|medium|low) ;; *) die "Invalid --priority" ;; esac

  SEQ=$(jq '.sequence' "$TICKET_FILE")
  TKT_ID=$(printf "TKT-%04d" "$SEQ")
  NOW_LOCAL=$(date '+%Y-%m-%dT%H:%M:%S+10:00')
  TODAY=$(date '+%Y-%m-%d')

  # Write ticket to local JSON (notionPageId starts null)
  TMP=$(jq --arg id "$TKT_ID" \
           --arg title "$TITLE" \
           --arg type "$TYPE" \
           --arg priority "$PRIORITY" \
           --arg status "open" \
           --arg requester "$REQUESTER" \
           --arg assignee "$ASSIGNEE" \
           --arg created "$NOW_LOCAL" \
           --arg updated "$NOW_LOCAL" \
           --arg desc "$DESC" \
    '.sequence += 1 |
     .tickets += [{
       id: $id, title: $title, type: $type, priority: $priority,
       status: $status, requester: $requester, assignee: $assignee,
       created: $created, updated: $updated,
       description: $desc, resolution: null,
       linked: {us: [], inc: [], chg: []},
       notes: "",
       notionPageId: null
     }]' "$TICKET_FILE")
  atomic_write "$TICKET_FILE" "$TMP"

  echo "✅ Ticket created: $TKT_ID"
  echo "   Title:    $TITLE"
  echo "   Type:     $TYPE"
  echo "   Priority: $PRIORITY"
  echo "   Status:   open"

  # Notion sync (best-effort — failure does NOT block ticket creation)
  echo -n "   Notion:   "
  NOTION_PAGE_ID=$(notion_create_ticket "$TKT_ID" "$TITLE" "open" "$PRIORITY" "$TODAY" "$DESC" 2>/dev/null || echo "NOTION_SKIP")
  if [[ -n "$NOTION_PAGE_ID" && "$NOTION_PAGE_ID" != "NOTION_SKIP" ]]; then
    TMP2=$(jq --arg id "$TKT_ID" --arg npid "$NOTION_PAGE_ID" \
      '(.tickets[] | select(.id == $id)) |= (.notionPageId = $npid)' "$TICKET_FILE")
    atomic_write "$TICKET_FILE" "$TMP2"
    echo "✅ synced → $NOTION_PAGE_ID"
  else
    echo "⚠️  sync skipped or failed (local ticket still created)"
  fi

  echo ""
  echo "Reference this ID in all work related to this request."

# ──────────────────────────────────────────
# LIST
# ──────────────────────────────────────────
elif [[ "$SUBCOMMAND" == "list" ]]; then
  FILTER_STATUS=""; FILTER_PRIORITY=""
  while (( $# > 0 )); do
    case "$1" in
      --status)   FILTER_STATUS="$2"; shift 2 ;;
      --priority) FILTER_PRIORITY="$2"; shift 2 ;;
      *) die "Unknown arg: $1" ;;
    esac
  done

  jq -r --arg s "$FILTER_STATUS" --arg p "$FILTER_PRIORITY" '
    .tickets[]
    | select(if $s != "" then .status == $s else true end)
    | select(if $p != "" then .priority == $p else true end)
    | "\(.id)  [\(.status | ascii_upcase)] [\(.priority | ascii_upcase)]  \(.title)  (created: \(.created[:10]))"
  ' "$TICKET_FILE"

# ──────────────────────────────────────────
# SHOW
# ──────────────────────────────────────────
elif [[ "$SUBCOMMAND" == "show" ]]; then
  TKT_ID="${1:-}"
  [[ -z "$TKT_ID" ]] && die "Usage: ticket.sh show TKT-NNNN"
  jq -r --arg id "$TKT_ID" '
    .tickets[] | select(.id == $id) |
    "ID:          \(.id)\nTitle:       \(.title)\nType:        \(.type)\nPriority:    \(.priority)\nStatus:      \(.status)\nRequester:   \(.requester)\nAssignee:    \(.assignee)\nCreated:     \(.created)\nUpdated:     \(.updated)\nDescription: \(.description)\nResolution:  \(.resolution // "—")\nLinked US:   \(.linked.us | join(", ") | if . == "" then "—" else . end)\nLinked INC:  \(.linked.inc | join(", ") | if . == "" then "—" else . end)\nLinked CHG:  \(.linked.chg | join(", ") | if . == "" then "—" else . end)\nNotes:       \(.notes)\nNotion Page: \(.notionPageId // "—")"
  ' "$TICKET_FILE"

# ──────────────────────────────────────────
# UPDATE
# ──────────────────────────────────────────
elif [[ "$SUBCOMMAND" == "update" ]]; then
  TKT_ID="${1:-}"; shift || true
  [[ -z "$TKT_ID" ]] && die "Usage: ticket.sh update TKT-NNNN --status STATUS [--notes ...]"
  NEW_STATUS=""; NEW_NOTES=""; NEW_RESOLUTION=""
  while (( $# > 0 )); do
    case "$1" in
      --status)     NEW_STATUS="$2"; shift 2 ;;
      --notes)      NEW_NOTES="$2"; shift 2 ;;
      --resolution) NEW_RESOLUTION="$2"; shift 2 ;;
      *) die "Unknown arg: $1" ;;
    esac
  done
  NOW_LOCAL=$(date '+%Y-%m-%dT%H:%M:%S+10:00')
  TMP=$(jq --arg id "$TKT_ID" \
           --arg status "$NEW_STATUS" \
           --arg notes "$NEW_NOTES" \
           --arg resolution "$NEW_RESOLUTION" \
           --arg updated "$NOW_LOCAL" '
    (.tickets[] | select(.id == $id)) |= (
      .updated = $updated |
      (if $status != "" then .status = $status else . end) |
      (if $notes != "" then .notes = (if .notes == "" then $notes else .notes + " | " + $notes end) else . end) |
      (if $resolution != "" then .resolution = $resolution else . end)
    )
  ' "$TICKET_FILE")
  atomic_write "$TICKET_FILE" "$TMP"
  echo "✅ $TKT_ID updated"

  # Sprint sync (auto)
  [[ -n "$NEW_STATUS" ]] && sprint_sync "$TKT_ID" "$NEW_STATUS"

  # Notion sync (best-effort)
  NOTION_PAGE_ID=$(jq -r --arg id "$TKT_ID" '.tickets[] | select(.id == $id) | .notionPageId // ""' "$TICKET_FILE")
  CURR_STATUS=$(jq -r --arg id "$TKT_ID" '.tickets[] | select(.id == $id) | .status' "$TICKET_FILE")
  CURR_PRIORITY=$(jq -r --arg id "$TKT_ID" '.tickets[] | select(.id == $id) | .priority' "$TICKET_FILE")
  CURR_NOTES=$(jq -r --arg id "$TKT_ID" '.tickets[] | select(.id == $id) | .notes // ""' "$TICKET_FILE")
  if [[ -n "$NOTION_PAGE_ID" && "$NOTION_PAGE_ID" != "null" && "$NOTION_PAGE_ID" != "" ]]; then
    notion_update_ticket "$NOTION_PAGE_ID" "$CURR_STATUS" "$CURR_PRIORITY" "$CURR_NOTES" 2>/dev/null \
      && echo "   Notion:   ✅ synced" \
      || echo "   Notion:   ⚠️  sync failed (local update still saved)"
  else
    echo "   Notion:   ⚠️  no notionPageId — run: ticket.sh notion-sync $TKT_ID"
  fi

# ──────────────────────────────────────────
# LINK
# ──────────────────────────────────────────
elif [[ "$SUBCOMMAND" == "link" ]]; then
  TKT_ID="${1:-}"; shift || true
  [[ -z "$TKT_ID" ]] && die "Usage: ticket.sh link TKT-NNNN --us US-NN | --inc INC-ID | --chg CHG-ID"
  LINK_US=""; LINK_INC=""; LINK_CHG=""
  while (( $# > 0 )); do
    case "$1" in
      --us)  LINK_US="$2"; shift 2 ;;
      --inc) LINK_INC="$2"; shift 2 ;;
      --chg) LINK_CHG="$2"; shift 2 ;;
      *) die "Unknown arg: $1" ;;
    esac
  done
  NOW_LOCAL=$(date '+%Y-%m-%dT%H:%M:%S+10:00')
  TMP=$(jq --arg id "$TKT_ID" \
           --arg us "$LINK_US" --arg inc "$LINK_INC" --arg chg "$LINK_CHG" \
           --arg updated "$NOW_LOCAL" '
    (.tickets[] | select(.id == $id)) |= (
      .updated = $updated |
      (if $us != "" then .linked.us += [$us] else . end) |
      (if $inc != "" then .linked.inc += [$inc] else . end) |
      (if $chg != "" then .linked.chg += [$chg] else . end)
    )
  ' "$TICKET_FILE")
  atomic_write "$TICKET_FILE" "$TMP" || die "Failed to write link — tickets.json may be corrupted, check backup"
  echo "✅ $TKT_ID linked"

# ──────────────────────────────────────────
# CLOSE
# ──────────────────────────────────────────
elif [[ "$SUBCOMMAND" == "close" ]]; then
  TKT_ID="${1:-}"; shift || true
  [[ -z "$TKT_ID" ]] && die "Usage: ticket.sh close TKT-NNNN --resolution \"...\""
  RESOLUTION=""
  while (( $# > 0 )); do
    case "$1" in --resolution) RESOLUTION="$2"; shift 2 ;; *) die "Unknown arg: $1" ;; esac
  done
  [[ -z "$RESOLUTION" ]] && die "--resolution required when closing"
  NOW_LOCAL=$(date '+%Y-%m-%dT%H:%M:%S+10:00')
  TMP=$(jq --arg id "$TKT_ID" --arg res "$RESOLUTION" --arg updated "$NOW_LOCAL" '
    (.tickets[] | select(.id == $id)) |= (.status = "closed" | .resolution = $res | .updated = $updated)
  ' "$TICKET_FILE")
  atomic_write "$TICKET_FILE" "$TMP"
  echo "✅ $TKT_ID closed"

  # Sprint sync (auto)
  sprint_sync "$TKT_ID" "done"

  # Notion sync — set Status to Done (best-effort)
  NOTION_PAGE_ID=$(jq -r --arg id "$TKT_ID" '.tickets[] | select(.id == $id) | .notionPageId // ""' "$TICKET_FILE")
  if [[ -n "$NOTION_PAGE_ID" && "$NOTION_PAGE_ID" != "null" && "$NOTION_PAGE_ID" != "" ]]; then
    notion_close_ticket "$NOTION_PAGE_ID" 2>/dev/null \
      && echo "   Notion:   ✅ marked Done in DB A" \
      || echo "   Notion:   ⚠️  DB A sync failed (local close still saved)"
  else
    echo "   Notion:   ⚠️  no notionPageId — run: ticket.sh notion-sync $TKT_ID"
  fi

  # CHG-0402: Auto-archive to DB C (Completed-Archived)
  echo -n "   Archive:  "
  TKT_TITLE=$(jq -r --arg id "$TKT_ID" '.tickets[] | select(.id == $id) | .title // "$TKT_ID"' "$TICKET_FILE")
  TKT_TYPE=$(jq -r --arg id "$TKT_ID" '.tickets[] | select(.id == $id) | .type // "task"' "$TICKET_FILE")
  TKT_PRIORITY=$(jq -r --arg id "$TKT_ID" '.tickets[] | select(.id == $id) | .priority // "medium"' "$TICKET_FILE")
  TKT_DESC=$(jq -r --arg id "$TKT_ID" '.tickets[] | select(.id == $id) | .description // ""' "$TICKET_FILE")
  TKT_NOTES=$(jq -r --arg id "$TKT_ID" '.tickets[] | select(.id == $id) | .notes // ""' "$TICKET_FILE")
  TODAY=$(date '+%Y-%m-%d')
  
  ARCHIVE_PAYLOAD=$(jq -n \
    --arg ttl "$TKT_TITLE" \
    --arg typ "$TKT_TYPE" \
    --arg pri "$TKT_PRIORITY" \
    --arg dsc "${TKT_DESC}${TKT_NOTES:+ | $TKT_NOTES}" \
    --arg res "$RESOLUTION" \
    --arg cdt "$TODAY" \
    --arg db "$NOTION_DB_ARCHIVE" \
    '{
      parent: {database_id: $db},
      properties: {
        "Title":          {title: [{text: {content: $ttl}}]},
        "Original ID":    {rich_text: [{text: {content: $ttl}}]},
        "Type":           {select: {name: (if $typ == "change" then "CHG" elif $typ == "auto-heal" then "AUTO-HEAL" else ($typ | ascii_upcase) end)}},
        "Status":         {select: {name: "Archived"}},
        "Priority":       {select: {name: ($pri | ascii_upcase[:1] + ascii_downcase[1:])}},
        "Completed Date": {date: {start: $cdt}},
        "Description":    {rich_text: [{text: {content: ("Resolution: " + $res + (if $dsc != "" then " | " + $dsc else "" end))[:2000]}}]}
      }
    }' 2>/dev/null)
  
  if [[ -n "$ARCHIVE_PAYLOAD" ]] && [[ -f "$NOTION_KEY_FILE" ]]; then
    local key; key=$(cat "$NOTION_KEY_FILE")
    ARCHIVE_RESP=$(curl -s -X POST "https://api.notion.com/v1/pages" \
      -H "Authorization: Bearer $key" \
      -H "Notion-Version: 2022-06-28" \
      -H "Content-Type: application/json" \
      --data "$ARCHIVE_PAYLOAD" 2>/dev/null)
    ARCHIVE_ID=$(echo "$ARCHIVE_RESP" | jq -r '.id // ""' 2>/dev/null)
    if [[ -n "$ARCHIVE_ID" && "$ARCHIVE_ID" != "null" && "$ARCHIVE_ID" != "" ]]; then
      echo "✅ archived to DB C ($ARCHIVE_ID)"
    else
      echo "⚠️  DB C archive failed (local close still saved)"
    fi
  else
    echo "⚠️  skipped (DB C not configured)"
  fi

# ──────────────────────────────────────────
# NOTION-SYNC (manual backfill for a single ticket)
# ──────────────────────────────────────────
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
  # Format sprint: integer 3 → "Sprint 3", string "Sprint 3" → "Sprint 3", null → ""
  T_SPRINT_RAW=$(echo "$TICKET_JSON" | jq -r '.sprint // ""')
  if [[ "$T_SPRINT_RAW" =~ ^[0-9]+$ ]]; then
    T_SPRINT="Sprint $T_SPRINT_RAW"
  elif [[ "$T_SPRINT_RAW" == "null" || "$T_SPRINT_RAW" == "None" || -z "$T_SPRINT_RAW" ]]; then
    T_SPRINT=""
  else
    T_SPRINT="$T_SPRINT_RAW"
  fi

  if [[ -n "$T_NOTION_ID" && "$T_NOTION_ID" != "null" && "$T_NOTION_ID" != "" ]]; then
    echo "Updating existing Notion page $T_NOTION_ID for $TKT_ID..."
    notion_update_ticket "$T_NOTION_ID" "$T_STATUS" "$T_PRIORITY" "${T_NOTES:-$T_DESC}" "$T_SPRINT" "" "" "$T_STREAM" "$T_TYPE" 2>/dev/null \
      && echo "✅ $TKT_ID synced to Notion (updated)" \
      || echo "⚠️  Notion update failed for $TKT_ID"
  else
    echo "Creating new Notion page for $TKT_ID..."
    COMBINED_NOTES="${T_DESC}${T_NOTES:+ | $T_NOTES}"
    NOTION_PAGE_ID=$(notion_create_ticket "$TKT_ID" "$T_TITLE" "$T_STATUS" "$T_PRIORITY" "$T_CREATED" "$COMBINED_NOTES" "$T_SPRINT" "" "" 2>/dev/null || echo "NOTION_SKIP")
    if [[ -n "$NOTION_PAGE_ID" && "$NOTION_PAGE_ID" != "NOTION_SKIP" ]]; then
      TMP=$(jq --arg id "$TKT_ID" --arg npid "$NOTION_PAGE_ID" \
        '(.tickets[] | select(.id == $id)) |= (.notionPageId = $npid)' "$TICKET_FILE")
      atomic_write "$TICKET_FILE" "$TMP" || echo "⚠️ Write failed for $TKT_ID Notion sync"
      echo "✅ $TKT_ID synced to Notion — page ID: $NOTION_PAGE_ID"
    else
      echo "⚠️  Notion sync failed for $TKT_ID"
    fi
  fi

# ──────────────────────────────────────────
# HELP
# ──────────────────────────────────────────
else
  echo "AInchors Ticket System"
  echo ""
  echo "Usage:"
  echo "  ticket.sh new --title \"Title\" --type TYPE --priority PRIORITY [--description \"...\"]"
  echo "  ticket.sh list [--status STATUS] [--priority PRIORITY]"
  echo "  ticket.sh show TKT-NNNN"
  echo "  ticket.sh update TKT-NNNN --status STATUS [--notes \"...\"] [--resolution \"...\"]"
  echo "  ticket.sh link TKT-NNNN --us US-NN | --inc INC-ID | --chg CHG-ID"
  echo "  ticket.sh close TKT-NNNN --resolution \"...\""
  echo "  ticket.sh notion-sync TKT-NNNN"
  echo ""
  echo "Types:    request | task | incident | question | bug | change"
  echo "Priority: critical | high | medium | low"
  echo "Status:   open | in-progress | pending | resolved | closed | cancelled"
  echo ""
  echo "Notion: Every new/update/close syncs to AKB Backlog automatically."
  echo "        Use notion-sync TKT-NNNN to manually backfill older tickets."
fi
