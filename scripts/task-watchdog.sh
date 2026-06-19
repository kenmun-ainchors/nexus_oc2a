#!/bin/bash
# task-watchdog.sh — Detect stalled, stuck, and spawn-queued async tasks
# Run by heartbeat every 30 min.
#
# Checks:
#   1. Tasks stalled (no update in >30 min) — existing check
#   2. Tasks created but no checkpoint within 15 min (spawn-but-not-started) — NEW
#   3. Tasks with status "pending" older than 15 min — NEW
#   4. JSON ↔ PG cross-check (L-075 fix, TKT-0409 D3) — NEW
#
# Writes state/task-stall-alert.json with all issues found.
# Exit codes:
#   0 = all healthy
#   1 = JSON/PG divergence detected (TKT-0409 D3 cross-check)
#   2 = stall/spawn/pending issues found

set -euo pipefail

WORKSPACE="/Users/ainchorsangiefpl/.openclaw/workspace"
# TKT-0409 D3: was state/async-tasks.json — that file does not exist.
# Real queue is state/task-queue.json (JSON) ↔ state_task_queue (PG table).
STATE="$WORKSPACE/state/task-queue.json"
STALL_THRESHOLD_MINUTES="${1:-30}"
SPAWN_THRESHOLD_MINUTES=15
PENDING_THRESHOLD_MINUTES=15

# ── TKT-0319 Atom 3: Resume detector for PG-backed running tasks ─────────
# Transition state_task_queue rows in status='running' (or 'dispatched')
# to 'resumable' when they have not updated recently. Runs before JSON stall
# checks so it is not blocked by L-075 JSON↔PG divergence.
python3 - << RESUME_PY
import json, os, subprocess, sys
from datetime import datetime, timezone, timedelta

ws = "/Users/ainchorsangiefpl/.openclaw/workspace"
env = os.environ.copy()
env.update({
    "PGHOST": "/tmp",
    "PGPORT": "5432",
    "PGUSER": "ainchorsangiefpl",
    "PGDATABASE": "ainchors_nexus",
})

now = datetime.now(timezone.utc)
STALE_MINUTES = 15
threshold = now - timedelta(minutes=STALE_MINUTES)

def pg_str(s):
    return "'" + str(s).replace("'", "''") + "'"

def pg_jsonb(obj):
    return pg_str(json.dumps(obj, ensure_ascii=False)) + "::jsonb"

select_sql = f"""
SELECT id, status, state_payload, resume_attempts, claimtimeout, claimedat
FROM state_task_queue
WHERE status IN ('running', 'dispatched')
  AND updated_at_ts < {pg_str(threshold.isoformat())}
ORDER BY updated_at_ts ASC;
"""

try:
    r = subprocess.run(
        ["/opt/homebrew/bin/psql", "-t", "-A", "-F", "|", "-v", "ON_ERROR_STOP=1", "-c", select_sql],
        capture_output=True, text=True, timeout=15, env=env
    )
    if r.returncode != 0:
        print(f"RESUME_DETECTOR: PG query failed: {r.stderr}")
        sys.exit(0)
    lines = [ln for ln in r.stdout.splitlines() if ln.strip()]
except Exception as e:
    print(f"RESUME_DETECTOR: PG query failed: {e}")
    sys.exit(0)

resumable = []
for ln in lines:
    parts = ln.split("|", 5)
    if len(parts) < 6:
        continue
    task_id, status, payload_json, attempts, claimtimeout, claimedat = parts
    try:
        payload = json.loads(payload_json) if payload_json else {}
    except Exception:
        payload = {}

    reason = "claim_timeout" if status == "dispatched" else "stalled"
    attempts = int(attempts) if attempts else 0
    new_attempts = attempts + 1
    payload["failure_reason"] = reason
    payload["resumed_from_status"] = status
    payload["resumable_detected_at"] = now.isoformat()

    update_sql = f"""
    UPDATE state_task_queue
    SET status = 'resumable',
        previous_status = {pg_str(status)},
        resume_attempts = {new_attempts},
        updated_at_ts = now(),
        state_payload = {pg_jsonb(payload)}
    WHERE id = {pg_str(task_id)}
      AND status IN ('running', 'dispatched');
    """
    try:
        u = subprocess.run(
            ["/opt/homebrew/bin/psql", "-t", "-A", "-v", "ON_ERROR_STOP=1", "-c", update_sql],
            capture_output=True, text=True, timeout=15, env=env
        )
        if u.returncode != 0:
            print(f"RESUME_DETECTOR: update failed for {task_id}: {u.stderr}")
            continue
        if "UPDATE 1" in u.stdout:
            resumable.append({
                "id": task_id,
                "previous_status": status,
                "failure_reason": reason,
                "resume_attempts": new_attempts,
                "detected_at": now.isoformat()
            })
    except Exception as e:
        print(f"RESUME_DETECTOR: failed to update {task_id}: {e}")

