#!/bin/bash
# task-queue.sh — Async Stateless Task Queue CLI
# Usage: task-queue.sh [add|list|claim|complete|status|reset] [args]

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
    # Usage: task-queue.sh add --title "Title" --tier 3 --atoms "atom1;atom2;atom3"
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
      echo "Usage: task-queue.sh add --title \"Title\" --atoms \"atom1;atom2\" [--tier 3] [--priority medium] [--source ken] [--chg CHG-XXXX]"
      exit 1
    fi
    
    TASK_ID="task-$(date +%Y-%m-%d)-$(python3 -c 'import uuid; print(uuid.uuid4().hex[:8])')"
    
    # Build atoms array
    IFS=';' read -ra ATOM_LIST <<< "$ATOMS"
    ATOM_JSON=""
    for i in "${!ATOM_LIST[@]}"; do
      ATOM_JSON="${ATOM_JSON}{\"id\":$((i+1)),\"description\":\"${ATOM_LIST[$i]}\",\"status\":\"pending\"},"
    done
    ATOM_JSON="[${ATOM_JSON%,}]"
    
    TASK_JSON=$(python3 -c "
    TASK_JSON=$(python3 -c "
import json, datetime
import json, datetime


task = {
task = {
  'id': '$TASK_ID',
  'id': '$TASK_ID',
  'title': '$TITLE',
  'title': '$TITLE',
  'tier': $TIER,
  'tier': $TIER,
  'status': 'pending',
  'status': 'pending',
  'priority': '$PRIORITY',
  'priority': '$PRIORITY',
  'source': '$SOURCE',
  'source': '$SOURCE',
  'relatedChg': '$RELATED_CHG',
  'relatedChg': '$RELATED_CHG',
  'atoms': $ATOM_JSON,
  'atoms': $ATOM_JSON,
  'createdAt': datetime.datetime.now().isoformat(),
  'createdAt': datetime.datetime.now().isoformat(),
  'updatedAt': datetime.datetime.now().isoformat()
  'updatedAt': datetime.datetime.now().isoformat()
}
}


with open('$QUEUE_FILE') as f:
with open('$QUEUE_FILE') as f:
    queue = json.load(f)
    queue = json.load(f)


queue['tasks'].append(task)
queue['tasks'].append(task)
queue['lastUpdated'] = datetime.datetime.now().isoformat()
queue['lastUpdated'] = datetime.datetime.now().isoformat()


with open('$QUEUE_FILE', 'w') as f:
with open('$QUEUE_FILE', 'w') as f:
    json.dump(queue, f, indent=2)
    json.dump(queue, f, indent=2)


print('$TASK_ID')
print('$TASK_ID')
")
")
    
    
    # Create checkpoint file
    # Create checkpoint file
    echo "$TASK_JSON" | python3 -c "
    echo "$TASK_JSON" | python3 -c "
import json, sys
import json, sys


task = json.load(sys.stdin)
task = json.load(sys.stdin)
cp = {
cp = {
  'schema': 'checkpoint-v1',
  'schema': 'checkpoint-v1',
  'taskId': task['id'],
  'taskId': task['id'],
  'currentAtom': 1,
  'currentAtom': 1,
  'atoms': task['atoms'],
  'atoms': task['atoms'],
  'lastUpdated': task['updatedAt']
  'lastUpdated': task['updatedAt']
}
}


with open('$CHECKPOINT_DIR/${task[\"id\"]}.json', 'w') as f:
with open('$CHECKPOINT_DIR/${task[\"id\"]}.json', 'w') as f:
    json.dump(cp, f, indent=2)
    json.dump(cp, f, indent=2)
"
"
    
    
    echo "✅ Task added: $TASK_JSON"
    echo "✅ Task added: $TASK_JSON"
    ;;
    
  list)
    # List all tasks
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
    # Show detailed status of a task
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
        print(f\"Tier: {t['tier']}\")
        print(f\"Priority: {t['priority']}\")
        print(f\"Created: {t['createdAt']}\")
        print(f\"Atoms: {len(t.get('atoms', []))}\")
        for a in t.get('atoms', []):
            print(f\"  Atom {a['id']}: {a['status']:12} | {a['description'][:50]}\")
        break
else:
    print(f'Task $TASK_ID not found')
"
    ;;
    
  claim)
    # Claim next pending task
    AGENT_ID="${1:-agent:manual}"
    
    python3 -c "
import json, datetime
with open('$QUEUE_FILE') as f:
    queue = json.load(f)

# Find first pending task
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
    # Mark atom as complete
    TASK_ID="$1"
    ATOM_ID="$2"
    RESULT="${3:-\"\"}"
    
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
                if '$RESULT':
                    try:
                        a['result'] = json.loads('$RESULT')
                    except:
                        a['result'] = '$RESULT'
        
        # Check if all atoms complete
        all_complete = all(a['status'] == 'complete' for a in t.get('atoms', []))
        if all_complete:
            t['status'] = 'complete'
        
        t['updatedAt'] = datetime.datetime.now().isoformat()
        queue['lastUpdated'] = datetime.datetime.now().isoformat()
        
        with open('$QUEUE_FILE', 'w') as f:
            json.dump(queue, f, indent=2)
        
        # Update checkpoint
        cp_file = '$CHECKPOINT_DIR/$TASK_ID.json'
        try:
            with open(cp_file) as f:
                cp = json.load(f)
            for a in cp.get('atoms', []):
                if str(a['id']) == '$ATOM_ID':
                    a['status'] = 'complete'
                    a['completedAt'] = datetime.datetime.now().isoformat()
                    if '$RESULT':
                        try:
                            a['result'] = json.loads('$RESULT')
                        except:
                            a['result'] = '$RESULT'
            cp['lastUpdated'] = datetime.datetime.now().isoformat()
            with open(cp_file, 'w') as f:
                json.dump(cp, f, indent=2)
        except FileNotFoundError:
            pass
        
        print(f\"Atom $ATOM_ID complete for $TASK_ID\")
        break
"
    ;;
    
  fail)
    # Mark atom as failed
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
    # Reset stale claims (claimTimeout expired)
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
