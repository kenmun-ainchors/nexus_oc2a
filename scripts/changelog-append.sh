#!/bin/zsh
# AInchors Change Log Append Helper
# Usage: changelog-append.sh --type TYPE --source SOURCE --title "TITLE" --trigger "TRIGGER" \
#                            --changed "WHAT" --why "WHY" --verified "VERIFIED" \
#                            [--rollback "ROLLBACK"] [--linked "LINKS"]
#
# All changes (Ken-prompted, auto-heal, incident recovery, scheduled) MUST go through this helper.
# It auto-increments CHG-NNNN, inserts into state_changes (PG), prepends to the markdown log,
# and syncs to Notion. Dual-write: PG + markdown.
#
# SKILL GATE: changelog skill MUST be loaded before use.
SCRIPT_DIR_CHG="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR_CHG}/skill-gate.sh" "changelog" || exit $?

# TKT-0720: Source entity_links helper for live-write hooks
source "${SCRIPT_DIR_CHG}/db-link.sh"

set -e

# Resolve workspace from script location (migration 2026-07-14: no hard-coded user home)
CHANGELOG="$(cd "$(dirname "$0")/.." && pwd)/memory/CHANGELOG.md"
DB_RAW="${SCRIPT_DIR_CHG}/db-raw.sh"

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
  val=""
  case "$var" in
    TYPE) val="$TYPE" ;;
    SOURCE) val="$SOURCE" ;;
    TITLE) val="$TITLE" ;;
    TRIGGER) val="$TRIGGER" ;;
    CHANGED) val="$CHANGED" ;;
    WHY) val="$WHY" ;;
    VERIFIED) val="$VERIFIED" ;;
  esac
  if [[ -z "$val" ]]; then
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

