#!/bin/bash
# task-watchdog.sh — Detect stalled, stuck, and spawn-queued async tasks
# Run by heartbeat every 30 min. 
#
# Checks:
#   1. Tasks stalled (no update in >30 min) — existing check
#   2. Tasks created but no checkpoint within 15 min (spawn-but-not-started) — NEW
#   3. Tasks with status "pending" older than 15 min — NEW
#
# Writes state/task-stall-alert.json with all issues found.
# Exit code 2 = issues found, 0 = all healthy.

set -euo pipefail

WORKSPACE="/Users/ainchorsangiefpl/.openclaw/workspace"
STATE="$WORKSPACE/state/async-tasks.json"
STALL_THRESHOLD_MINUTES="${1:-30}"
SPAWN_THRESHOLD_MINUTES=15   # New: detect spawn-queue delays
PENDING_THRESHOLD_MINUTES=15 # New: detect stuck-pending tasks

if [[ ! -f "$STATE" ]]; then
  echo "No async-tasks.json — nothing to watch"
  exit 0
fi

python3 - << PYEOF
import json, os, sys
from datetime import datetime, timezone, timedelta

state_file = "$STATE"
stall_threshold_min = int("$STALL_THRESHOLD_MINUTES")
spawn_threshold_min = int("$SPAWN_THRESHOLD_MINUTES")
pending_threshold_min = int("$PENDING_THRESHOLD_MINUTES")

with open(state_file) as f:
    tasks = json.load(f)

active = tasks.get("activeTasks", {})
if not active:
    print("No active tasks.")
    sys.exit(0)

now = datetime.now(timezone.utc)
stalled = []       # >30 min no update
spawn_queued = []  # created but no checkpoint after 15 min
stuck_pending = [] # status=pending for >15 min

for task_id, t in active.items():
    last_updated_str = t.get("lastUpdatedAt", "")
    created_at_str   = t.get("createdAt", "")
    last_checkpoint  = t.get("lastCheckpoint", "")
    status           = t.get("status", "unknown")
    
    # Skip tasks that are intentionally paused
    if status in ("waiting_ken", "waiting_approval", "cancelled", "completed"):
        continue

    # ── Check 1: Stalled tasks (no update in >30 min) ────────────────────────
    if last_updated_str:
        try:
            last_updated = datetime.fromisoformat(last_updated_str.replace("Z", "+00:00"))
            age_min = (now - last_updated).total_seconds() / 60
            if age_min > stall_threshold_min:
                stalled.append({
                    "id": task_id,
                    "goal": t.get("goal", "?"),
                    "currentStep": t.get("currentStep", "?"),
                    "status": status,
                    "agent": t.get("agent", "?"),
                    "reason": f"{int(age_min)} min since last update (threshold: {stall_threshold_min} min)",
                    "checkType": "stalled",
                    "taskFile": t.get("taskFile", "")
                })
        except Exception as e:
            stalled.append({
                "id": task_id,
                "goal": t.get("goal", "?"),
                "currentStep": t.get("currentStep", "?"),
                "status": status,
                "agent": t.get("agent", "?"),
                "reason": f"bad lastUpdatedAt timestamp: {e}",
                "checkType": "stalled",
                "taskFile": t.get("taskFile", "")
            })

    # ── Check 2: Spawn-but-not-started (created >15 min ago, no checkpoint) ──
    # This detects the sub-agent spawn queue delay pattern (power trip incident)
    if created_at_str and not last_checkpoint:
        try:
            created_at = datetime.fromisoformat(created_at_str.replace("Z", "+00:00"))
            age_min = (now - created_at).total_seconds() / 60
            if age_min > spawn_threshold_min:
                spawn_queued.append({
                    "id": task_id,
                    "goal": t.get("goal", "?"),
                    "status": status,
                    "agent": t.get("agent", "?"),
                    "reason": f"Created {int(age_min)} min ago — no checkpoint yet (threshold: {spawn_threshold_min} min)",
                    "checkType": "spawn_not_started",
                    "createdAt": created_at_str,
                    "taskFile": t.get("taskFile", "")
                })
        except Exception as e:
            pass

    # ── Check 3: Stuck pending (status=pending for >15 min) ──────────────────
    if status == "pending" and created_at_str:
        try:
            created_at = datetime.fromisoformat(created_at_str.replace("Z", "+00:00"))
            pending_age_min = (now - created_at).total_seconds() / 60
            if pending_age_min > pending_threshold_min:
                stuck_pending.append({
                    "id": task_id,
                    "goal": t.get("goal", "?"),
                    "status": "pending",
                    "agent": t.get("agent", "?"),
                    "reason": f"Status=pending for {int(pending_age_min)} min (threshold: {pending_threshold_min} min) — may be stuck in spawn queue",
                    "checkType": "stuck_pending",
                    "createdAt": created_at_str,
                    "taskFile": t.get("taskFile", "")
                })
        except Exception as e:
            pass

# Combine all issues
all_issues = stalled + spawn_queued + stuck_pending

if not all_issues:
    print(f"All {len(active)} task(s) healthy — no stalls, no spawn delays, no stuck pending.")
    sys.exit(0)

# Build alert
alert = {
    "alertAt": now.isoformat(),
    "totalIssues": len(all_issues),
    "stalledCount": len(stalled),
    "spawnQueuedCount": len(spawn_queued),
    "stuckPendingCount": len(stuck_pending),
    "issues": all_issues
}

# Maintain backward compat field
alert["stalledTasks"] = all_issues

alert_file = "$WORKSPACE/state/task-stall-alert.json"
with open(alert_file, "w") as f:
    json.dump(alert, f, indent=2)

print(f"WATCHDOG ALERT: {len(all_issues)} issue(s) found — written to task-stall-alert.json")
if stalled:
    print(f"\n  STALLED ({len(stalled)}):")
    for t in stalled:
        print(f"    - {t['id']}: {t['goal'][:60]} | {t['reason']}")
if spawn_queued:
    print(f"\n  SPAWN-NOT-STARTED ({len(spawn_queued)}):")
    for t in spawn_queued:
        print(f"    - {t['id']}: {t['goal'][:60]} | {t['reason']}")
if stuck_pending:
    print(f"\n  STUCK-PENDING ({len(stuck_pending)}):")
    for t in stuck_pending:
        print(f"    - {t['id']}: {t['goal'][:60]} | {t['reason']}")

sys.exit(2)
PYEOF
