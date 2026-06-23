#!/bin/bash
# pg-write-audit-event.sh — Bash wrapper for pg_write_audit_event PG function
# Usage: pg-write-audit-event.sh --actor <actor> --event-type <type> --table <table>
#                                [--entity-type <type>] [--entity-id <id>] [--row-id <id>]
#                                [--command <cmd>] [--payload <json>] [--prev-state <json>]
#                                [--new-state <json>] [--success <bool>] [--error-message <msg>]
#                                [--tenant-id <tenant>]
#
# All audit event writes are best-effort: failures are logged but exit 0.
# This ensures the primary write operation is never blocked by an audit write failure.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE="$(cd "$SCRIPT_DIR/.." && pwd)"
DB_RAW="$SCRIPT_DIR/db-raw.sh"

# Defaults
ACTOR=""
EVENT_TYPE="write"
ENTITY_TYPE=""
ENTITY_ID=""
TABLE_NAME=""
ROW_ID=""
COMMAND=""
PAYLOAD=""
PREV_STATE=""
NEW_STATE=""
SUCCESS="true"
ERROR_MESSAGE=""
TENANT_ID="ainchors"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --actor)         ACTOR="$2"; shift 2 ;;
    --event-type)    EVENT_TYPE="$2"; shift 2 ;;
    --entity-type)   ENTITY_TYPE="$2"; shift 2 ;;
    --entity-id)     ENTITY_ID="$2"; shift 2 ;;
    --table)         TABLE_NAME="$2"; shift 2 ;;
    --row-id)        ROW_ID="$2"; shift 2 ;;
    --command)       COMMAND="$2"; shift 2 ;;
    --payload)       PAYLOAD="$2"; shift 2 ;;
    --prev-state)    PREV_STATE="$2"; shift 2 ;;
    --new-state)     NEW_STATE="$2"; shift 2 ;;
    --success)       SUCCESS="$2"; shift 2 ;;
    --error-message) ERROR_MESSAGE="$2"; shift 2 ;;
    --tenant-id)     TENANT_ID="$2"; shift 2 ;;
    *) echo "pg-write-audit-event: Unknown arg: $1" >&2; exit 1 ;;
  esac
done

# Validate required
if [[ -z "$ACTOR" ]]; then
  echo "pg-write-audit-event: Missing required --actor" >&2
  exit 0
fi
if [[ -z "$TABLE_NAME" ]]; then
  echo "pg-write-audit-event: Missing required --table" >&2
  exit 0
fi

# Helper: escape single quotes for SQL
sql_escape() { echo "$1" | sed "s/'/''/g"; }

# Build SQL safely — quote each text value:
#   NULL values are passed as NULL literal (no quotes)
#   JSONB values use '...'::jsonb or NULL
#   Booleans are bare true/false
SQL="SELECT pg_write_audit_event("
SQL+="'$(sql_escape "$ACTOR")',"
SQL+="'$(sql_escape "$EVENT_TYPE")',"

# entity_type
if [[ -z "$ENTITY_TYPE" ]]; then SQL+="NULL,"; else SQL+="'$(sql_escape "$ENTITY_TYPE")',"; fi
# entity_id
if [[ -z "$ENTITY_ID" ]]; then SQL+="NULL,"; else SQL+="'$(sql_escape "$ENTITY_ID")',"; fi
# table_name (already validated as non-empty)
SQL+="'$(sql_escape "$TABLE_NAME")',"
# row_id
if [[ -z "$ROW_ID" ]]; then SQL+="NULL,"; else SQL+="'$(sql_escape "$ROW_ID")',"; fi
# command
if [[ -z "$COMMAND" ]]; then SQL+="NULL,"; else SQL+="'$(sql_escape "$COMMAND")',"; fi
# payload (JSONB)
if [[ -z "$PAYLOAD" ]]; then SQL+="NULL::jsonb,"; else SQL+="'$(sql_escape "$PAYLOAD")'::jsonb,"; fi
# prev_state (JSONB)
if [[ -z "$PREV_STATE" ]]; then SQL+="NULL::jsonb,"; else SQL+="'$(sql_escape "$PREV_STATE")'::jsonb,"; fi
# new_state (JSONB)
if [[ -z "$NEW_STATE" ]]; then SQL+="NULL::jsonb,"; else SQL+="'$(sql_escape "$NEW_STATE")'::jsonb,"; fi
# success (boolean)
if [[ "$SUCCESS" == "true" ]]; then SQL+="true,"; else SQL+="false,"; fi
# error_message
if [[ -z "$ERROR_MESSAGE" ]]; then SQL+="NULL,"; else SQL+="'$(sql_escape "$ERROR_MESSAGE")',"; fi
# tenant_id
SQL+="'$(sql_escape "$TENANT_ID")'"
SQL+=");"

# Execute — best-effort: log failures but always exit 0
result=$(bash "$DB_RAW" -c "$SQL" 2>&1)
rc=$?

if [[ $rc -ne 0 || -z "$result" ]]; then
  echo "pg-write-audit-event: WARNING audit write failed (actor=${ACTOR}, table=${TABLE_NAME}, row=${ROW_ID:-none})" >&2
  exit 0
fi

# Output the event ID
echo "$result"