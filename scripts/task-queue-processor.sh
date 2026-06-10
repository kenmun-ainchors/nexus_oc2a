#!/bin/zsh
# AInchors Task Queue Processor — TKT-0236 (PG backend + State Checking)
# Async, stateless atomic task execution with mandatory verify-before-close.
# Runs every 5 minutes via cron. Max 1 concurrent task.
# Owner: Forge | Sprint 5 | Updated: TKT-0236 PG migration

set -u

WORKSPACE_ROOT="/Users/ainchorsangiefpl/.openclaw/workspace"
TICKET_FILE="$WORKSPACE_ROOT/state/tickets.json"
TICKET_SH="$WORKSPACE_ROOT/scripts/ticket.sh"
ALERT_FILE="$WORKSPACE_ROOT/state/task-queue-failed.json"
DB_READ="$WORKSPACE_ROOT/scripts/db-read.sh"
DB_WRITE="$WORKSPACE_ROOT/scripts/db-write.sh"

die() { echo "TQP ERROR: $1" >&2; exit 1; }

# ──────────────────────────────────────────
# PG helper functions (TKT-0236 Atom 1)
# ──────────────────────────────────────────
pg() {
  PGHOST=/tmp PGPORT=5432 PGUSER=ainchorsangiefpl PGDATABASE=ainchors_nexus /opt/homebrew/bin/psql -t -A "$@"
}

# ──────────────────────────────────────────
# ATOM 2.2: Dispatch — pick next queued task from PG
# ──────────────────────────────────────────

# Check if another TQP instance is already running (lock file)
LOCK_FILE="/tmp/task-queue-processor.lock"
if [[ -f "$LOCK_FILE" ]]; then
  LOCK_AGE=$(($(date +%s) - $(stat -f%m "$LOCK_FILE" 2>/dev/null || echo 0)))
  if [[ $LOCK_AGE -lt 540 ]]; then
    echo "TQP: Another instance is running (lock age: ${LOCK_AGE}s). Skipping."
    exit 0
  fi
  echo "TQP: Stale lock detected (${LOCK_AGE}s). Clearing and proceeding."
  rm -f "$LOCK_FILE"
fi

# Pick first queued task from PG
TASK_JSON=$(pg -c "SELECT row_to_json(t)::text FROM (SELECT * FROM state_task_queue WHERE status = 'queued' ORDER BY priority DESC, created_at_ts ASC LIMIT 1) t;" 2>/dev/null)

# Check for dispatched tasks that need verification
VERIFY_JSON=$(pg -c "SELECT row_to_json(t)::text FROM (SELECT * FROM state_task_queue WHERE status = 'dispatched' ORDER BY claimedat ASC LIMIT 1) t;" 2>/dev/null)

