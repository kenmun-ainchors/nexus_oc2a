#!/bin/bash
# task-queue.sh — Async Stateless Task Queue CLI
# Usage: task-queue.sh [add|list|claim|complete|fail|status|reset] [args]

QUEUE_FILE="/Users/ainchorsangiefpl/.openclaw/workspace/state/task-queue.json"
CHECKPOINT_DIR="/Users/ainchorsangiefpl/.openclaw/workspace/state/checkpoints"

# Ensure queue file exists
if [ ! -f "$QUEUE_FILE" ]; then
  echo '{"schema":"task-queue-v1","tasks":[]}' > "$QUEUE_FILE"
fi

cmd="$1"
shift

case "$cmd" in
  add)
    # Add a new task to the queue
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
      echo "Usage: task-queue.sh add --title \"Title\" --atoms \"atom1;atom2\" [--tier 3] [--priority medium]"
      exit 1
    fi
    
    TASK_ID="task-$(date +%Y-%m-%d)-$(python3 -c 'import uuid; print(uuid.uuid4().hex[:8])')"
    
    # Build atoms array in Python
    ATOM_JSON=$(python3 -c "
atoms = '$ATOMS'.split(';')
result = []
for i, desc in enumerate(atoms):
    result.append({'id': i+1, 'description': desc.strip(), 'status': 'pending'})
import json
print(json.dumps(result))
")
    
    # Create task in queue
    python3 << 'PYEOF'
import json, datetime

with open("$QUEUE_FILE") as f:
    queue = json.load(f)

task = {
    "id": "$TASK_ID",
    "title": "$TITLE",
    "tier": $TIER,
    "status": "pending",
    "priority": "$PRIORITY",
    "source": "$SOURCE",
    "relatedChg": "$RELATED_CHG",
    "atoms": $ATOM_JSON,
    "createdAt": datetime.datetime.now().isoformat(),
    "updatedAt": datetime.datetime.now().isoformat()
}

queue["tasks"].append(task)
queue["lastUpdated"] = datetime.datetime.now().isoformat()

with open("$QUEUE_FILE", "w") as f:
    json.dump(queue, f, indent=2)

# Create checkpoint file
cp = {
    "schema": "checkpoint-v1",
    "taskId": task["id"],
    "currentAtom": 1,
    "atoms": task["atoms"],
    "lastUpdated": task["updatedAt"]
}

with open("$CHECKPOINT_DIR/$TASK_ID.json", "w") as f:
    json.dump(cp, f, indent=2)

print(f"Task added: {task['id']}")
PYEOF
    
    echo "✅ Checkpoint created"
    ;;
    
  list)
    python3 -c "
import json
with open('$QUEUE_FILE') as f:
    queue = json.load(f)

tasks = queue.get('tasks', [])
print(f'Total tasks: {len(tasks)}')
for t in tasks:
    pending = sum(1 for a in t.get('atoms',[]) if a['status']=='pending')
    complete = sum(1 for a in t.get('atoms',[]) if a['status']=='complete')
    failed = sum(1 for a in t.get('atoms',[]) if a['status']=='failed')
    total = len(t.get('atoms', []))
    print(f\"  [{t['id']}] {t['status']:12} | {complete}/{total} complete | {pending} pending | {failed} failed | {t['title'][:40]}...\")
"
    ;;
    
  status)
    TASK_ID="$1"
    if [ -z "$TASK_ID" ]; then
      echo "Usage: task-queue.sh status TASK_ID"
      exit 1
    fi
    
    python3 -c "
import json
with open('$QUEUE_FILE') as f:
    queue = json.load(f)

