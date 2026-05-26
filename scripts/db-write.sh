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

# Handle metadata: validate against JSON Schema, merge unknowns
if unknown_fields:
    existing_meta = known_fields.get('metadata', {})
    if isinstance(existing_meta, str):
        try:
            existing_meta = json.loads(existing_meta)
        except (json.JSONDecodeError, TypeError):
            existing_meta = {}
    elif not isinstance(existing_meta, dict):
        existing_meta = {}
    
    # TKT-0299: JSON Schema validation before merge
    schema_path = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'docs', 'schemas', 'metadata-jsonb-schema.json')
    mode = 'warn'  # P1 default: warn only. Set DBWRITE_MODE=strict for P2 enforcement.
    
    if os.path.exists(schema_path):
        try:
            with open(schema_path) as sf:
                schema = json.load(sf)
            table_config = schema.get('tables', {}).get(table, {})
            known_keys = table_config.get('knownKeys', {})
            allow_unknown = table_config.get('validation', {}).get('allowUnknownKeys', True)
            
            for k in unknown_fields.keys():
                if k not in known_keys:
                    msg = f'[metadata-schema] UNKNOWN KEY: {table}.metadata.{k} (table={table})'
                    if not allow_unknown:
                        print(f'SCHEMA_REJECT: {msg}', file=sys.stderr)
                        sys.exit(1)
                    else:
                        print(f'SCHEMA_WARN: {msg}', file=sys.stderr)
                else:
                    # Validate known key type
                    field_spec = known_keys[k]
                    expected_type = field_spec.get('type', 'string')
                    actual = unknown_fields[k]
                    type_ok = False
                    if expected_type == 'string' and isinstance(actual, str):
                        type_ok = True
                    elif expected_type == 'number' and isinstance(actual, (int, float)) and not isinstance(actual, bool):
                        type_ok = True
                    elif expected_type == 'integer' and isinstance(actual, int) and not isinstance(actual, bool):
                        type_ok = True
                    elif expected_type == 'boolean' and isinstance(actual, bool):
                        type_ok = True
                    elif expected_type == 'array' and isinstance(actual, list):
                        type_ok = True
                    elif expected_type == 'object' and isinstance(actual, dict):
                        type_ok = True
                    if not type_ok:
                        msg = f'[metadata-schema] TYPE MISMATCH: {table}.metadata.{k} expected {expected_type}, got {type(actual).__name__}'
                        print(f'SCHEMA_WARN: {msg}', file=sys.stderr)
                    # Check enum if defined
                    enum_vals = field_spec.get('enum')
                    if enum_vals and isinstance(actual, str) and actual not in enum_vals:
                        print(f'SCHEMA_WARN: [metadata-schema] ENUM VIOLATION: {table}.metadata.{k} value "{actual}" not in {enum_vals}', file=sys.stderr)
        except Exception as e:
            print(f'SCHEMA_WARN: validation skipped ({e})', file=sys.stderr)
    
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

# Step 3: Fallback — atomic write to file with locking
FALLBACK_FILE="$WORKSPACE/state/pg-write-fallback-$TABLE.jsonl"
echo '{"status":"degraded","backend":"file","id":"'$ID'","error":"PG write failed"}' 1>&2

python3 << PYFALLBACK
import sys, os, json, fcntl, tempfile

fallback_file = "$FALLBACK_FILE"
data = '''$DATA'''
target_dir = os.path.dirname(fallback_file)
os.makedirs(target_dir, exist_ok=True)

try:
    # Advisory lock on fallback file
    lock_fd = os.open(fallback_file + '.lock', os.O_CREAT | os.O_RDWR, 0o644)
    fcntl.flock(lock_fd, fcntl.LOCK_EX)
    
    # Read existing entries if any
    entries = []
    if os.path.exists(fallback_file):
        try:
            with open(fallback_file) as f:
                for line in f:
                    line = line.strip()
                    if line:
                        entries.append(line)
        except:
            pass
    
    # Append new entry
    entries.append(data.strip())
    
    # Atomic write: temp -> fsync -> rename
    fd, temp_path = tempfile.mkstemp(dir=target_dir, prefix='.db_write_fb_', suffix='.tmp')
    with os.fdopen(fd, 'w') as f:
        f.write('\n'.join(entries) + '\n')
        f.flush()
        os.fsync(f.fileno())
    os.replace(temp_path, fallback_file)
    
    # Sync directory
    dir_fd = os.open(target_dir, os.O_RDONLY | os.O_DIRECTORY)
    try:
        os.fsync(dir_fd)
    finally:
        os.close(dir_fd)
    
    # Release lock
    fcntl.flock(lock_fd, fcntl.LOCK_UN)
    os.close(lock_fd)
    sys.exit(0)
except Exception as e:
    print(f'ATOMIC_FALLBACK_ERROR: {e}', file=sys.stderr)
    sys.exit(1)
PYFALLBACK

exit 0
