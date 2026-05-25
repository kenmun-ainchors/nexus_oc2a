#!/bin/bash
# task-queue.sh — Async Stateless Task Queue CLI
# Usage: task-queue.sh [add|list|claim|complete|fail|status|reset] [args]

QUEUE_FILE="/Users/ainchorsangiefpl/.openclaw/workspace/state/task-queue.json"
CHECKPOINT_DIR="/Users/ainchorsangiefpl/.openclaw/workspace/state/checkpoints"

cmd="$1"
shift

case "$cmd" in
  add)
    TITLE=""
    TIER="3"
    ATOMS=""
    PRIORITY="medium"
    SOURCE=""
    RELATED_CHG=""
    
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --title) TITLE="$2"; shift 2 ;;
        --tier) TIER="$2"; shift 2 ;;
        --atoms) ATOMS="$2"; shift 2 ;;
        --priority) PRIORITY="$2"; shift 2 ;;
        --source) SOURCE="$2"; shift 2 ;;
        --chg) RELATED_CHG="$2"; shift 2 ;;
        *) shift ;;
      esac
    done
    
    if [ -z "$TITLE" ] || [ -z "$ATOMS" ]; then
      echo "Usage: task-queue.sh add --title \"Title\" --atoms \"atom1;atom2\" [--tier 3]"
      exit 1
    fi
    
    TASK_ID="task-$(date +%Y-%m-%d)-$(python3 -c 'import uuid; print(uuid.uuid4().hex[:8])')"
    
    # Use Python script file to avoid heredoc variable issues
    python3 /Users/ainchorsangiefpl/.openclaw/workspace/scripts/lib/task-queue-add.py \
      "$QUEUE_FILE" "$CHECKPOINT_DIR" "$TASK_ID" "$TITLE" "$TIER" "$ATOMS" "$PRIORITY" "$SOURCE" "$RELATED_CHG"
    
    echo "✅ Task added: $TASK_ID"
    ;;
    
  list)
    python3 /Users/ainchorsangiefpl/.openclaw/workspace/scripts/lib/task-queue-list.py "$QUEUE_FILE"
    ;;
    
  status)
    TASK_ID="$1"
    python3 /Users/ainchorsangiefpl/.openclaw/workspace/scripts/lib/task-queue-status.py "$QUEUE_FILE" "$TASK_ID"
    ;;
    
  claim)
    AGENT_ID="${1:-agent:manual}"
    python3 /Users/ainchorsangiefpl/.openclaw/workspace/scripts/lib/task-queue-claim.py "$QUEUE_FILE" "$AGENT_ID"
    ;;
    
  complete)
    TASK_ID="$1"
    ATOM_ID="$2"
    RESULT="${3:-{}}"
    python3 /Users/ainchorsangiefpl/.openclaw/workspace/scripts/lib/task-queue-complete.py \
      "$QUEUE_FILE" "$CHECKPOINT_DIR" "$TASK_ID" "$ATOM_ID" "$RESULT"
    ;;
    
  fail)
    TASK_ID="$1"
    ATOM_ID="$2"
    ERROR="${3:-Unknown error}"
    python3 /Users/ainchorsangiefpl/.openclaw/workspace/scripts/lib/task-queue-fail.py \
      "$QUEUE_FILE" "$TASK_ID" "$ATOM_ID" "$ERROR"
    ;;
    
  reset)
    python3 /Users/ainchorsangiefpl/.openclaw/workspace/scripts/lib/task-queue-reset.py "$QUEUE_FILE"
    ;;
    
  *)
    echo "Usage: task-queue.sh [add|list|claim|complete|fail|status|reset]"
    exit 1
    ;;
esac
