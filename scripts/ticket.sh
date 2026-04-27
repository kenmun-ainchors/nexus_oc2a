#!/bin/zsh
# AInchors Ticket System — TKT-NNNN
# Every ad-hoc request or action without an INC/US/CHG reference MUST have a TKT first.
#
# Usage:
#   ticket.sh new --title "Title" --type TYPE --priority PRIORITY [--description "..."] [--requester "..."]
#   ticket.sh list [--status STATUS] [--priority PRIORITY]
#   ticket.sh show TKT-NNNN
#   ticket.sh update TKT-NNNN --status STATUS [--notes "..."] [--resolution "..."]
#   ticket.sh link TKT-NNNN --us US-NN | --inc INC-ID | --chg CHG-ID
#   ticket.sh close TKT-NNNN --resolution "..."
#
# Types:    request | task | incident | question | bug | change
# Priority: critical | high | medium | low
# Status:   open | in-progress | pending | resolved | closed | cancelled

set -u

TICKET_FILE="/Users/ainchorsangiefpl/.openclaw/workspace/state/tickets.json"
CHANGELOG_HELPER="/Users/ainchorsangiefpl/.openclaw/workspace/scripts/changelog-append.sh"

die() { echo "ERROR: $1" >&2; exit 1; }
require_jq() { command -v jq > /dev/null || die "jq required"; }
require_jq

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
  NOW=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
  NOW_LOCAL=$(date '+%Y-%m-%dT%H:%M:%S+10:00')

  # Append ticket + increment sequence
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
       notes: ""
     }]' "$TICKET_FILE")
  echo "$TMP" > "$TICKET_FILE"

  echo "✅ Ticket created: $TKT_ID"
  echo "   Title:    $TITLE"
  echo "   Type:     $TYPE"
  echo "   Priority: $PRIORITY"
  echo "   Status:   open"
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
    "ID:          \(.id)\nTitle:       \(.title)\nType:        \(.type)\nPriority:    \(.priority)\nStatus:      \(.status)\nRequester:   \(.requester)\nAssignee:    \(.assignee)\nCreated:     \(.created)\nUpdated:     \(.updated)\nDescription: \(.description)\nResolution:  \(.resolution // "—")\nLinked US:   \(.linked.us | join(", ") | if . == "" then "—" else . end)\nLinked INC:  \(.linked.inc | join(", ") | if . == "" then "—" else . end)\nLinked CHG:  \(.linked.chg | join(", ") | if . == "" then "—" else . end)\nNotes:       \(.notes)"
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
  echo ""
  echo "Types:    request | task | incident | question | bug | change"
  echo "Priority: critical | high | medium | low"
  echo "Status:   open | in-progress | pending | resolved | closed | cancelled"
fi