if resumable:
    resume_file = os.path.join(ws, "state", "resumable-atoms.json")
    with open(resume_file, "w") as f:
        json.dump({
            "detectedAt": now.isoformat(),
            "count": len(resumable),
            "resumable": resumable
        }, f, indent=2)
    print(f"RESUME_DETECTOR: {len(resumable)} task(s) transitioned to resumable -> {resume_file}")
else:
    print("RESUME_DETECTOR: no stale running/dispatched tasks found")
RESUME_PY

if [[ ! -f "$STATE" ]]; then
  echo "No task-queue.json — skipping JSON stall checks"
  exit 0
fi

# ── Cross-check: JSON vs PG (L-075 fix, TKT-0409 D3) ───────────────────────
# If divergence is detected, emit a clear alert and exit 1 BEFORE the
# stall checks (because stall checks against stale JSON is the L-075 bug).
DIVERGENCE_OUT=$(python3 -<<'PYDIVERGE'
import json, os, subprocess, sys

ws = "/Users/ainchorsangiefpl/.openclaw/workspace"
json_path = os.path.join(ws, "state", "task-queue.json")

try:
    with open(json_path) as f:
        jdata = json.load(f)
except Exception as e:
    print(f"DIVERGENCE|json_unreadable|{e}")
    sys.exit(0)  # handled in shell, exit code controlled there

json_entries = jdata.get("queue", [])
# Build JSON view: {id: status}
json_view = {}
for e in json_entries:
    eid = e.get("atom_id") or e.get("id")
    if eid:
        json_view[eid] = e.get("status", "unknown")

# Read PG state_task_queue
env = os.environ.copy()
env.update({
    "PGHOST": "/tmp",
    "PGPORT": "5432",
    "PGUSER": "ainchorsangiefpl",
    "PGDATABASE": "ainchors_nexus",
})

try:
    r = subprocess.run(
        ["/opt/homebrew/bin/psql", "-t", "-A", "-F", "|", "-c",
         "SELECT id, status FROM state_task_queue"],
        capture_output=True, text=True, timeout=10, env=env
    )
    pg_lines = [ln for ln in r.stdout.splitlines() if "|" in ln]
except Exception as e:
    # PG unavailable — not a divergence, just skip
    print(f"OK|pg_unavailable|{e}")
    sys.exit(0)

pg_view = {}
for ln in pg_lines:
    parts = ln.split("|", 1)
    if len(parts) == 2:
        pg_view[parts[0]] = parts[1]

# Normalize status mapping: JSON uses 'verified' as terminal, PG uses 'complete'/'done'
# Map: verified → complete, pending → queued
norm = {"verified": "complete", "pending": "queued", "claimed": "dispatched"}

# Compare JSON view to PG view.
# CHG-0530: state/task-queue.json is audit-trail only; PG is source of truth.
# Therefore:
#   - JSON rows with status 'historical-orphan' or 'cancelled-orphaned' are
#     expected to have no PG counterpart. They are legacy traceability, not divergence.
#   - PG rows missing from JSON are expected (JSON is not a full mirror).
#   - Fatal divergence = active-status mismatch for an ID present in both, or
#     a JSON row with an active status that is absent from PG.
HISTORICAL_STATUSES = {"historical-orphan", "cancelled-orphaned", "legacy"}

mismatches = []
json_only_active = []
legacy_only = []

for jid, jstatus in json_view.items():
    if jstatus in HISTORICAL_STATUSES:
        legacy_only.append(f"{jid}:json={jstatus}")
        continue
    if jid not in pg_view:
        json_only_active.append(f"{jid}:json={jstatus}")
    else:
        pgstatus = pg_view[jid]
        jnorm = norm.get(jstatus, jstatus)
        pgnorm = norm.get(pgstatus, pgstatus)
        if jnorm != pgnorm and "unknown" not in (jnorm, pgnorm):
            mismatches.append(f"{jid}:json={jstatus}->pg={pgstatus}")

# missing_in_json is expected for an audit trail; track for info only
missing_in_json = [pgid for pgid in pg_view if pgid not in json_view]

if mismatches or json_only_active:
    parts = []
    if mismatches:
        parts.append(f"mismatches={';'.join(mismatches)}")
    if json_only_active:
        parts.append(f"json_only_active={','.join(json_only_active[:10])}")
    if legacy_only:
        parts.append(f"legacy_only={len(legacy_only)}")
    if missing_in_json:
        parts.append(f"missing_in_json={len(missing_in_json)}")
    print("DIVERGENCE|" + "|".join(parts))
    sys.exit(1)

if legacy_only or missing_in_json:
    # Non-fatal expected drift. Report it but allow stall checks to run.
    print(f"OK|expected_drift|legacy_only={len(legacy_only)}|missing_in_json={len(missing_in_json)}")
    sys.exit(0)

print("OK|cross_check_passed")
PYDIVERGE
)

DIVERGENCE_STATUS=$?

