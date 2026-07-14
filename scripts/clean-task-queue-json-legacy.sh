#!/bin/bash
# scripts/clean-task-queue-json-legacy.sh — TKT-0409 D3 cleanup
# One-time (idempotent) cleanup of state/task-queue.json audit-trail rows that
# have no counterpart in PG state_task_queue. These rows are moved from the
# active queue list into a separate legacy archive file and marked as
# 'historical-orphan'.
#
# CHG-0530: state/task-queue.json is audit-trail only; PG is source of truth.
# A row in the JSON queue with no PG id is therefore legacy and should not
# block the watchdog divergence check.

set -euo pipefail

WORKSPACE_ROOT="${WORKSPACE_ROOT:-/Users/ainchorsoc2a/.openclaw/workspace}"
JSON_FILE="$WORKSPACE_ROOT/state/task-queue.json"
ARCHIVE_FILE="$WORKSPACE_ROOT/state/task-queue-legacy-archive.json"
PSQL=${PSQL_BIN:-$(brew --prefix postgresql@16 2>/dev/null)/bin/psql}

if [[ ! -f "$JSON_FILE" ]]; then
  echo "No task-queue.json to clean"
  exit 0
fi

# Load PG ids
PG_IDS=$("$PSQL" -U ${PGUSER:-$(whoami)} -d ainchors_nexus -t -A -c "SELECT id FROM state_task_queue;" 2>/dev/null | sed '/^$/d' || true)

python3 - "$JSON_FILE" "$ARCHIVE_FILE" "$PG_IDS" <<'PY'
import json,sys,os
from datetime import datetime, timezone

json_path, archive_path, pg_ids_text = sys.argv[1:4]
pg_ids = set(pg_ids_text.strip().split('\n')) if pg_ids_text.strip() else set()

with open(json_path) as f:
    data=json.load(f)

archive = {"version":"1.0","archivedAt":datetime.now(timezone.utc).isoformat(),"entries":[]}
if os.path.exists(archive_path):
    try:
        archive=json.load(open(archive_path))
    except Exception:
        pass

kept=[]
moved=0
for e in data.get("queue",[]):
    eid=e.get("atom_id") or e.get("id")
    status=e.get("status","")
    # Keep rows that have a PG id or are already marked historical
    if eid and eid in pg_ids:
        kept.append(e)
    elif status in ("historical-orphan","cancelled-orphaned","legacy"):
        kept.append(e)
    else:
        e["status"]="historical-orphan"
        e["_archivedAt"]=archive["archivedAt"]
        e["_archiveReason"]="no_pg_counterpart"
        archive["entries"].append(e)
        moved+=1

data["queue"]=kept
data["lastUpdated"]=datetime.now(timezone.utc).isoformat()

with open(json_path,"w") as f:
    json.dump(data,f,indent=2)

with open(archive_path,"w") as f:
    json.dump(archive,f,indent=2)

print(f"CLEANUP: moved {moved} legacy JSON-only rows to {archive_path}")
print(f"CLEANUP: kept {len(kept)} rows in {json_path}")
PY

exit 0
