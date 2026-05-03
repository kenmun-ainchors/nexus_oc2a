#!/bin/zsh
# task-collector.sh — Always-on task monitoring collector (run by cron every 5 min)
# Actions: stall detection, completion verification, auto-discover, purge
# Output: exactly one line "TASKS: N stalls, N verified, N failed"
set -euo pipefail

WORKSPACE="${WORKSPACE:-$HOME/.openclaw/workspace}"
TASKS_DB="$WORKSPACE/state/tasks.db"
OBS_LOG="$WORKSPACE/scripts/obs-log.sh"
TASK_VERIFY="$WORKSPACE/scripts/task-verify.sh"
TASK_REGISTER="$WORKSPACE/scripts/task-register.sh"
COLLECTOR_STATE="$WORKSPACE/state/task-collector-state.json"
ALERT_FILE="$WORKSPACE/state/task-verification-alert.json"
ACTIVE_WORK="$WORKSPACE/state/active-work.json"
ASYNC_TASKS="$WORKSPACE/state/async-tasks.json"

STALLS_DETECTED=0
VERIFIED_COUNT=0
FAILED_COUNT=0

# ── Init DB if not exists ─────────────────────────────────────────────────────
if [[ ! -f "$TASKS_DB" ]]; then
  # DB doesn't exist yet — nothing to do
  echo "TASKS: 0 stalls, 0 verified, 0 failed"
  exit 0
fi

NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# ── Update collector state ────────────────────────────────────────────────────
python3 - "$COLLECTOR_STATE" "$NOW" <<'PYEOF'
import json, sys, os
state_file, now = sys.argv[1], sys.argv[2]
state = {}
if os.path.exists(state_file):
    try:
        with open(state_file) as f:
            state = json.load(f)
    except Exception:
        state = {}
state["lastRun"] = now
with open(state_file, "w") as f:
    json.dump(state, f, indent=2)
PYEOF

# ── a) Stall detection ────────────────────────────────────────────────────────
STALLED_TASKS=$(python3 - "$TASKS_DB" "$NOW" <<'PYEOF'
import sqlite3, sys, json
from datetime import datetime, timedelta, timezone
db, now_str = sys.argv[1], sys.argv[2]

conn = sqlite3.connect(db)
conn.row_factory = sqlite3.Row

# Stall threshold: 30 min with no heartbeat, OR created > 30 min ago with no heartbeat at all
cutoff = (datetime.now(timezone.utc) - timedelta(minutes=30)).strftime("%Y-%m-%dT%H:%M:%SZ")

rows = conn.execute("""
  SELECT id, title, agent, last_heartbeat, created_at
  FROM tasks
  WHERE status IN ('registered','in-progress')
  AND (
    (last_heartbeat IS NOT NULL AND last_heartbeat < ?)
    OR (last_heartbeat IS NULL AND created_at < ?)
  )
""", (cutoff, cutoff)).fetchall()

tasks = [dict(r) for r in rows]
if tasks:
    # Mark them as stalled
    ids = [t["id"] for t in tasks]
    for tid in ids:
        conn.execute(
            "UPDATE tasks SET status='stalled', last_heartbeat=? WHERE id=?",
            (now_str, tid)
        )
    conn.commit()

conn.close()
print(json.dumps(tasks))
PYEOF
)

STALLS_DETECTED=$(python3 -c "import sys,json; d=sys.stdin.read().strip(); print(len(json.loads(d)) if d else 0)" <<< "${STALLED_TASKS:-[]}")

# Log each stalled task
if (( STALLS_DETECTED > 0 )); then
  python3 - "$STALLED_TASKS" <<'PYEOF'
import sys, json, subprocess, os
tasks = json.loads(sys.argv[1])
obs_log = os.path.expanduser("~/.openclaw/workspace/scripts/obs-log.sh")
for t in tasks:
    heartbeat = t.get("last_heartbeat") or t.get("created_at") or "unknown"
    msg = f"Task {t['id']} stalled: {t['title']} (agent: {t['agent']}, last heartbeat: {heartbeat})"
    subprocess.run([
        "bash", obs_log,
        "--source", "task-collector",
        "--level", "WARN",
        "--type", "task_stall",
        "--message", msg,
        "--job-id", t["id"],
        "--detail", json.dumps({"task_id": t["id"], "agent": t["agent"], "last_heartbeat": heartbeat})
    ], capture_output=True)
PYEOF
fi

# ── b) Completion verification ────────────────────────────────────────────────
DONE_TASKS=$(python3 - "$TASKS_DB" <<'PYEOF'
import sqlite3, sys, json
db = sys.argv[1]
conn = sqlite3.connect(db)
conn.row_factory = sqlite3.Row
rows = conn.execute("""
  SELECT id, title, agent, reported_done_at, expected_deliverables
  FROM tasks
  WHERE status='done' AND verified_at IS NULL
""").fetchall()
conn.close()
print(json.dumps([dict(r) for r in rows]))
PYEOF
)

DONE_COUNT=$(python3 -c "import sys,json; d=sys.stdin.read().strip(); print(len(json.loads(d)) if d else 0)" <<< "${DONE_TASKS:-[]}")

if (( DONE_COUNT > 0 )); then
  # Build new alerts list
  NEW_ALERTS=()

  # Process each done task
  python3 - "$DONE_TASKS" <<'PYEOF' | while IFS= read -r TASK_ID; do
import sys, json
tasks = json.loads(sys.argv[1])
for t in tasks:
    print(t["id"])
