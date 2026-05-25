#!/bin/bash
# resume-task.sh — Resume a task from checkpoint
# Usage: resume-task.sh TASK_ID [AGENT_ID]

TASK_ID="$1"
AGENT_ID="${2:-agent:manual}"
CHECKPOINT_DIR="/Users/ainchorsangiefpl/.openclaw/workspace/state/checkpoints"
QUEUE_FILE="/Users/ainchorsangiefpl/.openclaw/workspace/state/task-queue.json"

if [ -z "$TASK_ID" ]; then
  echo "Usage: resume-task.sh TASK_ID [AGENT_ID]"
  exit 1
fi

CHECKPOINT_FILE="$CHECKPOINT_DIR/$TASK_ID.json"

if [ ! -f "$CHECKPOINT_FILE" ]; then
  echo "ERROR: No checkpoint found for $TASK_ID"
  exit 1
fi

python3 -c "
import json, datetime

with open('$CHECKPOINT_FILE') as f:
    cp = json.load(f)

# Find first pending or failed atom
resume_atom = None
for atom in cp.get('atoms', []):
    if atom['status'] in ['pending', 'failed']:
        resume_atom = atom
        break

if resume_atom:
    print(f\"RESUME_TASK={cp['taskId']}\")
    print(f\"RESUME_ATOM={resume_atom['id']}\")
    print(f\"RESUME_DESC={resume_atom['description']}\")
    print(f\"RETRY_COUNT={resume_atom.get('retryCount', 0)}\")
    
    # Update queue to mark task claimed
    try:
        with open('$QUEUE_FILE') as f:
            queue = json.load(f)
        for t in queue.get('queue', []):
            if t['id'] == '$TASK_ID':
                t['status'] = 'claimed'
                t['claimedBy'] = '$AGENT_ID'
                t['claimedAt'] = datetime.datetime.now().isoformat()
                t['claimTimeout'] = (datetime.datetime.now() + datetime.timedelta(minutes=30)).isoformat()
                t['updatedAt'] = datetime.datetime.now().isoformat()
        queue['lastUpdated'] = datetime.datetime.now().isoformat()
        with open('$QUEUE_FILE', 'w') as f:
            json.dump(queue, f, indent=2)
    except:
        pass
else:
    print(f\"TASK_COMPLETE={cp['taskId']}\")
    
    # Mark task complete in queue
    try:
        with open('$QUEUE_FILE') as f:
            queue = json.load(f)
        for t in queue.get('queue', []):
            if t['id'] == '$TASK_ID':
                t['status'] = 'complete'
                t['updatedAt'] = datetime.datetime.now().isoformat()
        queue['lastUpdated'] = datetime.datetime.now().isoformat()
        with open('$QUEUE_FILE', 'w') as f:
            json.dump(queue, f, indent=2)
    except:
        pass
"
