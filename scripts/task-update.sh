#!/bin/zsh
# task-update.sh — Update a task's status in tasks.db
# Usage: task-update.sh TASK-ID --status STATUS [--notes "NOTES"]
# Valid statuses: registered|in-progress|done|verified|failed|stalled
# Exit 0 on success.
set -euo pipefail

WORKSPACE="${WORKSPACE:-$HOME/.openclaw/workspace}"
TASKS_DB="$WORKSPACE/state/tasks.db"

VALID_STATUSES="registered in-progress done verified failed stalled"

# ── Parse args ────────────────────────────────────────────────────────────────
if (( $# < 1 )); then
  echo "[task-update] Usage: task-update.sh TASK-ID --status STATUS [--notes NOTES]" >&2
  exit 1
fi

TASK_ID="$1"; shift

STATUS=""
NOTES=""

while (( $# > 0 )); do
  case "$1" in
    --status) STATUS="$2"; shift 2 ;;
    --notes)  NOTES="$2";  shift 2 ;;
    *) echo "[task-update] Unknown arg: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$STATUS" ]]; then
  echo "[task-update] ERROR: --status is required" >&2; exit 1
fi

# Validate status
if ! echo "$VALID_STATUSES" | grep -qw "$STATUS"; then
  echo "[task-update] ERROR: Invalid status '$STATUS'. Valid: $VALID_STATUSES" >&2
  exit 1
fi

if [[ ! -f "$TASKS_DB" ]]; then
  echo "[task-update] ERROR: tasks.db not found at $TASKS_DB" >&2; exit 1
fi

# ── Update row ────────────────────────────────────────────────────────────────
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

python3 - "$TASKS_DB" "$TASK_ID" "$STATUS" "$NOTES" "$NOW" <<'PYEOF'
import sqlite3, sys
db, task_id, status, notes, now = sys.argv[1:]

conn = sqlite3.connect(db)

# Check task exists
row = conn.execute("SELECT id FROM tasks WHERE id = ?", (task_id,)).fetchone()
if not row:
    print(f"[task-update] ERROR: Task {task_id} not found", file=sys.stderr)
    sys.exit(1)

# Build update fields
fields = ["status = ?", "last_heartbeat = ?"]
params = [status, now]

if status == "in-progress":
    fields.append("started_at = COALESCE(started_at, ?)")
    params.append(now)

if status == "done":
    fields.append("reported_done_at = ?")
    params.append(now)

if notes:
    fields.append("verification_notes = ?")
    params.append(notes)

params.append(task_id)
sql = f"UPDATE tasks SET {', '.join(fields)} WHERE id = ?"
conn.execute(sql, params)
conn.commit()
conn.close()
print(f"[task-update] {task_id} → {status}")
PYEOF
