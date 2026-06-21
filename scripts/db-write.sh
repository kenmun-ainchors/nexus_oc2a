#!/bin/bash
# db-write.sh — Write to Postgres PRIMARY, file as FALLBACK
# Usage: db-write.sh <table> '<json_payload>' <unique_id>
#   db-write.sh state_tickets '{"id":"TKT-0001","status":"closed"}' TKT-0001
#
# TKT-0294: Unknown columns merged into metadata JSONB instead of failing.
# TKT-0311: Fix silent failures when Python crashes and verify writes.
# TKT-0408: Pipe JSON via stdin (temp file script) — shell interpolation of
#           $DATA in heredoc mangles nested objects. Add JSON parse-error gate
#           (exit 1, NO file fallback for parse errors). Consolidate SQL-gen.
# TKT-0538: Detect existing rows. For existing rows emit plain UPDATE so that
#           PG check constraints (e.g. chk_title_not_empty) are not evaluated
#           on the attempted insert row. New rows use plain INSERT.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE="$(cd "$SCRIPT_DIR/.." && pwd)"
DB="$WORKSPACE/scripts/db-raw.sh"
TABLE="$1"; DATA="$2"; ID="${3:-}"

if [[ -z "$TABLE" || -z "$DATA" ]]; then
  echo '{"error":"usage: db-write.sh <table> <json> <id>"}' 1>&2
  exit 1
fi

# Step 1 (TKT-0408): JSON parse-error gate — exit 1 (no file fallback). Python reads DATA from stdin.
if ! printf '%s' "$DATA" | python3 -c "import json,sys; json.loads(sys.stdin.read())" 2>/dev/null; then
  echo '{"status":"error","error":"JSON parse failed","id":"'"$ID"'"}' 1>&2
  exit 1
fi

# Write Python SQL-gen to a temp file. TKT-0408 key fix: `python3 <<EOF` makes
# stdin the heredoc body, so piped JSON never reaches the script. A file keeps
# stdin free for the JSON pipe.
PY_SQL=$(mktemp -t dbwrite_sql.XXXXXX.py) || { echo '{"status":"error","error":"mktemp failed"}' 1>&2; exit 1; }
trap 'rm -f "$PY_SQL" "$PY_FB"' EXIT
cat > "$PY_SQL" <<'PYEOF'
import json, subprocess, os, sys

try:
    data = json.loads(sys.stdin.read())
except Exception as e:
    print(f"JSON_LOAD_ERROR: {e}", file=sys.stderr)
    sys.exit(1)

table = os.environ['TABLE']
task_id = os.environ['ID']

column_aliases = {"createdat": "created_at", "updatedat": "updated_at"}
normalized_data = {column_aliases.get(k, k): v for k, v in data.items()}

# Query valid columns + types from PG (TKT-0408: also need types for json/jsonb casting)
env = os.environ.copy()
env.update({"PGHOST": "/tmp", "PGPORT": "5432", "PGUSER": "ainchorsangiefpl", "PGDATABASE": "ainchors_nexus"})
try:
    result = subprocess.run(
        ["/opt/homebrew/bin/psql", "-t", "-A", "-F", "|", "-c",
         f"SELECT column_name, data_type FROM information_schema.columns WHERE table_name='{table}' ORDER BY ordinal_position"],
        capture_output=True, text=True, timeout=5, env=env
    )
    col_types = {}
    if result.stdout.strip():
        for line in result.stdout.strip().split('\n'):
            parts = line.split('|', 1)
            if len(parts) == 2: col_types[parts[0]] = parts[1]
    valid_cols = set(col_types.keys())
except Exception:
    print("PG_QUERY_FAILED")
    sys.exit(0)

if not valid_cols:
    print("PG_QUERY_FAILED")
    sys.exit(0)

# TKT-0538: Check if row already exists BEFORE deciding INSERT vs UPDATE.
row_exists = False
try:
    exists_result = subprocess.run(
        ["/opt/homebrew/bin/psql", "-t", "-A", "-c",
         f"SELECT 1 FROM {table} WHERE id='{task_id}' LIMIT 1"],
        capture_output=True, text=True, timeout=5, env=env
    )
    if exists_result.stdout.strip() == '1':
        row_exists = True
except Exception:
    pass

