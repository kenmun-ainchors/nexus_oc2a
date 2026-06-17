#!/bin/zsh
# ollama-request-counter.sh — Count Ollama API model invocations from gateway logs
# Updates cost-state.json → turnsLimit with live request counts.
# Each model invocation = 1 request (flat count, all models equal weight per CHG-0603).
# Window: Monday 10:00 AEST → next Monday 10:00 AEST.
#
# LIMITATION: Counts "agent model:" log events from gateway subsystem — this is the best
# available signal but may undercount. A true per-request counter requires OpenClaw metrics
# endpoint (not yet available). Accuracy improves with log retention.
#
# Exit codes: 0=OK, 1=no logs found, 2=update failed.

set -euo pipefail

WORKSPACE="${WORKSPACE:-$HOME/.openclaw/workspace}"
COST_STATE="$WORKSPACE/state/cost-state.json"
LOG_DIR="/tmp/openclaw"
JQ="${JQ:-/opt/homebrew/bin/jq}"
NOW="$(date +%Y-%m-%dT%H:%M:%S%z)"
TODAY="$(date +%Y-%m-%d)"

# --- Parse args ---
MODE="update"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --report) MODE="report"; shift ;;
    --dry-run) MODE="dry-run"; shift ;;
    *) echo "Unknown arg: $1"; exit 2 ;;
  esac
done

# --- Compute window boundaries ---
# Monday 10:00 AEST this week
AEST_DOW=$(TZ=Australia/Melbourne date +%u)  # 1=Mon, 7=Sun
DAYS_SINCE_MON=$(( AEST_DOW - 1 ))
WINDOW_START=$(TZ=Australia/Melbourne date -v-${DAYS_SINCE_MON}d -v10H -v0M -v0S +%Y-%m-%dT%H:%M:%S%z)
WINDOW_END=$(TZ=Australia/Melbourne date -v+$((7 - DAYS_SINCE_MON))d -v10H -v0M -v0S +%Y-%m-%dT%H:%M:%S%z)
WINDOW_START_DATE=$(TZ=Australia/Melbourne date -v-${DAYS_SINCE_MON}d +%Y-%m-%d)

# --- Count model invocations from gateway logs ---
# Pattern: field "1" contains "agent model: ollama/..." (string) OR has "model":"ollama/..." (dict)
# This is the best available signal in gateway logs.
TOTAL=0
declare -A MODEL_COUNTS
LOGS_FOUND=0
LOGS_MISSING=0

