#!/bin/bash
# scripts/tqp-executor.sh — TKT-0504
# TQP executor: polls state_task_queue for non-CREST TQP atoms (source=agent:tqp,
# status=dispatched, claimedby=agent:tqp, no parent_task_id) and dispatches them
# via sessions_spawn (in-band path: INSERT exec-atom into state_task_queue).
#
# TKT-0504-A1: skeleton — poll + lock + state file + idempotency gate.
# TKT-0504-A2: sessions_spawn integration via in-band exec-atom INSERT
#              (atomic UPDATE state_payload.executor + INSERT exec-atom row
#              with parent_task_id=original). Model + task + agent extracted
#              from atoms_jsonb. Idempotency gate preserved (WHERE executor
#              IS NULL). --dry-run and --limit flags honored.
#
# Usage:
#   bash scripts/tqp-executor.sh                # claim up to 5 (default)
#   bash scripts/tqp-executor.sh --dry-run      # print would-spawn, no INSERT, no UPDATE
#   bash scripts/tqp-executor.sh --limit N      # claim up to N (default 5)
#   bash scripts/tqp-executor.sh --dry-run --limit 1
#
# Exit codes:
#   0 = success (claimed 0+ atoms, all idempotent)
#   1 = transient PG error (caller may retry)
#
# Lock: state/tqp-executor.lock (flock)
# State: state/tqp-executor-state.json (last_poll_at, processed_count, last_claimed_ids)
#
# L-096 silence class fix (TKT-0504): TQP claims but no executor existed; this
# script IS the executor. Idempotency gate: skip rows where state_payload.executor
# is non-null. A2 will populate that field.

set -euo pipefail

# ---------- Defaults ----------
LIMIT=5
DRY_RUN="false"

# ---------- Args ----------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN="true"
      shift
      ;;
    --dry-run=false)
      DRY_RUN="false"
      shift
      ;;
    --poll-once)
      # alias for --dry-run --limit 5 used by cron
      DRY_RUN="false"
      LIMIT="${LIMIT:-5}"
      shift
      ;;
    --limit)
      LIMIT="${2:-5}"
      shift 2
      ;;
    --limit=*)
      LIMIT="${1#--limit=}"
      shift
      ;;
    -h|--help)
      sed -n '2,30p' "$0"
      exit 0
      ;;
    *)
      echo "tqp-executor: unknown arg: $1" >&2
      exit 1
      ;;
  esac
done

# ---------- Paths ----------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOCK_FILE="$WORKSPACE_ROOT/state/tqp-executor.lock"
STATE_FILE="$WORKSPACE_ROOT/state/tqp-executor-state.json"
DB_RAW="$SCRIPT_DIR/db-raw.sh"

# Pre-flight
if [[ ! -x "$DB_RAW" ]]; then
  echo "tqp-executor: db-raw.sh not found or not executable at $DB_RAW" >&2
  exit 1
fi

mkdir -p "$WORKSPACE_ROOT/state"

# ---------- Lock ----------
# Atomic lock via mkdir(1) (POSIX-portable, macOS/Linux). mkdir is atomic, so
# exactly one runner can create the lock dir. Stale lock dirs are detected by
# mtime and removed (best-effort).
LOCK_DIR="$LOCK_FILE.dir"
if mkdir "$LOCK_DIR" 2>/dev/null; then
  echo $$ > "$LOCK_DIR/pid"
else
  # Stale? Check age; if > 1h, remove and retry once.
  if [[ -d "$LOCK_DIR" ]]; then
    lock_mtime=$(stat -f %m "$LOCK_DIR" 2>/dev/null || stat -c %Y "$LOCK_DIR" 2>/dev/null || echo 0)
    now_epoch=$(date +%s)
    age=$((now_epoch - lock_mtime))
    if [[ $age -gt 3600 ]]; then
      echo "[tqp-executor] removing stale lock (age=${age}s)" >&2
      rm -rf "$LOCK_DIR"
      if mkdir "$LOCK_DIR" 2>/dev/null; then
        echo $$ > "$LOCK_DIR/pid"
      else
        echo "[tqp-executor] another instance holds the lock; exiting"
        exit 0
      fi
    else
      echo "[tqp-executor] another instance holds the lock; exiting"
      exit 0
    fi
  else
    echo "[tqp-executor] another instance holds the lock; exiting"
    exit 0
  fi
