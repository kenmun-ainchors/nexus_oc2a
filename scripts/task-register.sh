#!/bin/zsh
# task-register.sh — Register a new task in tasks.db
# Usage: task-register.sh --title "TITLE" --agent AGENT [--goal "GOAL"]
#                         [--deliverables '[...]'] [--us US41] [--tkt TKT-0026]
# Prints TASK-ID on stdout. Exit 0 on success.
set -euo pipefail

WORKSPACE="${WORKSPACE:-$HOME/.openclaw/workspace}"
TASKS_DB="$WORKSPACE/state/tasks.db"

# ── Parse args ────────────────────────────────────────────────────────────────
TITLE=""
AGENT=""
GOAL=""
DELIVERABLES=""
US_REF=""
TKT_REF=""

while (( $# > 0 )); do
  case "$1" in
    --title)        TITLE="$2";        shift 2 ;;
    --agent)        AGENT="$2";        shift 2 ;;
    --goal)         GOAL="$2";         shift 2 ;;
    --deliverables) DELIVERABLES="$2"; shift 2 ;;
    --us)           US_REF="$2";       shift 2 ;;
    --tkt)          TKT_REF="$2";      shift 2 ;;
    *) echo "[task-register] Unknown arg: $1" >&2; exit 1 ;;
  esac
done

# ── Validate required ─────────────────────────────────────────────────────────
if [[ -z "$TITLE" ]]; then
  echo "[task-register] ERROR: --title is required" >&2; exit 1
fi
if [[ -z "$AGENT" ]]; then
  echo "[task-register] ERROR: --agent is required" >&2; exit 1
fi

# ── Init DB if needed ─────────────────────────────────────────────────────────
python3 - "$TASKS_DB" <<'PYEOF'
import sqlite3, sys
db = sys.argv[1]
conn = sqlite3.connect(db)
conn.executescript("""
CREATE TABLE IF NOT EXISTS tasks (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  agent TEXT NOT NULL,
  assigned_by TEXT DEFAULT 'yoda',
  status TEXT NOT NULL DEFAULT 'registered',
  goal TEXT,
  expected_deliverables TEXT,
  created_at TEXT NOT NULL,
  started_at TEXT,
  reported_done_at TEXT,
  verified_at TEXT,
  last_heartbeat TEXT,
  verification_result TEXT,
  verification_notes TEXT,
  us_ref TEXT,
  tkt_ref TEXT
);
CREATE INDEX IF NOT EXISTS idx_status ON tasks(status);
CREATE INDEX IF NOT EXISTS idx_created_at ON tasks(created_at);
""")
conn.commit()
conn.close()
PYEOF

# ── Generate task ID ──────────────────────────────────────────────────────────
TODAY=$(date +%Y%m%d)

TASK_ID=$(python3 - "$TASKS_DB" "$TODAY" <<'PYEOF'
import sqlite3, sys
db, today = sys.argv[1], sys.argv[2]
conn = sqlite3.connect(db)
prefix = f"TASK-{today}-"
row = conn.execute(
    "SELECT id FROM tasks WHERE id LIKE ? ORDER BY id DESC LIMIT 1",
    (prefix + "%",)
).fetchone()
if row:
    last_n = int(row[0].split("-")[-1])
    n = last_n + 1
else:
    n = 1
task_id = f"{prefix}{n:03d}"
print(task_id)
conn.close()
PYEOF
)

# ── Insert row ────────────────────────────────────────────────────────────────
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

python3 - "$TASKS_DB" "$TASK_ID" "$TITLE" "$AGENT" "$GOAL" "$DELIVERABLES" "$NOW" "$US_REF" "$TKT_REF" <<'PYEOF'
import sqlite3, sys
db, task_id, title, agent, goal, deliverables, now, us_ref, tkt_ref = sys.argv[1:]
conn = sqlite3.connect(db)
conn.execute("""
  INSERT INTO tasks (id, title, agent, status, goal, expected_deliverables,
                     created_at, last_heartbeat, us_ref, tkt_ref)
  VALUES (?, ?, ?, 'registered', ?, ?, ?, ?, ?, ?)
""", (
    task_id, title, agent,
    goal or None,
    deliverables or None,
    now, now,
    us_ref or None,
    tkt_ref or None
))
conn.commit()
conn.close()
PYEOF

echo "$TASK_ID"
