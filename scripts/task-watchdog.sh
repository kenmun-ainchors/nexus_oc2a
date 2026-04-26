#!/bin/bash
# task-watchdog.sh — Detect stalled async tasks and alert Ken via Telegram
# Run by heartbeat every 30 min. Alerts if a task hasn't updated in >30 min.

set -euo pipefail

WORKSPACE="/Users/ainchorsangiefpl/.openclaw/workspace"
STATE="$WORKSPACE/state/async-tasks.json"
STALL_THRESHOLD_MINUTES="${1:-30}"

if [[ ! -f "$STATE" ]]; then
  echo "No async-tasks.json — nothing to watch"
  exit 0
fi

python3 - << PYEOF
import json, os, sys
from datetime import datetime, timezone, timedelta

state_file = "$STATE"
threshold_min = int("$STALL_THRESHOLD_MINUTES")

with open(state_file) as f:
    tasks = json.load(f)

active = tasks.get("activeTasks", {})
if not active:
    print("No active tasks.")
    sys.exit(0)

now = datetime.now(timezone.utc)
stalled = []

for task_id, t in active.items():
    last_updated_str = t.get("lastUpdatedAt", "")
    status = t.get("status", "unknown")
    
    # Skip tasks that are intentionally waiting on Ken
    if status in ("waiting_ken", "waiting_approval", "cancelled"):
        continue
    
    if not last_updated_str:
        stalled.append((task_id, t, "never updated"))
        continue
    
    try:
        last_updated = datetime.fromisoformat(last_updated_str.replace("Z", "+00:00"))
        age_min = (now - last_updated).total_seconds() / 60
        if age_min > threshold_min:
            stalled.append((task_id, t, f"{int(age_min)} min since last update"))
    except Exception as e:
        stalled.append((task_id, t, f"bad timestamp: {e}"))

if not stalled:
    print(f"All {len(active)} task(s) active and healthy.")
    sys.exit(0)

# Write stall alert to a file for Yoda to pick up in heartbeat
alert = {
    "alertAt": now.isoformat(),
    "stalledTasks": [
        {
            "id": tid,
            "goal": t.get("goal", "?"),
            "currentStep": t.get("currentStep", "?"),
            "status": t.get("status", "?"),
            "agent": t.get("agent", "?"),
            "reason": reason,
            "taskFile": t.get("taskFile", "")
        }
        for tid, t, reason in stalled
    ]
}

alert_file = "$WORKSPACE/state/task-stall-alert.json"
with open(alert_file, "w") as f:
    json.dump(alert, f, indent=2)

print(f"STALL ALERT: {len(stalled)} task(s) stalled — written to task-stall-alert.json")
for tid, t, reason in stalled:
    print(f"  - {tid}: {t.get('goal','?')} | {reason}")
sys.exit(2)
PYEOF
