#!/bin/zsh
# AInchors Task Queue Processor — TKT-0237 C1
# Async, stateless atomic task execution with mandatory verify-before-close.
# Runs every 5 minutes via cron. Max 1 concurrent task.
# Owner: Forge | Sprint 4

set -u

WORKSPACE_ROOT="/Users/ainchorsangiefpl/.openclaw/workspace"
QUEUE_FILE="$WORKSPACE_ROOT/state/task-queue.json"
TICKET_FILE="$WORKSPACE_ROOT/state/tickets.json"
TICKET_SH="$WORKSPACE_ROOT/scripts/ticket.sh"
ALERT_FILE="$WORKSPACE_ROOT/state/task-queue-failed.json"

die() { echo "TQP ERROR: $1" >&2; exit 1; }

# ──────────────────────────────────────────
# ATOM 2.2: Dispatch — pick next queued task
# ──────────────────────────────────────────

# Check if another TQP instance is already running (lock file)
LOCK_FILE="/tmp/task-queue-processor.lock"
if [[ -f "$LOCK_FILE" ]]; then
  LOCK_AGE=$(($(date +%s) - $(stat -f%m "$LOCK_FILE" 2>/dev/null || echo 0)))
  if [[ $LOCK_AGE -lt 540 ]]; then  # 9 min — cron runs every 5, so 9 means stuck
    echo "TQP: Another instance is running (lock age: ${LOCK_AGE}s). Skipping."
    exit 0
  fi
  echo "TQP: Stale lock detected (${LOCK_AGE}s). Clearing and proceeding."
  rm -f "$LOCK_FILE"
fi

# Validate state files exist
[[ ! -f "$QUEUE_FILE" ]] && die "task-queue.json not found at $QUEUE_FILE"
[[ ! -f "$TICKET_FILE" ]] && die "tickets.json not found at $TICKET_FILE"

# Pick first item with status=queued (use jq first() to get complete object)
TASK_JSON=$(jq -c '[.queue[] | select(.status == "queued")][0]' "$QUEUE_FILE" 2>/dev/null)