if [[ -z "$TASK_JSON" || "$TASK_JSON" == "null" || "$TASK_JSON" == "" ]]; then
  # No queued tasks — check for dispatched tasks that need verification
  if [[ -n "$VERIFY_JSON" && "$VERIFY_JSON" != "null" && "$VERIFY_JSON" != "" ]]; then
    # ──────────────────────────────────────────
    # ATOM 2.3: Verification of dispatched tasks (PG backend)
    # ──────────────────────────────────────────
    V_TASK_ID=$(echo "$VERIFY_JSON" | jq -r '.id')
    V_TICKET_ID=$(echo "$VERIFY_JSON" | jq -r '.id')  # task ID = ticket ID in current schema
    V_CLAIMEDBY=$(echo "$VERIFY_JSON" | jq -r '.claimedby')
    V_CLAIMEDAT=$(echo "$VERIFY_JSON" | jq -r '.claimedat')
    
    echo "TQP: Verifying dispatched task $V_TASK_ID..."
    
    # Check if claim has timed out (default 30 min)
    if [[ -n "$V_CLAIMEDAT" ]]; then
      CLAIM_EPOCH=$(date -j -f "%Y-%m-%dT%H:%M:%S" "${V_CLAIMEDAT:0:19}" +%s 2>/dev/null || echo 0)
      NOW_EPOCH=$(date +%s)
      CLAIM_AGE=$((NOW_EPOCH - CLAIM_EPOCH))
      if [[ $CLAIM_AGE -gt 1800 ]]; then
        echo "TQP: Claim timed out for $V_TASK_ID (${CLAIM_AGE}s). Re-queuing."
        pg -c "UPDATE state_task_queue SET status='queued', claimedby=NULL, claimedat=NULL, updated_at_ts=now(), claimtimeout=NULL WHERE id='$V_TASK_ID'" 2>/dev/null
        rm -f "$LOCK_FILE"
        exit 0
      fi
    fi
    
    # State Checking (TKT-0182): verify dispatched task has a real agent session
    SESSION_CHECK=$(bash "$WORKSPACE_ROOT/scripts/sessions_list" 2>/dev/null | grep "$V_TASK_ID" || echo "")
    
    if [[ -z "$SESSION_CHECK" ]]; then
      # Agent session not found — task may have been completed or failed
      # Check for deliverable
      V_DELIVERABLE=$(echo "$VERIFY_JSON" | jq -r '.atoms_jsonb // ""')
      
      echo "TQP: No active session found for $V_TASK_ID. Checking deliverable..."
      
      # Simple check: did the task complete? (atoms_jsonb has atoms with status)
      ATOMS_DONE=$(echo "$V_DELIVERABLE" | jq '[.[] | select(.status == "complete")] | length' 2>/dev/null || echo 0)
      ATOMS_TOTAL=$(echo "$V_DELIVERABLE" | jq 'length' 2>/dev/null || echo 0)
      
      if [[ "$ATOMS_DONE" -eq "$ATOMS_TOTAL" && "$ATOMS_TOTAL" -gt 0 ]]; then
        echo "TQP: All atoms complete ($ATOMS_DONE/$ATOMS_TOTAL). Marking done."
        pg -c "UPDATE state_task_queue SET status='complete', updated_at_ts=now() WHERE id='$V_TASK_ID'" 2>/dev/null
      else
        # Re-queue for retry
        echo "TQP: Task incomplete ($ATOMS_DONE/$ATOMS_TOTAL atoms). Re-queuing."
        pg -c "UPDATE state_task_queue SET status='queued', claimedby=NULL, claimedat=NULL, updated_at_ts=now() WHERE id='$V_TASK_ID'" 2>/dev/null
      fi
    else
      echo "TQP: Session active for $V_TASK_ID — verification deferred."
    fi
  else
    echo "TQP: No queued or dispatched tasks. Exiting."
    exit 0
  fi
  rm -f "$LOCK_FILE"
  exit 0
fi

# Create lock
echo "$$ $(date -Iseconds)" > "$LOCK_FILE"

TASK_ID=$(echo "$TASK_JSON" | jq -r '.id')
TASK_TITLE=$(echo "$TASK_JSON" | jq -r '.title')
TASK_TIER=$(echo "$TASK_JSON" | jq -r '.tier')
TASK_SOURCE=$(echo "$TASK_JSON" | jq -r '.source')

TASK_PARENT=$(echo "$TASK_JSON" | jq -r '.parent_task_id // empty')

echo "TQP: Processing $TASK_ID — $TASK_TITLE"

# State Checking (TKT-0182): verify task exists and is still queued before claiming
CURRENT_STATUS=$(pg -c "SELECT status FROM state_task_queue WHERE id='$TASK_ID'" 2>/dev/null)
if [[ "$CURRENT_STATUS" != "queued" ]]; then
  echo "TQP: State check failed — $TASK_ID is $CURRENT_STATUS, not queued. Skipping."
  rm -f "$LOCK_FILE"
  exit 0
fi

# Claim the task (atomic UPDATE with WHERE status='queued' prevents double-claim)
NOW=$(date -Iseconds)
CLAIMED=$(pg -c "UPDATE state_task_queue SET status='dispatched', claimedby='agent:tqp', claimedat='$NOW', claimtimeout='$(date -v+30M -Iseconds)', updated_at_ts=now() WHERE id='$TASK_ID' AND status='queued' RETURNING id;" 2>/dev/null)

