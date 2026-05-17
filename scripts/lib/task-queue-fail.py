import json, datetime, sys

QUEUE_FILE = sys.argv[1]
TASK_ID = sys.argv[2]
ATOM_ID = sys.argv[3]
ERROR = sys.argv[4]

with open(QUEUE_FILE) as f:
    queue = json.load(f)

for t in queue.get('tasks', []):
    if t['id'] == TASK_ID:
        for a in t.get('atoms', []):
            if str(a['id']) == ATOM_ID:
                a['status'] = 'failed'
                a['error'] = ERROR
                a['failedAt'] = datetime.datetime.now().isoformat()
                a['retryCount'] = a.get('retryCount', 0) + 1
        
        t['updatedAt'] = datetime.datetime.now().isoformat()
        queue['lastUpdated'] = datetime.datetime.now().isoformat()
        
        with open(QUEUE_FILE, 'w') as f:
            json.dump(queue, f, indent=2)
        
        print(f"Atom {ATOM_ID} failed for {TASK_ID}: {ERROR}")
        break
