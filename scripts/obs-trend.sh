#!/usr/bin/env bash
# obs-trend.sh — AInchors Observability Error Trend Widget
# Reads obs.db, emits state/obs-trend.json
# Called by generate-mission-control.sh and can run standalone.
# Output keys:
#   totals        — errors / warns / info for last 24h
#   top_errors    — top 5 error event_types with counts
#   top_warnings  — top 5 warning event_types with counts
#   trend         — % change vs previous 24h
#   worst_hour    — hour with most errors in last 24h

set -euo pipefail

WORKSPACE="${WORKSPACE:-$HOME/.openclaw/workspace}"
OBS_DB="$WORKSPACE/state/obs.db"
OUTPUT="$WORKSPACE/state/obs-trend.json"

if [[ ! -f "$OBS_DB" ]]; then
  echo "[obs-trend] WARNING: obs.db not found at $OBS_DB — writing empty output" >&2
  python3 -c "
import json, datetime, time
print(json.dumps({
  'error': 'obs.db not found',
  'generated_at': datetime.datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ'),
  'generated_at_aest': '',
  'period_hours': 24,
  'totals': {'ERROR': 0, 'WARN': 0, 'INFO': 0},
  'top_errors': [],
  'top_warnings': [],
  'trend': {'has_prev_data': False},
  'worst_hour': None
}, indent=2))
" > "$OUTPUT"
  exit 0
fi

python3 - "$OBS_DB" "$OUTPUT" << 'PYEOF'
import sqlite3, sys, json, time
from datetime import datetime, timezone, timedelta

db_path, output_path = sys.argv[1], sys.argv[2]
now_epoch = int(time.time())
h24_start = now_epoch - 86400   # 24h ago
h48_start = now_epoch - 172800  # 48h ago

con = sqlite3.connect(db_path)
con.row_factory = sqlite3.Row

def query(sql, params=()):
    return [dict(r) for r in con.execute(sql, params).fetchall()]

# ── Last 24h: by level + event_type ──────────────────────────────────────────
rows_24h = query(
    "SELECT level, event_type, COUNT(*) as cnt FROM obs_log "
    "WHERE ts_epoch >= ? GROUP BY level, event_type ORDER BY cnt DESC",
    (h24_start,)
)

totals_24h = {"ERROR": 0, "WARN": 0, "INFO": 0}
errors_24h = {}
warns_24h  = {}

for r in rows_24h:
    lvl, et, cnt = r["level"], r["event_type"], r["cnt"]
    if lvl in totals_24h:
        totals_24h[lvl] += cnt
    if lvl == "ERROR":
        errors_24h[et] = cnt
    elif lvl == "WARN":
        warns_24h[et]  = cnt

top_errors = sorted(errors_24h.items(), key=lambda x: -x[1])[:5]
top_warns  = sorted(warns_24h.items(),  key=lambda x: -x[1])[:5]

# ── Previous 24h totals (for trend) ──────────────────────────────────────────
rows_prev = query(
    "SELECT level, COUNT(*) as cnt FROM obs_log "
    "WHERE ts_epoch >= ? AND ts_epoch < ? GROUP BY level",
    (h48_start, h24_start)
)
totals_prev = {"ERROR": 0, "WARN": 0, "INFO": 0}
for r in rows_prev:
    if r["level"] in totals_prev:
        totals_prev[r["level"]] = r["cnt"]

has_prev_data = sum(totals_prev.values()) > 0

def pct_change(curr, prev):
    if prev == 0:
        return None
    return round((curr - prev) / prev * 100, 1)

trend = {
    "has_prev_data":     has_prev_data,
    "prev_errors":       totals_prev["ERROR"],
    "prev_warns":        totals_prev["WARN"],
    "errors_pct_change": pct_change(totals_24h["ERROR"], totals_prev["ERROR"]) if has_prev_data else None,
    "warns_pct_change":  pct_change(totals_24h["WARN"],  totals_prev["WARN"])  if has_prev_data else None,
}

# ── Worst hour (most errors in a single clock-hour, last 24h) ────────────────
hour_rows = query(
    "SELECT strftime('%Y-%m-%dT%H:00Z', ts) as hour, COUNT(*) as cnt "
    "FROM obs_log WHERE ts_epoch >= ? AND level='ERROR' "
    "GROUP BY hour ORDER BY cnt DESC LIMIT 1",
    (h24_start,)
)
worst_hour = dict(hour_rows[0]) if hour_rows else None

con.close()

now_utc  = datetime.now(timezone.utc)
AEST     = timezone(timedelta(hours=8))
now_aest = now_utc.astimezone(AEST)

output = {
    "generated_at":      now_utc.isoformat(),
    "generated_at_local": now_aest.strftime("%Y-%m-%d %H:%M MYT"),
    "period_hours":      24,
    "totals":            totals_24h,
    "top_errors":        [{"type": k, "count": v} for k, v in top_errors],
    "top_warnings":      [{"type": k, "count": v} for k, v in top_warns],
    "trend":             trend,
    "worst_hour":        worst_hour,
}

with open(output_path, "w") as f:
    json.dump(output, f, indent=2)

print(f"[obs-trend] Written: {output_path}")
print(f"[obs-trend] 24h totals — {totals_24h['ERROR']} errors / {totals_24h['WARN']} warns / {totals_24h['INFO']} info")
if top_errors:
    top_e = ", ".join(f"{k}={v}" for k, v in top_errors[:3])
    print(f"[obs-trend] Top errors: {top_e}")
if top_warns:
    top_w = ", ".join(f"{k}={v}" for k, v in top_warns[:3])
    print(f"[obs-trend] Top warns:  {top_w}")
if has_prev_data:
    ep = trend['errors_pct_change']
    wp = trend['warns_pct_change']
    if ep is not None and wp is not None:
        print(f"[obs-trend] Trend vs prev 24h — errors {ep:+.1f}%, warns {wp:+.1f}%")
    elif ep is not None:
        print(f"[obs-trend] Trend vs prev 24h — errors {ep:+.1f}%, warns N/A")
    elif wp is not None:
        print(f"[obs-trend] Trend vs prev 24h — errors N/A, warns {wp:+.1f}%")
if worst_hour:
    print(f"[obs-trend] Worst hour: {worst_hour['hour']} ({worst_hour['cnt']} errors)")
PYEOF
