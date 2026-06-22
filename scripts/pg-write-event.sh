#!/bin/bash
# pg-write-event.sh — Bash wrapper for pg_write_event PG function
# Usage: pg-write-event.sh --actor <actor> --event-type <type> --entity-type <type> --entity-id <id>
#                          [--payload <json>] [--prev-state <json>] [--new-state <json>]
#                          [--tenant-id <tenant>]
#
# All event writes are best-effort: failures are logged but do not exit non-zero.
# This ensures the primary mutation (ticket/CHG/sprint write) is never blocked
# by an event write failure.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DB_RAW="$SCRIPT_DIR/db-raw.sh"

# Parse args
ACTOR=""
EVENT_TYPE=""
ENTITY_TYPE=""
ENTITY_ID=""
PAYLOAD="{}"
PREV_STATE=""
NEW_STATE=""
TENANT_ID="ainchors"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --actor)       ACTOR="$2"; shift 2 ;;
    --event-type)  EVENT_TYPE="$2"; shift 2 ;;
    --entity-type) ENTITY_TYPE="$2"; shift 2 ;;
    --entity-id)   ENTITY_ID="$2"; shift 2 ;;
    --payload)     PAYLOAD="$2"; shift 2 ;;
    --prev-state)  PREV_STATE="$2"; shift 2 ;;
    --new-state)   NEW_STATE="$2"; shift 2 ;;
    --tenant-id)   TENANT_ID="$2"; shift 2 ;;
    *) echo "pg-write-event: Unknown arg: $1" >&2; exit 1 ;;
  esac
done

# Validate required
if [[ -z "$ACTOR" || -z "$EVENT_TYPE" || -z "$ENTITY_TYPE" || -z "$ENTITY_ID" ]]; then
  echo "pg-write-event: Missing required args: --actor, --event-type, --entity-type, --entity-id" >&2
  exit 1
fi

# Build the SQL call
# Escape single quotes for PG
esc_actor=$(echo "$ACTOR" | sed "s/'/''/g")
esc_event_type=$(echo "$EVENT_TYPE" | sed "s/'/''/g")
esc_entity_type=$(echo "$ENTITY_TYPE" | sed "s/'/''/g")
esc_entity_id=$(echo "$ENTITY_ID" | sed "s/'/''/g")
esc_tenant=$(echo "$TENANT_ID" | sed "s/'/''/g")

# Build prev_state / new_state SQL fragments
prev_state_sql="NULL"
new_state_sql="NULL"
if [[ -n "$PREV_STATE" ]]; then
  prev_state_sql="'$(echo "$PREV_STATE" | sed "s/'/''/g")'::jsonb"
fi
if [[ -n "$NEW_STATE" ]]; then
  new_state_sql="'$(echo "$NEW_STATE" | sed "s/'/''/g")'::jsonb"
fi

SQL="SELECT pg_write_event(
  '${esc_actor}',
  '${esc_event_type}',
  '${esc_entity_type}',
  '${esc_entity_id}',
  '$(echo "$PAYLOAD" | sed "s/'/''/g")'::jsonb,
  ${prev_state_sql},
  ${new_state_sql},
  '${esc_tenant}'
);"

# Execute — best-effort: log failures but don't exit non-zero
result=$(bash "$DB_RAW" -c "$SQL" 2>/dev/null) || true
if [[ -z "$result" || "$result" == "null" ]]; then
  echo "pg-write-event: WARNING event write failed for ${ENTITY_TYPE}:${ENTITY_ID} (${EVENT_TYPE})" >&2
  exit 0
fi

echo "$result"
