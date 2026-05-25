#!/bin/bash
# db-write.sh — Write to Postgres PRIMARY, file as FALLBACK
# Usage: db-write.sh <table> '<json_payload>' <unique_id>
#   db-write.sh state_tickets '{"id":"TKT-0001","status":"closed"}' TKT-0001
#
# TKT-0294: Unknown columns merged into metadata JSONB instead of failing.

DB="/Users/ainchorsangiefpl/.openclaw/workspace/scripts/db.sh"
WORKSPACE="/Users/ainchorsangiefpl/.openclaw/workspace"
TABLE="$1"; DATA="$2"; ID="${3:-}"

if [[ -z "$TABLE" || -z "$DATA" ]]; then
  echo '{"error":"usage: db-write.sh <table> <json> <id>"}' 1>&2
  exit 1
fi

# Step 1: Query PG for valid columns, then route known/unknown fields
SQL=$(python3 << PYEOF
import json, subprocess, os, sys

data = json.loads('''$DATA''')
table = "$TABLE"
task_id = "$ID"

# Query valid columns from PG
env = os.environ.copy()
env.update({"PGHOST": "/tmp", "PGPORT": "5432", "PGUSER": "ainchorsangiefpl", "PGDATABASE": "ainchors_nexus"})
try:
    result = subprocess.run(
        ["/opt/homebrew/bin/psql", "-t", "-A", "-c",
         f"SELECT column_name FROM information_schema.columns WHERE table_name='{table}' ORDER BY ordinal_position"],
        capture_output=True, text=True, timeout=5, env=env
    )
    valid_cols = set(result.stdout.strip().split('\n')) if result.stdout.strip() else set()
except Exception:
    # PG unavailable — fall through to file fallback
    print("PG_QUERY_FAILED")
    sys.exit(0)

if not valid_cols:
    print("PG_QUERY_FAILED")
    sys.exit(0)

# Separate known columns from unknowns
known_fields = {}
unknown_fields = {}
for k, v in data.items():
    if k == 'id':
        continue
    if k in valid_cols:
        known_fields[k] = v
    else:
        unknown_fields[k] = v

# Handle metadata: merge unknowns into existing metadata if present
if unknown_fields:
    existing_meta = known_fields.get('metadata', {})
    if isinstance(existing_meta, str):
        try:
            existing_meta = json.loads(existing_meta)
        except (json.JSONDecodeError, TypeError):
            existing_meta = {}
    elif not isinstance(existing_meta, dict):
        existing_meta = {}
    existing_meta.update(unknown_fields)
    known_fields['metadata'] = json.dumps(existing_meta)

# Build INSERT columns
cols = list(known_fields.keys())
if not cols:
    # Nothing to insert beyond id — use minimal insert
    print(f"INSERT INTO {table} (id) VALUES ('{task_id}') ON CONFLICT (id) DO NOTHING")
    sys.exit(0)

# Build VALUES with proper escaping
vals = []
for k in cols:
    v = known_fields[k]
    if v is None:
        vals.append('NULL')
    elif isinstance(v, bool):
        vals.append(str(v).upper())
    elif isinstance(v, (int, float)):
        vals.append(str(v))
    else:
        escaped = str(v).replace("'", "''")
        vals.append(f"'{escaped}'")

# Build ON CONFLICT SET clause
updates = [f"{k}=EXCLUDED.{k}" for k in cols]

col_str = ','.join(cols)
val_str = ','.join(vals)
set_str = ','.join(updates)

sql = f"INSERT INTO {table} (id, {col_str}) VALUES ('{task_id}', {val_str}) ON CONFLICT (id) DO UPDATE SET {set_str}"
print(sql)
PYEOF
)

if [ "$SQL" = "PG_QUERY_FAILED" ]; then
  # PG is down — fallback to file
  echo '{"status":"degraded","backend":"file","id":"'$ID'","error":"PG unavailable"}' 1>&2
  echo "$DATA" >> "$WORKSPACE/state/pg-write-fallback-$TABLE.jsonl"
  exit 0
fi

# Step 2: Execute the generated SQL
PG_RESULT=$(bash "$DB" -c "$SQL" 2>/dev/null && echo "PG_WRITE_OK" || echo "PG_WRITE_FAIL")

if echo "$PG_RESULT" | grep -q "PG_WRITE_OK"; then
  echo '{"status":"ok","backend":"postgres","id":"'$ID'"}'
  exit 0
fi

# Step 3: Fallback — write to file
echo '{"status":"degraded","backend":"file","id":"'$ID'","error":"PG write failed"}' 1>&2
echo "$DATA" >> "$WORKSPACE/state/pg-write-fallback-$TABLE.jsonl"
exit 0
