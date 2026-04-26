#!/bin/zsh
# AInchors Startup Recovery Script
# Runs after every gateway restart.
# 
# Actions:
#   1. Clear stale lock files
#   2. Check what tasks were active before shutdown
#   3. Run health checks on all services
#   4. Write state/startup-report.json
#   5. Write /tmp/startup-alert.txt for Yoda to dispatch to Ken
#
# Triggered by: gateway restart hook / launchd OnDemand

set -euo pipefail

WORKSPACE="$HOME/.openclaw/workspace"
STATE="$WORKSPACE/state"
ASYNC_TASKS="$STATE/async-tasks.json"
HEALTH_STATE="$STATE/health-state.json"
STARTUP_REPORT="$STATE/startup-report.json"
LOCK_DIR="$STATE"
LOG="$HOME/Backups/ainchors/logs/startup.log"
LOCK_STALE_MIN=5
STARTUP_ALERT="/tmp/startup-alert.txt"

mkdir -p "$(dirname $LOG)"
mkdir -p "$STATE"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [STARTUP] $1" | tee -a "$LOG"
}

log "=== Startup Recovery Begin ==="
STARTUP_TIME=$(date -u +%Y-%m-%dT%H:%M:%SZ)
STARTUP_TIME_LOCAL=$(date '+%Y-%m-%d %H:%M:%S %Z')

