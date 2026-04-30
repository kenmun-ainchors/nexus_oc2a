#!/bin/zsh
# obs-init.sh — Initialise AInchors observability SQLite DB
# Idempotent: safe to run multiple times.
# Usage: bash scripts/obs-init.sh
set -euo pipefail

WORKSPACE="${WORKSPACE:-$HOME/.openclaw/workspace}"
OBS_DB="$WORKSPACE/state/obs.db"

mkdir -p "$(dirname "$OBS_DB")"

python3 - "$OBS_DB" <<'PYEOF'
import sqlite3, sys

db_path = sys.argv[1]
con = sqlite3.connect(db_path)
cur = con.cursor()

cur.executescript("""
CREATE TABLE IF NOT EXISTS obs_log (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    ts         TEXT    NOT NULL,
    ts_epoch   INTEGER NOT NULL,
    source     TEXT    NOT NULL,
    agent      TEXT    DEFAULT 'yoda',
    job_id     TEXT,
    level      TEXT    NOT NULL,
    event_type TEXT    NOT NULL,
    message    TEXT    NOT NULL,
    detail     TEXT,
    resolved   INTEGER DEFAULT 0
);
CREATE INDEX IF NOT EXISTS idx_ts_epoch ON obs_log(ts_epoch);
CREATE INDEX IF NOT EXISTS idx_level    ON obs_log(level);
CREATE INDEX IF NOT EXISTS idx_source   ON obs_log(source);
""")

con.commit()
con.close()
print(f"[obs-init] DB ready: {db_path}")
PYEOF
