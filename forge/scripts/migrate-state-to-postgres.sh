#!/bin/bash

# migrate-state-to-postgres.sh
# Migrates a JSON state file to a Postgres table.
# Usage: bash scripts/migrate-state-to-postgres.sh <json_file_path> [--dry-run]

set -e

JSON_FILE=$1
DRY_RUN=false

if [[ "$2" == "--dry-run" ]]; then
    DRY_RUN=true
fi

if [[ -z "$JSON_FILE" ]]; then
    echo "Usage: $0 <json_file_path> [--dry-run]"
    exit 1
fi

if [[ ! -f "$JSON_FILE" ]]; then
    echo "Error: File $JSON_FILE not found."
    exit 1
fi

# Extract table name from filename (e.g., state/tickets.json -> state_tickets)
# Replace hyphens with underscores for Postgres compatibility
FILENAME=$(basename "$JSON_FILE" .json)
TABLE_NAME="state_${FILENAME//-/_}"

# Postgres connection details
PSQL_CMD="/opt/homebrew/bin/psql -U ainchorsangiefpl -d ainchors_nexus"

echo "Processing $JSON_FILE -> $TABLE_NAME"

# We use a separate python file for logic to avoid shell heredoc issues
PY_SCRIPT="/tmp/migrate_logic.py"
cat <<EOF > "$PY_SCRIPT"
import json
import os
import sys

json_file = "$JSON_FILE"
table_name = "$TABLE_NAME"
dry_run = "$DRY_RUN"

try:
    with open(json_file, 'r') as f:
        data = json.load(f)
except Exception as e:
    print(f"Error reading JSON: {e}")
    sys.exit(1)

data_list = None
if isinstance(data, list):
    data_list = data
elif isinstance(data, dict):
    for key in ['tickets', 'tasks', 'checks', 'history']:
        if key in data:
            val = data[key]
            if isinstance(val, list):
                data_list = val
            elif isinstance(val, dict):
                data_list = [{"date_key": k, **v} for k, v in val.items()]
                break
    if data_list is None:
        data_list = [data]

if data_list is None:
    print(f"Error: No compatible data array found in {json_file}")
    sys.exit(1)

if not data_list:
    print(f"Warning: Data list is empty for {json_file}")
    sys.exit(0)

sample = data_list[0]
columns = list(sample.keys())

col_defs = ", ".join([f"{col} TEXT" for col in columns])
create_sql = f"CREATE TABLE IF NOT EXISTS {table_name} ({col_defs});"

pk = columns[0]

sql_statements = []
sql_statements.append(create_sql + ";")
# Use a safer way to add PK: drop it if it exists or just handle failure
# Actually, we'll just use a DO block to add the PK if it's missing
pk_sql = f"""
DO \$\$ 
BEGIN 
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = '{table_name}_pkey') THEN 
        ALTER TABLE {table_name} ADD PRIMARY KEY ({pk}); 
    END IF; 
END \$\$;
"""
sql_statements.append(pk_sql)

for row in data_list:
    vals = []
    for col in columns:
        v = row.get(col, "")
        if v is None:
            v = "NULL"
        elif isinstance(v, (dict, list)):
            v = json.dumps(v)
        else:
            v = str(v).replace("'", "''")
        
        if v == "NULL":
            vals.append("NULL")
        else:
            vals.append(f"'{v}'")
    
    val_str = ", ".join(vals)
    sql = f"INSERT INTO {table_name} ({', '.join(columns)}) VALUES ({val_str}) ON CONFLICT ({pk}) DO UPDATE SET {', '.join([f'{col} = EXCLUDED.{col}' for col in columns[1:]])};"
    sql_statements.append(sql)

with open("/tmp/migrate_generated.sql", "w") as f:
    f.write("\n".join(sql_statements))
EOF

python3 "$PY_SCRIPT"

if [ "$DRY_RUN" = true ]; then
    cat /tmp/migrate_generated.sql
else
    $PSQL_CMD -v ON_ERROR_STOP=0 -f /tmp/migrate_generated.sql
fi
