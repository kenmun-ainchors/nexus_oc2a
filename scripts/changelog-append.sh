#!/bin/zsh
# AInchors Change Log Append Helper
# Usage: changelog-append.sh --type TYPE --source SOURCE --title "TITLE" --trigger "TRIGGER" \
#                            --changed "WHAT" --why "WHY" --verified "VERIFIED" \
#                            [--rollback "ROLLBACK"] [--linked "LINKS"]
#
# All changes (Ken-prompted, auto-heal, incident recovery, scheduled) MUST go through this helper.
# It auto-increments CHG-NNNN, prepends to the log, and prints the new ID.

set -e

CHANGELOG="/Users/ainchorsangiefpl/.openclaw/workspace/memory/CHANGELOG.md"

# Defaults
TYPE=""; SOURCE=""; TITLE=""; TRIGGER=""; CHANGED=""; WHY=""; VERIFIED=""; ROLLBACK="N/A"; LINKED=""; FRAMEWORK_DOCS=""; CATEGORY=""; CHANGE_TYPE="Normal"

while (( $# > 0 )); do
  case "$1" in
    --type)     TYPE="$2"; shift 2 ;;
    --source)   SOURCE="$2"; shift 2 ;;
    --title)    TITLE="$2"; shift 2 ;;
    --trigger)  TRIGGER="$2"; shift 2 ;;
    --changed)  CHANGED="$2"; shift 2 ;;
    --why)      WHY="$2"; shift 2 ;;
    --verified) VERIFIED="$2"; shift 2 ;;
    --rollback) ROLLBACK="$2"; shift 2 ;;
    --linked)          LINKED="$2"; shift 2 ;;
    --framework-docs)  FRAMEWORK_DOCS="$2"; shift 2 ;;
    --category)        CATEGORY="$2"; shift 2 ;;
    --change-type)     CHANGE_TYPE="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

# Validate change-type
case "$CHANGE_TYPE" in
  Standard|Normal|Emergency) ;;
  *) echo "ERROR: --change-type must be one of: Standard|Normal|Emergency" >&2; exit 6 ;;
esac

# Validate required
for var in TYPE SOURCE TITLE TRIGGER CHANGED WHY VERIFIED; do
  if [[ -z "${(P)var}" ]]; then
    echo "ERROR: --${var:l} is required" >&2
    exit 2
  fi
done

# If category provided but no framework-docs, auto-resolve from registry
REGISTRY="$HOME/.openclaw/workspace/state/framework-registry.json"
if [[ -n "$CATEGORY" && -z "$FRAMEWORK_DOCS" && -f "$REGISTRY" ]]; then
  FRAMEWORK_DOCS=$(python3 -c "
import json, sys
cat = '$CATEGORY'.lower().replace(' ','-')
d = json.load(open('$REGISTRY'))
frames = d.get('registry',{}).get(cat,{}).get('frameworks',[])
print(', '.join(frames))
" 2>/dev/null || echo "")
fi

# Allowed values
case "$TYPE" in
  config|script|cron|rule|agent|infra|data|doc) ;;
  *) echo "ERROR: --type must be one of: config|script|cron|rule|agent|infra|data|doc" >&2; exit 3 ;;
esac
case "$SOURCE" in
  ken-prompt|auto-heal|incident-recovery|scheduled|manual) ;;
  *) echo "ERROR: --source must be one of: ken-prompt|auto-heal|incident-recovery|scheduled|manual" >&2; exit 4 ;;
esac

# Find next CHG ID — use MAX of all IDs (not just first) to avoid duplicates from out-of-order edits
MAX_ID=$(grep -oE 'CHG-[0-9]{4}' "$CHANGELOG" | grep -v 'CHG-NNNN' | sed 's/CHG-//' | sort -n | tail -1)
if [[ -z "$MAX_ID" ]]; then
  NEXT=1
