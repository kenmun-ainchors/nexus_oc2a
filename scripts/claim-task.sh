#!/bin/bash
# claim-task.sh — Claim next pending task from queue
# Usage: claim-task.sh [AGENT_ID]

AGENT_ID="${1:-agent:manual}"
QUEUE_FILE="/Users/ainchorsoc2a/.openclaw/workspace/state/task-queue.json"

# First reset stale claims
bash /Users/ainchorsoc2a/.openclaw/workspace/scripts/task-queue.sh reset > /dev/null 2>&1

# Claim next pending task
python3 -c "
import json, datetime, sys

with open('$QUEUE_FILE') as f:
    queue = json.load(f)

# Find first pending task
for t in queue.get('queue', []):
    if t['status'] == 'pending':
        t['status'] = 'claimed'
        t['claimedBy'] = '$AGENT_ID'
        t['claimedAt'] = datetime.datetime.now().isoformat()
        t['claimTimeout'] = (datetime.datetime.now() + datetime.timedelta(minutes=30)).isoformat()
        t['updatedAt'] = datetime.datetime.now().isoformat()
        
        queue['lastUpdated'] = datetime.datetime.now().isoformat()
        with open('$QUEUE_FILE', 'w') as f:
            json.dump(queue, f, indent=2)
        
        # Output task details for the agent
        print(f\"TASK_ID={t['id']}\")
        print(f\"TITLE={t['title']}\")
        print(f\"TIER={t['tier']}\")
        print(f\"ATOMS={len(t.get('atoms', []))}\")
        sys.exit(0)

print('NO_TASK')
sys.exit(1)
"