if [[ "$DIVERGENCE_OUT" == DIVERGENCE* ]]; then
  echo "WATCHDOG DIVERGENCE (L-075 / TKT-0409 D3): $DIVERGENCE_OUT"
  # Write divergence alert file (separate from stall alert for clarity)
  divergence_file="$WORKSPACE/state/task-queue-divergence-alert.json"
  python3 -c "
import json
from datetime import datetime, timezone
alert = {
    'alertAt': datetime.now(timezone.utc).isoformat(),
    'alertType': 'json_pg_divergence',
    'source': 'task-watchdog.sh',
    'tkt': 'TKT-0409 D3',
    'raw': '''$DIVERGENCE_OUT'''
}
with open('$divergence_file', 'w') as f:
    json.dump(alert, f, indent=2)
"
  echo "WATCHDOG EXIT 1: JSON/PG divergence — see $divergence_file"
  exit 1
fi

# ── Stall / spawn / pending checks (original logic) ───────────────────────
python3 - << PYEOF
import json, os, sys
from datetime import datetime, timezone, timedelta

state_file = "$STATE"
stall_threshold_min = int("$STALL_THRESHOLD_MINUTES")
spawn_threshold_min = int("$SPAWN_THRESHOLD_MINUTES")
pending_threshold_min = int("$PENDING_THRESHOLD_MINUTES")

with open(state_file) as f:
    data = json.load(f)

# TKT-0409 D3: real queue is data['queue'] (list of entries), not data['activeTasks']
# Backward-compat: support both shapes.
if "queue" in data and isinstance(data["queue"], list):
    entries = {e.get("atom_id") or e.get("id"): e for e in data["queue"]}
elif "activeTasks" in data and isinstance(data["activeTasks"], dict):
    entries = data["activeTasks"]
else:
    print("No active tasks.")
    sys.exit(0)

if not entries:
    print("No active tasks.")
    sys.exit(0)

now = datetime.now(timezone.utc)
stalled = []       # >30 min no update
spawn_queued = []  # created but no checkpoint after 15 min
stuck_pending = [] # status=pending for >15 min

for task_id, t in entries.items():
    last_updated_str = t.get("lastUpdatedAt", t.get("updated_at", t.get("queued_at", "")))
    created_at_str   = t.get("createdAt", t.get("queued_at", t.get("created_at", "")))
    last_checkpoint  = t.get("lastCheckpoint", "")
    status           = t.get("status", "unknown")

    # Skip tasks that are intentionally paused, terminal, or audit-trail legacy
    if status in ("waiting_ken", "waiting_approval", "cancelled", "completed",
                  "verified", "complete", "done", "closed", "sub_crest_done",
                  "historical-orphan", "cancelled-orphaned", "legacy"):
        continue

    # ── Check 1: Stalled tasks (no update in >30 min) ────────────────────────
    if last_updated_str:
        try:
            last_updated = datetime.fromisoformat(last_updated_str.replace("Z", "+00:00"))
            age_min = (now - last_updated).total_seconds() / 60
            if age_min > stall_threshold_min:
                stalled.append({
                    "id": task_id,
                    "goal": t.get("title", t.get("task", "?"))[:60],
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
                "goal": t.get("title", "?"),
                "status": status,
                "agent": t.get("agent", "?"),
                "reason": f"bad lastUpdatedAt timestamp: {e}",
                "checkType": "stalled",
            })

    # ── Check 2: Spawn-but-not-started (created >15 min ago, no checkpoint) ──
    if created_at_str and not last_checkpoint:
        try:
            created_at = datetime.fromisoformat(created_at_str.replace("Z", "+00:00"))
            age_min = (now - created_at).total_seconds() / 60
            if age_min > spawn_threshold_min:
                spawn_queued.append({
                    "id": task_id,
                    "goal": t.get("title", t.get("task", "?"))[:60],
                    "status": status,
                    "agent": t.get("agent", "?"),
                    "reason": f"Created {int(age_min)} min ago — no checkpoint yet (threshold: {spawn_threshold_min} min)",
                    "checkType": "spawn_not_started",
                    "createdAt": created_at_str,
                })
        except Exception:
            pass

    # ── Check 3: Stuck pending (status=pending for >15 min) ──────────────────
    if status == "pending" and created_at_str:
        try:
            created_at = datetime.fromisoformat(created_at_str.replace("Z", "+00:00"))
            pending_age_min = (now - created_at).total_seconds() / 60
            if pending_age_min > pending_threshold_min:
                stuck_pending.append({
                    "id": task_id,
                    "goal": t.get("title", "?"),
                    "status": "pending",
                    "agent": t.get("agent", "?"),
                    "reason": f"Status=pending for {int(pending_age_min)} min (threshold: {pending_threshold_min} min) — may be stuck in spawn queue",
                    "checkType": "stuck_pending",
                    "createdAt": created_at_str,
                })
        except Exception:
            pass

# Combine all issues
all_issues = stalled + spawn_queued + stuck_pending

if not all_issues:
    print(f"All {len(entries)} task(s) healthy — no stalls, no spawn delays, no stuck pending.")
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
alert["stalledTasks"] = all_issues  # backward compat

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

