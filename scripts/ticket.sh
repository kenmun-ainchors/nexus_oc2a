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
NOTION_DB_ID="34dc1829-53ff-814b-8257-d3a3bf351d44"
NOTION_KEY_FILE="$HOME/.config/notion/api_key"

die() { echo "ERROR: $1" >&2; exit 1; }
require_jq() { command -v jq > /dev/null || die "jq required"; }
require_jq

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
# Usage: notion_create_ticket TKT-ID TITLE STATUS PRIORITY CREATED_DATE [NOTES]
notion_create_ticket() {
  local tkt_id="$1" title="$2" tkt_status="$3" priority="$4" created_date="$5" notes="${6:-}"
  [[ ! -f "$NOTION_KEY_FILE" ]] && echo "NOTION_SKIP" && return
  local key; key=$(cat "$NOTION_KEY_FILE")
  local n_status; n_status=$(notion_status "$tkt_status")
  local n_priority; n_priority=$(notion_priority "$priority")
  local n_title="[${tkt_id}] ${title}"
  notes="${notes:0:2000}"

  # Use jq for safe JSON construction — handles all escaping/special chars
  local payload
  payload=$(jq -n \
    --arg db   "$NOTION_DB_ID" \
    --arg ttl  "$n_title" \
    --arg sta  "$n_status" \
    --arg pri  "$n_priority" \
    --arg cdt  "$created_date" \
    --arg nts  "$notes" \
    '{
      parent: {database_id: $db},
      properties: {
        "US Title":     {title:  [{text: {content: $ttl}}]},
        "Status":       {select: {name: $sta}},
        "Type":         {select: {name: "TKT"}},
        "Priority":     {select: {name: $pri}},
        "Created Date": {date:   {start: $cdt}},
        "Notes":        {rich_text: (if $nts != "" then [{text: {content: $nts}}] else [] end)}
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
# Usage: notion_update_ticket PAGE_ID STATUS PRIORITY [NOTES]
notion_update_ticket() {
  local page_id="$1" tkt_status="$2" priority="$3" notes="${4:-}"
  [[ -z "$page_id" || "$page_id" == "null" || "$page_id" == "NOTION_SKIP" ]] && return
  [[ ! -f "$NOTION_KEY_FILE" ]] && return
  local key; key=$(cat "$NOTION_KEY_FILE")
  local n_status; n_status=$(notion_status "$tkt_status")
  local n_priority; n_priority=$(notion_priority "$priority")
  notes="${notes:0:2000}"

  local payload
  payload=$(jq -n \
    --arg sta "$n_status" \
    --arg pri "$n_priority" \
    --arg nts "$notes" \
    '{
      properties: {
        "Status":   {select: {name: $sta}},
        "Priority": {select: {name: $pri}},
        "Notes":    {rich_text: (if $nts != "" then [{text: {content: $nts}}] else [] end)}
      }
    }' 2>/dev/null)
  [[ -z "$payload" ]] && return

  curl -s -X PATCH "https://api.notion.com/v1/pages/${page_id}" \
    -H "Authorization: Bearer $key" \
    -H "Notion-Version: 2025-09-03" \
    -H "Content-Type: application/json" \
    --data "$payload" > /dev/null 2>&1 || true
}

# Set Notion page Status to Done (used by close).
# Usage: notion_close_ticket PAGE_ID
notion_close_ticket() {
  local page_id="$1"
  [[ -z "$page_id" || "$page_id" == "null" || "$page_id" == "NOTION_SKIP" ]] && return
  [[ ! -f "$NOTION_KEY_FILE" ]] && return
  local key; key=$(cat "$NOTION_KEY_FILE")
  curl -s -X PATCH "https://api.notion.com/v1/pages/${page_id}" \
    -H "Authorization: Bearer $key" \
    -H "Notion-Version: 2025-09-03" \
    -H "Content-Type: application/json" \
    --data '{"properties": {"Status": {"select": {"name": "Done"}}}}' \
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
  echo "$TMP" > "$TICKET_FILE"

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
    echo "$TMP2" > "$TICKET_FILE"
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
  echo "$TMP" > "$TICKET_FILE"
  echo "✅ $TKT_ID updated"

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
  echo "$TMP" > "$TICKET_FILE"
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
  echo "$TMP" > "$TICKET_FILE"
  echo "✅ $TKT_ID closed"

  # Notion sync — set Status to Done (best-effort)
  NOTION_PAGE_ID=$(jq -r --arg id "$TKT_ID" '.tickets[] | select(.id == $id) | .notionPageId // ""' "$TICKET_FILE")
  if [[ -n "$NOTION_PAGE_ID" && "$NOTION_PAGE_ID" != "null" && "$NOTION_PAGE_ID" != "" ]]; then
    notion_close_ticket "$NOTION_PAGE_ID" 2>/dev/null \
      && echo "   Notion:   ✅ marked Done" \
      || echo "   Notion:   ⚠️  sync failed (local close still saved)"
  else
    echo "   Notion:   ⚠️  no notionPageId — run: ticket.sh notion-sync $TKT_ID"
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
  T_CREATED=$(echo "$TICKET_JSON" | jq -r '.created[:10]')
  T_NOTION_ID=$(echo "$TICKET_JSON" | jq -r '.notionPageId // ""')

  if [[ -n "$T_NOTION_ID" && "$T_NOTION_ID" != "null" && "$T_NOTION_ID" != "" ]]; then
    echo "Updating existing Notion page $T_NOTION_ID for $TKT_ID..."
    notion_update_ticket "$T_NOTION_ID" "$T_STATUS" "$T_PRIORITY" "${T_NOTES:-$T_DESC}" 2>/dev/null \
      && echo "✅ $TKT_ID synced to Notion (updated)" \
      || echo "⚠️  Notion update failed for $TKT_ID"
  else
    echo "Creating new Notion page for $TKT_ID..."
    COMBINED_NOTES="${T_DESC}${T_NOTES:+ | $T_NOTES}"
    NOTION_PAGE_ID=$(notion_create_ticket "$TKT_ID" "$T_TITLE" "$T_STATUS" "$T_PRIORITY" "$T_CREATED" "$COMBINED_NOTES" 2>/dev/null || echo "NOTION_SKIP")
    if [[ -n "$NOTION_PAGE_ID" && "$NOTION_PAGE_ID" != "NOTION_SKIP" ]]; then
      TMP=$(jq --arg id "$TKT_ID" --arg npid "$NOTION_PAGE_ID" \
        '(.tickets[] | select(.id == $id)) |= (.notionPageId = $npid)' "$TICKET_FILE")
      echo "$TMP" > "$TICKET_FILE"
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
