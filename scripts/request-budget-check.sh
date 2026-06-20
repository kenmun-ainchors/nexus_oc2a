#!/bin/zsh
# Ollama Weekly Request Budget Check
# Tracks request count (flat across all models) against weekly limit.
# SSOT: state/cost-state.json → turnsLimit object.
# Exit codes: 0=OK, 1=warning (WARN/ALERT/CRITICAL), 2=exceeded (EMERGENCY)

# Ensure UTF-8 locale so jq/zsh handle Unicode in cost-state.json.
export LC_ALL="en_US.UTF-8"
export LANG="en_US.UTF-8"

WORKSPACE="$HOME/.openclaw/workspace"
DB_READ="$WORKSPACE/scripts/db-read.sh"
COST_STATE="$WORKSPACE/state/cost-state.json"
ALERT_STATE="$WORKSPACE/state/request-budget-alert-state.json"
JQ="/opt/homebrew/bin/jq"
NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
TODAY="$(date +%Y-%m-%d)"

# Thresholds (pct of weeklyLimit)
WARN_PCT=50
ALERT_PCT=70
CRITICAL_PCT=85
EMERGENCY_PCT=95

# Parse args
MODE="check"
TARGET_AGENT=""
TARGET_WORKFLOW=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --report) MODE="report"; shift ;;
    --agent)
      MODE="agent"
      if [[ $# -lt 2 || -z "$2" || "$2" == --* ]]; then
        echo "ERROR: --agent requires an agent ID"
        exit 1
      fi
      TARGET_AGENT="$2"; shift 2 ;;
    --workflow)
      MODE="workflow"
      if [[ $# -lt 2 || -z "$2" || "$2" == --* ]]; then
        echo "ERROR: --workflow requires a workflow name"
        exit 1
      fi
      TARGET_WORKFLOW="$2"; shift 2 ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

# Verify dependencies
if [[ ! -f "$JQ" ]]; then
  echo "ERROR: jq not found at $JQ"
  exit 1
fi

# Read turnsLimit from PG (SSOT) with file fallback
# PG returns [{id, data:{...}}]; file returns {turnsLimit:{...}} at root.
COST_DATA="$("$DB_READ" state_cost 2>/dev/null)"
if [[ -n "$COST_DATA" && "$COST_DATA" != "null" ]]; then
  # Try PG shape first: [{id, data:{turnsLimit:...}}]
  PG_TL="$(echo "$COST_DATA" | $JQ -c 'if type=="array" then (.[0].data.turnsLimit // empty) elif type=="object" then (.turnsLimit // empty) else empty end' 2>/dev/null)"
fi
if [[ -z "$PG_TL" && -f "$COST_STATE" ]]; then
  # File fallback
  COST_DATA="$(cat "$COST_STATE")"
  TL="$(echo "$COST_DATA" | $JQ -c '.turnsLimit // empty' 2>/dev/null)"
else
  TL="$PG_TL"
fi
if [[ -z "$TL" || "$TL" == "null" ]]; then
  echo "ERROR: turnsLimit object missing from cost state (PG and file)"
  exit 1
fi

# Extract fields (prefer new nested weekly/session structure)
WEEKLY_LIMIT=$(echo "$TL" | $JQ -r '(.weekly.limit // .weeklyLimit) // empty')
USED=$(echo "$TL" | $JQ -r '(.weekly.requests // .currentRequests) // empty')
PCT=$(echo "$TL" | $JQ -r '(.weekly.pct // .currentPct) // empty')
REMAINING=$(echo "$TL" | $JQ -r '(.weekly.remaining // .requestsRemaining) // empty')
BURN=$(echo "$TL" | $JQ -r '(.weekly.burnRateRequestsPerHour // .burnRateRequestsPerHour) // empty')
PROJ_EXHAUST=$(echo "$TL" | $JQ -r '(.weekly.projectedExhaustion // .projectedExhaustion) // empty')
WIN_START=$(echo "$TL" | $JQ -r '(.weekly.windowStart // .currentWindowStart) // empty')
WIN_END=$(echo "$TL" | $JQ -r '(.weekly.windowEnd // .currentWindowEnd) // empty')

# Absolute threshold values
WARN_REQ=$(python3 -c "print(int($WEEKLY_LIMIT * $WARN_PCT / 100))")
ALERT_REQ=$(python3 -c "print(int($WEEKLY_LIMIT * $ALERT_PCT / 100))")
CRITICAL_REQ=$(python3 -c "print(int($WEEKLY_LIMIT * $CRITICAL_PCT / 100))")
EMERGENCY_REQ=$(python3 -c "print(int($WEEKLY_LIMIT * $EMERGENCY_PCT / 100))")

# Determine status
STATUS="ok"
EXIT_CODE=0
if [[ "$USED" -ge $EMERGENCY_REQ ]]; then
  STATUS="emergency"; EXIT_CODE=2
elif [[ "$USED" -ge $CRITICAL_REQ ]]; then
  STATUS="critical"; EXIT_CODE=1
elif [[ "$USED" -ge $ALERT_REQ ]]; then
  STATUS="alert"; EXIT_CODE=1
elif [[ "$USED" -ge $WARN_REQ ]]; then
  STATUS="warn"; EXIT_CODE=1
fi

STATUS_DISPLAY="✅ OK"
case "$STATUS" in
  emergency) STATUS_DISPLAY="🚨 EMERGENCY" ;;
  critical)  STATUS_DISPLAY="🔴 CRITICAL" ;;
  alert)     STATUS_DISPLAY="⚠️  ALERT" ;;
  warn)      STATUS_DISPLAY="⚠️  WARNING" ;;
