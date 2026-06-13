#!/bin/zsh
# obs-log.sh — Insert one observability event into obs.db
# Usage: obs-log.sh --source SOURCE --level LEVEL --type TYPE --message "MSG" \
#                   [--agent AGENT] [--job-id ID] [--detail JSON]
# level must be: ERROR | WARN | INFO | CRITICAL | WARNING
# L-100: CRITICAL/WARNING added so OpenClaw diagnostic events can be logged
# with native severity levels (was downgraded to ERROR/WARN with info loss).
set -euo pipefail

WORKSPACE="${WORKSPACE:-$HOME/.openclaw/workspace}"
OBS_DB="$WORKSPACE/state/obs.db"

# ── Defaults ──────────────────────────────────────────────────────────────────
OBS_SOURCE=""
OBS_LEVEL=""
OBS_TYPE=""
OBS_MESSAGE=""
OBS_AGENT="yoda"
OBS_JOB_ID=""
OBS_DETAIL=""

# ── Parse args ────────────────────────────────────────────────────────────────
while (( $# > 0 )); do
  case "$1" in
    --source)   OBS_SOURCE="$2";  shift 2 ;;
    --level)    OBS_LEVEL="$2";   shift 2 ;;
    --type)     OBS_TYPE="$2";    shift 2 ;;
    --message)  OBS_MESSAGE="$2"; shift 2 ;;
    --agent)    OBS_AGENT="$2";   shift 2 ;;
    --job-id)   OBS_JOB_ID="$2";  shift 2 ;;
    --detail)   OBS_DETAIL="$2";  shift 2 ;;
    *) echo "[obs-log] Unknown arg: $1" >&2; exit 1 ;;
  esac
done

# ── Validate ──────────────────────────────────────────────────────────────────
if [[ -z "$OBS_SOURCE" ]];  then echo "[obs-log] ERROR: --source is required"  >&2; exit 1; fi
if [[ -z "$OBS_LEVEL" ]];   then echo "[obs-log] ERROR: --level is required"   >&2; exit 1; fi
if [[ -z "$OBS_TYPE" ]];    then echo "[obs-log] ERROR: --type is required"    >&2; exit 1; fi
if [[ -z "$OBS_MESSAGE" ]]; then echo "[obs-log] ERROR: --message is required" >&2; exit 1; fi

case "$OBS_LEVEL" in
  ERROR|WARN|INFO|CRITICAL|WARNING) ;;
  *) echo "[obs-log] ERROR: --level must be ERROR|WARN|INFO|CRITICAL|WARNING (got: $OBS_LEVEL)" >&2; exit 1 ;;
esac

# ── Init DB if missing ────────────────────────────────────────────────────────
if [[ ! -f "$OBS_DB" ]]; then
  bash "$(dirname "$0")/obs-init.sh" >/dev/null 2>&1
fi

# ── Insert ────────────────────────────────────────────────────────────────────
python3 - "$OBS_DB" "$OBS_SOURCE" "$OBS_AGENT" "${OBS_JOB_ID:-}" \
          "$OBS_LEVEL" "$OBS_TYPE" "$OBS_MESSAGE" "${OBS_DETAIL:-}" <<'PYEOF'
import sqlite3, sys, time
from datetime import datetime, timezone

db_path, source, agent, job_id, level, event_type, message, detail = sys.argv[1:9]

ts       = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
ts_epoch = int(time.time())

con = sqlite3.connect(db_path)
con.execute(
    """INSERT INTO obs_log (ts, ts_epoch, source, agent, job_id, level, event_type, message, detail)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)""",
    (ts, ts_epoch, source, agent,
     job_id if job_id else None,
     level, event_type, message,
     detail if detail else None)
)
con.commit()
con.close()
print(f"[obs-log] {level} {event_type} from {source}: {message}")
PYEOF
