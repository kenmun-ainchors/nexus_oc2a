#!/usr/bin/env bash
# shield-check.sh — Shield 🛡️ Security Assurance Gate
# Usage: bash shield-check.sh --asset-path PATH --asset-type TYPE --brief "..." --intended-for "..." --produced-by AGENT
# Returns: 0 = PASS, 1 = FAIL, 2 = ERROR
# TKT-0017 | Shield Rule 1

export PATH="$PATH:/usr/local/bin:/opt/homebrew/bin"

WORKSPACE="/Users/ainchorsoc2a/.openclaw/workspace"
QA_LOG="$WORKSPACE/state/shield-qa-log.json"
TIMESTAMP=$(date +"%Y-%m-%dT%H:%M:%S+10:00")

ASSET_PATH=""; ASSET_TYPE=""; BRIEF=""; INTENDED_FOR=""; PRODUCED_BY="yoda"

while (( $# > 0 )); do
  case "$1" in
    --asset-path)   ASSET_PATH="$2"; shift 2 ;;
    --asset-type)   ASSET_TYPE="$2"; shift 2 ;;
    --brief)        BRIEF="$2"; shift 2 ;;
    --intended-for) INTENDED_FOR="$2"; shift 2 ;;
    --produced-by)  PRODUCED_BY="$2"; shift 2 ;;
    *) echo "Unknown: $1" >&2; exit 2 ;;
  esac
done

[ -z "$ASSET_PATH" ] && { echo "ERROR: --asset-path required" >&2; exit 2; }

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║  SHIELD 🛡️  Security Gate — $(date '+%Y-%m-%d %H:%M AEST')    ║"
echo "╠══════════════════════════════════════════════════════╣"
echo "  Asset:        $(basename "$ASSET_PATH")"
echo "  Intended for: $INTENDED_FOR"
echo "  Produced by:  $PRODUCED_BY"
echo ""

PASS=0; FAIL=0; ISSUES=()

if [ ! -f "$ASSET_PATH" ]; then
  echo "  ERROR — File not found: $ASSET_PATH"
  exit 2
fi

CONTENT=$(cat "$ASSET_PATH" 2>/dev/null || echo "")

# ── S1: Secrets & Credentials ────────────────────────────────────────────────
echo "[ S1 — Secrets & Credentials ]"
S1_FAIL=false

# API key patterns
if echo "$CONTENT" | grep -qE "sk-ant-[a-zA-Z0-9\-]{10,}"; then
  S1_FAIL=true; ISSUES+=("S1: Anthropic API key pattern detected")
  echo "  FAIL — Anthropic API key pattern found"
fi
if echo "$CONTENT" | grep -qE "sk-[a-zA-Z0-9]{20,}"; then
  S1_FAIL=true; ISSUES+=("S1: Generic API key pattern detected")
  echo "  FAIL — Generic API key pattern found"
fi
if echo "$CONTENT" | grep -qE "AKIA[0-9A-Z]{16}"; then
  S1_FAIL=true; ISSUES+=("S1: AWS access key detected")
  echo "  FAIL — AWS key pattern found"
fi
# Pairing codes (8+ uppercase alphanumeric — skip common words)
PAIRING=$(echo "$CONTENT" | grep -oE '\b[A-Z0-9]{8,12}\b' | grep -E '[0-9]' | grep -vE '^(PLACEHOLDER|REDACTED|CHG[0-9]+|TKT[0-9]+|INC[0-9]+|US[0-9]+|API[0-9]*)$' | head -3)
if [ -n "$PAIRING" ]; then
  echo "  WARN — Possible auth/pairing code pattern: $(echo "$PAIRING" | head -1) — manual review recommended"
fi
# Bearer/password patterns
if echo "$CONTENT" | grep -iqE "bearer [a-zA-Z0-9\._\-]{20,}|password[:=]\s*[^\s]{8,}"; then
  S1_FAIL=true; ISSUES+=("S1: Bearer token or password pattern detected")
  echo "  FAIL — Bearer token or password pattern found"
fi

if [ "$S1_FAIL" = false ]; then
  PASS=$((PASS+1)); echo "  PASS — No credential patterns detected"
else
  FAIL=$((FAIL+1))
fi

# ── S2: Internal System Exposure ─────────────────────────────────────────────
echo ""
echo "[ S2 — Internal System Exposure ]"
S2_FAIL=false

if echo "$CONTENT" | grep -qE "/Users/ainchorsoc2a|~/.openclaw|/opt/homebrew"; then
  S2_FAIL=true; ISSUES+=("S2: Internal filesystem path exposed")
  echo "  FAIL — Internal path exposed (/Users/ainchorsoc2a or ~/.openclaw)"
fi
if echo "$CONTENT" | grep -qE "192\.168\.[0-9]+\.[0-9]+|10\.[0-9]+\.[0-9]+\.[0-9]+"; then
  S2_FAIL=true; ISSUES+=("S2: Internal IP address detected")
  echo "  FAIL — Internal IP address found"
fi
# Session/run UUIDs (OpenClaw internal)
if echo "$CONTENT" | grep -qE "agent:main:[a-z]+:[a-f0-9\-]{36}"; then
  S2_FAIL=true; ISSUES+=("S2: Internal OpenClaw session ID exposed")
  echo "  FAIL — Internal session ID found"