# Also check for dispatched tasks that need verification
VERIFY_JSON=$(jq -c '[.queue[] | select(.status == "dispatched")][0]' "$QUEUE_FILE" 2>/dev/null)
if [[ -z "$TASK_JSON" || "$TASK_JSON" == "null" ]]; then
  # No queued tasks — check for dispatched tasks that need verification
  if [[ -n "$VERIFY_JSON" && "$VERIFY_JSON" != "null" ]]; then
    # ──────────────────────────────────────────
    # ATOM 2.3: Verification of dispatched tasks
    # ──────────────────────────────────────────
    V_TASK_ID=$(echo "$VERIFY_JSON" | jq -r '.taskId')
    V_TICKET_ID=$(echo "$VERIFY_JSON" | jq -r '.ticketId')
    V_DELIVERABLE=$(echo "$VERIFY_JSON" | jq -r '.expectedDeliverable')
    V_TYPE=$(echo "$VERIFY_JSON" | jq -r '.type')
    V_RETRIES=$(echo "$VERIFY_JSON" | jq -r '.retries')
    V_MAX=$(echo "$VERIFY_JSON" | jq -r '.maxRetries')
    
    echo "TQP: Verifying dispatched task $V_TASK_ID..."
    
    # Source verify_before_close from ticket.sh
    source "$TICKET_SH" 2>/dev/null || true
    
    # Run verification
    if verify_before_close "$V_TICKET_ID" "$V_TYPE" "$V_DELIVERABLE" 2>/tmp/tqp-verify.log; then
      echo "TQP: Verification PASSED for $V_TASK_ID"
      NOW=$(date -Iseconds)
      jq --arg tid "$V_TASK_ID" --arg ts "$NOW" \
        '(.queue[] | select(.taskId == $tid and .status == "dispatched")) |= (.status = "done" | .completedAt = $ts | .verificationResult = "passed")' \
        "$QUEUE_FILE" > "${QUEUE_FILE}.tmp" && mv "${QUEUE_FILE}.tmp" "$QUEUE_FILE"
      
      # Update metrics
      jq '.metrics.totalProcessed += 1 | .metrics.lastProcessedAt = now' "$QUEUE_FILE" > "${QUEUE_FILE}.tmp" && mv "${QUEUE_FILE}.tmp" "$QUEUE_FILE"
      
      # Atom 2.4: Update rolling avg completion time
      local start_ts
      start_ts=$(echo "$VERIFY_JSON" | jq -r '.startedAt // empty')
      if [[ -n "$start_ts" ]]; then
        local start_epoch end_epoch duration
        start_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%S" "${start_epoch:0:19}" +%s 2>/dev/null || echo 0)
        end_epoch=$(date +%s)
        duration=$((end_epoch - start_epoch))
        jq --arg dur "$duration" '.metrics.avgCompletionMs = ((.metrics.avgCompletionMs * (.metrics.totalProcessed - 1) + ($dur | tonumber) * 1000) / .metrics.totalProcessed | floor)' \
          "$QUEUE_FILE" > "${QUEUE_FILE}.tmp" && mv "${QUEUE_FILE}.tmp" "$QUEUE_FILE"
      fi
    else
      V_NEW_RETRIES=$((V_RETRIES + 1))
      VERIFY_ERROR=$(cat /tmp/tqp-verify.log 2>/dev/null | head -3)
      echo "TQP: Verification FAILED for $V_TASK_ID (attempt $V_NEW_RETRIES/$V_MAX)"
      echo "TQP: Error: $VERIFY_ERROR"
      
      if [[ $V_NEW_RETRIES -ge $V_MAX ]]; then
        # Max retries exceeded — escalate
        echo "TQP: Max retries ($V_MAX) exceeded. Escalating to Ken."
        NOW=$(date -Iseconds)
        jq --arg tid "$V_TASK_ID" --arg ts "$NOW" \
          '(.queue[] | select(.taskId == $tid)) |= (.status = "failed" | .completedAt = $ts | .verificationResult = "failed_max_retries")' \
          "$QUEUE_FILE" > "${QUEUE_FILE}.tmp" && mv "${QUEUE_FILE}.tmp" "$QUEUE_FILE"
        
        # Create alert
        jq -n --arg tid "$V_TASK_ID" --arg tkt "$V_TICKET_ID" --arg err "$VERIFY_ERROR" --arg ts "$NOW" \
          '{alerts: [{taskId: $tid, ticketId: $tkt, error: $err, detectedAt: $ts, acknowledged: false}]}' \
          > "$ALERT_FILE"
        
        jq '.metrics.totalFailed += 1' "$QUEUE_FILE" > "${QUEUE_FILE}.tmp" && mv "${QUEUE_FILE}.tmp" "$QUEUE_FILE"
      else
        # Re-queue for retry
        jq --arg tid "$V_TASK_ID" \
          '(.queue[] | select(.taskId == $tid and .status == "dispatched")) |= (.status = "queued" | .retries += 1)' \
          "$QUEUE_FILE" > "${QUEUE_FILE}.tmp" && mv "${QUEUE_FILE}.tmp" "$QUEUE_FILE"
        echo "TQP: Re-queued $V_TASK_ID for retry $V_NEW_RETRIES/$V_MAX"
      fi
    fi
    rm -f /tmp/tqp-verify.log
  else
    echo "TQP: No queued or dispatched tasks. Exiting."
    exit 0
  fi
  rm -f "$LOCK_FILE"
  exit 0
fi

# Create lock
echo "$$ $(date -Iseconds)" > "$LOCK_FILE"