CURRENT_DATE="$WINDOW_START_DATE"
while [[ "$CURRENT_DATE" < "$TODAY" || "$CURRENT_DATE" == "$TODAY" ]]; do
  LOG_FILE="$LOG_DIR/openclaw-${CURRENT_DATE}.log"
  if [[ -f "$LOG_FILE" ]]; then
    LOGS_FOUND=$(( LOGS_FOUND + 1 ))
    # Use python3 for robust JSONL parsing
    DAY_RESULT=$(python3 -c "
import json, re, sys
total = 0
models = {}
seen_runs = set()
with open('$LOG_FILE') as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            d = json.loads(line)
            data = d.get('1', '')
            model = None
            run_id = None
            
            # Pattern 1: 'agent model: ollama/...' in string field (gateway subsystem)
            # These don't have runId — each is a unique model selection event
            if isinstance(data, str) and 'agent model:' in data:
                m = re.search(r'agent model:\s*(ollama/\S+)', data)
                if m:
                    model = re.sub(r'[),;()]+$', '', m.group(1))
            
            # Pattern 2: dict with provider=ollama + model field
            # Deduplicate by runId to avoid counting fallback/failover retries
            elif isinstance(data, dict):
                provider = data.get('provider', '')
                m = data.get('model', '')
                run_id = data.get('runId', '')
                if provider == 'ollama' and m:
                    if run_id and run_id in seen_runs:
                        continue
                    if run_id:
                        seen_runs.add(run_id)
                    if not m.startswith('ollama/'):
                        m = 'ollama/' + m
                    model = m
            
            if model:
                models[model] = models.get(model, 0) + 1
                total += 1
        except:
            pass

# Output as key=value pairs
print(f'TOTAL={total}')
for m, c in models.items():
    print(f'MODEL:{m}={c}')
" 2>&1)
    
    # Parse python output
    DAY_TOTAL=$(echo "$DAY_RESULT" | grep '^TOTAL=' | cut -d= -f2)
    TOTAL=$(( TOTAL + ${DAY_TOTAL:-0} ))
    
    while IFS= read -r line; do
      if [[ "$line" == MODEL:* ]]; then
        MODEL_NAME="${line#MODEL:}"
        MODEL_NAME="${MODEL_NAME%%=*}"
        MODEL_COUNT="${line##*=}"
        MODEL_COUNTS[$MODEL_NAME]=$(( ${MODEL_COUNTS[$MODEL_NAME]:-0} + MODEL_COUNT ))
      fi
    done < <(echo "$DAY_RESULT" | grep '^MODEL:')
  else
    LOGS_MISSING=$(( LOGS_MISSING + 1 ))
  fi
  
  CURRENT_DATE=$(date -j -v+1d -f %Y-%m-%d "$CURRENT_DATE" +%Y-%m-%d 2>/dev/null || echo "")
  [[ -z "$CURRENT_DATE" ]] && break
done

# --- Compute metrics ---
WEEKLY_LIMIT=30000
if [[ $TOTAL -gt 0 ]]; then
  CURRENT_PCT=$(echo "scale=2; $TOTAL * 100 / $WEEKLY_LIMIT" | bc | sed 's/^0*//; s/^\./0./')
else
  CURRENT_PCT="0.0"
fi
REMAINING=$(( WEEKLY_LIMIT - TOTAL ))

# Burn rate: requests per hour since window start
WINDOW_START_EPOCH=$(TZ=Australia/Melbourne date -j -f %Y-%m-%dT%H:%M:%S%z "$WINDOW_START" +%s 2>/dev/null || echo 0)
NOW_EPOCH=$(date +%s)
HOURS_ELAPSED=$(echo "scale=2; ($NOW_EPOCH - $WINDOW_START_EPOCH) / 3600" | bc 2>/dev/null || echo 0)
if [[ "$(echo "$HOURS_ELAPSED > 0" | bc 2>/dev/null)" == "1" ]]; then
  BURN_RATE=$(echo "scale=1; $TOTAL / $HOURS_ELAPSED" | bc)
else
  BURN_RATE="0"
fi

# Projected exhaustion
if [[ "$(echo "$BURN_RATE > 0" | bc 2>/dev/null)" == "1" ]]; then
  HOURS_TO_EXHAUST=$(echo "scale=0; $REMAINING / $BURN_RATE" | bc)
  EXHAUST_EPOCH=$(( NOW_EPOCH + HOURS_TO_EXHAUST * 3600 ))
  PROJ_EXHAUST=$(TZ=Australia/Melbourne date -r $EXHAUST_EPOCH +%Y-%m-%dT%H:%M:%S%z 2>/dev/null || echo "unknown")
else
  HOURS_TO_EXHAUST=0
  PROJ_EXHAUST="N/A (burn rate zero)"
fi

# --- Build model breakdown JSON ---
MODEL_JSON="{"
FIRST=true
for model count in ${(kv)MODEL_COUNTS}; do
  if [[ "$FIRST" != true ]]; then MODEL_JSON+=","; fi
  FIRST=false
  MODEL_JSON+="\"$model\":$count"
done
MODEL_JSON+="}"

# --- Report mode ---
if [[ "$MODE" == "report" || "$MODE" == "dry-run" ]]; then
  echo "=== Ollama Request Counter ==="
  echo "Window: $WINDOW_START → $WINDOW_END"
  echo "Logs found: $LOGS_FOUND day(s) | Missing: $LOGS_MISSING day(s)"
  echo "Hours elapsed: $HOURS_ELAPSED"
  echo ""
  echo "Total requests: $TOTAL / $WEEKLY_LIMIT ($CURRENT_PCT%)"
  echo "Remaining: $REMAINING"
  echo "Burn rate: $BURN_RATE req/hr"
  echo "Projected exhaustion: $PROJ_EXHAUST"
  echo ""
  echo "By model:"
  for model count in ${(kv)MODEL_COUNTS}; do
    printf "  %-45s %d\n" "$model" "$count"
  done
  if [[ $LOGS_MISSING -gt 0 ]]; then
    echo ""
    echo "⚠️  $LOGS_MISSING day(s) of logs missing — count is partial."
    echo "    Log retention: $(ls "$LOG_DIR"/openclaw-*.log 2>/dev/null | wc -l | tr -d ' ') day(s) available."
  fi
  if [[ "$MODE" == "dry-run" ]]; then
    echo ""
    echo "[DRY RUN — cost-state.json NOT updated]"
  fi
  exit 0
fi

# --- Update cost-state.json ---
if [[ ! -f "$COST_STATE" ]]; then
  echo "ERROR: cost-state.json not found at $COST_STATE" >&2
  exit 2
fi

TMPFILE=$(mktemp)
$JQ --arg total "$TOTAL" \
    --arg pct "$CURRENT_PCT" \
    --arg remaining "$REMAINING" \
    --arg burn "$BURN_RATE" \
    --arg exhaust "$PROJ_EXHAUST" \
    --arg wstart "$WINDOW_START" \
    --arg wend "$WINDOW_END" \
    --arg updated "$NOW" \
    --arg logs_found "$LOGS_FOUND" \
    --arg logs_missing "$LOGS_MISSING" \
    --argjson models "$MODEL_JSON" \
    '.turnsLimit.currentRequests = ($total | tonumber) |
     .turnsLimit.currentPct = ($pct | tonumber) |
     .turnsLimit.requestsRemaining = ($remaining | tonumber) |
     .turnsLimit.burnRateRequestsPerHour = ($burn | tonumber) |
     .turnsLimit.projectedExhaustion = $exhaust |
     .turnsLimit.currentWindowStart = $wstart |
     .turnsLimit.currentWindowEnd = $wend |
     .turnsLimit.lastUpdated = $updated |
     .turnsLimit.modelBreakdown = $models |
     .turnsLimit.byModel = $models |
     .turnsLimit.logsFound = ($logs_found | tonumber) |
     .turnsLimit.logsMissing = ($logs_missing | tonumber) |
     .turnsLimit.countingMethod = "gateway-log-agent-model-events" |
     .turnsLimit.countingLimitation = "Undercount possible — counts agent model selection events, not raw API calls. True per-request counter requires OpenClaw metrics endpoint."' \
    "$COST_STATE" > "$TMPFILE" 2>/dev/null

if [[ $? -eq 0 && -s "$TMPFILE" ]]; then
  mv "$TMPFILE" "$COST_STATE"
  echo "OK: cost-state.json updated — $TOTAL requests ($CURRENT_PCT%) | burn=$BURN_RATE req/hr | logs=$LOGS_FOUND found/$LOGS_MISSING missing | $NOW"
  exit 0
else
  rm -f "$TMPFILE"
  echo "ERROR: jq update failed" >&2
  exit 2
fi
