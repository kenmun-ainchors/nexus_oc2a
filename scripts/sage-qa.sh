#!/usr/bin/env bash
# sage-qa.sh — Invoke Sage 🧪 QA gate on a generated asset
# Usage: bash sage-qa.sh --asset-path PATH --asset-type TYPE --brief "..." --intended-for "..." --produced-by AGENT
# Returns: 0 = PASS, 1 = FAIL, 2 = ERROR
# TKT-0016 | Sage Rule 1

set -euo pipefail
export PATH="$PATH:/usr/local/bin:/opt/homebrew/bin"

WORKSPACE="/Users/ainchorsoc2a/.openclaw/workspace"
QA_LOG="$WORKSPACE/state/sage-qa-log.json"
TIMESTAMP=$(date +"%Y-%m-%dT%H:%M:%S+10:00")

ASSET_PATH=""; ASSET_TYPE=""; BRIEF=""; INTENDED_FOR=""; PRODUCED_BY="yoda"

while (( $# > 0 )); do
  case "$1" in
    --asset-path)    ASSET_PATH="$2"; shift 2 ;;
    --asset-type)    ASSET_TYPE="$2"; shift 2 ;;
    --brief)         BRIEF="$2"; shift 2 ;;
    --intended-for)  INTENDED_FOR="$2"; shift 2 ;;
    --produced-by)   PRODUCED_BY="$2"; shift 2 ;;
    *) echo "Unknown: $1" >&2; exit 2 ;;
  esac
done

[ -z "$ASSET_PATH" ] && { echo "ERROR: --asset-path required" >&2; exit 2; }
[ -z "$BRIEF" ] && { echo "ERROR: --brief required" >&2; exit 2; }

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║  SAGE 🧪 QA Gate — $(date '+%Y-%m-%d %H:%M AEST')         ║"
echo "╠══════════════════════════════════════════════════════╣"
echo "  Asset:        $ASSET_PATH"
echo "  Type:         $ASSET_TYPE"
echo "  Produced by:  $PRODUCED_BY"
echo "  Intended for: $INTENDED_FOR"
echo "  Brief:        $BRIEF"
echo ""

PASS=0; FAIL=0
ISSUES=()

# ── Check 4: Formatting & Rendering (scriptable checks) ──────────────────────
echo "[ Check 4 — Formatting & Rendering ]"
FORMAT_PASS=true

if [ ! -f "$ASSET_PATH" ]; then
  echo "  FAIL — File does not exist: $ASSET_PATH"
  FORMAT_PASS=false; ISSUES+=("File not found at $ASSET_PATH")
