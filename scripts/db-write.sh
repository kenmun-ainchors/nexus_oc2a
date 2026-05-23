#!/bin/bash
# db-write.sh — Write to Postgres PRIMARY, file as FALLBACK
# Usage: db-write.sh <table> '<json_payload>' <unique_id>
#   db-write.sh state_tickets '{"id":"TKT-0001","status":"closed"}' TKT-0001

DB="/Users/ainchorsangiefpl/.openclaw/workspace/scripts/db.sh"
WORKSPACE="/Users/ainchorsangiefpl/.openclaw/workspace"
TABLE="$1"; DATA="$2"; ID="${3:-}"

if [[ -z "$TABLE" || -z "$DATA" ]]; then
  echo '{"error":"usage: db-write.sh <table> <json> <id>"}' 1>&2
  exit 1
fi

# Step 1: Write to Postgres (PRIMARY — this is SSOT)
PG_RESULT=$(bash "$DB" -c "INSERT INTO $TABLE (id, $(python3 -c "
import json
d = json.loads('''$DATA''')
cols = [k for k in d.keys() if k != 'id']
print(','.join(cols))" 2>/dev/null)) VALUES ('$ID', $(python3 -c "
import json
d = json.loads('''$DATA''')
vals = []
for k,v in d.items():
    if k == 'id': continue
    if v is None: vals.append('NULL')
    elif isinstance(v,bool): vals.append(str(v).upper())
    elif isinstance(v,(int,float)): vals.append(str(v))
    else: vals.append(\"'\" + str(v).replace(\"'\",\"''\") + \"'\")
print(','.join(vals))" 2>/dev/null)) ON CONFLICT (id) DO UPDATE SET $(python3 -c "
import json
d = json.loads('''$DATA''')
updates = [f\"{k}=EXCLUDED.{k}\" for k in d.keys() if k != 'id']
print(','.join(updates))" 2>/dev/null)" 2>/dev/null && echo "PG_WRITE_OK" || echo "PG_WRITE_FAIL")

if echo "$PG_RESULT" | grep -q "PG_WRITE_OK"; then
  echo '{"status":"ok","backend":"postgres","id":"'$ID'"}' 
  exit 0
fi

# Step 2: Fallback — write to file
echo '{"status":"degraded","backend":"file","id":"'$ID'","error":"PG write failed"}' 1>&2
# Append to a fallback log
echo "$DATA" >> "$WORKSPACE/state/pg-write-fallback-$TABLE.jsonl"
exit 0