fi
trap 'rm -rf "$LOCK_DIR"' EXIT

# ---------- State helpers ----------
now_iso() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

# Read state (or initialize). We avoid jq dependency; use python3 if available, else
# a minimal awk-based reader. Since this file is small, we just keep the full state
# in memory and rewrite on each poll.
read_state() {
  if [[ -f "$STATE_FILE" ]]; then
    cat "$STATE_FILE"
  else
    printf '{"last_poll_at":"","processed_count":0,"last_claimed_ids":[]}'
  fi
}

write_state() {
  local last_poll_at="$1"
  local processed_count="$2"
  local last_claimed_ids_json="$3"
  cat > "$STATE_FILE" <<EOF
{"last_poll_at":"$last_poll_at","processed_count":$processed_count,"last_claimed_ids":$last_claimed_ids_json}
EOF
}

PROCESSED_COUNT=$(read_state | python3 -c "import sys,json; print(json.load(sys.stdin).get('processed_count',0))" 2>/dev/null || echo 0)

# ---------- Query ----------
# Match: status=dispatched, claimedby=agent:tqp, no parent_task_id, executor empty.
# A2 will UPDATE state_payload.executor; A1 only prints poll output.
QUERY="SELECT id FROM state_task_queue
WHERE status='dispatched'
  AND claimedby='agent:tqp'
  AND (parent_task_id IS NULL OR parent_task_id = '')
  AND (state_payload->>'executor' IS NULL OR state_payload->>'executor' = '')
ORDER BY claimedat ASC
LIMIT $LIMIT;"

POLL_OUTPUT=$("$DB_RAW" -c "$QUERY" 2>&1) || {
  rc=$?
  echo "[tqp-executor] transient PG error (rc=$rc) on poll" >&2
  echo "$POLL_OUTPUT" >&2
  exit 1
}

# Strip header line + blank; collect IDs
CLAIMED_IDS=()
while IFS= read -r line; do
  # Skip psql header lines (those starting with non-id characters)
  [[ -z "$line" ]] && continue
  [[ "$line" =~ ^[A-Za-z0-9_-]+$ ]] || continue
  CLAIMED_IDS+=("$line")
done <<< "$POLL_OUTPUT"

LAST_POLL_AT=$(now_iso)

# ── TKT-0319 Atom 4 finalizer: copy child exec-atom status back to parent ──
# Any parent atom that we marked 'running' and spawned an exec-atom for should
# reflect the child's terminal status. This is idempotent: it only updates
# parents that are still 'running' and whose child is in a terminal state.
# Runs before the no-atoms early exit so it executes on every poll.
FINALIZER_SQL="
WITH terminal_children AS (
  SELECT parent_task_id AS parent_id,
         status         AS child_status,
         updated_at_ts  AS child_updated_at
  FROM state_task_queue
  WHERE parent_task_id IS NOT NULL
    AND status IN ('done', 'complete', 'failed', 'cancelled')
),
parents_to_update AS (
  SELECT c.parent_id, c.child_status, c.child_updated_at
  FROM terminal_children c
  JOIN state_task_queue p ON p.id = c.parent_id
  WHERE p.status = 'running'
    AND p.state_payload->>'executor' = 'tqp-executor'
)
UPDATE state_task_queue p
SET status = u.child_status,
    previous_status = 'running',
    updated_at_ts = now()
FROM parents_to_update u
WHERE p.id = u.parent_id;
"

FINALIZER_OUT=$("$DB_RAW" -c "$FINALIZER_SQL" 2>&1) || {
  echo "[tqp-executor] finalizer query failed: $FINALIZER_OUT" >&2
}

FINALIZED_COUNT=$(echo "$FINALIZER_OUT" | grep -oE 'UPDATE [0-9]+' | awk '{s+=$2} END {print s+0}')
if [[ "$FINALIZED_COUNT" -gt 0 ]]; then
  echo "[tqp-executor] finalizer: $FINALIZED_COUNT parent(s) updated from child exec-atom status"