else
  NEXT=$((10#$MAX_ID + 1))
fi
CHG_ID=$(printf "CHG-%04d" "$NEXT")

TS=$(date '+%Y-%m-%d %H:%M AEST')

# Build entry
FRAMEWORK_LINE=""
[[ -n "$FRAMEWORK_DOCS" ]] && FRAMEWORK_LINE="**Framework docs:** ${FRAMEWORK_DOCS}"
[[ -n "$CATEGORY" ]] && CATEGORY_LINE="**Category:** ${CATEGORY}" || CATEGORY_LINE=""

ENTRY="## ${TS} — [${CHG_ID}] ${TITLE}
**Type:** ${TYPE}
**Change Type:** ${CHANGE_TYPE}
**Source:** ${SOURCE}
**Trigger:** ${TRIGGER}
**What changed:** ${CHANGED}
**Why:** ${WHY}
**Verification:** ${VERIFIED}
**Rollback:** ${ROLLBACK}
**Linked:** ${LINKED:-none}
${CATEGORY_LINE:+${CATEGORY_LINE}\n}${FRAMEWORK_LINE:+${FRAMEWORK_LINE}\n}---
"

# Insert AFTER the header block (after the second --- line) and before existing entries
# Find the line of the schema closing ---
INSERT_LINE=$(grep -n "^---$" "$CHANGELOG" | sed -n '2p' | cut -d: -f1)
if [[ -z "$INSERT_LINE" ]]; then
  echo "ERROR: CHANGELOG.md format unexpected — could not find insertion point" >&2
  exit 5
fi

# Insert
{
  head -n "$INSERT_LINE" "$CHANGELOG"
  echo ""
  echo "$ENTRY"
  tail -n +$((INSERT_LINE + 1)) "$CHANGELOG"
} > "${CHANGELOG}.tmp" && mv "${CHANGELOG}.tmp" "$CHANGELOG"

echo "$CHG_ID"

# ── Notion sync (best-effort — failure does NOT block CHG logging) ──────────────
NOTION_KEY_FILE="$HOME/.config/notion/api_key"
NOTION_DB_ID="34dc1829-53ff-814b-8257-d3a3bf351d44"
if [[ -f "$NOTION_KEY_FILE" ]] && command -v jq > /dev/null && command -v curl > /dev/null; then
  NOTION_KEY=$(cat "$NOTION_KEY_FILE")
  N_TODAY=$(date '+%Y-%m-%d')
  N_TITLE="[${CHG_ID}] ${TITLE}"
  # Build CHG details for Notes (truncated to 2000 chars)
  N_NOTES="Type: ${TYPE} | Source: ${SOURCE} | Trigger: ${TRIGGER} | Changed: ${CHANGED} | Why: ${WHY} | Verified: ${VERIFIED} | Rollback: ${ROLLBACK}"
  N_NOTES="${N_NOTES:0:2000}"
  N_PAYLOAD=$(jq -n \
    --arg db  "$NOTION_DB_ID" \
    --arg ttl "$N_TITLE" \
    --arg cdt "$N_TODAY" \
    --arg nts "$N_NOTES" \
    '{
      parent: {database_id: $db},
      properties: {
        "US Title":     {title:  [{text: {content: $ttl}}]},
        "Status":       {select: {name: "Done"}},
        "Type":         {select: {name: "CHG"}},
        "Created Date": {date:   {start: $cdt}},
        "Notes":        {rich_text: [{text: {content: $nts}}]}
      }
    }' 2>/dev/null)
  if [[ -n "$N_PAYLOAD" ]]; then
    N_RESP=$(curl -s -X POST "https://api.notion.com/v1/pages" \
      -H "Authorization: Bearer $NOTION_KEY" \
      -H "Notion-Version: 2025-09-03" \
      -H "Content-Type: application/json" \
      --data "$N_PAYLOAD" 2>/dev/null)
    N_PAGE_ID=$(echo "$N_RESP" | jq -r '.id // ""' 2>/dev/null)
    if [[ -n "$N_PAGE_ID" && "$N_PAGE_ID" != "null" && "$N_PAGE_ID" != "" ]]; then
      echo "[notion] ✅ $CHG_ID synced → $N_PAGE_ID" >&2
    else
      echo "[notion] ⚠️  sync failed for $CHG_ID (CHG still logged)" >&2
    fi
  fi
fi
