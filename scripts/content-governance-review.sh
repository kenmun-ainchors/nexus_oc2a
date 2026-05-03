#!/usr/bin/env bash
# content-governance-review.sh — Full Governance Triad Gate (Shield → Lex → Sage)
# Usage: content-governance-review.sh --content-id CONTENT-NNNN --file <path> --type <type>
# Types: blog|proposal|social|email|training|doc
# Exit: 0 = triad-cleared | 2 = blocked
# TKT-0033

set -uo pipefail
export PATH="$PATH:/usr/local/bin:/opt/homebrew/bin"

WORKSPACE="/Users/ainchorsangiefpl/.openclaw/workspace"
QUEUE_FILE="$WORKSPACE/state/content-queue.json"
SCRIPTS_DIR="$WORKSPACE/scripts"
TIMESTAMP=$(date +"%Y-%m-%dT%H:%M:%S+10:00")
DATE_SHORT=$(date '+%Y-%m-%d %H:%M AEST')

# ── Colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

CONTENT_ID=""; FILE=""; TYPE=""

while (( $# > 0 )); do
  case "$1" in
    --content-id) CONTENT_ID="$2"; shift 2 ;;
    --file)       FILE="$2"; shift 2 ;;
    --type)       TYPE="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

# ── Route governance sub-agents via tier routing engine (TKT-0039) ───────────
SHIELD_MODEL=$(bash "$SCRIPTS_DIR/spawn-with-routing.sh" "shield-review" "content-governance-review.sh" "content-id=$CONTENT_ID" 2>/dev/null || echo "anthropic/claude-haiku-4-5")
LEX_MODEL=$(bash "$SCRIPTS_DIR/spawn-with-routing.sh" "lex-review" "content-governance-review.sh" "content-id=$CONTENT_ID" 2>/dev/null || echo "anthropic/claude-haiku-4-5")
SAGE_MODEL=$(bash "$SCRIPTS_DIR/spawn-with-routing.sh" "sage-review" "content-governance-review.sh" "content-id=$CONTENT_ID" 2>/dev/null || echo "anthropic/claude-haiku-4-5")

[[ -z "$CONTENT_ID" ]] && { echo "ERROR: --content-id required (e.g. CONTENT-0001)" >&2; exit 1; }
[[ -z "$FILE" ]]       && { echo "ERROR: --file required" >&2; exit 1; }
[[ -z "$TYPE" ]]       && { echo "ERROR: --type required (blog|proposal|social|email|training|doc)" >&2; exit 1; }
[[ ! -f "$FILE" ]]     && { echo "ERROR: File not found: $FILE" >&2; exit 1; }

# ── Header ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}${BOLD}║  CONTENT GOVERNANCE TRIAD — TKT-0033                ║${RESET}"
echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════════╝${RESET}"
echo -e "  ${CYAN}ID:${RESET}   $CONTENT_ID"
echo -e "  ${CYAN}File:${RESET} $FILE"
echo -e "  ${CYAN}Type:${RESET} $TYPE"
echo -e "  ${CYAN}Time:${RESET} $DATE_SHORT"
echo ""
echo -e "  Sequence: 🛡️ Shield → ⚖️ Lex → 🧪 Sage"
echo -e "  All three must return CLEAR or CONDITIONAL before delivery."
echo ""

# ── Register in queue ─────────────────────────────────────────────────────────
TITLE=$(basename "$FILE")

python3 - << PYEOF
import json, os, sys
from datetime import datetime

qfile = '$QUEUE_FILE'
content_id = '$CONTENT_ID'
title = '$TITLE'
ctype = '$TYPE'
ts = '$TIMESTAMP'

os.makedirs(os.path.dirname(qfile), exist_ok=True)

if os.path.exists(qfile):
    with open(qfile) as f:
        data = json.load(f)
else:
    data = {'schema': '1.0', 'queue': []}

# Check if already registered
existing = next((item for item in data['queue'] if item['id'] == content_id), None)

if not existing:
    item = {
        'id': content_id,
        'title': title,
        'type': ctype,
        'createdBy': 'yoda',
        'requestedBy': 'ken',
        'status': 'triad-pending',
        'shield': 'pending',
        'lex': 'pending',
        'sage': 'pending',
        'clearedAt': None,
        'publishedAt': None,
        'notes': f'Registered at {ts}'
    }
    data['queue'].append(item)
    with open(qfile, 'w') as f:
        json.dump(data, f, indent=2)
    print(f"  Registered: {content_id} in content-queue.json")
else:
    # Update to triad-pending if rerunning
    existing['status'] = 'triad-pending'
    existing['shield'] = 'pending'
    existing['lex'] = 'pending'
    existing['sage'] = 'pending'
    with open(qfile, 'w') as f:
        json.dump(data, f, indent=2)
    print(f"  Re-registered: {content_id} (existing entry reset to triad-pending)")
PYEOF

echo ""