PYEOF
    if bash "$TASK_VERIFY" "$TASK_ID" >/dev/null 2>&1; then
      VERIFIED_COUNT=$((VERIFIED_COUNT + 1))
    else
      FAILED_COUNT=$((FAILED_COUNT + 1))
      # Collect alert details
      ALERT_DETAIL=$(python3 - "$TASKS_DB" "$TASK_ID" "$NOW" <<'PYEOF'
import sqlite3, sys, json
db, task_id, detected_at = sys.argv[1], sys.argv[2], sys.argv[3]
conn = sqlite3.connect(db)
conn.row_factory = sqlite3.Row
row = conn.execute("SELECT * FROM tasks WHERE id=?", (task_id,)).fetchone()
conn.close()
if row:
    d = dict(row)
    failed_deliverables = []
    if d.get("verification_notes"):
        failed_deliverables = [d["verification_notes"]]
    print(json.dumps({
        "task_id": d["id"],
        "title": d["title"],
        "agent": d["agent"],
        "failed_deliverables": failed_deliverables,
        "reported_done_at": d.get("reported_done_at",""),
        "detected_at": detected_at
    }))
PYEOF
      )
      NEW_ALERTS+=("$ALERT_DETAIL")
    fi
  done

  # Write alert file if there are failures
  if (( ${#NEW_ALERTS[@]} > 0 )); then
    # Load existing alerts
    EXISTING_ALERTS="[]"
    if [[ -f "$ALERT_FILE" ]]; then
      EXISTING_ALERTS=$(python3 -c "
import json, sys
with open('$ALERT_FILE') as f:
    d = json.load(f)
print(json.dumps(d.get('alerts',[])))
" 2>/dev/null || echo "[]")
    fi

    python3 - "$ALERT_FILE" "$EXISTING_ALERTS" "${NEW_ALERTS[@]}" <<'PYEOF'
import sys, json
alert_file = sys.argv[1]
existing = json.loads(sys.argv[2])
new_raw = sys.argv[3:]  # JSON strings

new_alerts = []
for raw in new_raw:
    try:
        new_alerts.append(json.loads(raw))
    except Exception:
        pass

all_alerts = existing + new_alerts
out = {
    "schema": "task-verification-alert-v1",
    "alerts": all_alerts
}
with open(alert_file, "w") as f:
    json.dump(out, f, indent=2)
print(f"[task-collector] Wrote {len(new_alerts)} new alert(s) to alert file", file=sys.stderr)
PYEOF
  fi
fi

# ── c) Auto-discover from active-work.json and async-tasks.json ───────────────
python3 - "$TASKS_DB" "$ACTIVE_WORK" "$ASYNC_TASKS" "$TASK_REGISTER" "$NOW" <<'PYEOF'
import sqlite3, sys, json, os, subprocess
db, active_work_path, async_tasks_path, task_register, now = sys.argv[1:]

conn = sqlite3.connect(db)

# Get existing IDs
existing = set(r[0] for r in conn.execute("SELECT id FROM tasks").fetchall())
conn.close()

candidates = []

# Scan active-work.json
if os.path.exists(active_work_path):
    try:
        with open(active_work_path) as f:
            aw = json.load(f)
        # Look for subAgentKey style tasks
        work = aw.get("currentWork", {})
        if work and work.get("ticket"):
            ticket = work.get("ticket","")
            title = work.get("title","")
            key = work.get("subAgentKey","")
            if ticket and title and ticket not in existing and key not in existing:
                candidates.append({
                    "title": title[:100],
                    "agent": key or "active-work",
                    "goal": f"Auto-discovered from active-work.json: {ticket}",
                    "us_ref": ticket,
                })
    except Exception:
        pass

# Scan async-tasks.json
if os.path.exists(async_tasks_path):
    try:
        with open(async_tasks_path) as f:
            at = json.load(f)
        active = at.get("activeTasks", {})
        for task_id, task in active.items():
            if task_id not in existing:
                candidates.append({
                    "title": task.get("goal","Unknown task")[:100],
                    "agent": task.get("agent","unknown"),
                    "goal": task.get("goal",""),
                    "us_ref": task_id,
                })
    except Exception:
        pass

# Register candidates
for c in candidates:
    try:
        result = subprocess.run([
            "bash", task_register,
            "--title", c["title"],
            "--agent", c["agent"],
            "--goal", c.get("goal",""),
            "--us", c.get("us_ref",""),
        ], capture_output=True, text=True, timeout=10)
        if result.returncode == 0:
            new_id = result.stdout.strip()
            # Mark as in-progress immediately
            conn2 = sqlite3.connect(db)
            conn2.execute(
                "UPDATE tasks SET status='in-progress', started_at=? WHERE id=?",
                (now, new_id)
            )
            conn2.commit()
            conn2.close()
            print(f"[task-collector] Auto-discovered and registered: {new_id} — {c['title']}", file=sys.stderr)
    except Exception as e:
        print(f"[task-collector] Auto-discover error: {e}", file=sys.stderr)
PYEOF

# ── d) Purge tasks older than 7 days ─────────────────────────────────────────
python3 - "$TASKS_DB" <<'PYEOF'
import sqlite3, sys
from datetime import datetime, timedelta, timezone
db = sys.argv[1]
cutoff = (datetime.now(timezone.utc) - timedelta(days=7)).strftime("%Y-%m-%dT%H:%M:%SZ")
conn = sqlite3.connect(db)
deleted = conn.execute("DELETE FROM tasks WHERE created_at < ?", (cutoff,)).rowcount
conn.commit()
conn.close()
PYEOF

# ── Output summary ────────────────────────────────────────────────────────────
echo "TASKS: $STALLS_DETECTED stalls, $VERIFIED_COUNT verified, $FAILED_COUNT failed"
