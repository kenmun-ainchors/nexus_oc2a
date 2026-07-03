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

# ── US23: Outage detection (runs first — sets standby/banner state) ───────────
OUTAGE_DETECT="$HOME/.openclaw/workspace/scripts/outage-detect.sh"
if [[ -x "$OUTAGE_DETECT" ]]; then
  zsh "$OUTAGE_DETECT" >> "$LOG" 2>&1
  OUTAGE_EXIT=$?
  if (( OUTAGE_EXIT != 0 )); then
    log "OUTAGE DETECTED — standby mode active (see outage-detect.log)"
  fi
else
  log "WARN — outage-detect.sh missing or not executable: $OUTAGE_DETECT"
fi

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
# Plain variables (bash 3.2 compat — no declare -A)
CHECK_gateway="unknown"
CHECK_ollama="unknown"
CHECK_disk="ok"
CHECK_health_state="ok"
CHECK_cost_state="ok"
CHECK_anthropic="unknown"
CHECK_ollamaApi="unknown"
OVERALL_STATUS="ok"
ISSUES=()

# ── CHECK 1: Gateway reachability ────────────────────────────────────────────
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  --connect-timeout 5 \
  "$GATEWAY_URL" 2>/dev/null)

if [[ "$HTTP_STATUS" == "200" ]] || [[ "$HTTP_STATUS" == "301" ]] || [[ "$HTTP_STATUS" == "302" ]] || [[ "$HTTP_STATUS" == "401" ]]; then
  CHECK_gateway="ok"
  log "CHECK gateway: OK (HTTP $HTTP_STATUS)"
  GATEWAY_OK=true
else
  CHECK_gateway="critical"
  OVERALL_STATUS="critical"
  ISSUES+=("Gateway unreachable (HTTP $HTTP_STATUS)")
  log "CHECK gateway: FAIL (HTTP $HTTP_STATUS)"
  GATEWAY_OK=false
fi

# ── CHECK 2: Ollama process ───────────────────────────────────────────────────
if pgrep -x ollama > /dev/null 2>&1; then
  CHECK_ollama="ok"
  log "CHECK ollama: OK (process running)"
else
  CHECK_ollama="degraded"
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
  CHECK_disk="ok"
  log "CHECK disk: OK (all volumes <${DISK_ALERT_PCT}%)"
else
  CHECK_disk="$DISK_STATUS"
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
    if [[ "$label" == "health-state" ]]; then CHECK_health_state="stale"; else CHECK_cost_state="stale"; fi
    [[ "$OVERALL_STATUS" == "ok" ]] && OVERALL_STATUS="degraded"
    ISSUES+=("$label is stale (${age_min} min since last update)")
    log "CHECK $label age: STALE (${age_min} min old — threshold: ${STALE_THRESHOLD_MIN} min)"
  else
    if [[ "$label" == "health-state" ]]; then CHECK_health_state="ok"; else CHECK_cost_state="ok"; fi
    log "CHECK $label age: OK (${age_min} min old)"
  fi
}

check_state_age "$STATE_FILE" "health-state"
check_state_age "$COST_STATE" "cost-state"

