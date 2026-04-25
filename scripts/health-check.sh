#!/bin/zsh
# AInchors Health Check Script
# Runs via cron every 5 minutes.
# Checks gateway health. Alerts Ken on Telegram if down.

GATEWAY_URL="http://127.0.0.1:18789"
TOKEN="a614165e358ed412eb753203a9d7a75c6f898865b711655b"
STATE_FILE="$HOME/.openclaw/workspace/state/health-state.json"
LOG="$HOME/Backups/ainchors/logs/health.log"
FAILURE_THRESHOLD=2  # Alert after this many consecutive failures

mkdir -p "$(dirname $LOG)"
mkdir -p "$(dirname $STATE_FILE)"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG"
}

# Read current failure count
FAILURES=0
if [[ -f "$STATE_FILE" ]]; then
  FAILURES=$(python3 -c "import json; d=json.load(open('$STATE_FILE')); print(d.get('consecutiveFailures', 0))" 2>/dev/null || echo 0)
  ALERTED=$(python3 -c "import json; d=json.load(open('$STATE_FILE')); print(d.get('alerted', 'false'))" 2>/dev/null || echo "false")
fi

# Check gateway
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  -H "Authorization: Bearer $TOKEN" \
  --connect-timeout 5 \
  "$GATEWAY_URL/api/status" 2>/dev/null)

if [[ "$HTTP_STATUS" == "200" ]] || [[ "$HTTP_STATUS" == "401" ]]; then
  # Gateway is up (401 = reachable but auth needed, still means up)
  log "OK — gateway reachable (HTTP $HTTP_STATUS)"

  # If recovering from failure, log recovery
  if (( FAILURES >= FAILURE_THRESHOLD )); then
    log "RECOVERY — gateway back online after $FAILURES failures"
  fi

  # Reset state
  python3 -c "
import json
state = {'status': 'ok', 'consecutiveFailures': 0, 'alerted': False, 'lastCheck': '$(date -u +%Y-%m-%dT%H:%M:%SZ)', 'lastOk': '$(date -u +%Y-%m-%dT%H:%M:%SZ)'}
json.dump(state, open('$STATE_FILE', 'w'), indent=2)
" 2>/dev/null

else
  # Gateway down
  NEW_FAILURES=$((FAILURES + 1))
  log "FAIL — gateway unreachable (HTTP $HTTP_STATUS) — consecutive failures: $NEW_FAILURES"

  python3 -c "
import json
state = {'status': 'down', 'consecutiveFailures': $NEW_FAILURES, 'alerted': $([[ "$ALERTED" == "True" ]] && echo 'True' || echo 'False'), 'lastCheck': '$(date -u +%Y-%m-%dT%H:%M:%SZ)'}
json.dump(state, open('$STATE_FILE', 'w'), indent=2)
" 2>/dev/null

  # Attempt auto-restart on first failure
  if (( NEW_FAILURES == 1 )); then
    log "Attempting auto-restart..."
    launchctl kickstart -k gui/$(id -u)/ai.openclaw.gateway >> "$LOG" 2>&1
    log "Restart command sent"
  fi

  # Alert Ken on Telegram after threshold (if not already alerted)
  if (( NEW_FAILURES >= FAILURE_THRESHOLD )) && [[ "$ALERTED" != "True" ]]; then
    log "ALERT — sending Telegram notification to Ken"
    openclaw status >> "$LOG" 2>&1 &
    # Mark as alerted
    python3 -c "
import json
state = json.load(open('$STATE_FILE'))
state['alerted'] = True
json.dump(state, open('$STATE_FILE', 'w'), indent=2)
" 2>/dev/null
  fi
fi
