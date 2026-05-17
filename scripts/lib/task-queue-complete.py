import json, datetime, sys, os

# Import atomic write helper
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from atomic_write import atomic_write_json

QUEUE_FILE = sys.argv[1]
CHECKPOINT_DIR = sys.argv[2]
TASK_ID = sys.argv[3]
ATOM_ID = sys.argv[4]
RESULT = sys.argv[5]

with open(QUEUE_FILE) as f:
    queue = json.load(f)

for t in queue.get('tasks', []):
    if t['id'] == TASK_ID:
        for a in t.get('atoms', []):
            if str(a['id']) == ATOM_ID:
                a['status'] = 'complete'
                a['completedAt'] = datetime.datetime.now().isoformat()
                try:
                    a['result'] = json.loads(RESULT)
                except:
                    a['result'] = RESULT
        
        all_complete = all(a['status'] == 'complete' for a in t.get('atoms', []))
        if all_complete:
            t['status'] = 'complete'
        
        t['updatedAt'] = datetime.datetime.now().isoformat()
        queue['lastUpdated'] = datetime.datetime.now().isoformat()
        
        # Atomic write queue file
        if not atomic_write_json(QUEUE_FILE, queue):
            print(f"ERROR: Failed to write queue file", file=sys.stderr)
            sys.exit(1)
        
        # Update checkpoint
        try:
            with open(f"{CHECKPOINT_DIR}/{TASK_ID}.json") as f:
                cp = json.load(f)
            for a in cp.get('atoms', []):
                if str(a['id']) == ATOM_ID:
                    a['status'] = 'complete'
                    a['completedAt'] = datetime.datetime.now().isoformat()
                    try:
                        a['result'] = json.loads(RESULT)
                    except:
                        a['result'] = RESULT
            cp['lastUpdated'] = datetime.datetime.now().isoformat()
            
            # Atomic write checkpoint file
            cp_path = f"{CHECKPOINT_DIR}/{TASK_ID}.json"
            if not atomic_write_json(cp_path, cp):
                print(f"ERROR: Failed to write checkpoint file", file=sys.stderr)
                sys.exit(1)
        except:
            pass
        
        print(f"Atom {ATOM_ID} complete for {TASK_ID}")
        break
