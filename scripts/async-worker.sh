#!/bin/bash
# async-worker.sh — Background worker that processes tasks from queue
# Usage: async-worker.sh [AGENT_ID]
# This runs in an infinite loop, claiming and executing tasks

AGENT_ID="${1:-agent:background}"
QUEUE_FILE="/Users/ainchorsangiefpl/.openclaw/workspace/state/task-queue.json"
CHECKPOINT_DIR="/Users/ainchorsangiefpl/.openclaw/workspace/state/checkpoints"
LOG_FILE="/Users/ainchorsangiefpl/.openclaw/workspace/state/async-worker.log"

echo "[$(date)] Async worker started: $AGENT_ID" >> "$LOG_FILE"

while true; do
  # Reset stale claims
  bash /Users/ainchorsangiefpl/.openclaw/workspace/scripts/task-queue.sh reset > /dev/null 2>&1
  
  # Claim next task
  CLAIM_RESULT=$(bash /Users/ainchorsangiefpl/.openclaw/workspace/scripts/claim-task.sh "$AGENT_ID" 2>&1)
  
  if echo "$CLAIM_RESULT" | grep -q "NO_TASK"; then
    echo "[$(date)] No pending tasks. Sleeping 300s..." >> "$LOG_FILE"
    sleep 300
    continue
  fi
  
  # Extract task info
  TASK_ID=$(echo "$CLAIM_RESULT" | grep "TASK_ID=" | cut -d= -f2)
  TASK_TITLE=$(echo "$CLAIM_RESULT" | grep "TITLE=" | cut -d= -f2)
  TASK_TIER=$(echo "$CLAIM_RESULT" | grep "TIER=" | cut -d= -f2)
  
  echo "[$(date)] Claimed task: $TASK_ID ($TASK_TITLE)" >> "$LOG_FILE"
  
  # Process each atom
  while true; do
    RESUME_RESULT=$(bash /Users/ainchorsangiefpl/.openclaw/workspace/scripts/resume-task.sh "$TASK_ID" "$AGENT_ID" 2>&1)
    
    if echo "$RESUME_RESULT" | grep -q "TASK_COMPLETE"; then
      echo "[$(date)] Task complete: $TASK_ID" >> "$LOG_FILE"
      break
    fi
    
    ATOM_ID=$(echo "$RESUME_RESULT" | grep "RESUME_ATOM=" | cut -d= -f2)
    ATOM_DESC=$(echo "$RESUME_RESULT" | grep "RESUME_DESC=" | cut -d= -f2)
    
    echo "[$(date)] Executing atom $ATOM_ID: $ATOM_DESC" >> "$LOG_FILE"
    
    # Execute the atom (this would be replaced with actual work)
    # For now, just mark as complete for demonstration
    bash /Users/ainchorsangiefpl/.openclaw/workspace/scripts/task-queue.sh complete "$TASK_ID" "$ATOM_ID"
    
    echo "[$(date)] Atom $ATOM_ID complete" >> "$LOG_FILE"
    
    # Small delay between atoms
    sleep 2
  done
  
  echo "[$(date)] Task $TASK_ID processed. Looking for next..." >> "$LOG_FILE"
done
