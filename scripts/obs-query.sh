#!/bin/zsh
# obs-query.sh — Query AInchors observability DB; auto-purges entries older than 7 days
# Usage: obs-query.sh [--hours N] [--month YYYY-MM] [--level ERROR,WARN,INFO]
#                     [--source SOURCE] [--format summary|json|table]
# Formats:
#   summary  = human counts by event_type (default)
#   json     = JSON array of matching rows
#   table    = ASCII table
set -euo pipefail

WORKSPACE="${WORKSPACE:-$HOME/.openclaw/workspace}"
OBS_DB="$WORKSPACE/state/obs.db"

# ── Defaults ──────────────────────────────────────────────────────────────────
OBS_HOURS=""
OBS_MONTH=""
OBS_LEVEL=""
OBS_SOURCE=""
OBS_FORMAT="summary"

# ── Parse args ────────────────────────────────────────────────────────────────
while (( $# > 0 )); do
  case "$1" in
    --hours)   OBS_HOURS="$2";  shift 2 ;;
    --month)   OBS_MONTH="$2";  shift 2 ;;
    --level)   OBS_LEVEL="$2";  shift 2 ;;
    --source)  OBS_SOURCE="$2"; shift 2 ;;
    --format)  OBS_FORMAT="$2"; shift 2 ;;
    *) echo "[obs-query] Unknown arg: $1" >&2; exit 1 ;;
  esac
done

# ── Guard: DB must exist ──────────────────────────────────────────────────────
if [[ ! -f "$OBS_DB" ]]; then
  echo "[obs-query] obs.db not found at $OBS_DB — run obs-init.sh first" >&2
  exit 1
fi

python3 - "$OBS_DB" "$OBS_HOURS" "$OBS_MONTH" "$OBS_LEVEL" "$OBS_SOURCE" "$OBS_FORMAT" <<'PYEOF'
import sqlite3, sys, time, json
from datetime import datetime, timezone

db_path, hours_s, month_s, level_s, source_s, fmt = sys.argv[1:7]
now_epoch = int(time.time())

con = sqlite3.connect(db_path)
con.row_factory = sqlite3.Row

# ── Auto-purge entries older than 7 days ──────────────────────────────────────
cutoff_7d = now_epoch - (7 * 86400)
deleted = con.execute("DELETE FROM obs_log WHERE ts_epoch < ?", (cutoff_7d,)).rowcount
con.commit()

# ── Build WHERE clauses ───────────────────────────────────────────────────────
wheres = []
params = []

if hours_s:
    cutoff_h = now_epoch - int(hours_s) * 3600
    wheres.append("ts_epoch >= ?")
    params.append(cutoff_h)

if month_s:
    # ts is stored as ISO UTC — match YYYY-MM prefix
    wheres.append("ts LIKE ?")
    params.append(f"{month_s}%")

if level_s:
    levels = [l.strip().upper() for l in level_s.split(",")]
    placeholders = ",".join("?" for _ in levels)
    wheres.append(f"level IN ({placeholders})")
    params.extend(levels)

if source_s:
    wheres.append("source = ?")
    params.append(source_s)

where_sql = ("WHERE " + " AND ".join(wheres)) if wheres else ""
sql = f"SELECT * FROM obs_log {where_sql} ORDER BY ts_epoch DESC"

rows = con.execute(sql, params).fetchall()
con.close()

# ── Output ────────────────────────────────────────────────────────────────────
if fmt == "json":
    out = [dict(r) for r in rows]
    print(json.dumps(out, indent=2))

elif fmt == "table":
    if not rows:
        print("[obs-query] No events found.")
    else:
        headers = ["id", "ts", "level", "source", "event_type", "message"]
        col_w = {h: len(h) for h in headers}
        data = []
        for r in rows:
            rd = dict(r)
            row_data = {h: str(rd.get(h, "") or "") for h in headers}
            row_data["message"] = row_data["message"][:60]
            for h in headers:
                col_w[h] = max(col_w[h], len(row_data[h]))
            data.append(row_data)
        sep = "+-" + "-+-".join("-" * col_w[h] for h in headers) + "-+"
        hdr = "| " + " | ".join(h.ljust(col_w[h]) for h in headers) + " |"
        print(sep)
        print(hdr)
        print(sep)
        for rd in data:
            print("| " + " | ".join(rd[h].ljust(col_w[h]) for h in headers) + " |")
        print(sep)
        print(f"\n[obs-query] {len(rows)} event(s) shown. Auto-purged {deleted} event(s) older than 7 days.")

else:  # summary (default)
    if not rows:
        print("[obs-query] No events found for the given filters.")
    else:
        from collections import Counter
        level_counts   = Counter(r["level"] for r in rows)
        type_counts    = Counter(r["event_type"] for r in rows)
        source_counts  = Counter(r["source"] for r in rows)

        print(f"[obs-query] Summary — {len(rows)} event(s)")
        print(f"  Auto-purged: {deleted} event(s) older than 7 days")
        print()
        print("  By Level:")
        for lvl in ("ERROR", "WARN", "INFO"):
            if level_counts[lvl]:
                print(f"    {lvl:5s}: {level_counts[lvl]}")
        print()
        print("  By Event Type:")
        for et, cnt in type_counts.most_common():
            print(f"    {et}: {cnt}")
        print()
        print("  By Source:")
        for src, cnt in source_counts.most_common():
            print(f"    {src}: {cnt}")

PYEOF