TASK_ID=$(echo "$TASK_JSON" | jq -r '.taskId')
TICKET_ID=$(echo "$TASK_JSON" | jq -r '.ticketId')
PROMPT_FILE=$(echo "$TASK_JSON" | jq -r '.promptFile')
EXPECTED_DELIVERABLE=$(echo "$TASK_JSON" | jq -r '.expectedDeliverable')
TASK_TYPE=$(echo "$TASK_JSON" | jq -r '.type')
MODEL=$(echo "$TASK_JSON" | jq -r '.assignedModel')
RETRIES=$(echo "$TASK_JSON" | jq -r '.retries')
MAX_RETRIES=$(echo "$TASK_JSON" | jq -r '.maxRetries')

echo "TQP: Processing $TASK_ID (ticket=$TICKET_ID, attempt=$((RETRIES + 1))/$MAX_RETRIES)"

# Mark as running
NOW=$(date -Iseconds)
jq --arg tid "$TASK_ID" --arg ts "$NOW" \
  '(.queue[] | select(.taskId == $tid and .status == "queued")) |= (.status = "running" | .startedAt = $ts)' \
  "$QUEUE_FILE" > "${QUEUE_FILE}.tmp" && mv "${QUEUE_FILE}.tmp" "$QUEUE_FILE"

# ──────────────────────────────────────────
# ATOM 2.2: Dispatch to sub-agent via sessions_spawn
# ──────────────────────────────────────────

# For cron execution, we use a direct sub-agent approach.
# The processor itself runs as a cron — it spawns the task as a sub-agent 
# and waits for completion.

# Build the task prompt
TASK_PROMPT="ATOMIC TASK: ${TASK_ID}
Ticket: ${TICKET_ID}
Type: ${TASK_TYPE}
Expected deliverable: ${EXPECTED_DELIVERABLE}

This is an ATOMIC task. Execute exactly one unit of work. 
Produce the deliverable at the expected path. 
Do NOT mark anything as done. The platform will verify.
Do NOT self-report completion — just produce the output file.

Task specification: $(cat "$PROMPT_FILE" 2>/dev/null | head -100 || echo "See $PROMPT_FILE for full spec")"

echo "TQP: Dispatching sub-agent for $TASK_ID..."
echo "TQP: Model: $MODEL"
echo "TQP: Expected deliverable: $EXPECTED_DELIVERABLE"

# ──────────────────────────────────────────
# NOTE: In cron context, sessions_spawn is not available.
# The TQP cron runs as an agentTurn, and the agentTurn's task 
# is to process the queue. The agent itself uses sessions_spawn.
# 
# For the shell script (called from cron), we mark the task 
# as 'dispatched' and let the cron agent handle the actual spawn.
# The next cron run picks up verification.
# ──────────────────────────────────────────

# Since we're in a shell script (not an agent session), we can't sessions_spawn.
# Instead, we write a dispatch marker and the cron agent picks it up.
# The verification happens on the NEXT cron run.

# Save dispatch info for the agent
DISPATCH_FILE="$WORKSPACE_ROOT/state/task-queue-dispatch.json"
jq -n --arg tid "$TASK_ID" --arg tkt "$TICKET_ID" --arg prompt "$TASK_PROMPT" \
    --arg model "$MODEL" --arg deliverable "$EXPECTED_DELIVERABLE" \
    --arg type "$TASK_TYPE" \
  '{taskId: $tid, ticketId: $tkt, prompt: $prompt, model: $model, expectedDeliverable: $deliverable, type: $type, dispatchedAt: now | todate}' \
  > "$DISPATCH_FILE"

# Mark as dispatched (waiting for agent to spawn)
jq --arg tid "$TASK_ID" --arg ts "$NOW" \
  '(.queue[] | select(.taskId == $tid and .status == "running")) |= (.status = "dispatched" | .startedAt = $ts)' \
  "$QUEUE_FILE" > "${QUEUE_FILE}.tmp" && mv "${QUEUE_FILE}.tmp" "$QUEUE_FILE"

echo "TQP: $TASK_ID dispatched. Verification will run on next cycle."

# Cleanup lock
rm -f "$LOCK_FILE"
exit 0