if [[ -z "$CLAIMED" || "$CLAIMED" == "" ]]; then
  echo "TQP: Claim failed — $TASK_ID already claimed by another instance. Skipping."
  rm -f "$LOCK_FILE"
  exit 0
fi

echo "TQP: Claimed $TASK_ID — dispatched."

# ──────────────────────────────────────────
# ATOM 2.2: Task is now dispatched. The cron agent (deepseek-pro) will
# process the dispatch in its own session using sessions_spawn.
# The TQP script just handles queue management — the actual execution
# happens in the agent session that calls this script.
# ──────────────────────────────────────────

echo "TQP: $TASK_ID dispatched — agent session will pick up for execution."

# ──────────────────────────────────────────
# TKT-0382: Sub-CREST escalated state handling
# If a sub-task is in 'escalated' state, the processor detects it
# and ensures the parent is in master_replanning
# ──────────────────────────────────────────
ESCALATED_JSON=$(pg -c "SELECT row_to_json(t)::text FROM (SELECT * FROM state_task_queue WHERE status = 'escalated' AND parent_task_id IS NOT NULL ORDER BY updated_at_ts DESC LIMIT 1) t;" 2>/dev/null)

if [[ -n "$ESCALATED_JSON" && "$ESCALATED_JSON" != "null" && "$ESCALATED_JSON" != "" ]]; then
  E_TASK_ID=$(echo "$ESCALATED_JSON" | jq -r '.id')
  E_PARENT=$(echo "$ESCALATED_JSON" | jq -r '.parent_task_id')
  echo "TQP: Escalated sub-task detected: $E_TASK_ID (parent: $E_PARENT)"
  
  # Ensure parent is in master_replanning
  PARENT_STATUS=$(pg -c "SELECT status FROM state_task_queue WHERE id='$E_PARENT'" 2>/dev/null)
  if [[ "$PARENT_STATUS" != "master_replanning" ]]; then
    echo "TQP: Setting parent $E_PARENT to master_replanning"
    pg -c "UPDATE state_task_queue SET status='master_replanning', updated_at_ts=now() WHERE id='$E_PARENT'" 2>/dev/null
  fi
  
  # Verify escalation linkage
  pg -c "UPDATE state_task_queue SET state_payload = jsonb_set(COALESCE(state_payload, '{}'), '{escalated_from}', to_jsonb('$E_TASK_ID'::text)) WHERE id='$E_PARENT'" 2>/dev/null
fi

# ──────────────────────────────────────────
# TKT-0382: Replan iterate detection
# Check for sub_crest_replanning tasks that need to be iterated
# ──────────────────────────────────────────
REPLAN_JSON=$(pg -c "SELECT row_to_json(t)::text FROM (SELECT * FROM state_task_queue WHERE status = 'sub_crest_replanning' ORDER BY updated_at_ts DESC LIMIT 1) t;" 2>/dev/null)

if [[ -n "$REPLAN_JSON" && "$REPLAN_JSON" != "null" && "$REPLAN_JSON" != "" ]]; then
  R_TASK_ID=$(echo "$REPLAN_JSON" | jq -r '.id')
  R_ITERATION=$(echo "$REPLAN_JSON" | jq -r '.iteration_count // 0')
  R_NEW_ITER=$((R_ITERATION + 1))
  echo "TQP: Replan iterate detected: $R_TASK_ID (iteration $R_ITERATION -> $R_NEW_ITER)"
  
  pg -c "UPDATE state_task_queue SET status='sub_crest_executing', iteration_count=$R_NEW_ITER, updated_at_ts=now() WHERE id='$R_TASK_ID'" 2>/dev/null
  echo "TQP: $R_TASK_ID transitioned to sub_crest_executing (iteration #$R_NEW_ITER)"
fi

rm -f "$LOCK_FILE"
exit 0