fi

if [[ ${#CLAIMED_IDS[@]} -eq 0 ]]; then
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "[tqp-executor] dry-run: 0 atoms ready for spawn (poll at $LAST_POLL_AT)"
  else
    echo "[tqp-executor] poll: no atoms ready (poll at $LAST_POLL_AT)"
  fi
  write_state "$LAST_POLL_AT" "$PROCESSED_COUNT" "[]"
  exit 0
fi

# ---------- Print + A2 spawn integration ----------
# For each claimed atom: fetch atoms_jsonb, atomic UPDATE state_payload.executor,
# INSERT exec-atom (in-band path: parent_task_id=original, source=agent:tqp-queued,
# status=queued). The exec-atom carries model + task + agent for the spawn consumer
# (TQP cron or sessions_spawn bridge) to pick up.
NEW_COUNT=0
LAST_IDS_JSON="["
first=1
for id in "${CLAIMED_IDS[@]}"; do
  if [[ $first -eq 1 ]]; then
    LAST_IDS_JSON+="\"$id\""
    first=0
  else
    LAST_IDS_JSON+=",\"$id\""
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "[tqp-executor] dry-run: would claim $id (no UPDATE, no INSERT)"
    continue
  fi

  # Fetch model + task + agent + checkpoint from the parent atom.
  # We use row_to_json so embedded JSON (state_payload, last_checkpoint)
  # does not break a pipe-delimited parse.
  DETAIL_QUERY="SELECT row_to_json(t)::text FROM (SELECT
                       atoms_jsonb->>'model' AS model,
                       atoms_jsonb->>'task' AS task,
                       atoms_jsonb->>'agent' AS agent,
                       atoms_jsonb->>'parent_ticket' AS parent_ticket,
                       atoms_jsonb->>'ac' AS ac,
                       COALESCE(state_payload, '{}'::jsonb) AS state_payload,
                       COALESCE(last_checkpoint, '{}'::jsonb) AS last_checkpoint
                FROM state_task_queue WHERE id='$id') t;"
  DETAIL=$("$DB_RAW" -c "$DETAIL_QUERY" 2>&1) || {
    echo "[tqp-executor] transient PG error fetching details for $id; skipping" >&2
    continue
  }

  # First non-empty line is the JSON row.
  JSON_LINE=$(echo "$DETAIL" | awk 'NF {print; exit}')
  if [[ -z "$JSON_LINE" ]]; then
    echo "[tqp-executor] no detail returned for $id; skipping" >&2
    continue
  fi

  # Parse with python3 (jq-free)
  PARSED=$(python3 -c "
import json,sys
try:
    d=json.loads(sys.stdin.read())
    for k in ['model','task','agent','parent_ticket','ac']:
        v=d.get(k) or ''
        v=v.replace('\\n','\\u000a')
        print(v)
    print(json.dumps(d.get('state_payload') or {}))
    print(json.dumps(d.get('last_checkpoint') or {}))
except Exception:
    sys.exit(1)
" <<< "$JSON_LINE")
  if [[ $? -ne 0 ]]; then
    echo "[tqp-executor] failed to parse detail JSON for $id; skipping" >&2
    continue
  fi

  # Read 7 lines: model, task, agent, parent_ticket, ac, state_payload_json, last_checkpoint_json
  MODEL=$(echo "$PARSED" | sed -n '1p')
  TASK=$(echo "$PARSED" | sed -n '2p')
  AGENT=$(echo "$PARSED" | sed -n '3p')
  PARENT_TKT=$(echo "$PARSED" | sed -n '4p')
  AC=$(echo "$PARSED" | sed -n '5p')
  STATE_PAYLOAD_JSON=$(echo "$PARSED" | sed -n '6p')
  LAST_CHECKPOINT_JSON=$(echo "$PARSED" | sed -n '7p')

  # Defaults
  [[ -z "$MODEL" || "$MODEL" == "" ]] && MODEL="flash"
  [[ -z "$AGENT" || "$AGENT" == "" ]] && AGENT="forge"

  # Atomic UPDATE: only if executor is still NULL (idempotency gate).
  UPDATE_SQL="UPDATE state_task_queue
SET state_payload = jsonb_set(
                  jsonb_set(COALESCE(state_payload, '{}'::jsonb), '{executor}', '\"tqp-executor\"'),
                  '{executed_at}', to_jsonb(now()::text)
                ),
    status = 'running',
    updated_at = '$LAST_POLL_AT',
    updated_at_ts = now()
WHERE id = '$id'
  AND (state_payload->>'executor' IS NULL OR state_payload->>'executor' = '');"

  UPDATE_OUT=$("$DB_RAW" -c "$UPDATE_SQL" 2>&1) || {
    echo "[tqp-executor] UPDATE failed for $id; skipping" >&2
    echo "$UPDATE_OUT" >&2
    continue
  }

  # psql returns "UPDATE <n>"; we want n=1 for successful claim.
  if ! echo "$UPDATE_OUT" | grep -q "UPDATE 1"; then
    echo "[tqp-executor] $id: idempotency gate tripped (already has executor); skipping"
    continue
  fi

  # In-band exec-atom INSERT. Carry model + task + agent + checkpoint forward.
  # Use parent_task_id = original atom id so downstream consumers can correlate.
  ESC_TASK=$(printf '%s' "$TASK" | sed "s/'/''/g")
  ESC_AGENT=$(printf '%s' "$AGENT" | sed "s/'/''/g")
  ESC_MODEL=$(printf '%s' "$MODEL" | sed "s/'/''/g")
  ESC_PARENT_TKT=$(printf '%s' "$PARENT_TKT" | sed "s/'/''/g")
  ESC_AC=$(printf '%s' "$AC" | sed "s/'/''/g")
  ESC_ID=$(printf '%s' "$id" | sed "s/'/''/g")
  ESC_STATE_PAYLOAD=$(printf '%s' "$STATE_PAYLOAD_JSON" | sed "s/'/''/g")
  ESC_LAST_CHECKPOINT=$(printf '%s' "$LAST_CHECKPOINT_JSON" | sed "s/'/''/g")

  EXEC_ID="${id}-EXEC-$(date +%s)"
  EXEC_PAYLOAD="{\"tkt\": \"${ESC_PARENT_TKT}\", \"task\": \"${ESC_TASK}\", \"agent\": \"${ESC_AGENT}\", \"model\": \"${ESC_MODEL}\", \"ac\": \"${ESC_AC}\", \"spawned_by\": \"tqp-executor\", \"spawned_for\": \"${ESC_ID}\", \"parent_state_payload\": ${ESC_STATE_PAYLOAD}, \"last_checkpoint\": ${ESC_LAST_CHECKPOINT}}"

  INSERT_SQL="INSERT INTO state_task_queue
(id, title, tier, status, priority, source, parent_task_id, atoms_jsonb, created_at, updated_at, created_at_ts, updated_at_ts)
VALUES
('${EXEC_ID}',
 'TQP exec for ${id}',
 'S',
 'queued',
 'normal',
 'agent:tqp-queued',
 '${ESC_ID}',
 '${EXEC_PAYLOAD}'::jsonb,
 '${LAST_POLL_AT}',
 '${LAST_POLL_AT}',
 now(),
 now());"

  INSERT_OUT=$("$DB_RAW" -c "$INSERT_SQL" 2>&1) || {
    echo "[tqp-executor] INSERT exec-atom failed for $id; exec-atom may be lost" >&2
    echo "$INSERT_OUT" >&2
    continue
  }

  echo "[tqp-executor] poll: $id ready for spawn (model=$MODEL, agent=$AGENT) → $EXEC_ID"
  NEW_COUNT=$((NEW_COUNT + 1))
done
LAST_IDS_JSON+="]"

TOTAL=$((PROCESSED_COUNT + NEW_COUNT))

write_state "$LAST_POLL_AT" "$TOTAL" "$LAST_IDS_JSON"

exit 0