# Separate known columns from unknowns (TKT-0294: unknowns → metadata JSONB)
known_fields = {}
unknown_fields = {}
for k, v in normalized_data.items():
    if k == 'id': continue
    (known_fields if k in valid_cols else unknown_fields)[k] = v

if unknown_fields:
    existing_meta = known_fields.get('metadata', {})
    if isinstance(existing_meta, str):
        try: existing_meta = json.loads(existing_meta)
        except (json.JSONDecodeError, TypeError): existing_meta = {}
    elif not isinstance(existing_meta, dict):
        existing_meta = {}

    # TKT-0299: JSON Schema validation before merge
    schema_path = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'docs', 'schemas', 'metadata-jsonb-schema.json')
    TYPE_CHECKS = {'string': lambda a: isinstance(a, str),
                   'number': lambda a: isinstance(a, (int, float)) and not isinstance(a, bool),
                   'integer': lambda a: isinstance(a, int) and not isinstance(a, bool),
                   'boolean': lambda a: isinstance(a, bool),
                   'array': lambda a: isinstance(a, list),
                   'object': lambda a: isinstance(a, dict)}
    if os.path.exists(schema_path):
        try:
            with open(schema_path) as sf: schema = json.load(sf)
            tc = schema.get('tables', {}).get(table, {})
            kk = tc.get('knownKeys', {})
            allow_unknown = tc.get('validation', {}).get('allowUnknownKeys', True)
            for k, actual in unknown_fields.items():
                if k not in kk:
                    msg = f'[metadata-schema] UNKNOWN KEY: {table}.metadata.{k} (table={table})'
                    if not allow_unknown:
                        print(f'SCHEMA_REJECT: {msg}', file=sys.stderr); sys.exit(1)
                    else:
                        print(f'SCHEMA_WARN: {msg}', file=sys.stderr)
                else:
                    fs = kk[k]; et = fs.get('type', 'string')
                    if not TYPE_CHECKS.get(et, lambda a: True)(actual):
                        print(f'SCHEMA_WARN: [metadata-schema] TYPE MISMATCH: {table}.metadata.{k} expected {et}, got {type(actual).__name__}', file=sys.stderr)
                    ev = fs.get('enum')
                    if ev and isinstance(actual, str) and actual not in ev:
                        print(f'SCHEMA_WARN: [metadata-schema] ENUM VIOLATION: {table}.metadata.{k} value "{actual}" not in {ev}', file=sys.stderr)
        except Exception as e:
            print(f'SCHEMA_WARN: validation skipped ({e})', file=sys.stderr)

    existing_meta.update(unknown_fields)
    known_fields['metadata'] = json.dumps(existing_meta)

cols = list(known_fields.keys())
safe_mode = os.environ.get('DBWRITE_SAFE_MODE', '0') == '1'

# TKT-0538: Branches based on row existence + SAFE_MODE
if row_exists and not safe_mode:
    # Existing row + normal mode → plain UPDATE (avoids check-constraint re-eval on insert row)
    update_cols = list(cols)
    # TKT-0538: include updated_at=NOW() if updated_at is a valid column and not already present
    if 'updated_at' in valid_cols and 'updated_at' not in update_cols:
        update_cols.append('updated_at')
    if not update_cols:
        # Nothing to update — emit no-op that still touches updated_at
        if 'updated_at' in valid_cols:
            print(f"UPDATE {table} SET updated_at=NOW() WHERE id='{task_id}'")
        else:
            print(f"UPDATE {table} SET id='{task_id}' WHERE id='{task_id}'")
        sys.exit(0)
    sets = []
    for k in update_cols:
        if k == 'updated_at':
            sets.append('updated_at=NOW()')
            continue
        v = known_fields[k]
        col_type = col_types.get(k, '')
        if v is None:
            sets.append(f"{k}=NULL")
        elif col_type in ('json', 'jsonb'):
            if isinstance(v, str):
                try: obj = json.loads(v)
                except (json.JSONDecodeError, TypeError): obj = v
            else:
                obj = v
            sql_safe = json.dumps(obj).replace("'", "''")
            sets.append(f"{k}='{sql_safe}'::{col_type}")
        elif isinstance(v, bool):
            sets.append(f"{k}={str(v).upper()}")
        elif isinstance(v, (int, float)):
            sets.append(f"{k}={v}")
        else:
            sets.append(f"{k}='{str(v).replace(chr(39), chr(39)*2)}'")
    print(f"UPDATE {table} SET {','.join(sets)} WHERE id='{task_id}'")
    sys.exit(0)