esac

# Days remaining in window (AEST now vs window end)
DAYS_REMAINING=$(python3 -c "
from datetime import datetime, timezone, timedelta
try:
    end = datetime.fromisoformat('$WIN_END')
    now = datetime.now(end.tzinfo) if end.tzinfo else datetime.now()
    days = (end - now).total_seconds() / 86400
    print(max(0, round(days, 1)))
except Exception:
    print('?')
")

# ---------------------------------------------------------------------------
# REPORT mode
# ---------------------------------------------------------------------------
if [[ "$MODE" == "report" || "$MODE" == "check" ]]; then
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Ollama Weekly Request Budget — $TODAY"
  echo "  Window: $WIN_START → $WIN_END (${DAYS_REMAINING} days remaining)"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "  Total requests: $USED / $WEEKLY_LIMIT (${PCT}%)"
  echo "  Requests remaining: $REMAINING"
  echo "  Burn rate: $BURN req/hr"
  echo "  Projected exhaustion: $PROJ_EXHAUST (at current rate)"
  echo ""
  printf "  %-22s %10s %8s\n" "MODEL" "REQUESTS" "SHARE"
  printf "  %-22s %10s %8s\n" "──────────────────────" "──────────" "────────"

  # Iterate byModel (sorted by value desc)
  while IFS=$'\t' read -r model count; do
    [[ -z "$model" ]] && continue
    share=$(python3 -c "print(round(float('$count')/float('$WEEKLY_LIMIT')*100, 1))")
    printf "  %-22s %10s %7s%%\n" "$model" "$count" "$share"
  done < <(echo "$TL" | $JQ -r '.byModel | to_entries | sort_by(-.value) | .[] | "\(.key)\t\(.value)"')
  echo ""
  echo "  Status: $STATUS_DISPLAY"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  # Write alert state atomically
  ALERT_JSON=$(cat <<EOF
{
  "lastChecked": "$NOW",
  "status": "$STATUS",
  "currentPct": $PCT,
  "requestsUsed": $USED,
  "requestsRemaining": $REMAINING,
  "thresholds": {
    "warn":      {"pct": $WARN_PCT,      "requests": $WARN_REQ},
    "alert":     {"pct": $ALERT_PCT,     "requests": $ALERT_REQ},
    "critical":  {"pct": $CRITICAL_PCT,  "requests": $CRITICAL_REQ},
    "emergency": {"pct": $EMERGENCY_PCT, "requests": $EMERGENCY_REQ}
  }
}
EOF
)
  if command -v python3 >/dev/null 2>&1; then
    python3 -c "
import json, os, tempfile
data = json.loads('''$ALERT_JSON''')
tmp = '$ALERT_STATE' + '.tmp'
with open(tmp, 'w') as f:
    json.dump(data, f, indent=2)
os.replace(tmp, '$ALERT_STATE')
" 2>/dev/null || echo "$ALERT_JSON" > "$ALERT_STATE"
  else
    echo "$ALERT_JSON" > "$ALERT_STATE"
  fi

  case "$EXIT_CODE" in
    2) echo "🚨 REQUEST BUDGET EMERGENCY — at/over $EMERGENCY_PCT%." ;;
    1) echo "⚠️  REQUEST BUDGET WARNING — at/over $WARN_PCT% threshold." ;;
    *) echo "✅ Request budget healthy." ;;
  esac
  echo ""
fi

# ---------------------------------------------------------------------------
# AGENT mode — placeholder for future per-agent tracking
# ---------------------------------------------------------------------------
if [[ "$MODE" == "agent" ]]; then
  echo "Per-agent request tracking not yet configured. Use --report for platform-level view."
  exit 0
fi

# ---------------------------------------------------------------------------
# WORKFLOW mode — placeholder for future per-workflow tracking
# ---------------------------------------------------------------------------
if [[ "$MODE" == "workflow" ]]; then
  echo "Per-workflow request tracking not yet configured. Use --report for platform-level view."
  exit 0
fi

exit $EXIT_CODE