# ── STEP 1: Clear stale lock files ───────────────────────────────────────────
log "Clearing stale lock files..."
LOCKS_CLEARED=0
LOCKS_FOUND=()
for lock_file in "$LOCK_DIR"/*.lock; do
  [[ -f "$lock_file" ]] || continue
  lock_age_min=$(( ($(date +%s) - $(stat -f %m "$lock_file" 2>/dev/null || echo 0)) / 60 ))
  LOCKS_FOUND+=("$(basename $lock_file) (${lock_age_min}min old)")
  if (( lock_age_min > LOCK_STALE_MIN )); then
    log "  Removing stale lock: $lock_file (${lock_age_min} min old)"
    rm -f "$lock_file"
    LOCKS_CLEARED=$((LOCKS_CLEARED + 1))
  else
    log "  Active lock kept: $lock_file (${lock_age_min} min old)"
  fi
done
if (( ${#LOCKS_FOUND[@]} == 0 )); then
  log "  No lock files found"
fi
log "Lock files cleared: $LOCKS_CLEARED"

# ── STEP 2: Check tasks active before shutdown ───────────────────────────────
log "Checking pre-shutdown task state..."
ACTIVE_TASKS_JSON="[]"
ACTIVE_TASK_COUNT=0
INCOMPLETE_TASKS=()

if [[ -f "$ASYNC_TASKS" ]]; then
  TASK_SUMMARY=$(python3 - << PYEOF
import json, sys
from datetime import datetime, timezone

try:
    with open("$ASYNC_TASKS") as f:
        data = json.load(f)
except Exception as e:
    print(json.dumps({"error": str(e), "tasks": [], "count": 0}))
    sys.exit(0)

active = data.get("activeTasks", {})
completed = data.get("completedTasks", {})

task_list = []
incomplete = []
for tid, t in active.items():
    status = t.get("status", "unknown")
    task_list.append({
        "id": tid,
        "goal": t.get("goal", "?")[:80],
        "status": status,
        "agent": t.get("agent", "?"),
        "lastUpdated": t.get("lastUpdatedAt", "?"),
        "currentStep": t.get("currentStep", "?")
    })
    if status not in ("completed", "cancelled"):
        incomplete.append(f"{tid}: {t.get('goal','?')[:60]} [{status}]")

print(json.dumps({
    "activeCount": len(active),
    "completedCount": len(completed),
    "incompleteCount": len(incomplete),
    "tasks": task_list,
    "incomplete": incomplete
}))
PYEOF
)
  ACTIVE_TASK_COUNT=$(echo "$TASK_SUMMARY" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('activeCount',0))" 2>/dev/null || echo 0)
  INCOMPLETE_COUNT=$(echo "$TASK_SUMMARY" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('incompleteCount',0))" 2>/dev/null || echo 0)
  ACTIVE_TASKS_JSON=$(echo "$TASK_SUMMARY" | python3 -c "import json,sys; d=json.load(sys.stdin); print(json.dumps(d.get('tasks',[])))" 2>/dev/null || echo '[]')
  
  log "  Tasks in async-tasks.json: $ACTIVE_TASK_COUNT active, $INCOMPLETE_COUNT incomplete"
  
  while IFS= read -r task_line; do
    [[ -z "$task_line" ]] && continue
    INCOMPLETE_TASKS+=("$task_line")
    log "  Incomplete task: $task_line"
  done < <(echo "$TASK_SUMMARY" | python3 -c "import json,sys; d=json.load(sys.stdin); [print(x) for x in d.get('incomplete',[])]" 2>/dev/null || true)
else
  log "  async-tasks.json not found — no pre-shutdown task data"
fi

# ── STEP 3: Health check all services ────────────────────────────────────────
log "Running service health checks..."
GATEWAY_STATUS="unknown"
OLLAMA_STATUS="unknown"
DISK_STATUS="ok"
DISK_DETAILS=""

# Gateway
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "http://127.0.0.1:18789" 2>/dev/null || echo "000")
if [[ "$HTTP_STATUS" == "200" ]] || [[ "$HTTP_STATUS" == "301" ]] || [[ "$HTTP_STATUS" == "302" ]] || [[ "$HTTP_STATUS" == "401" ]]; then
  GATEWAY_STATUS="ok"
  log "  Gateway: OK (HTTP $HTTP_STATUS)"
else
  GATEWAY_STATUS="down"
  log "  Gateway: DOWN (HTTP $HTTP_STATUS)"
fi

# Ollama
if pgrep -x ollama > /dev/null 2>&1; then
  OLLAMA_STATUS="ok"
  log "  Ollama: OK (process running)"
else
  OLLAMA_STATUS="not_running"
  log "  Ollama: NOT RUNNING"
fi

# Disk
DISK_ALERTS=""
while IFS= read -r line; do
  PCT=$(echo "$line" | awk '{print $5}' | tr -d '%')
  MOUNT=$(echo "$line" | awk '{print $6}')
  if [[ "$PCT" =~ ^[0-9]+$ ]] && (( PCT >= 85 )); then
    DISK_STATUS="high"
    DISK_ALERTS="${DISK_ALERTS}${MOUNT}:${PCT}% "
    log "  Disk: HIGH — $MOUNT at ${PCT}%"
  fi
done < <(df -h | tail -n +2)
if [[ "$DISK_STATUS" == "ok" ]]; then
  log "  Disk: OK (all volumes <85%)"
fi

# Health state age
HEALTH_STATE_AGE_MIN=999
HEALTH_STATE_LAST="unknown"
if [[ -f "$HEALTH_STATE" ]]; then
  now_epoch=$(date +%s)
  file_epoch=$(stat -f %m "$HEALTH_STATE" 2>/dev/null || echo 0)
  HEALTH_STATE_AGE_MIN=$(( (now_epoch - file_epoch) / 60 ))
  HEALTH_STATE_LAST=$(python3 -c "import json; d=json.load(open('$HEALTH_STATE')); print(d.get('lastCheck','unknown'))" 2>/dev/null || echo "unknown")
  log "  Health state age: ${HEALTH_STATE_AGE_MIN} min (last check: $HEALTH_STATE_LAST)"
fi

# ── STEP 4: Write startup-report.json ────────────────────────────────────────
log "Writing startup-report.json..."
python3 - << PYEOF
import json
from datetime import datetime

report = {
  "startupTime": "$STARTUP_TIME",
  "startupTimeLocal": "$STARTUP_TIME_LOCAL",
  "locksCleared": $LOCKS_CLEARED,
  "services": {
    "gateway": "$GATEWAY_STATUS",
    "ollama": "$OLLAMA_STATUS",
    "disk": "$DISK_STATUS",
    "diskAlerts": "$DISK_ALERTS".strip()
  },
  "taskState": {
    "activeTaskCount": $ACTIVE_TASK_COUNT,
    "incompleteCount": ${#INCOMPLETE_TASKS[@]},
    "tasks": $ACTIVE_TASKS_JSON
  },
  "healthStateAgeMins": $HEALTH_STATE_AGE_MIN,
  "healthStateLastCheck": "$HEALTH_STATE_LAST"
}
with open("$STARTUP_REPORT", "w") as f:
    json.dump(report, f, indent=2)
print("startup-report.json written")
PYEOF

log "startup-report.json written"

# ── STEP 5: Write /tmp/startup-alert.txt for Yoda to send to Ken ──────────────
log "Writing startup alert for Ken..."

# Determine overall status
if [[ "$GATEWAY_STATUS" == "down" ]]; then
  STATUS_EMOJI="🔴"
  STATUS_LABEL="CRITICAL"
elif [[ "$OLLAMA_STATUS" == "not_running" ]] || [[ "$DISK_STATUS" == "high" ]] || (( INCOMPLETE_COUNT > 0 )); then
  STATUS_EMOJI="🟡"
  STATUS_LABEL="DEGRADED"
else
  STATUS_EMOJI="🟢"
  STATUS_LABEL="HEALTHY"
fi

TASK_SECTION=""
if (( ${#INCOMPLETE_TASKS[@]} > 0 )); then
  TASK_SECTION="\n\n⚠️ *Tasks pending before shutdown:*"
  for t in "${INCOMPLETE_TASKS[@]}"; do
    TASK_SECTION="$TASK_SECTION\n• $t"
  done
  TASK_SECTION="$TASK_SECTION\n\n_These tasks may need attention._"
fi

ISSUES_SECTION=""
if [[ "$OLLAMA_STATUS" != "ok" ]]; then
  ISSUES_SECTION="$ISSUES_SECTION\n• Ollama: not running"
fi
if [[ "$DISK_STATUS" == "high" ]]; then
  ISSUES_SECTION="$ISSUES_SECTION\n• Disk space high: $DISK_ALERTS"
fi
if (( LOCKS_CLEARED > 0 )); then
  ISSUES_SECTION="$ISSUES_SECTION\n• Cleared $LOCKS_CLEARED stale lock file(s)"
fi
if (( HEALTH_STATE_AGE_MIN > 10 )); then
  ISSUES_SECTION="$ISSUES_SECTION\n• Health monitor was stale for ${HEALTH_STATE_AGE_MIN} min before restart"
fi

if [[ -n "$ISSUES_SECTION" ]]; then
  ISSUES_SECTION="\n\n⚠️ *Issues detected:*$ISSUES_SECTION"
fi

cat > "$STARTUP_ALERT" << MSG
${STATUS_EMOJI} *AInchors Gateway Restarted* — ${STATUS_LABEL}

🕐 Time: ${STARTUP_TIME_LOCAL}

*Service Status:*
• Gateway: ${GATEWAY_STATUS}
• Ollama: ${OLLAMA_STATUS}
• Disk: ${DISK_STATUS}${ISSUES_SECTION}${TASK_SECTION}

_Startup recovery complete. All stale locks cleared._
MSG

log "Startup alert written to $STARTUP_ALERT"
log "=== Startup Recovery Complete ==="