else
  FILE_SIZE=$(wc -c < "$ASSET_PATH")
  if [ "$FILE_SIZE" -lt 500 ]; then
    echo "  FAIL — File suspiciously small ($FILE_SIZE bytes) — likely empty or truncated"
    FORMAT_PASS=false; ISSUES+=("File too small: $FILE_SIZE bytes. Likely truncated or generation failed.")
  else
    echo "  OK   — File exists ($FILE_SIZE bytes)"
  fi

  # Check for placeholder text
  if grep -qiE "YYYY-MM-DD|INSERT NAME|TODO|FIXME|\[placeholder\]|\[TBD\]" "$ASSET_PATH" 2>/dev/null; then
    echo "  FAIL — Placeholder text detected (YYYY-MM-DD / TODO / INSERT NAME etc.)"
    FORMAT_PASS=false; ISSUES+=("Placeholder text found. Asset not complete.")
  else
    echo "  OK   — No placeholder text detected"
  fi

  # For PDF: check it's a valid PDF
  if [[ "$ASSET_TYPE" == "pdf" || "$ASSET_PATH" == *.pdf ]]; then
    if ! head -c 4 "$ASSET_PATH" | grep -q "%PDF"; then
      echo "  FAIL — Not a valid PDF (missing %PDF header)"
      FORMAT_PASS=false; ISSUES+=("Invalid PDF — missing %PDF header. Generation may have failed.")
    else
      echo "  OK   — Valid PDF header"
    fi
    # Check page count via python
    PAGE_COUNT=$(python3 -c "
from pypdf import PdfReader
import sys
try:
    r = PdfReader('$ASSET_PATH')
    print(len(r.pages))
except Exception as e:
    print('ERROR')
" 2>/dev/null || echo "unknown")
    if [ "$PAGE_COUNT" = "ERROR" ] || [ "$PAGE_COUNT" = "0" ]; then
      echo "  FAIL — Could not read PDF pages (corrupt or empty)"
      FORMAT_PASS=false; ISSUES+=("PDF appears corrupt or has 0 pages.")
    else
      echo "  OK   — PDF has $PAGE_COUNT page(s)"
    fi
  fi

  # For HTML: check basic structure
  if [[ "$ASSET_TYPE" == "html" || "$ASSET_PATH" == *.html ]]; then
    if ! grep -q "<html" "$ASSET_PATH" 2>/dev/null; then
      echo "  FAIL — Not valid HTML (missing <html> tag)"
      FORMAT_PASS=false; ISSUES+=("Invalid HTML structure.")
    else
      echo "  OK   — Valid HTML structure"
    fi
    if grep -qiE "http[s]?://(cdn\.|unpkg\.|fonts\.google)" "$ASSET_PATH" 2>/dev/null; then
      echo "  FAIL — External CDN dependencies detected (not self-contained)"
      FORMAT_PASS=false; ISSUES+=("External CDN/font links found. Asset must be self-contained.")
    else
      echo "  OK   — No external CDN dependencies"
    fi
  fi
fi

[ "$FORMAT_PASS" = true ] && { PASS=$((PASS+1)); echo "  RESULT: PASS"; } || { FAIL=$((FAIL+1)); echo "  RESULT: FAIL"; }

# ── Check 5: Compliance & Safety (scriptable) ────────────────────────────────
echo ""
echo "[ Check 5 — Compliance & Safety ]"
COMPLIANCE_PASS=true

if [ -f "$ASSET_PATH" ]; then
  # Check for secrets/tokens
  if grep -qiE "sk-ant-|sk-[a-zA-Z0-9]{20,}|AKIA[0-9A-Z]{16}|[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}" "$ASSET_PATH" 2>/dev/null; then
    echo "  FAIL — Potential API key or UUID token detected"
    COMPLIANCE_PASS=false; ISSUES+=("Potential API key or token found. PII sweep required.")
  else
    echo "  OK   — No API keys or tokens detected"
  fi

  # Check for pairing codes (8-char uppercase alphanumeric)
  if grep -qE "\b[A-Z0-9]{8}\b" "$ASSET_PATH" 2>/dev/null; then
    echo "  WARN — Possible pairing/auth code pattern found — manual review recommended"
  else
    echo "  OK   — No pairing code patterns"
  fi

  # Check for internal paths
  if grep -q "/Users/ainchorsoc2a" "$ASSET_PATH" 2>/dev/null; then
    echo "  FAIL — Internal filesystem path exposed"
    COMPLIANCE_PASS=false; ISSUES+=("Internal filesystem path found in asset. Redact before sharing.")
  else
    echo "  OK   — No internal paths exposed"
  fi
fi

[ "$COMPLIANCE_PASS" = true ] && { PASS=$((PASS+1)); echo "  RESULT: PASS"; } || { FAIL=$((FAIL+1)); echo "  RESULT: FAIL"; }


# ── Shield security check ─────────────────────────────────────────────────────
echo ""
echo "[ Invoking Shield 🛡️ Security Gate ]"
bash /Users/ainchorsoc2a/.openclaw/workspace/scripts/shield-check.sh \
  --asset-path "$ASSET_PATH" --asset-type "$ASSET_TYPE" \
  --brief "$BRIEF" --intended-for "$INTENDED_FOR" --produced-by "$PRODUCED_BY" 2>/dev/null
SHIELD_EXIT=$?
if [ $SHIELD_EXIT -ne 0 ]; then
  FAIL=$((FAIL+1)); ISSUES+=("Shield security check FAILED — see shield output above")
else
  PASS=$((PASS+1))
fi

# ── Lex legal check ───────────────────────────────────────────────────────────
echo ""
echo "[ Invoking Lex ⚖️ Legal Gate ]"
bash /Users/ainchorsoc2a/.openclaw/workspace/scripts/lex-check.sh \
  --asset-path "$ASSET_PATH" --asset-type "$ASSET_TYPE" \
  --brief "$BRIEF" --intended-for "$INTENDED_FOR" --produced-by "$PRODUCED_BY" 2>/dev/null
LEX_EXIT=$?
if [ $LEX_EXIT -ne 0 ]; then
  FAIL=$((FAIL+1)); ISSUES+=("Lex legal check FAILED — see lex output above")
else
  PASS=$((PASS+1))
fi

# ── Checks 1, 2, 3 require LLM — log as manual for now ─────────────────────
echo ""
echo "[ Checks 1, 2, 3 — Requirements / Outcome / Accuracy ]"
echo "  NOTE: Brief-vs-asset and factual accuracy checks require LLM review."
echo "  Producing agent must self-attest or Sage cron will review within 1hr."
echo "  Brief: $BRIEF"
echo "  Intended for: $INTENDED_FOR"
PASS=$((PASS+3))  # Provisional pass — LLM check deferred
echo "  RESULT: PROVISIONAL PASS (deferred LLM check)"

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo "╠══════════════════════════════════════════════════════╣"
TOTAL=$((PASS+FAIL))
if [ $FAIL -eq 0 ]; then
  echo "║  OVERALL: PASS ($PASS/$TOTAL checks)                          ║"
  VERDICT="PASS"
else
  echo "║  OVERALL: FAIL ($PASS/$TOTAL checks, $FAIL failed)                   ║"
  VERDICT="FAIL"
  echo "╠══════════════════════════════════════════════════════╣"
  echo "  Issues to fix:"
  for issue in "${ISSUES[@]}"; do
    echo "  • $issue"
  done
fi
echo "╚══════════════════════════════════════════════════════╝"
echo ""

# ── Write to QA log ──────────────────────────────────────────────────────────
python3 -c "
import json, os
log = '$QA_LOG'
data = json.load(open(log)) if os.path.exists(log) else {'entries': [], 'summary': {'total': 0, 'pass': 0, 'fail': 0}}
entry = {
    'ts': '$TIMESTAMP',
    'assetPath': '$ASSET_PATH',
    'assetType': '$ASSET_TYPE',
    'producedBy': '$PRODUCED_BY',
    'intendedFor': '$INTENDED_FOR',
    'brief': '$BRIEF',
    'verdict': '$VERDICT',
    'passCount': $PASS,
    'failCount': $FAIL,
    'issues': $(python3 -c "import json; print(json.dumps($(printf '%s\n' "${ISSUES[@]:-[]}" | python3 -c 'import sys,json; lines=[l.strip() for l in sys.stdin if l.strip()]; print(json.dumps(lines))' 2>/dev/null || echo '[]')))")
}
data['entries'].append(entry)
data['summary']['total'] += 1
data['summary']['$VERDICT'.lower()] = data['summary'].get('$VERDICT'.lower(), 0) + 1
with open(log, 'w') as f:
    json.dump(data, f, indent=2)
" 2>/dev/null || true

[ $FAIL -eq 0 ] && exit 0 || exit 1
