import json, datetime, sys, os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from atomic_write import atomic_write_json
from pg_task_queue import sc_fail_atom

QUEUE_FILE = sys.argv[1]
TASK_ID = sys.argv[2]
ATOM_ID = sys.argv[3]
ERROR = sys.argv[4]

# Step 1: State-checked atom fail (TKT-0182: READ → VALIDATE → EXECUTE → VERIFY)
sc_ok, sc_msg = sc_fail_atom(TASK_ID, ATOM_ID, ERROR)
if not sc_ok:
    print(f"ERROR: {sc_msg}", file=sys.stderr)
    sys.exit(1)

# Step 2: Dual-write to JSON queue file
now = datetime.datetime.now().isoformat()
with open(QUEUE_FILE) as f:
    queue = json.load(f)

for t in queue.get('queue', []):
    if t['id'] == TASK_ID:
        for a in t.get('atoms', []):
            if str(a['id']) == ATOM_ID:
                a['status'] = 'failed'
                a['error'] = ERROR
                a['failedAt'] = now
                a['retryCount'] = a.get('retryCount', 0) + 1
        
        t['updatedAt'] = now
        queue['lastUpdated'] = now
        
        if not atomic_write_json(QUEUE_FILE, queue):
            print(f"ERROR: Failed to write queue file", file=sys.stderr)
            sys.exit(1)
        break

# Step 3: Update checkpoint file
WORKSPACE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CHECKPOINT_DIR = os.path.join(WORKSPACE, 'state', 'checkpoints')
cp_path = os.path.join(CHECKPOINT_DIR, f"{TASK_ID}.json")
try:
    if os.path.exists(cp_path):
        with open(cp_path) as f:
            cp = json.load(f)
        
        for a in cp.get('atoms', []):
            if str(a.get('id')) == ATOM_ID:
                a['status'] = 'failed'
                a['error'] = ERROR
                a['failedAt'] = now
                a['retryCount'] = a.get('retryCount', 0) + 1
        
        cp['lastUpdated'] = now
        
        if not atomic_write_json(cp_path, cp):
            print(f"WARNING: Failed to write checkpoint file {cp_path}", file=sys.stderr)
        else:
            print(f"  Checkpoint: {TASK_ID} atom {ATOM_ID} → failed")
    else:
        print(f"WARNING: No checkpoint file found at {cp_path}", file=sys.stderr)
except Exception as e:
    print(f"WARNING: Checkpoint update failed: {e}", file=sys.stderr)

print(f"Atom {ATOM_ID} failed for {TASK_ID}: {ERROR}")
print(f"  SC: {sc_msg}")
