import json, datetime, sys, os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from atomic_write import atomic_write_json
from pg_task_queue import sc_complete_atom

QUEUE_FILE = sys.argv[1]
CHECKPOINT_DIR = sys.argv[2]
TASK_ID = sys.argv[3]
ATOM_ID = sys.argv[4]
RESULT = sys.argv[5]

try:
    result_data = json.loads(RESULT)
except (json.JSONDecodeError, TypeError):
    result_data = RESULT

# Step 1: State-checked atom complete (TKT-0182: READ → VALIDATE → EXECUTE → VERIFY)
sc_ok, sc_msg = sc_complete_atom(TASK_ID, ATOM_ID, result_data=result_data)
if not sc_ok:
    print(f"ERROR: {sc_msg}", file=sys.stderr)
    sys.exit(1)

# Step 2: Dual-write to JSON queue file
with open(QUEUE_FILE) as f:
    queue = json.load(f)

for t in queue.get('queue', []):
    if t['id'] == TASK_ID:
        for a in t.get('atoms', []):
            if str(a['id']) == ATOM_ID:
                a['status'] = 'complete'
                a['completedAt'] = datetime.datetime.now().isoformat()
                a['result'] = result_data
        
        all_complete = all(a['status'] == 'complete' for a in t.get('atoms', []))
        if all_complete:
            t['status'] = 'complete'
        
        t['updatedAt'] = datetime.datetime.now().isoformat()
        queue['lastUpdated'] = datetime.datetime.now().isoformat()
        
        if not atomic_write_json(QUEUE_FILE, queue):
            print(f"ERROR: Failed to write queue file", file=sys.stderr)
            sys.exit(1)
        break

# Step 3: Update checkpoint file (synchronous — must succeed)
cp_path = os.path.join(CHECKPOINT_DIR, f"{TASK_ID}.json")
try:
    if os.path.exists(cp_path):
        with open(cp_path) as f:
            cp = json.load(f)
        
        for a in cp.get('atoms', []):
            if str(a.get('id')) == ATOM_ID:
                a['status'] = 'complete'
                a['completedAt'] = datetime.datetime.now().isoformat()
                a['result'] = result_data
        
        # Check if all atoms complete
        all_done = all(a.get('status') == 'complete' for a in cp.get('atoms', []))
        if all_done:
            cp['status'] = 'complete'
        
        cp['lastUpdated'] = datetime.datetime.now().isoformat()
        
        if not atomic_write_json(cp_path, cp):
            print(f"WARNING: Failed to write checkpoint file {cp_path}", file=sys.stderr)
        else:
            print(f"  Checkpoint: {TASK_ID} atom {ATOM_ID} → complete")
    else:
        print(f"WARNING: No checkpoint file found at {cp_path}", file=sys.stderr)
except Exception as e:
    print(f"WARNING: Checkpoint update failed: {e}", file=sys.stderr)

print(f"Atom {ATOM_ID} complete for {TASK_ID}")
print(f"  SC: {sc_msg}")
