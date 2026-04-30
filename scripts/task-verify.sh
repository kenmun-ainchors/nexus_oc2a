#!/bin/zsh
# task-verify.sh — Verify a task's deliverables and update status
# Usage: task-verify.sh TASK-ID
# Exit 0 if verified/passed, exit 1 if failed or error.
set -euo pipefail

WORKSPACE="${WORKSPACE:-$HOME/.openclaw/workspace}"
TASKS_DB="$WORKSPACE/state/tasks.db"
OBS_LOG="$WORKSPACE/scripts/obs-log.sh"

if (( $# < 1 )); then
  echo "[task-verify] Usage: task-verify.sh TASK-ID" >&2; exit 1
fi

TASK_ID="$1"

if [[ ! -f "$TASKS_DB" ]]; then
  echo "[task-verify] ERROR: tasks.db not found at $TASKS_DB" >&2; exit 1
fi

# ── Fetch task row ────────────────────────────────────────────────────────────
TASK_JSON=$(python3 - "$TASKS_DB" "$TASK_ID" <<'PYEOF'
import sqlite3, sys, json
db, task_id = sys.argv[1], sys.argv[2]
conn = sqlite3.connect(db)
conn.row_factory = sqlite3.Row
row = conn.execute("SELECT * FROM tasks WHERE id = ?", (task_id,)).fetchone()
if not row:
    print("NOT_FOUND")
    sys.exit(0)
print(json.dumps(dict(row)))
conn.close()
PYEOF
)

if [[ "$TASK_JSON" == "NOT_FOUND" ]]; then
  echo "[task-verify] ERROR: Task $TASK_ID not found" >&2; exit 1
fi

# ── Extract deliverables ──────────────────────────────────────────────────────
DELIVERABLES=$(python3 -c "
import sys, json
task = json.loads(sys.stdin.read())
print(task.get('expected_deliverables') or 'null')
" <<< "$TASK_JSON")

TITLE=$(python3 -c "
import sys, json
task = json.loads(sys.stdin.read())
print(task.get('title',''))
" <<< "$TASK_JSON")

# ── Run verifications ─────────────────────────────────────────────────────────
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

VERIFY_RESULT=$(python3 - "$TASKS_DB" "$TASK_ID" "$NOW" "$WORKSPACE" <<'PYEOF'
import sqlite3, sys, json, subprocess, os

db, task_id, now, workspace = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
conn = sqlite3.connect(db)
conn.row_factory = sqlite3.Row

row = conn.execute("SELECT * FROM tasks WHERE id = ?", (task_id,)).fetchone()
deliverables_raw = row["expected_deliverables"]

if not deliverables_raw:
    # No deliverables — treat as custom/manual
    result = {
        "status": "no_deliverables",
        "passed": True,
        "failed": [],
        "skipped": [],
        "notes": "No deliverables defined — treating as verified"
    }
    print(json.dumps(result))
    conn.close()
    sys.exit(0)

try:
    deliverables = json.loads(deliverables_raw)
except Exception as e:
    result = {"status": "parse_error", "passed": False, "failed": [f"JSON parse error: {e}"], "skipped": [], "notes": str(e)}
    print(json.dumps(result))
    conn.close()
    sys.exit(0)

failed = []
skipped = []
passed_count = 0

for d in deliverables:
    dtype = d.get("type", "")
    desc = d.get("description", str(d))

    if dtype == "file_exists":
        path = d.get("path", "")
        if os.path.exists(path):
            passed_count += 1
        else:
            failed.append(f"file_exists FAIL: {path} — {desc}")

    elif dtype == "script_exit_0":
        cmd = d.get("cmd", "")
        try:
            r = subprocess.run(cmd, shell=True, capture_output=True, timeout=30)
            if r.returncode == 0:
                passed_count += 1
            else:
                stderr = r.stderr.decode(errors="replace")[:200]
                failed.append(f"script_exit_0 FAIL (rc={r.returncode}): {cmd} — {desc}. stderr: {stderr}")
        except subprocess.TimeoutExpired:
            failed.append(f"script_exit_0 TIMEOUT: {cmd} — {desc}")

    elif dtype == "custom":
        skipped.append(f"custom (manual-required): {desc}")
    else:
        skipped.append(f"unknown type '{dtype}': {desc}")

overall_passed = len(failed) == 0
result = {
    "status": "passed" if overall_passed else "failed",
    "passed": overall_passed,
    "passed_count": passed_count,
    "failed": failed,
    "skipped": skipped,
    "notes": "; ".join(failed) if failed else "All deliverables verified"
}
print(json.dumps(result))
conn.close()
PYEOF
)

PASSED=$(python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print('true' if d['passed'] else 'false')" <<< "$VERIFY_RESULT")
NOTES=$(python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print(d['notes'])" <<< "$VERIFY_RESULT")
FAILED_LIST=$(python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print('\n'.join(d.get('failed',[])))" <<< "$VERIFY_RESULT")

# ── Update DB ─────────────────────────────────────────────────────────────────
if [[ "$PASSED" == "true" ]]; then
  python3 - "$TASKS_DB" "$TASK_ID" "$NOW" "$NOTES" <<'PYEOF'
import sqlite3, sys
db, task_id, now, notes = sys.argv[1:]
conn = sqlite3.connect(db)
conn.execute("""
  UPDATE tasks SET status='verified', verification_result='passed',
  verified_at=?, verification_notes=?, last_heartbeat=?
  WHERE id=?
""", (now, notes, now, task_id))
conn.commit()
conn.close()
PYEOF

  echo "[task-verify] ✅ $TASK_ID PASSED — $NOTES"

  bash "$OBS_LOG" \
    --source "task-verify" \
    --level INFO \
    --type task_verified \
    --message "Task $TASK_ID verified: $TITLE" \
    --job-id "$TASK_ID" \
    --detail "{\"task_id\":\"$TASK_ID\",\"result\":\"passed\"}"

  exit 0

else
  python3 - "$TASKS_DB" "$TASK_ID" "$NOW" "$NOTES" <<'PYEOF'
import sqlite3, sys
db, task_id, now, notes = sys.argv[1:]
conn = sqlite3.connect(db)
conn.execute("""
  UPDATE tasks SET status='failed', verification_result='failed',
  verified_at=?, verification_notes=?, last_heartbeat=?
  WHERE id=?
""", (now, notes, now, task_id))
conn.commit()
conn.close()
PYEOF

  echo "[task-verify] ❌ $TASK_ID FAILED — $NOTES"
  if [[ -n "$FAILED_LIST" ]]; then
    echo "$FAILED_LIST"
  fi

  bash "$OBS_LOG" \
    --source "task-verify" \
    --level ERROR \
    --type task_verification_failed \
    --message "Task $TASK_ID verification failed: $TITLE" \
    --job-id "$TASK_ID" \
    --detail "{\"task_id\":\"$TASK_ID\",\"result\":\"failed\",\"notes\":\"$(echo "$NOTES" | head -c 200)\"}"

  exit 1
fi
