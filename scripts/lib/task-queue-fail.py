import json, datetime, sys, os

# Import atomic write helper
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from atomic_write import atomic_write_json

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
        
        # Atomic write queue file
        if not atomic_write_json(QUEUE_FILE, queue):
            print(f"ERROR: Failed to write queue file", file=sys.stderr)
            sys.exit(1)
        
        print(f"Atom {ATOM_ID} failed for {TASK_ID}: {ERROR}")
        break