# ── CHECK 13: Anthropic API reachability ────────────────────────────────────
# Read from auth-profiles.json (source of truth for gateway key) with keychain as fallback
ANTHROPIC_KEY=$(jq -r '.profiles["anthropic:default"].key // empty' /Users/ainchorsangiefpl/.openclaw/agents/main/agent/auth-profiles.json 2>/dev/null || security find-generic-password -s "anthropic-api-key" -a "ainchors" -w 2>/dev/null || security find-generic-password -s "anthropic-api-key" -w 2>/dev/null || echo "")
if [[ -n "$ANTHROPIC_KEY" && ${#ANTHROPIC_KEY} -gt 20 ]]; then
  ANTHROPIC_HTTP=$(curl -s -o /dev/null -w "%{http_code}" \
    --connect-timeout 8 \
    -H "x-api-key: $ANTHROPIC_KEY" \
    -H "anthropic-version: 2023-06-01" \
    "https://api.anthropic.com/v1/models" 2>/dev/null)
  if [[ "$ANTHROPIC_HTTP" == "200" ]]; then
    CHECK_anthropic="ok"
    ANTHROPIC_REACHABLE=1
    log "CHECK anthropic: OK (HTTP $ANTHROPIC_HTTP)"
  else
    CHECK_anthropic="failure"
    ANTHROPIC_REACHABLE=0
    [[ "$OVERALL_STATUS" == "ok" ]] && OVERALL_STATUS="degraded"
    ISSUES+=("Anthropic API unreachable (HTTP $ANTHROPIC_HTTP) — billing or auth failure")
    log "CHECK anthropic: FAIL (HTTP $ANTHROPIC_HTTP) — billing or auth failure"
  fi
else
  CHECK_anthropic="no-key"
  ANTHROPIC_REACHABLE=0
  [[ "$OVERALL_STATUS" == "ok" ]] && OVERALL_STATUS="degraded"
  ISSUES+=("Anthropic API key missing from keychain")
  log "CHECK anthropic: FAIL (key not in keychain)"
  # Trigger outage handler (non-blocking)
  zsh "$HOME/.openclaw/workspace/scripts/outage-handler.sh" >> "$HOME/Backups/ainchors/logs/health.log" 2>&1 &
fi

# ── CHECK 14: Ollama API reachability ────────────────────────────────────────
OLLAMA_HTTP=$(curl -s -o /dev/null -w "%{http_code}" \
  --connect-timeout 5 \
  "http://localhost:11434/api/tags" 2>/dev/null)
if [[ "$OLLAMA_HTTP" == "200" ]]; then
  CHECK_ollamaApi="ok"
  OLLAMA_API_REACHABLE=1
  log "CHECK ollamaApi: OK (HTTP $OLLAMA_HTTP)"
else
  CHECK_ollamaApi="failure"
  OLLAMA_API_REACHABLE=0
  [[ "$OVERALL_STATUS" == "ok" ]] && OVERALL_STATUS="degraded"
  ISSUES+=("Ollama API unreachable (HTTP $OLLAMA_HTTP)")
  log "CHECK ollamaApi: FAIL (HTTP $OLLAMA_HTTP)"
fi

# ── CHECK 15: Gemma4 standby mode management ─────────────────────────────────
STANDBY_FILE="$HOME/.openclaw/workspace/state/standby-mode.json"
if [[ "$ANTHROPIC_REACHABLE" == "0" ]]; then
  # Anthropic down — activate standby if not already active
  SINCE_TS=$(TZ=Australia/Melbourne date +%Y-%m-%dT%H:%M:%S%z)
  if [[ -f "$STANDBY_FILE" ]]; then
    # Already in standby — preserve original 'since' timestamp
    SINCE_TS=$(python3 -c "import json; d=json.load(open('$STANDBY_FILE')); print(d.get('since','$SINCE_TS'))" 2>/dev/null || echo "$SINCE_TS")
  else
    # First detection — fire API-independent alert immediately (TKT-0113)
    log "ALERT: Anthropic API down — firing fallback Telegram alert (TKT-0113)"
    bash "$HOME/.openclaw/workspace/scripts/telegram-alert.sh" \
      --message "🚨 Anthropic API UNREACHABLE\n\nTime: $(date)\nHTTP: $ANTHROPIC_HTTP\n\nStandby mode activating. Check billing at console.anthropic.com\nAuto-reload active — if balance is fine, may be a transient outage.\n\nCHG-0799: Routing to Ken + Angie" \
      --recipients "8574109706,8141152780" --silent >> "$LOG" 2>&1 \
      || log "WARNING: Telegram fallback alert failed"
  fi
  python3 - << PYEOF2
import json
state = {
  "active": True,
  "reason": "Anthropic API unreachable",
  "since": "$SINCE_TS",
  "fallback": "gemma4"
}
json.dump(state, open("$STANDBY_FILE", "w"), indent=2)
print("Standby mode ACTIVATED — fallback: gemma4")
PYEOF2
  log "CHECK standby: ACTIVATED — Anthropic down, fallback=gemma4"
else
  # Anthropic OK — clear standby and outage state if they were set
  if [[ -f "$STANDBY_FILE" ]]; then
    rm -f "$STANDBY_FILE"
    rm -f "$HOME/.openclaw/workspace/state/outage-alert-state.json"
    rm -f "$HOME/.openclaw/workspace/state/system-banner.json"
    log "CHECK standby: CLEARED — Anthropic recovered, standby mode removed, banner cleared"
  else
    log "CHECK standby: OK (not in standby)"
  fi
fi

# ── CHECK 16: Event loop health (gateway log) ───────────────────────────────
GW_LOG="/tmp/openclaw/openclaw-$(date +%Y-%m-%d).log"
CHECK_eventLoop="ok"
if [[ -f "$GW_LOG" ]]; then
  # Check last 5 minutes of log for critical event loop warnings
  # Use P99 (not MAX) to avoid false positives from startup spikes
  # Also skip entries during gateway startup phase (channels.telegram.start-account)
  LOOP_WARN=$(tail -200 "$GW_LOG" 2>/dev/null | grep "eventLoopDelayMaxMs" | grep -v 'channels.telegram.start-account' | tail -3)
  if [[ -n "$LOOP_WARN" ]]; then
    P99_DELAY=$(echo "$LOOP_WARN" | grep -oE 'eventLoopDelayP99Ms=[0-9.]+' | tail -1 | cut -d= -f2 | cut -d. -f1)
    MAX_DELAY=$(echo "$LOOP_WARN" | grep -oE 'eventLoopDelayMaxMs=[0-9.]+' | tail -1 | cut -d= -f2 | cut -d. -f1)
    UTIL=$(echo "$LOOP_WARN" | grep -oE 'eventLoopUtilization=[0-9.]+' | tail -1 | cut -d= -f2)
    # Use P99 if available, fall back to MAX
    CHECK_DELAY=${P99_DELAY:-$MAX_DELAY}
    if [[ -n "$CHECK_DELAY" ]] && (( CHECK_DELAY > 10000 )); then
      CHECK_eventLoop="critical"
      [[ "$OVERALL_STATUS" == "ok" ]] && OVERALL_STATUS="degraded"
      ISSUES+=("Event loop delay critical: ${CHECK_DELAY}ms P99, utilisation ${UTIL} — gateway may be saturated")
      log "CHECK eventLoop: CRITICAL maxDelay=${MAX_DELAY}ms p99=${P99_DELAY}ms util=${UTIL}"
    elif [[ -n "$CHECK_DELAY" ]] && (( CHECK_DELAY > 5000 )); then
      CHECK_eventLoop="warning"
      log "CHECK eventLoop: WARNING maxDelay=${MAX_DELAY}ms p99=${P99_DELAY}ms util=${UTIL}"
    else
      log "CHECK eventLoop: OK maxDelay=${MAX_DELAY}ms p99=${P99_DELAY}ms"
    fi
  else
    log "CHECK eventLoop: OK (no delay warnings in log)"
  fi
else
  log "CHECK eventLoop: SKIP (log not found at $GW_LOG)"
fi

# ── CHECK 17: Zombie task runs ───────────────────────────────────────────────
# Uses JSON API to get full task IDs (audit output truncates IDs with ellipsis)
CHECK_zombieTasks="ok"
STALE_THRESHOLD_HOURS=4
STALE_THRESHOLD_MS=$(( STALE_THRESHOLD_HOURS * 3600 * 1000 ))
NOW_MS=$(date +%s)000

ZOMBIE_JSON=$(openclaw tasks list --status running --json 2>/dev/null || echo '{"tasks":[]}')
STALE_TASKS=$(echo "$ZOMBIE_JSON" | jq -r --argjson now "$NOW_MS" --argjson thresh "$STALE_THRESHOLD_MS" '
  .tasks[]? | select(.status == "running") |
  (.lastEventAt // .startedAt // 0) as $lastEvent |
  select(($now | tonumber) - $lastEvent > $thresh) |
  .taskId
')

if [[ -n "$STALE_TASKS" ]]; then
  ZOMBIE_COUNT=$(echo "$STALE_TASKS" | grep -c '^' || echo 0)
  log "CHECK zombieTasks: $ZOMBIE_COUNT stale_running task(s) found (> ${STALE_THRESHOLD_HOURS}h) — auto-cancelling..."
  CANCELLED=0
  while IFS= read -r task_id; do
    [[ -z "$task_id" ]] && continue
    if openclaw tasks cancel "$task_id" >> "$LOG" 2>&1; then
      log "  AUTO-FIX: cancelled zombie task ${task_id:0:8}"
      (( CANCELLED++ ))
    else
      log "  FAIL: could not cancel zombie task ${task_id:0:8}"
    fi
  done <<< "$STALE_TASKS"
  log "CHECK zombieTasks: cancelled $CANCELLED/$ZOMBIE_COUNT zombie task(s)"
  if (( CANCELLED > 0 )); then
    CHECK_zombieTasks="fixed:${CANCELLED}"
  else
    CHECK_zombieTasks="warning:${ZOMBIE_COUNT}"
    [[ "$OVERALL_STATUS" == "ok" ]] && OVERALL_STATUS="degraded"
    ISSUES+=("$ZOMBIE_COUNT zombie task(s) could not be auto-cancelled — run: openclaw tasks list --status running")
  fi
else
  log "CHECK zombieTasks: OK (no stale tasks > ${STALE_THRESHOLD_HOURS}h)"
fi

# ── CHECK 18: MinIO health (TKT-0124) ───────────────────────────────────────────────────────
MINIO_HEALTH=$(curl -sf --connect-timeout 3 http://127.0.0.1:9000/minio/health/live 2>/dev/null && echo "ok" || echo "down")
if [[ "$MINIO_HEALTH" != "ok" ]]; then
  ISSUES+=("MinIO: down (http://127.0.0.1:9000/minio/health/live failed)")
  log "CHECK 18: MinIO DOWN"
  # Alert via Telegram if gateway is healthy enough
  bash "$WORKSPACE/scripts/telegram-alert.sh" \
    "📦 MinIO down on OC1 — native minio process not responding on :9000. Check: pgrep minio / launchctl list com.ainchors.minio" \
    "$TELEGRAM_CHAT_ID" 2>/dev/null || true
else
  log "CHECK 18: MinIO ok"
fi

# ── CHECK 5: Stale lock files — clear if >LOCK_STALE_MIN old ─────────────────
LOCK_CLEARED=0
LOCK_FOUND=0
for lock_file in "$LOCK_DIR"/*.lock; do
  [[ -e "$lock_file" ]] || continue
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

  # Alert Ken after threshold — TKT-0113: API-independent fallback alert
  if (( NEW_FAILURES >= FAILURE_THRESHOLD )) && [[ "$ALERTED" != "true" ]]; then
    log "ALERT: Sending gateway-down notification via direct Telegram"
    ALERT_MSG="🚨 AInchors Gateway DOWN

Consecutive failures: $NEW_FAILURES
Time: $(date)
HTTP status: $HTTP_STATUS

Auto-restart attempted. Manual check needed."
    # CHG-0799: Route gateway-down alert to both Ken (8574109706) and Angie (8141152780)
    bash "$HOME/.openclaw/workspace/scripts/telegram-alert.sh" \
      --message "$ALERT_MSG" --recipients "8574109706,8141152780" --silent \
      >> "$LOG" 2>&1 || log "WARNING: Telegram fallback alert also failed"
  fi

  # US40: Log health failure to obs.db
  bash "$HOME/.openclaw/workspace/scripts/obs-log.sh" \
    --source health-check --level ERROR --type health_failure \
    --message "Gateway health failure: consecutiveFailures=$NEW_FAILURES HTTP=$HTTP_STATUS" \
    --detail "{\"consecutiveFailures\":$NEW_FAILURES,\"httpStatus\":\"$HTTP_STATUS\"}" \
    >> "$LOG" 2>&1 || true

  # Write state
  python3 - << PYEOF
import json
state = {
  "status": "critical",
  "overallStatus": "critical",
  "consecutiveFailures": $NEW_FAILURES,
  "alerted": $([[ "$ALERTED" == "true" ]] && echo 'True' || echo 'False'),
  "lastCheck": "$(TZ=Australia/Melbourne date +%Y-%m-%dT%H:%M:%S%z)",
  "issues": $(python3 -c "import json; print(json.dumps(${ISSUES[@]}))" 2>/dev/null || echo '[]'),
  "anthropicReachable": False,
  "ollamaReachable": False,
  "checks": {
    "gateway": "critical",
    "ollama": "$CHECK_ollama",
    "disk": "$CHECK_disk",
    "anthropicApi": "unknown",
    "ollamaApi": "unknown"
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
    # US40: Log recovery event to obs.db
    bash "$HOME/.openclaw/workspace/scripts/obs-log.sh" \
      --source health-check --level INFO --type health_recovery \
      --message "Gateway recovered after $FAILURES consecutive failures" \
      --detail "{\"previousFailures\":$FAILURES}" \
      >> "$LOG" 2>&1 || true
  fi

  # ── CHECK 16: Sprint FK consistency (TKT-0348 A6) ──────────────────────────
  # Alert-only — never auto-mutates. Reports divergence between state_tickets.sprint_id
  # and state_sprints.items. Only checks the current active sprint.
  FK_CHECK_SCRIPT="$HOME/.openclaw/workspace/scripts/sprint-fk-consistency-check.sh"
  if [[ -x "$FK_CHECK_SCRIPT" ]]; then
    FK_RESULT=$(bash "$FK_CHECK_SCRIPT" 2>/dev/null)
    FK_EXIT=$?
    if [[ $FK_EXIT -ne 0 ]]; then
      FK_CONSISTENT=$(echo "$FK_RESULT" | /opt/homebrew/bin/jq -r '.consistent // "unknown"' 2>/dev/null)
      if [[ "$FK_CONSISTENT" == "false" ]]; then
        FK_ITEMS_NOT_PG=$(echo "$FK_RESULT" | /opt/homebrew/bin/jq -r '.in_items_not_in_pg_count // 0' 2>/dev/null)
        FK_PG_NOT_ITEMS=$(echo "$FK_RESULT" | /opt/homebrew/bin/jq -r '.in_pg_not_in_items_count // 0' 2>/dev/null)
        log "ALERT: Sprint FK divergence detected — items_not_in_pg=$FK_ITEMS_NOT_PG, pg_not_in_items=$FK_PG_NOT_ITEMS (alert-only, no auto-mutation)"
        [[ "$OVERALL_STATUS" == "ok" ]] && OVERALL_STATUS="degraded"
        ISSUES+=("Sprint FK divergence: $FK_ITEMS_NOT_PG items in sprint not in PG, $FK_PG_NOT_ITEMS tickets in PG not in sprint items")
      fi
    fi
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
  "lastCheck": "$(TZ=Australia/Melbourne date +%Y-%m-%dT%H:%M:%S%z)",
  "lastOk": "$(TZ=Australia/Melbourne date +%Y-%m-%dT%H:%M:%S%z)",
  "exitCode": $EXIT_CODE,
  "issues": $ISSUES_JSON,
  "anthropicReachable": $([ "$ANTHROPIC_REACHABLE" = "1" ] && echo True || echo False),
  "ollamaReachable": $([ "$OLLAMA_API_REACHABLE" = "1" ] && echo True || echo False),
  "checks": {
    "gateway": "$CHECK_gateway",
    "ollama": "$CHECK_ollama",
    "disk": "$CHECK_disk",
    "healthStateAge": "$CHECK_health_state",
    "costStateAge": "$CHECK_cost_state",
    "staleLockFilesCleared": $LOCK_CLEARED,
    "anthropicApi": "$CHECK_anthropic",
    "ollamaApi": "$CHECK_ollamaApi"
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


# ── Uptime logging (QW-4) ────────────────────────────────────────────────────
# Track service uptime at every health check cycle for SLO reporting.
UPTIME_FILE="$HOME/.openclaw/workspace/state/uptime-log.json"
UPTIME_STATUS="${OVERALL_STATUS:-unknown}"
UPTIME_ISSUES="${ISSUES_JSON:-[]}"
python3 - << UEOF
import json
from datetime import datetime, timezone

ufile = "$UPTIME_FILE"
now = datetime.now(timezone.utc).isoformat()
status = "$UPTIME_STATUS"
try:
    issues = $UPTIME_ISSUES
except:
    issues = []

if not __import__('os').path.exists(ufile):
    data = {
        "schema": "1.0",
        "trackingStarted": now[:10],
        "sloTarget": 0.995,
        "events": [],
        "summary": {"totalChecks": 0, "upChecks": 0, "downtimeMinutes": 0, "uptimePct": 100.0}
    }
else:
    data = json.load(open(ufile))

data["events"].append({"ts": now, "status": status, "consecutiveFailures": $NEW_FAILURES, "issues": issues})
data["events"] = data["events"][-720:]  # keep last 720 events (~2.5 days at 5-min cadence)

s = data["summary"]
s["totalChecks"] = s.get("totalChecks", 0) + 1
if status == "ok":
    s["upChecks"] = s.get("upChecks", 0) + 1
else:
    s["downtimeMinutes"] = s.get("downtimeMinutes", 0) + 5
s["uptimePct"] = round(s["upChecks"] / s["totalChecks"] * 100, 3) if s["totalChecks"] > 0 else 100.0
s["lastCheck"] = now
s["lastStatus"] = status

open(ufile, "w").write(json.dumps(data, indent=2))
print(f"[uptime] {status} logged — uptime {s['uptimePct']}% ({s['upChecks']}/{s['totalChecks']} checks)")
UEOF


log "Health check complete. Exit code: ${EXIT_CODE:-2}"
exit ${EXIT_CODE:-2}
