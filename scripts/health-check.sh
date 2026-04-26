#!/bin/zsh
# AInchors Health Check Script — Enhanced
# Runs via main session system-event every 5 minutes.
# 
# IMPORTANT: Must run in main session context (NOT isolated session).
# See PATTERN-001 in memory/agents/infra.md — Ollama/Gemma4 auth fails
# in isolated session contexts causing monitoring blackouts.
#
# Exit codes:
#   0 = ok (all checks pass)
#   1 = degraded (non-critical issues)
#   2 = critical (gateway down, multi-failure)

GATEWAY_URL="http://127.0.0.1:18789"
STATE_FILE="$HOME/.openclaw/workspace/state/health-state.json"
COST_STATE="$HOME/.openclaw/workspace/state/cost-state.json"
LOCK_DIR="$HOME/.openclaw/workspace/state"
LOG="$HOME/Backups/ainchors/logs/health.log"
FAILURE_THRESHOLD=2      # Alert after this many consecutive failures
STALE_THRESHOLD_MIN=1440 # Flag state files if older than this (minutes) — 24hrs (cost-state updates daily via end-of-day close + midday cron)
LOCK_STALE_MIN=5         # Clear lock files older than this (minutes)
DISK_ALERT_PCT=85        # Alert if disk usage exceeds this percentage

mkdir -p "$(dirname $LOG)"
mkdir -p "$(dirname $STATE_FILE)"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG"
}

# ── Read previous state ──────────────────────────────────────────────────────
FAILURES=0
ALERTED="false"
if [[ -f "$STATE_FILE" ]]; then
  FAILURES=$(python3 -c "import json; d=json.load(open('$STATE_FILE')); print(d.get('consecutiveFailures', 0))" 2>/dev/null || echo 0)
  ALERTED=$(python3 -c "import json; d=json.load(open('$STATE_FILE')); print(str(d.get('alerted', False)).lower())" 2>/dev/null || echo "false")
fi

# ── Collect all check results ─────────────────────────────────────────────────
declare -A CHECK_RESULTS
OVERALL_STATUS="ok"
ISSUES=()

# ── CHECK 1: Gateway reachability ────────────────────────────────────────────
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  --connect-timeout 5 \
  "$GATEWAY_URL" 2>/dev/null)

if [[ "$HTTP_STATUS" == "200" ]] || [[ "$HTTP_STATUS" == "301" ]] || [[ "$HTTP_STATUS" == "302" ]] || [[ "$HTTP_STATUS" == "401" ]]; then
  CHECK_RESULTS[gateway]="ok"
  log "CHECK gateway: OK (HTTP $HTTP_STATUS)"
  GATEWAY_OK=true
else
  CHECK_RESULTS[gateway]="critical"
  OVERALL_STATUS="critical"
  ISSUES+=("Gateway unreachable (HTTP $HTTP_STATUS)")
  log "CHECK gateway: FAIL (HTTP $HTTP_STATUS)"
  GATEWAY_OK=false
fi

# ── CHECK 2: Ollama process ───────────────────────────────────────────────────
if pgrep -x ollama > /dev/null 2>&1; then
  CHECK_RESULTS[ollama]="ok"
  log "CHECK ollama: OK (process running)"
else
  CHECK_RESULTS[ollama]="degraded"
  [[ "$OVERALL_STATUS" == "ok" ]] && OVERALL_STATUS="degraded"
  ISSUES+=("Ollama process not running")
  log "CHECK ollama: WARN (process not found)"
fi

# ── CHECK 3: Disk space ───────────────────────────────────────────────────────
DISK_STATUS="ok"
DISK_DETAILS=""
while IFS= read -r line; do
  # Skip virtual/special filesystems (devfs, tmpfs, map auto)
  FS=$(echo "$line" | awk '{print $1}')
  [[ "$FS" == devfs || "$FS" == tmpfs || "$FS" =~ ^map ]] && continue
  # macOS df -h: col5=Capacity%, col9=Mounted on
  PCT=$(echo "$line" | awk '{print $5}' | tr -d '%')
  MOUNT=$(echo "$line" | awk '{print $NF}')
  if [[ "$PCT" =~ ^[0-9]+$ ]]; then
    if (( PCT >= DISK_ALERT_PCT )); then
      DISK_STATUS="degraded"
      DISK_DETAILS="$MOUNT at ${PCT}%"
      ISSUES+=("Disk usage high: $MOUNT at ${PCT}%")
      log "CHECK disk: WARN — $MOUNT at ${PCT}%"
    fi
  fi
done < <(df -h | tail -n +2)

if [[ "$DISK_STATUS" == "ok" ]]; then
  CHECK_RESULTS[disk]="ok"
  log "CHECK disk: OK (all volumes <${DISK_ALERT_PCT}%)"
else
  CHECK_RESULTS[disk]="$DISK_STATUS"
  [[ "$OVERALL_STATUS" == "ok" ]] && OVERALL_STATUS="degraded"
fi

# ── CHECK 4: State file freshness ─────────────────────────────────────────────
check_state_age() {
  local file="$1"
  local label="$2"
  if [[ ! -f "$file" ]]; then
    log "CHECK $label age: SKIP (file not found)"
    return
  fi
  local now_epoch=$(date +%s)
  local file_epoch=$(stat -f %m "$file" 2>/dev/null || echo 0)
  local age_min=$(( (now_epoch - file_epoch) / 60 ))
  if (( age_min > STALE_THRESHOLD_MIN )); then
    CHECK_RESULTS[$label]="stale"
    [[ "$OVERALL_STATUS" == "ok" ]] && OVERALL_STATUS="degraded"
    ISSUES+=("$label is stale (${age_min} min since last update)")
    log "CHECK $label age: STALE (${age_min} min old — threshold: ${STALE_THRESHOLD_MIN} min)"
  else
    CHECK_RESULTS[$label]="ok"
    log "CHECK $label age: OK (${age_min} min old)"
  fi
}

