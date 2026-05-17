import json, datetime, sys

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
        
        with open(QUEUE_FILE, 'w') as f:
            json.dump(queue, f, indent=2)
        
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
            with open(f"{CHECKPOINT_DIR}/{TASK_ID}.json", 'w') as f:
                json.dump(cp, f, indent=2)
        except:
            pass
        
        print(f"Atom {ATOM_ID} complete for {TASK_ID}")
        break