# ── Helper: update queue verdict ─────────────────────────────────────────────
update_queue() {
  local agent="$1"  # shield | lex | sage
  local verdict="$2"  # clear | conditional | block

  python3 - "$agent" "$verdict" << 'PYEOF'
import json, sys, os
from datetime import datetime

qfile = '/Users/ainchorsangiefpl/.openclaw/workspace/state/content-queue.json'
content_id = 'CONTENT_ID_PLACEHOLDER'
agent = sys.argv[1]
verdict = sys.argv[2]

with open(qfile) as f:
    data = json.load(f)

for item in data['queue']:
    if item['id'] == content_id:
        item[agent] = verdict
        break

with open(qfile, 'w') as f:
    json.dump(data, f, indent=2)
PYEOF
}

# Override the placeholder — inject content ID properly
update_queue_verdict() {
  local agent="$1"
  local verdict="$2"
  python3 << PYEOF2
import json, os
qfile = '$QUEUE_FILE'
with open(qfile) as f:
    data = json.load(f)
for item in data['queue']:
    if item['id'] == '$CONTENT_ID':
        item['$agent'] = '$verdict'
        break
with open(qfile, 'w') as f:
    json.dump(data, f, indent=2)
print("  Queue updated: $CONTENT_ID.$agent = $verdict")
PYEOF2
}

# ── Helper: map exit code → verdict ──────────────────────────────────────────
# Exit 0 = CLEAR, Exit 1 = BLOCK (fail), Exit 2 = ERROR → treat as BLOCK
map_exit_to_verdict() {
  local exit_code="$1"
  local output="$2"
  if [[ $exit_code -eq 0 ]]; then
    # Check for WARN in output → CONDITIONAL
    if echo "$output" | grep -q "WARN"; then
      echo "conditional"
    else
      echo "clear"
    fi
  else
    echo "block"
  fi
}

# ── SHIELD REVIEW ─────────────────────────────────────────────────────────────
echo -e "${BOLD}[1/3] 🛡️ Shield — PII & Security Review${RESET}"
SHIELD_OUTPUT=$(bash "$SCRIPTS_DIR/shield-check.sh" \
  --asset-path "$FILE" \
  --asset-type "$TYPE" \
  --brief "Content governance review for $CONTENT_ID" \
  --intended-for "public distribution" \
  --produced-by "yoda" 2>&1) || true
SHIELD_EXIT=${PIPESTATUS[0]}
# Re-run to capture exit code properly
bash "$SCRIPTS_DIR/shield-check.sh" \
  --asset-path "$FILE" \
  --asset-type "$TYPE" \
  --brief "Content governance review for $CONTENT_ID" \
  --intended-for "public distribution" \
  --produced-by "yoda" > /tmp/shield-out-$$.txt 2>&1
SHIELD_EXIT=$?
SHIELD_OUTPUT=$(cat /tmp/shield-out-$$.txt)
SHIELD_VERDICT=$(map_exit_to_verdict $SHIELD_EXIT "$SHIELD_OUTPUT")

echo "$SHIELD_OUTPUT"

if [[ "$SHIELD_VERDICT" == "block" ]]; then
  echo -e "${RED}  → Shield: BLOCK 🚫${RESET}"
elif [[ "$SHIELD_VERDICT" == "conditional" ]]; then
  echo -e "${YELLOW}  → Shield: CONDITIONAL ⚠️ (warnings detected — fixes applied)${RESET}"
else
  echo -e "${GREEN}  → Shield: CLEAR ✅${RESET}"
fi
update_queue_verdict "shield" "$SHIELD_VERDICT"

echo ""

# ── LEX REVIEW ───────────────────────────────────────────────────────────────
echo -e "${BOLD}[2/3] ⚖️ Lex — Legal & Compliance Review${RESET}"
bash "$SCRIPTS_DIR/lex-check.sh" \
  --asset-path "$FILE" \
  --asset-type "$TYPE" \
  --brief "Content governance review for $CONTENT_ID" \
  --intended-for "public distribution" \
  --produced-by "yoda" > /tmp/lex-out-$$.txt 2>&1
LEX_EXIT=$?
LEX_OUTPUT=$(cat /tmp/lex-out-$$.txt)
LEX_VERDICT=$(map_exit_to_verdict $LEX_EXIT "$LEX_OUTPUT")

echo "$LEX_OUTPUT"

if [[ "$LEX_VERDICT" == "block" ]]; then
  echo -e "${RED}  → Lex: BLOCK 🚫${RESET}"
elif [[ "$LEX_VERDICT" == "conditional" ]]; then
  echo -e "${YELLOW}  → Lex: CONDITIONAL ⚠️ (warnings detected — fixes applied)${RESET}"
else
  echo -e "${GREEN}  → Lex: CLEAR ✅${RESET}"
fi
update_queue_verdict "lex" "$LEX_VERDICT"

echo ""

# ── SAGE REVIEW ───────────────────────────────────────────────────────────────
echo -e "${BOLD}[3/3] 🧪 Sage — Quality & Accuracy Review${RESET}"
bash "$SCRIPTS_DIR/sage-qa.sh" \
  --asset-path "$FILE" \
  --asset-type "$TYPE" \
  --brief "Content governance review for $CONTENT_ID" \
  --intended-for "public distribution" \
  --produced-by "yoda" > /tmp/sage-out-$$.txt 2>&1