for t in queue.get('tasks', []):
    if t['id'] == '$TASK_ID':
        print(f\"Task: {t['id']}\")
        print(f\"Title: {t['title']}\")
        print(f\"Status: {t['status']}\")
        print(f\"Atoms: {len(t.get('atoms', []))}\")
        for a in t.get('atoms', []):
            print(f\"  Atom {a['id']}: {a['status']:12} | {a['description'][:50]}\")
        break
else:
    print(f'Task $TASK_ID not found')
"
    ;;
    
  claim)
    AGENT_ID="${1:-agent:manual}"
    
    python3 -c "
import json, datetime
with open('$QUEUE_FILE') as f:
    queue = json.load(f)

for t in queue.get('tasks', []):
    if t['status'] == 'pending':
        t['status'] = 'claimed'
        t['claimedBy'] = '$AGENT_ID'
        t['claimedAt'] = datetime.datetime.now().isoformat()
        t['claimTimeout'] = (datetime.datetime.now() + datetime.timedelta(minutes=30)).isoformat()
        t['updatedAt'] = datetime.datetime.now().isoformat()
        
        queue['lastUpdated'] = datetime.datetime.now().isoformat()
        with open('$QUEUE_FILE', 'w') as f:
            json.dump(queue, f, indent=2)
        
        print(f\"Claimed: {t['id']} | {t['title'][:40]}... | Atoms: {len(t.get('atoms', []))}\")
        break
else:
    print('No pending tasks')
"
    ;;
    
  complete)
    TASK_ID="$1"
    ATOM_ID="$2"
    RESULT="${3:-{}}"
    
    if [ -z "$TASK_ID" ] || [ -z "$ATOM_ID" ]; then
      echo "Usage: task-queue.sh complete TASK_ID ATOM_ID [RESULT_JSON]"
      exit 1
    fi
    
    python3 -c "
import json, datetime
with open('$QUEUE_FILE') as f:
    queue = json.load(f)

for t in queue.get('tasks', []):
    if t['id'] == '$TASK_ID':
        for a in t.get('atoms', []):
            if str(a['id']) == '$ATOM_ID':
                a['status'] = 'complete'
                a['completedAt'] = datetime.datetime.now().isoformat()
                try:
                    a['result'] = json.loads('$RESULT')
                except:
                    a['result'] = '$RESULT'
        
        all_complete = all(a['status'] == 'complete' for a in t.get('atoms', []))
        if all_complete:
            t['status'] = 'complete'
        
        t['updatedAt'] = datetime.datetime.now().isoformat()
        queue['lastUpdated'] = datetime.datetime.now().isoformat()
        
        with open('$QUEUE_FILE', 'w') as f:
            json.dump(queue, f, indent=2)
        
        # Update checkpoint
        try:
            with open('$CHECKPOINT_DIR/$TASK_ID.json') as f:
                cp = json.load(f)
            for a in cp.get('atoms', []):
                if str(a['id']) == '$ATOM_ID':
                    a['status'] = 'complete'
                    a['completedAt'] = datetime.datetime.now().isoformat()
                    try:
                        a['result'] = json.loads('$RESULT')
                    except:
                        a['result'] = '$RESULT'
            cp['lastUpdated'] = datetime.datetime.now().isoformat()
            with open('$CHECKPOINT_DIR/$TASK_ID.json', 'w') as f:
                json.dump(cp, f, indent=2)
        except:
            pass
        
        print(f\"Atom $ATOM_ID complete for $TASK_ID\")
        break
"
    ;;
    
  fail)
    TASK_ID="$1"
    ATOM_ID="$2"
    ERROR="${3:-\"Unknown error\"}"
    
    python3 -c "
import json, datetime
with open('$QUEUE_FILE') as f:
    queue = json.load(f)

for t in queue.get('tasks', []):
    if t['id'] == '$TASK_ID':
        for a in t.get('atoms', []):
            if str(a['id']) == '$ATOM_ID':
                a['status'] = 'failed'
                a['error'] = '$ERROR'
                a['failedAt'] = datetime.datetime.now().isoformat()
                a['retryCount'] = a.get('retryCount', 0) + 1
        
        t['updatedAt'] = datetime.datetime.now().isoformat()
        queue['lastUpdated'] = datetime.datetime.now().isoformat()
        
        with open('$QUEUE_FILE', 'w') as f:
            json.dump(queue, f, indent=2)
        
        print(f\"Atom $ATOM_ID failed for $TASK_ID: $ERROR\")
        break
"
    ;;
    
  reset)
    python3 -c "
import json, datetime
with open('$QUEUE_FILE') as f:
    queue = json.load(f)

now = datetime.datetime.now().isoformat()
reset_count = 0

for t in queue.get('tasks', []):
    if t['status'] == 'claimed':
        timeout = t.get('claimTimeout', '1970-01-01')
        if timeout < now:
            t['status'] = 'pending'
            t.pop('claimedBy', None)
            t.pop('claimedAt', None)
            t.pop('claimTimeout', None)
            reset_count += 1

queue['lastUpdated'] = datetime.datetime.now().isoformat()
with open('$QUEUE_FILE', 'w') as f:
    json.dump(queue, f, indent=2)

print(f'Reset {reset_count} stale claims')
"
    ;;
    
  *)
    echo "Usage: task-queue.sh [add|list|claim|complete|fail|status|reset]"
    echo ""
    echo "  add      --title \"Title\" --atoms \"atom1;atom2\" [--tier 3] [--priority medium]"
    echo "  list     Show all tasks with summary"
    echo "  claim    [AGENT_ID] Claim next pending task"
    echo "  complete TASK_ID ATOM_ID [RESULT] Mark atom complete"
    echo "  fail     TASK_ID ATOM_ID [ERROR] Mark atom failed"
    echo "  status   TASK_ID Show detailed task status"
    echo "  reset    Reset stale claims (claimTimeout expired)"
    exit 1
    ;;
esac