check_state_age "$STATE_FILE" "health-state"
check_state_age "$COST_STATE" "cost-state"

# ── CHECK 5: Stale lock files — clear if >LOCK_STALE_MIN old ─────────────────
LOCK_CLEARED=0
LOCK_FOUND=0
for lock_file in "$LOCK_DIR"/*.lock; do
  [[ -f "$lock_file" ]] || continue
  LOCK_FOUND=$((LOCK_FOUND + 1))
  lock_epoch=$(stat -f %m "$lock_file" 2>/dev/null || echo 0)
  now_epoch=$(date +%s)
  lock_age_min=$(( (now_epoch - lock_epoch) / 60 ))
  if (( lock_age_min > LOCK_STALE_MIN )); then
    log "LOCK: Clearing stale lock $lock_file (${lock_age_min} min old)"
    rm -f "$lock_file"
    LOCK_CLEARED=$((LOCK_CLEARED + 1))
  else
    log "LOCK: Active lock $lock_file (${lock_age_min} min old — keeping)"
  fi
done

if (( LOCK_FOUND == 0 )); then
  log "CHECK locks: OK (no lock files)"
elif (( LOCK_CLEARED > 0 )); then
  log "CHECK locks: Cleared $LOCK_CLEARED stale lock(s)"
fi

# ── Gateway failure handling ──────────────────────────────────────────────────
if [[ "$GATEWAY_OK" == "false" ]]; then
  NEW_FAILURES=$((FAILURES + 1))
  log "Gateway failure count: $NEW_FAILURES"

  # Auto-restart on first failure
  if (( NEW_FAILURES == 1 )); then
    log "Attempting auto-restart..."
    launchctl kickstart -k gui/$(id -u)/ai.openclaw.gateway >> "$LOG" 2>&1 || true
    log "Restart command sent"
  fi

  # Alert Ken after threshold
  if (( NEW_FAILURES >= FAILURE_THRESHOLD )) && [[ "$ALERTED" != "true" ]]; then
    log "ALERT: Sending gateway-down notification"
    echo "🚨 AInchors Gateway DOWN\n\nConsecutive failures: $NEW_FAILURES\nTime: $(date)\nHTTP status: $HTTP_STATUS\n\nAuto-restart attempted on first failure. Manual check needed." > /tmp/startup-alert.txt
  fi

  # Write state
  python3 - << PYEOF
import json
state = {
  "status": "critical",
  "overallStatus": "critical",
  "consecutiveFailures": $NEW_FAILURES,
  "alerted": $([[ "$ALERTED" == "true" ]] && echo 'True' || echo 'False'),
  "lastCheck": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "issues": $(python3 -c "import json; print(json.dumps(${ISSUES[@]}))" 2>/dev/null || echo '[]'),
  "checks": {
    "gateway": "critical",
    "ollama": "${CHECK_RESULTS[ollama]:-unknown}",
    "disk": "${CHECK_RESULTS[disk]:-unknown}"
  }
}
json.dump(state, open("$STATE_FILE", "w"), indent=2)
print("State written (critical)")
PYEOF

else
  # Gateway is up — build full status
  NEW_FAILURES=0
  if (( FAILURES >= FAILURE_THRESHOLD )); then
    log "RECOVERY: Gateway back online after $FAILURES failures"
  fi

  # Map overall status to exit code
  EXIT_CODE=0
  if [[ "$OVERALL_STATUS" == "critical" ]]; then
    EXIT_CODE=2
  elif [[ "$OVERALL_STATUS" == "degraded" ]]; then
    EXIT_CODE=1
  fi

  # Build issues JSON
  ISSUES_JSON=$(python3 -c "
issues = []
$(for issue in "${ISSUES[@]}"; do echo "issues.append('$issue')"; done)
import json
print(json.dumps(issues))
" 2>/dev/null || echo '[]')

  # Write structured state
  python3 - << PYEOF
import json
from datetime import datetime, timezone

state = {
  "status": "$OVERALL_STATUS",
  "overallStatus": "$OVERALL_STATUS",
  "consecutiveFailures": 0,
  "alerted": False,
  "lastCheck": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "lastOk": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "exitCode": $EXIT_CODE,
  "issues": $ISSUES_JSON,
  "checks": {
    "gateway": "${CHECK_RESULTS[gateway]:-unknown}",
    "ollama": "${CHECK_RESULTS[ollama]:-unknown}",
    "disk": "${CHECK_RESULTS[disk]:-unknown}",
    "healthStateAge": "${CHECK_RESULTS[health-state]:-ok}",
    "costStateAge": "${CHECK_RESULTS[cost-state]:-ok}",
    "staleLockFilesCleared": $LOCK_CLEARED
  }
}
json.dump(state, open("$STATE_FILE", "w"), indent=2)
print(f"State written: {state['status']}")
PYEOF

  if (( ${#ISSUES[@]} > 0 )); then
    log "STATUS: $OVERALL_STATUS — Issues: ${ISSUES[*]}"
  else
    log "STATUS: ok — all checks passed"
  fi
fi

log "Health check complete. Exit code: ${EXIT_CODE:-2}"
exit ${EXIT_CODE:-2}