# Get next CHG ID from PG sequence (TKT-0330 A4)
# set +e guard: under set -e, $() capture of a failing command can kill the
# script before $? is reached. We disable -e around the capture, then re-enable.
set +e
CHG_NUM=$(bash "$DB_RAW" -c "SELECT nextval('state_changes_change_id_seq');" 2>/dev/null | head -1 || true)
set -e
if [[ -z "$CHG_NUM" || "$CHG_NUM" == "null" ]]; then
  # Fallback: derive from markdown (should not happen if PG is healthy)
  echo "WARNING: PG sequence unavailable, falling back to markdown grep" >&2
  MAX_ID=$(grep -oE 'CHG-[0-9]{4}' "$CHANGELOG" | grep -v 'CHG-NNNN' | sed 's/CHG-//' | sort -n | tail -1)
  if [[ -z "$MAX_ID" ]]; then
    NEXT=1
  else
    NEXT=$((10#$MAX_ID + 1))
  fi
  CHG_NUM=$NEXT
fi
CHG_ID=$(printf "CHG-%04d" "$CHG_NUM")

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

# Insert BEFORE the first ## heading (prepend to existing entries)
# Preserve any preamble/comments before the first ## if present.
# Use a temp file to avoid pipefail issues with head/tail
INSERT_LINE=$(grep -n "^## " "$CHANGELOG" | cut -d: -f1 | head -1 || true)
if [[ -z "$INSERT_LINE" ]]; then
  # No ## heading found — append at end
  cat "$CHANGELOG" > "${CHANGELOG}.tmp"
  echo "" >> "${CHANGELOG}.tmp"
  printf '%s\n' "$ENTRY" >> "${CHANGELOG}.tmp"
  mv "${CHANGELOG}.tmp" "$CHANGELOG"
elif [[ "$INSERT_LINE" -eq 1 ]]; then
  # Insert at the very beginning (before first line)
  printf '%s\n' "$ENTRY" > "${CHANGELOG}.tmp"
  cat "$CHANGELOG" >> "${CHANGELOG}.tmp"
  mv "${CHANGELOG}.tmp" "$CHANGELOG"
else
  # Insert immediately before the first ## line
  head -n $((INSERT_LINE - 1)) "$CHANGELOG" > "${CHANGELOG}.tmp"
  echo "" >> "${CHANGELOG}.tmp"
  printf '%s\n' "$ENTRY" >> "${CHANGELOG}.tmp"
  tail -n +$((INSERT_LINE)) "$CHANGELOG" >> "${CHANGELOG}.tmp"
  mv "${CHANGELOG}.tmp" "$CHANGELOG"
fi

echo "$CHG_ID"

# ── PG insert into state_changes (TKT-0330 A4) ───────────────────────────────
# Dual-write: PG + markdown. PG is the SSOT; markdown is kept for backward compat.
# Escape single quotes for PG
PG_DESC=$(echo "$CHANGED" | sed "s/'/''/g")
PG_TITLE=$(echo "$TITLE" | sed "s/'/''/g")
PG_ACTOR=$(echo "$SOURCE" | sed "s/'/''/g")
PG_VERIFIED=$(echo "$VERIFIED" | sed "s/'/''/g")
PG_WHY=$(echo "$WHY" | sed "s/'/''/g")
PG_ROLLBACK=$(echo "$ROLLBACK" | sed "s/'/''/g")
PG_LINKED=$(echo "$LINKED" | sed "s/'/''/g")
PG_FRAMEWORK=$(echo "$FRAMEWORK_DOCS" | sed "s/'/''/g")
PG_CATEGORY=$(echo "$CATEGORY" | sed "s/'/''/g")
PG_TRIGGER=$(echo "$TRIGGER" | sed "s/'/''/g")
PG_CHANGE_TYPE=$(echo "$CHANGE_TYPE" | sed "s/'/''/g")

# ── Idempotency guard: skip INSERT if row already exists ──────────────────
# set +e guard: under set -e, $() capture of a failing command kills the script
# before $? is reached. We disable -e around the capture, then re-enable.
set +e
PG_EXISTS=$(bash "$DB_RAW" -c "SELECT 1 FROM state_changes WHERE change_id = '$CHG_ID';" 2>/dev/null | head -1 || true)
set -e
PG_OK=true
if [[ "$PG_EXISTS" == "1" ]]; then
  echo "[pg] ⚠️  $CHG_ID already exists in state_changes, skipping INSERT" >&2
else
  # ── PG insert with retry + backoff ───────────────────────────────────────
  # set +e guards: under set -e, $() capture of a failing command kills the script
  # before PG_RC=$? is reached. We disable -e around the capture, then re-enable.
  PG_ERROR=""
  for attempt in 1 2 3; do
    set +e
    PG_STDERR=$(bash "$DB_RAW" -c "INSERT INTO state_changes (change_id, title, description, actor, status, metadata, tenant_id)
VALUES (
  '$CHG_ID',
  '$PG_TITLE',
  'Trigger: $PG_TRIGGER | Changed: $PG_DESC | Why: $PG_WHY | Verified: $PG_VERIFIED | Rollback: $PG_ROLLBACK',
  '$PG_ACTOR',
  'applied',
  '{\"change_type\":\"$PG_CHANGE_TYPE\",\"type\":\"$TYPE\",\"source\":\"$PG_ACTOR\",\"trigger\":\"$PG_TRIGGER\",\"verified\":\"$PG_VERIFIED\",\"rollback\":\"$PG_ROLLBACK\",\"linked\":\"$PG_LINKED\",\"framework_docs\":\"$PG_FRAMEWORK\",\"category\":\"$PG_CATEGORY\"}'::jsonb,
  'ainchors'
);" 2>&1)
    PG_RC=$?
    set -e
    if [[ $PG_RC -eq 0 ]]; then
      echo "[pg] ✅ $CHG_ID inserted into state_changes" >&2
      PG_ERROR=""
      break
    fi
    PG_ERROR="$PG_STDERR"
    echo "[pg] ⚠️  attempt $attempt/3 failed for $CHG_ID (exit $PG_RC)" >&2
    if [[ $attempt -lt 3 ]]; then
      sleep 2
    fi
  done

  if [[ -n "$PG_ERROR" ]]; then
    PG_OK=false
    echo "[pg] ❌ All 3 INSERT attempts failed for $CHG_ID" >&2
    echo "[pg]    Last error: $PG_ERROR" >&2

    # ── Write dead-letter record ────────────────────────────────────────────
    DEAD_LETTER_FILE="$HOME/.openclaw/workspace/state/chg-pg-dead-letter.json"
    DL_ENTRY=$(/opt/homebrew/bin/jq -n \
      --arg changeId "$CHG_ID" \
      --arg title "$TITLE" \
      --arg ts "$TS" \
      --arg error "$PG_ERROR" \
      --argjson markdownOk true \
      --argjson notionOk false \
      '{
        changeId: $changeId,
        title: $title,
        timestamp: $ts,
        error: $error,
        markdownOk: $markdownOk,
        notionOk: $notionOk
      }' 2>/dev/null)
    if [[ -n "$DL_ENTRY" ]]; then
      echo "$DL_ENTRY" > "$DEAD_LETTER_FILE"
      echo "[dl] ⚠️  Dead-letter record written to $DEAD_LETTER_FILE" >&2
    else
      echo "[dl] ❌ Failed to write dead-letter record (jq unavailable?) — dumping raw" >&2
      cat > "$DEAD_LETTER_FILE" <<DLRAW
{
  "changeId": "$CHG_ID",
  "title": "$TITLE",
  "timestamp": "$TS",
  "error": "$PG_ERROR",
  "markdownOk": true,
  "notionOk": false
}
DLRAW
    fi

    # Fail closed — exit non-zero so callers know PG write failed
    exit 7
  fi
fi
# TKT-0726: Emit created event for CHG (best-effort)
EVENT_SCRIPT="${SCRIPT_DIR_CHG}/pg-write-event.sh"
if [[ -x "$EVENT_SCRIPT" ]]; then
  CHG_PAYLOAD=$(/opt/homebrew/bin/jq -n --arg chg "$CHG_ID" --arg title "$TITLE" --arg type "$TYPE" --arg source "$SOURCE" '{change_id: $chg, title: $title, type: $type, source: $source}' 2>/dev/null || echo '{"change_id":"'"$CHG_ID"'"}')
  bash "$EVENT_SCRIPT" --actor "$SOURCE" --event-type "created" --entity-type "chg" --entity-id "$CHG_ID" --payload "$CHG_PAYLOAD" --prev-state "{}" --new-state "$CHG_PAYLOAD" > /dev/null 2>&1 || echo "WARNING: event write failed for $CHG_ID" >&2
fi

# TKT-0720: Insert entity_links for --linked value (best-effort)
if [[ -n "$LINKED" && "$LINKED" != "none" ]]; then
  linked_pairs=$(parse_linked_line "$LINKED" 2>/dev/null) || true
  if [[ -n "$linked_pairs" ]]; then
    to_pairs=()
    while IFS= read -r pair; do
      [[ -n "$pair" ]] && to_pairs+=("$pair")
    done <<< "$linked_pairs"
    if [[ ${#to_pairs[@]} -gt 0 ]]; then
      insert_entity_links "chg" "$CHG_ID" "relates-to" "live-write:changelog-append" "${to_pairs[@]}" > /dev/null 2>&1 || true
    fi
  fi
fi

# ── Notion sync (best-effort — failure does NOT block CHG logging) ──────────────
NOTION_KEY_FILE="$HOME/.config/notion/api_key"
# CHG records go to Archive DB (DB C: Completed-Archived) — TKT-0392-D
NOTION_DB_ID="39d890b6-ece8-81fd-8826-d250c3c2df13"
notion_sync_chg() {
  local retry=0
  local max_retries=2
  while [[ $retry -le $max_retries ]]; do
    if [[ -f "$NOTION_KEY_FILE" ]] && command -v jq > /dev/null && command -v curl > /dev/null; then
      NOTION_KEY=$(cat "$NOTION_KEY_FILE")
      N_TODAY=$(date '+%Y-%m-%d')
      N_TITLE="[${CHG_ID}] ${TITLE}"
      # Build CHG details for Description (truncated to 2000 chars)
      N_DESC="Type: ${TYPE} | Source: ${SOURCE} | Trigger: ${TRIGGER} | Changed: ${CHANGED} | Why: ${WHY} | Verified: ${VERIFIED} | Rollback: ${ROLLBACK}"
      N_DESC="${N_DESC:0:2000}"
      N_PAYLOAD=$(jq -n \
        --arg db  "$NOTION_DB_ID" \
        --arg ttl "$N_TITLE" \
        --arg cdt "$N_TODAY" \
        --arg dsc "$N_DESC" \
        '{
          parent: {database_id: $db},
          properties: {
            "Title":         {title:  [{text: {content: $ttl}}]},
            "Status":        {select: {name: "Done"}},
            "Type":          {select: {name: "CHG"}},
            "Completed Date": {date:   {start: $cdt}},
            "Description":   {rich_text: [{text: {content: $dsc}}]}
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
          return 0
        fi
      fi
    fi
    retry=$((retry + 1))
    if [[ $retry -le $max_retries ]]; then
      echo "[notion] ⚠️  sync failed for $CHG_ID, retry $retry/$max_retries..." >&2
      sleep 2
    fi
  done
  echo "[notion] ⚠️  sync failed for $CHG_ID after $max_retries retries (CHG still logged)" >&2
  return 1
}
notion_sync_chg