# New row (or SAFE_MODE on existing row) → INSERT, optionally with conflict clause
if not cols:
    if safe_mode:
        print(f"INSERT INTO {table} (id) VALUES ('{task_id}') ON CONFLICT (id) DO NOTHING")
    else:
        print(f"INSERT INTO {table} (id) VALUES ('{task_id}')")
    sys.exit(0)

vals = []
for k in cols:
    v = known_fields[k]
    col_type = col_types.get(k, '')
    if v is None: vals.append('NULL')
    elif col_type in ('json', 'jsonb'):
        # JSON/JSONB: re-parse if string (unknown-merge produces a string), then
        # json.dumps for a single clean encode. PG standard-conforming strings
        # treat backslash as literal — only single quotes need doubling.
        if isinstance(v, str):
            try: obj = json.loads(v)
            except (json.JSONDecodeError, TypeError): obj = v
        else:
            obj = v
        sql_safe = json.dumps(obj).replace("'", "''")
        vals.append(f"'{sql_safe}'::{col_type}")
    elif isinstance(v, bool): vals.append(str(v).upper())
    elif isinstance(v, (int, float)): vals.append(str(v))
    else: vals.append(f"'{str(v).replace(chr(39), chr(39)*2)}'")

# TKT-0538: SAFE mode = DO NOTHING. Normal new-row mode = plain INSERT (no ON CONFLICT).
if safe_mode:
    conflict_clause = "ON CONFLICT (id) DO NOTHING"
    print(f"INSERT INTO {table} (id, {','.join(cols)}) VALUES ('{task_id}', {','.join(vals)}) {conflict_clause}")
else:
    print(f"INSERT INTO {table} (id, {','.join(cols)}) VALUES ('{task_id}', {','.join(vals)})")
PYEOF

export TABLE ID
SQL=$(printf '%s' "$DATA" | python3 "$PY_SQL")
PY_EXIT=$?

# TKT-0311: Python crash / empty output → file fallback (data loss prevention).
if [ $PY_EXIT -ne 0 ] || [ -z "$SQL" ]; then
  echo '{"status":"error","error":"SQL generation failed (Python crash or empty output)"}' 1>&2
  printf '%s\n' "$DATA" >> "$WORKSPACE/state/pg-write-fallback-$TABLE.jsonl"
  exit 1
fi

# Real PG outage (genuine, NOT a parse error) → file fallback.
if [ "$SQL" = "PG_QUERY_FAILED" ]; then
  echo '{"status":"degraded","backend":"file","id":"'"$ID"'","error":"PG unavailable"}' 1>&2
  printf '%s\n' "$DATA" >> "$WORKSPACE/state/pg-write-fallback-$TABLE.jsonl"
  exit 0
fi

# Step 3: Execute the generated SQL
# TKT-0698: Capture stderr to classify PG errors. Do NOT suppress stderr blindly.
PG_ERR_TMP=$(mktemp -t dbwrite_pgerr.XXXXXX)
trap 'rm -f "$PY_SQL" "$PY_FB" "$PG_ERR_TMP"' EXIT

bash "$DB" -c "$SQL" > /dev/null 2>"$PG_ERR_TMP"
PG_EXIT=$?
PG_ERR=$(cat "$PG_ERR_TMP" 2>/dev/null)

# TKT-0698: Error classification — only fallback on genuine PG unavailability.
_classify_pg_error() {
  local code="$1"; local msg="$2"
  # Outage / connection-level patterns
  case "$msg" in
    *"could not connect"*|*"Connection refused"*|*"FATAL:"*|*"server closed the connection"*|*"timeout expired"*|*"pg_ctl start"*|*"No such file or directory"*)
      echo "OUTAGE"; return ;;
  esac
  # psql connection failure exit codes
  if [[ "$code" == "2" ]]; then
    echo "OUTAGE"; return
  fi
  # Any SQL-level ERROR means the query was rejected by PG; caller bug, not outage.
  if [[ "$code" != "0" ]] || [[ "$msg" == *"ERROR:"* ]]; then
    echo "REJECTED"; return
  fi
  echo "OK"
}

