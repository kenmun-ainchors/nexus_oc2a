#!/bin/zsh
# ollama-usage-scraper.sh — Scrape Ollama Cloud usage dashboard for real request counts
# Uses OpenClaw browser automation to extract data-usage-segment values.
# Updates cost-state.json → turnsLimit with live data from Ollama's own dashboard.
#
# Prerequisites:
#   - OpenClaw browser must be running (openclaw browser start)
#   - Must be signed into ollama.com in the browser profile
#   - Session cookie must be valid
#
# Exit codes: 0=OK, 1=not signed in, 2=browser not running, 3=extraction failed, 4=update failed

set -euo pipefail

WORKSPACE="${WORKSPACE:-$HOME/.openclaw/workspace}"
COST_STATE="$WORKSPACE/state/cost-state.json"
JQ="${JQ:-/opt/homebrew/bin/jq}"
NOW="$(date +%Y-%m-%dT%H:%M:%S%z)"
BROWSER_CMD="openclaw browser"

# --- Parse args ---
MODE="update"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --report) MODE="report"; shift ;;
    --dry-run) MODE="dry-run"; shift ;;
    *) echo "Unknown arg: $1"; exit 2 ;;
  esac
done

# --- Check browser is running ---
STATUS_OUT=$(eval "$BROWSER_CMD status" 2>&1) || true
if ! echo "$STATUS_OUT" | grep -q 'running: true'; then
  echo "ERROR: Browser not running. Start with: openclaw browser start" >&2
  exit 2
fi

# --- Navigate to usage page ---
eval "$BROWSER_CMD navigate 'https://ollama.com/settings'" 2>/dev/null || true
sleep 2

# --- Check if signed in ---
PAGE_TEXT=$(eval "$BROWSER_CMD evaluate --fn '() => document.body.innerText.substring(0, 500)'" 2>/dev/null || echo "")
if echo "$PAGE_TEXT" | grep -q "Sign in"; then
  echo "ERROR: Not signed into ollama.com. Sign in first." >&2
  exit 1
fi

# --- Extract usage data ---
EXTRACT_JS=$(cat << 'JSEOF'
() => {
  const meters = document.querySelectorAll('[data-usage-meter]');
  const result = { session: null, weekly: null, balance: null };

  meters.forEach((meter, i) => {
    const segments = meter.querySelectorAll('[data-usage-segment]');
    const data = { models: {}, total: 0 };

    segments.forEach(seg => {
      const model = seg.dataset.model || '';
      const requests = parseInt(seg.dataset.requests || '0', 10);
      if (model) {
        data.models[model] = requests;
        data.total += requests;
      }
    });

    if (i === 0) result.session = data;
    else if (i === 1) result.weekly = data;
  });

  const body = document.body.innerText;
  const sessionPctMatch = body.match(/Session usage\s+(\d+\.?\d*)%\s+used/);
  const weeklyPctMatch = body.match(/Weekly usage\s+(\d+\.?\d*)%\s+used/);
  if (sessionPctMatch) result.session.pct = parseFloat(sessionPctMatch[1]);
  if (weeklyPctMatch) result.weekly.pct = parseFloat(weeklyPctMatch[1]);

  const timeEls = document.querySelectorAll('[data-time]');
  const resetTimes = [];
  timeEls.forEach(el => {
    const iso = el.dataset.time;
    if (iso) resetTimes.push(iso);
  });
  if (resetTimes.length >= 1) result.session.resetTime = resetTimes[0];
  if (resetTimes.length >= 2) result.weekly.resetTime = resetTimes[1];

  const balanceMatch = body.match(/Balance remaining\s+\$?([\d.]+)/);
  if (balanceMatch) result.balance = parseFloat(balanceMatch[1]);

  return JSON.stringify(result);
}
JSEOF
)

USAGE_JSON=$(eval "$BROWSER_CMD evaluate --fn '$EXTRACT_JS'" 2>/dev/null || echo "{}")