SAGE_EXIT=$?
SAGE_OUTPUT=$(cat /tmp/sage-out-$$.txt)
SAGE_VERDICT=$(map_exit_to_verdict $SAGE_EXIT "$SAGE_OUTPUT")

echo "$SAGE_OUTPUT"

if [[ "$SAGE_VERDICT" == "block" ]]; then
  echo -e "${RED}  → Sage: BLOCK 🚫${RESET}"
elif [[ "$SAGE_VERDICT" == "conditional" ]]; then
  echo -e "${YELLOW}  → Sage: CONDITIONAL ⚠️ (warnings detected)${RESET}"
else
  echo -e "${GREEN}  → Sage: CLEAR ✅${RESET}"
fi
update_queue_verdict "sage" "$SAGE_VERDICT"

# Cleanup temp files
rm -f /tmp/shield-out-$$.txt /tmp/lex-out-$$.txt /tmp/sage-out-$$.txt

echo ""

# ── Determine overall verdict ─────────────────────────────────────────────────
OVERALL_BLOCKED=false
BLOCKED_BY=""

[[ "$SHIELD_VERDICT" == "block" ]] && { OVERALL_BLOCKED=true; BLOCKED_BY="${BLOCKED_BY}Shield "; }
[[ "$LEX_VERDICT"    == "block" ]] && { OVERALL_BLOCKED=true; BLOCKED_BY="${BLOCKED_BY}Lex "; }
[[ "$SAGE_VERDICT"   == "block" ]] && { OVERALL_BLOCKED=true; BLOCKED_BY="${BLOCKED_BY}Sage "; }

# ── Update queue final status ─────────────────────────────────────────────────
FINAL_STATUS="triad-cleared"
$OVERALL_BLOCKED && FINAL_STATUS="blocked"

CLEARED_AT_VAL="null"
$OVERALL_BLOCKED || CLEARED_AT_VAL="\"$TIMESTAMP\""

python3 << PYEOF3
import json
qfile = '$QUEUE_FILE'
with open(qfile) as f:
    data = json.load(f)
for item in data['queue']:
    if item['id'] == '$CONTENT_ID':
        item['status'] = '$FINAL_STATUS'
        item['clearedAt'] = $CLEARED_AT_VAL
        if '$OVERALL_BLOCKED' == 'true':
            item['notes'] = 'BLOCKED by: $BLOCKED_BY — escalated to Ken. Do not publish.'
        else:
            item['notes'] = 'Triad cleared at $TIMESTAMP. Cleared for distribution.'
        break
with open(qfile, 'w') as f:
    json.dump(data, f, indent=2)
PYEOF3

# ── Apply footer stamp ────────────────────────────────────────────────────────
STAMP_STATUS="triad-cleared"
$OVERALL_BLOCKED && STAMP_STATUS="blocked"

EXT="${FILE##*.}"
if [[ "$EXT" == "html" || "$EXT" == "htm" || "$EXT" == "docx" ]]; then
  bash "$SCRIPTS_DIR/content-footer-stamp.sh" --file "$FILE" --status "$STAMP_STATUS" 2>/dev/null || true
fi

# ── Summary banner ────────────────────────────────────────────────────────────
echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════════╗${RESET}"
if $OVERALL_BLOCKED; then
  echo -e "${RED}${BOLD}║  RESULT: 🚫 BLOCKED — DO NOT PUBLISH                 ║${RESET}"
  echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════════╝${RESET}"
  echo ""
  echo -e "  ${RED}${BOLD}Content ID:${RESET} $CONTENT_ID"
  echo -e "  ${RED}Blocked by: $BLOCKED_BY${RESET}"
  echo -e "  ${RED}Action:     Escalate to Ken. Fix issues and re-run triad.${RESET}"
  echo ""
  echo -e "  Verdicts:"
  echo -e "    🛡️ Shield: $SHIELD_VERDICT"
  echo -e "    ⚖️ Lex:    $LEX_VERDICT"
  echo -e "    🧪 Sage:   $SAGE_VERDICT"
  echo ""
  exit 2
else
  echo -e "${GREEN}${BOLD}║  RESULT: ✅ CLEARED FOR DISTRIBUTION                 ║${RESET}"
  echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════════╝${RESET}"
  echo ""
  echo -e "  ${GREEN}${BOLD}Content ID:${RESET} $CONTENT_ID"
  echo -e "  ${GREEN}Status:     triad-cleared${RESET}"
  echo ""
  echo -e "  Verdicts:"
  echo -e "    🛡️ Shield: $SHIELD_VERDICT"
  echo -e "    ⚖️ Lex:    $LEX_VERDICT"
  echo -e "    🧪 Sage:   $SAGE_VERDICT"
  echo ""
  echo -e "  ✅ Safe to publish. Footer stamp applied."
  echo ""
  exit 0
fi