ERR_KIND=$(_classify_pg_error "$PG_EXIT" "$PG_ERR")

if [[ "$ERR_KIND" == "OUTAGE" ]]; then
  echo '{"status":"degraded","backend":"file","id":"'"$ID"'","error":"PG unavailable","pg_error":"'"${PG_ERR//$'\n'/ }"'"}' 1>&2
  printf '%s\n' "$DATA" >> "$WORKSPACE/state/pg-write-fallback-$TABLE.jsonl"
  exit 0
fi

if [[ "$ERR_KIND" == "REJECTED" ]]; then
  # Sanitize error message for JSON: collapse newlines and escape double quotes.
  SAFE_ERR=$(printf '%s' "$PG_ERR" | tr '\n' ' ' | sed 's/\\/\\\\/g; s/"/\\"/g')
  echo '{"status":"error","backend":"postgres","id":"'"$ID"'","pg_error":"'"$SAFE_ERR"'"}' 1>&2
  exit 1
fi

if [[ "$PG_EXIT" == "0" ]]; then
  # TKT-0311: Post-write verification
  VERIFY=$(bash "$DB" -c "SELECT id FROM $TABLE WHERE id='$ID'" 2>/dev/null)
  if [[ "$VERIFY" == *"$ID"* ]]; then
    # TKT-0313: SAFE_MODE collision detection
    if [ "${DBWRITE_SAFE_MODE:-0}" = "1" ]; then
      EXISTING_TITLE=$(bash "$DB" -c "SELECT title FROM $TABLE WHERE id='$ID'" 2>/dev/null | tail -1)
      NEW_TITLE=$(printf '%s' "$DATA" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('title',''))" 2>/dev/null)
      if [ -n "$NEW_TITLE" ] && [ -n "$EXISTING_TITLE" ] && [ "$EXISTING_TITLE" != "$NEW_TITLE" ]; then
        echo '{"status":"collision","backend":"postgres","id":"'"$ID"'","error":"Ticket ID already exists with different title","existing_title":"'"$EXISTING_TITLE"'","new_title":"'"$NEW_TITLE"'"}' 1>&2
        exit 3
      fi
    fi
    echo '{"status":"ok","backend":"postgres","id":"'"$ID"'"}'
    exit 0
  else
    echo '{"status":"error","error":"PG write reported success but row not found during verification"}' 1>&2
  fi
fi

# Step 4: Fallback — atomic write to file with locking. TKT-0408: stdin JSON, no interpolation.
FALLBACK_FILE="$WORKSPACE/state/pg-write-fallback-$TABLE.jsonl"
echo '{"status":"degraded","backend":"file","id":"'"$ID"'","error":"PG write failed or verification failed"}' 1>&2

PY_FB=$(mktemp -t dbwrite_fb.XXXXXX.py) || exit 0
cat > "$PY_FB" <<'PYEOF'
import sys, os, json, fcntl, tempfile
fallback_file = sys.argv[1]
data = sys.stdin.read()
target_dir = os.path.dirname(fallback_file)
os.makedirs(target_dir, exist_ok=True)
try:
    lock_fd = os.open(fallback_file + '.lock', os.O_CREAT | os.O_RDWR, 0o644)
    fcntl.flock(lock_fd, fcntl.LOCK_EX)
    entries = []
    if os.path.exists(fallback_file):
        try:
            with open(fallback_file) as f:
                entries = [l.strip() for l in f if l.strip()]
        except: pass
    entries.append(data.strip())
    fd, temp_path = tempfile.mkstemp(dir=target_dir, prefix='.db_write_fb_', suffix='.tmp')
    with os.fdopen(fd, 'w') as f:
        f.write('\n'.join(entries) + '\n'); f.flush(); os.fsync(f.fileno())
    os.replace(temp_path, fallback_file)
    dir_fd = os.open(target_dir, os.O_RDONLY | os.O_DIRECTORY)
    try: os.fsync(dir_fd)
    finally: os.close(dir_fd)
    fcntl.flock(lock_fd, fcntl.LOCK_UN); os.close(lock_fd)
    sys.exit(0)
except Exception as e:
    print(f'ATOMIC_FALLBACK_ERROR: {e}', file=sys.stderr); sys.exit(1)
PYEOF

printf '%s' "$DATA" | python3 "$PY_FB" "$FALLBACK_FILE"
