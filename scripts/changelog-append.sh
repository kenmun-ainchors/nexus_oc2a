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
TYPE=""; SOURCE=""; TITLE=""; TRIGGER=""; CHANGED=""; WHY=""; VERIFIED=""; ROLLBACK="N/A"; LINKED=""

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
    --linked)   LINKED="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

# Validate required
for var in TYPE SOURCE TITLE TRIGGER CHANGED WHY VERIFIED; do
  if [[ -z "${(P)var}" ]]; then
    echo "ERROR: --${var:l} is required" >&2
    exit 2
  fi
done

# Allowed values
case "$TYPE" in
  config|script|cron|rule|agent|infra|data|doc) ;;
  *) echo "ERROR: --type must be one of: config|script|cron|rule|agent|infra|data|doc" >&2; exit 3 ;;
esac
case "$SOURCE" in
  ken-prompt|auto-heal|incident-recovery|scheduled|manual) ;;
  *) echo "ERROR: --source must be one of: ken-prompt|auto-heal|incident-recovery|scheduled|manual" >&2; exit 4 ;;
esac

# Find next CHG ID
LAST_ID=$(grep -oE 'CHG-[0-9]{4}' "$CHANGELOG" | head -1 | sed 's/CHG-//')
if [[ -z "$LAST_ID" ]]; then
  NEXT=1
else
  NEXT=$((10#$LAST_ID + 1))
fi
CHG_ID=$(printf "CHG-%04d" "$NEXT")

TS=$(date '+%Y-%m-%d %H:%M AEST')

# Build entry
ENTRY="## ${TS} — [${CHG_ID}] ${TITLE}
**Type:** ${TYPE}
**Source:** ${SOURCE}
**Trigger:** ${TRIGGER}
**What changed:** ${CHANGED}
**Why:** ${WHY}
**Verification:** ${VERIFIED}
**Rollback:** ${ROLLBACK}
**Linked:** ${LINKED:-none}
---
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
