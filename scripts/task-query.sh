#!/bin/zsh
# task-query.sh — Query tasks from tasks.db
# Usage: task-query.sh [--status STATUS] [--hours N] [--format summary|json|table]
# Purges tasks older than 7 days before querying. Exit 0.
set -euo pipefail

WORKSPACE="${WORKSPACE:-$HOME/.openclaw/workspace}"
TASKS_DB="$WORKSPACE/state/tasks.db"

# ── Defaults ──────────────────────────────────────────────────────────────────
FILTER_STATUS=""
FILTER_HOURS=""
FORMAT="summary"

# ── Parse args ────────────────────────────────────────────────────────────────
while (( $# > 0 )); do
  case "$1" in
    --status) FILTER_STATUS="$2"; shift 2 ;;
    --hours)  FILTER_HOURS="$2";  shift 2 ;;
    --format) FORMAT="$2";        shift 2 ;;
    *) echo "[task-query] Unknown arg: $1" >&2; exit 1 ;;
  esac
done

if [[ ! -f "$TASKS_DB" ]]; then
  echo "[task-query] No tasks.db found — no tasks registered yet."
  exit 0
fi

# ── Purge tasks older than 7 days ─────────────────────────────────────────────
python3 - "$TASKS_DB" <<'PYEOF'
import sqlite3, sys
from datetime import datetime, timedelta, timezone
db = sys.argv[1]
cutoff = (datetime.now(timezone.utc) - timedelta(days=7)).strftime("%Y-%m-%dT%H:%M:%SZ")
conn = sqlite3.connect(db)
deleted = conn.execute("DELETE FROM tasks WHERE created_at < ?", (cutoff,)).rowcount
conn.commit()
conn.close()
if deleted > 0:
    print(f"[task-query] Purged {deleted} tasks older than 7 days", file=__import__('sys').stderr)
PYEOF

# ── Query ─────────────────────────────────────────────────────────────────────
python3 - "$TASKS_DB" "$FILTER_STATUS" "$FILTER_HOURS" "$FORMAT" <<'PYEOF'
import sqlite3, sys, json
from datetime import datetime, timedelta, timezone

db = sys.argv[1]
filter_status = sys.argv[2]   # "" = no filter
filter_hours  = sys.argv[3]   # "" = no filter
fmt           = sys.argv[4]   # summary|json|table

conn = sqlite3.connect(db)
conn.row_factory = sqlite3.Row

# Build WHERE clauses
conditions = []
params = []

if filter_status:
    conditions.append("status = ?")
    params.append(filter_status)

if filter_hours:
    cutoff = (datetime.now(timezone.utc) - timedelta(hours=int(filter_hours))).strftime("%Y-%m-%dT%H:%M:%SZ")
    conditions.append("created_at >= ?")
    params.append(cutoff)

where = ("WHERE " + " AND ".join(conditions)) if conditions else ""
sql = f"SELECT * FROM tasks {where} ORDER BY created_at DESC"
rows = conn.execute(sql, params).fetchall()
tasks = [dict(r) for r in rows]
conn.close()

# ── Format: json ──────────────────────────────────────────────────────────────
if fmt == "json":
    print(json.dumps(tasks, indent=2))

# ── Format: table ─────────────────────────────────────────────────────────────
elif fmt == "table":
    cols = ["id", "title", "agent", "status", "created_at", "verification_result"]
    widths = {c: len(c) for c in cols}
    for t in tasks:
        for c in cols:
            val = str(t.get(c) or "")
            widths[c] = max(widths[c], min(len(val), 40))
    def row_str(vals):
        return "| " + " | ".join(str(v)[:widths[c]].ljust(widths[c]) for c, v in zip(cols, vals)) + " |"
    sep = "+-" + "-+-".join("-" * widths[c] for c in cols) + "-+"
    print(sep)
    print(row_str([c.upper() for c in cols]))
    print(sep)
    for t in tasks:
        vals = [t.get(c) or "" for c in cols]
        print(row_str(vals))
    print(sep)
    print(f"\nTotal: {len(tasks)} tasks")

# ── Format: summary ───────────────────────────────────────────────────────────
else:
    from collections import Counter
    counts = Counter(t["status"] for t in tasks)
    print("=== Task Tracker Summary ===")
    print(f"Period: last {filter_hours}h" if filter_hours else "Period: all time")
    print(f"Total tasks: {len(tasks)}")
    print()
    for status in ["registered","in-progress","done","verified","failed","stalled"]:
        n = counts.get(status, 0)
        if n > 0 or status in ("failed","stalled"):
            bar = "⚠️ " if status in ("failed","stalled") and n > 0 else "   "
            print(f"{bar}{status:15s}: {n}")
    print()
    problem = [t for t in tasks if t["status"] in ("failed","stalled")]
    if problem:
        print(f"⚠️  ATTENTION — {len(problem)} task(s) need review:")
        for t in problem:
            print(f"  [{t['status'].upper()}] {t['id']} — {t['title']} (agent: {t['agent']})")
            if t.get("verification_notes"):
                print(f"         notes: {t['verification_notes'][:120]}")
    else:
        print("✅ No failed or stalled tasks.")
PYEOF