# --- Parse extracted data ---
SESSION_TOTAL=$(echo "$USAGE_JSON" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('session',{}).get('total',0))" 2>/dev/null || echo "0")
WEEKLY_TOTAL=$(echo "$USAGE_JSON" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('weekly',{}).get('total',0))" 2>/dev/null || echo "0")
WEEKLY_PCT=$(echo "$USAGE_JSON" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('weekly',{}).get('pct',0))" 2>/dev/null || echo "0")
SESSION_PCT=$(echo "$USAGE_JSON" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('session',{}).get('pct',0))" 2>/dev/null || echo "0")
BALANCE=$(echo "$USAGE_JSON" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('balance',0))" 2>/dev/null || echo "0")
MODEL_JSON=$(echo "$USAGE_JSON" | python3 -c "
import json, sys
d = json.load(sys.stdin)
weekly = d.get('weekly', {}).get('models', {})
print(json.dumps(weekly))
" 2>/dev/null || echo "{}")

if [[ "$WEEKLY_TOTAL" == "0" ]]; then
  echo "ERROR: Failed to extract usage data from page. Raw: $(echo "$USAGE_JSON" | head -c 200)" >&2
  exit 3
fi

# --- Compute our 30k budget metrics ---
WEEKLY_LIMIT=30000
OUR_PCT=$(echo "scale=2; $WEEKLY_TOTAL * 100 / $WEEKLY_LIMIT" | bc | sed 's/^0*//; s/^\./0./')
REMAINING=$(( WEEKLY_LIMIT - WEEKLY_TOTAL ))

# Burn rate: requests per hour since Monday 10:00 MYT (Asia/Kuala_Lumpur)
MYT_DOW=$(TZ=Asia/Kuala_Lumpur date +%u)
DAYS_SINCE_MON=$(( MYT_DOW - 1 ))
WINDOW_START_EPOCH=$(TZ=Asia/Kuala_Lumpur date -v-${DAYS_SINCE_MON}d -v10H -v0M -v0S +%s 2>/dev/null || echo 0)
NOW_EPOCH=$(date +%s)
HOURS_ELAPSED=$(echo "scale=2; ($NOW_EPOCH - $WINDOW_START_EPOCH) / 3600" | bc 2>/dev/null || echo 0)
if [[ "$(echo "$HOURS_ELAPSED > 0" | bc 2>/dev/null)" == "1" ]]; then
  BURN_RATE=$(echo "scale=1; $WEEKLY_TOTAL / $HOURS_ELAPSED" | bc)
else
  BURN_RATE="0"
fi

# Projected exhaustion
if [[ "$(echo "$BURN_RATE > 0" | bc 2>/dev/null)" == "1" ]]; then
  HOURS_TO_EXHAUST=$(echo "scale=0; $REMAINING / $BURN_RATE" | bc)
  EXHAUST_EPOCH=$(( NOW_EPOCH + HOURS_TO_EXHAUST * 3600 ))
  PROJ_EXHAUST=$(TZ=Asia/Kuala_Lumpur date -r $EXHAUST_EPOCH +%Y-%m-%dT%H:%M:%S%z 2>/dev/null || echo "unknown")
else
  PROJ_EXHAUST="N/A"
fi

# --- Report mode ---
if [[ "$MODE" == "report" || "$MODE" == "dry-run" ]]; then
  echo "=== Ollama Cloud Usage (from dashboard) ==="
  echo "Scraped at: $NOW"
  echo ""
  echo "Session: $SESSION_TOTAL requests ($SESSION_PCT% of session limit)"
  echo "Weekly: $WEEKLY_TOTAL requests ($WEEKLY_PCT% of Ollama weekly limit)"
  echo "Balance: \$$BALANCE"
  echo ""
  echo "=== Our 30k Budget ==="
  echo "Used: $WEEKLY_TOTAL / $WEEKLY_LIMIT ($OUR_PCT%)"
  echo "Remaining: $REMAINING"
  echo "Burn rate: $BURN_RATE req/hr"
  echo "Projected exhaustion: $PROJ_EXHAUST"
  echo ""
  echo "By model (weekly):"
  echo "$USAGE_JSON" | python3 -c "
import json, sys
d = json.load(sys.stdin)
models = d.get('weekly', {}).get('models', {})
for m, c in sorted(models.items(), key=lambda x: -x[1]):
    print(f'  {m:<35} {c:>6} requests')
"
  if [[ "$MODE" == "dry-run" ]]; then
    echo ""
    echo "[DRY RUN — cost-state.json NOT updated]"
  fi
  exit 0
fi

# --- Update cost-state.json ---
if [[ ! -f "$COST_STATE" ]]; then
  echo "ERROR: cost-state.json not found at $COST_STATE" >&2
  exit 4
fi

WINDOW_START=$(TZ=Asia/Kuala_Lumpur date -v-${DAYS_SINCE_MON}d -v10H -v0M -v0S +%Y-%m-%dT%H:%M:%S%z)
WINDOW_END=$(TZ=Asia/Kuala_Lumpur date -v+$((7 - DAYS_SINCE_MON))d -v10H -v0M -v0S +%Y-%m-%dT%H:%M:%S%z)

TMPFILE=$(mktemp)
$JQ --arg total "$WEEKLY_TOTAL" \
    --arg pct "$OUR_PCT" \
    --arg remaining "$REMAINING" \
    --arg burn "$BURN_RATE" \
    --arg exhaust "$PROJ_EXHAUST" \
    --arg wstart "$WINDOW_START" \
    --arg wend "$WINDOW_END" \
    --arg updated "$NOW" \
    --arg session_total "$SESSION_TOTAL" \
    --arg session_pct "$SESSION_PCT" \
    --arg ollama_pct "$WEEKLY_PCT" \
    --arg balance "$BALANCE" \
    --argjson models "$MODEL_JSON" \
    '.turnsLimit.currentRequests = ($total | tonumber) |
     .turnsLimit.currentPct = ($pct | tonumber) |
     .turnsLimit.requestsRemaining = ($remaining | tonumber) |
     .turnsLimit.burnRateRequestsPerHour = ($burn | tonumber) |
     .turnsLimit.projectedExhaustion = $exhaust |
     .turnsLimit.currentWindowStart = $wstart |
     .turnsLimit.currentWindowEnd = $wend |
     .turnsLimit.lastUpdated = $updated |
     .turnsLimit.byModel = $models |
     .turnsLimit.modelBreakdown = $models |
     .turnsLimit.ollamaDashboardPct = ($ollama_pct | tonumber) |
     .turnsLimit.sessionRequests = ($session_total | tonumber) |
     .turnsLimit.sessionPct = ($session_pct | tonumber) |
     .turnsLimit.balance = ($balance | tonumber) |
     .turnsLimit.countingMethod = "ollama-dashboard-scrape" |
     .turnsLimit.countingLimitation = "Scraped from ollama.com/settings via browser automation. Requires valid login session. Accuracy: source of truth (Ollama'\''s own dashboard)."' \
    "$COST_STATE" > "$TMPFILE" 2>/dev/null

if [[ $? -eq 0 && -s "$TMPFILE" ]]; then
  mv "$TMPFILE" "$COST_STATE"
  echo "OK: cost-state.json updated from Ollama dashboard — $WEEKLY_TOTAL requests ($OUR_PCT% of 30k) | ollama=$WEEKLY_PCT% | balance=\$$BALANCE | $NOW"
  exit 0
else
  rm -f "$TMPFILE"
  echo "ERROR: jq update failed" >&2
  exit 4
fi