fi
if echo "$CONTENT" | grep -qE "18789|11434"; then
  echo "  WARN — Internal port numbers detected (18789/11434) — verify intentional"
fi

if [ "$S2_FAIL" = false ]; then
  PASS=$((PASS+1)); echo "  PASS — No internal system details exposed"
else
  FAIL=$((FAIL+1))
fi

# ── S3: PII & Personal Data ───────────────────────────────────────────────────
echo ""
echo "[ S3 — PII & Personal Data ]"
S3_FAIL=false

# Phone numbers (AU format)
if echo "$CONTENT" | grep -qE "\+614[0-9]{8}|\b04[0-9]{8}\b"; then
  echo "  WARN — Australian mobile number detected — verify intentional for this recipient"
fi
# Telegram chat IDs (numeric, not in an expected context)
if echo "$CONTENT" | grep -qE "\b8574109706\b|\b8141152780\b"; then
  S3_FAIL=true; ISSUES+=("S3: Internal Telegram chat ID exposed")
  echo "  FAIL — Internal Telegram chat ID found (not for external sharing)"
fi
# Email addresses not belonging to recipient
EMAILS=$(echo "$CONTENT" | grep -oE "[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}" | sort -u | head -5)
if [ -n "$EMAILS" ]; then
  echo "  INFO — Email addresses found: $(echo "$EMAILS" | tr '\n' ' ') — verify appropriate for recipient"
fi

if [ "$S3_FAIL" = false ]; then
  PASS=$((PASS+1)); echo "  PASS — No PII breach detected (manual review for emails above if any)"
else
  FAIL=$((FAIL+1))
fi

# ── S4: Data Classification ────────────────────────────────────────────────
echo ""
echo "[ S4 — Data Classification ]"
# Scriptable: check for 'INTERNAL ONLY' / 'CONFIDENTIAL' markers vs external recipient
if echo "$CONTENT" | grep -iqE "INTERNAL ONLY|DO NOT DISTRIBUTE|NOT FOR EXTERNAL"; then
  if [[ "$INTENDED_FOR" != *"Ken"* ]] && [[ "$INTENDED_FOR" != *"Yoda"* ]] && [[ "$INTENDED_FOR" != *"internal"* ]]; then
    FAIL=$((FAIL+1))
    ISSUES+=("S4: Asset marked INTERNAL ONLY but intended for external recipient: $INTENDED_FOR")
    echo "  FAIL — Asset marked INTERNAL ONLY but recipient is external"
  else
    PASS=$((PASS+1)); echo "  PASS — Internal marking consistent with recipient"
  fi
else
  PASS=$((PASS+1)); echo "  PASS — No conflicting classification markers"
fi

# ── S5: External Send Risk ─────────────────────────────────────────────────
echo ""
echo "[ S5 — External Send Risk ]"
S5_FAIL=false

# System architecture terms that shouldn't go external
if echo "$CONTENT" | grep -iqE "openclaw\.json|auth-profiles\.json|critical-config-baseline|model-drift-violations"; then
  S5_FAIL=true; ISSUES+=("S5: Internal system config file names exposed in external asset")
  echo "  FAIL — Internal config file names present (security through obscurity risk)"
fi
# Incident details
if echo "$CONTENT" | grep -iqE "INC-[0-9]+|incident log|outage root cause" && [[ "$INTENDED_FOR" != *"Ken"* ]] && [[ "$INTENDED_FOR" != *"Angie"* ]]; then
  echo "  WARN — Incident/outage language detected for external recipient — verify appropriate"
fi

if [ "$S5_FAIL" = false ]; then
  PASS=$((PASS+1)); echo "  PASS — No high-risk external exposure patterns detected"
else
  FAIL=$((FAIL+1))
fi

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo "╠══════════════════════════════════════════════════════╣"
TOTAL=$((PASS+FAIL))
if [ $FAIL -eq 0 ]; then
  VERDICT="PASS"
  echo "║  SHIELD OVERALL: PASS ($PASS/$TOTAL)                        ║"
else
  VERDICT="FAIL"
  echo "║  SHIELD OVERALL: FAIL ($PASS/$TOTAL, $FAIL failed)                ║"
  echo "  Issues:"
  for issue in "${ISSUES[@]}"; do echo "  • $issue"; done
fi
echo "╚══════════════════════════════════════════════════════╝"
echo ""

# Write to log
python3 -c "
import json, os
log = '$QA_LOG'
data = json.load(open(log)) if os.path.exists(log) else {'entries':[],'summary':{'total':0,'pass':0,'fail':0}}
data['entries'].append({'ts':'$TIMESTAMP','asset':'$ASSET_PATH','producedBy':'$PRODUCED_BY','intendedFor':'$INTENDED_FOR','verdict':'$VERDICT','pass':$PASS,'fail':$FAIL,'issues':$(python3 -c "import json; print(json.dumps([]))" 2>/dev/null || echo '[]')})
data['summary']['total']+=1
data['summary']['$VERDICT'.lower()]=data['summary'].get('$VERDICT'.lower(),0)+1
open(log,'w').write(json.dumps(data,indent=2))
" 2>/dev/null || true

[ $FAIL -eq 0 ] && exit 0 || exit 1
