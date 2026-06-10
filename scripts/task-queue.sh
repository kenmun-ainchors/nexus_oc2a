#!/bin/bash
# task-queue.sh — Async Stateless Task Queue CLI
# Usage: task-queue.sh [add|list|claim|complete|fail|status|reset|crest-phase|escalate|replan-iterate|sub-crest-complete]
# TKT-0382: Extended with sub-CREST phase state machine commands

QUEUE_FILE="/Users/ainchorsangiefpl/.openclaw/workspace/state/task-queue.json"
CHECKPOINT_DIR="/Users/ainchorsangiefpl/.openclaw/workspace/state/checkpoints"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

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
    PARENT_TASK_ID=""
    
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --title) TITLE="$2"; shift 2 ;;
        --tier) TIER="$2"; shift 2 ;;
        --atoms) ATOMS="$2"; shift 2 ;;
        --priority) PRIORITY="$2"; shift 2 ;;
        --source) SOURCE="$2"; shift 2 ;;
        --chg) RELATED_CHG="$2"; shift 2 ;;
        --parent-task-id) PARENT_TASK_ID="$2"; shift 2 ;;
        *) shift ;;
      esac
    done
    
    if [ -z "$TITLE" ] || [ -z "$ATOMS" ]; then
      echo "Usage: task-queue.sh add --title \"Title\" --atoms \"atom1;atom2\" [--tier 3] [--parent-task-id TKT-XXXX]"
      exit 1
    fi
    
    TASK_ID="task-$(date +%Y-%m-%d)-$(python3 -c 'import uuid; print(uuid.uuid4().hex[:8])')"
    
    # Use Python script file to avoid heredoc variable issues
    python3 /Users/ainchorsangiefpl/.openclaw/workspace/scripts/lib/task-queue-add.py \
      "$QUEUE_FILE" "$CHECKPOINT_DIR" "$TASK_ID" "$TITLE" "$TIER" "$ATOMS" "$PRIORITY" "$SOURCE" "$RELATED_CHG" "$PARENT_TASK_ID"
    
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
    
  crest-phase)
    # TKT-0382: Persist a sub-CREST phase transition
    TASK_ID="$1"
    PHASE="$2"
    PAYLOAD="${3:-}"
    ITERATION="${4:-}"
    
    if [ -z "$TASK_ID" ] || [ -z "$PHASE" ]; then
      echo "Usage: task-queue.sh crest-phase <task-id> <phase> [payload_json] [iteration_count]"
      echo "Phases: sub_crest_planning, sub_crest_executing, sub_crest_verifying,"
      echo "        sub_crest_replanning, sub_crest_synthesizing, sub_crest_done, escalated"
      exit 1
    fi
    
    python3 -c "
import sys, json
sys.path.insert(0, '$SCRIPT_DIR/lib')
from pg_task_queue import sc_persist_sub_crest_phase

payload = json.loads('''$PAYLOAD''') if '''$PAYLOAD''' else None
iter_count = int('''$ITERATION''') if '''$ITERATION''' else None
ok, msg = sc_persist_sub_crest_phase('''$TASK_ID''', '''$PHASE''', payload, iter_count)
print(json.dumps({'ok': ok, 'msg': msg}))
"
    ;;
    
  escalate)
    # TKT-0382: Escalate a sub-CREST task — sets sub to escalated, parent to master_replanning
    SUB_TASK_ID="$1"
    REASON="${2:-No reason provided}"
    
    if [ -z "$SUB_TASK_ID" ]; then
      echo "Usage: task-queue.sh escalate <sub-task-id> [reason]"
      exit 1
    fi
    
    python3 -c "
import sys, json
sys.path.insert(0, '$SCRIPT_DIR/lib')
from pg_task_queue import sc_escalate_task

ok, msg = sc_escalate_task('''$SUB_TASK_ID''', '''$REASON''')
print(json.dumps({'ok': ok, 'msg': msg}))
"
    ;;
    
  replan-iterate)
    # TKT-0382: Replan iteration — increment iteration_count, back to sub_crest_executing
    TASK_ID="$1"
    
    if [ -z "$TASK_ID" ]; then
      echo "Usage: task-queue.sh replan-iterate <task-id>"
      exit 1
    fi
    
    python3 -c "
import sys, json
sys.path.insert(0, '$SCRIPT_DIR/lib')
from pg_task_queue import sc_replan_iterate

ok, msg = sc_replan_iterate('''$TASK_ID''')
print(json.dumps({'ok': ok, 'msg': msg}))
"
    ;;
    
  sub-crest-complete)
    # TKT-0382: Mark a sub-CREST task as complete (sub_crest_done)
    TASK_ID="$1"
    RESULT="${2:-}"
    
    if [ -z "$TASK_ID" ]; then
      echo "Usage: task-queue.sh sub-crest-complete <task-id> [result_json]"
      exit 1
    fi
    
    python3 -c "
import sys, json
sys.path.insert(0, '$SCRIPT_DIR/lib')
from pg_task_queue import sc_sub_crest_complete

result = json.loads('''$RESULT''') if '''$RESULT''' else None
ok, msg = sc_sub_crest_complete('''$TASK_ID''', result)
print(json.dumps({'ok': ok, 'msg': msg}))
"
    ;;
    
  *)
    echo "Usage: task-queue.sh [add|list|claim|complete|fail|status|reset|crest-phase|escalate|replan-iterate|sub-crest-complete]"
    exit 1
    ;;
esac
