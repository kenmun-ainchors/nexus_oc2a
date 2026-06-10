import json, datetime, sys, os

# Import helpers
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from atomic_write import atomic_write_json
from pg_task_queue import pg_upsert_task, sc_add_task

QUEUE_FILE = sys.argv[1]
CHECKPOINT_DIR = sys.argv[2]
TASK_ID = sys.argv[3]
TITLE = sys.argv[4]
TIER = int(sys.argv[5])
ATOMS_STR = sys.argv[6]
PRIORITY = sys.argv[7]
SOURCE = sys.argv[8]
RELATED_CHG = sys.argv[9]
PARENT_TASK_ID = sys.argv[10] if len(sys.argv) > 10 else ""

# Parse atoms
atoms = []
for i, desc in enumerate(ATOMS_STR.split(';')):
    atoms.append({"id": i+1, "description": desc.strip(), "status": "pending"})

now = datetime.datetime.now().isoformat()

task = {
    "id": TASK_ID,
    "title": TITLE,
    "tier": TIER,
    "status": "pending",
    "priority": PRIORITY,
    "source": SOURCE,
    "relatedChg": RELATED_CHG,
    "atoms": atoms,
    "createdAt": now,
    "updatedAt": now
}

# Add parent_task_id if provided (TKT-0382)
if PARENT_TASK_ID:
    task["parentTaskId"] = PARENT_TASK_ID

# Step 1: State-checked PG write (TKT-0182: READ → VALIDATE → EXECUTE → VERIFY)
sc_ok, sc_msg = sc_add_task(TASK_ID, task)
if not sc_ok:
    print(f"ERROR: {sc_msg}", file=sys.stderr)
    sys.exit(1)
print(f"  SC: {sc_msg}")

# Step 2: Dual-write to JSON file
with open(QUEUE_FILE) as f:
    queue = json.load(f)

queue["queue"].append(task)
queue["lastUpdated"] = now

if not atomic_write_json(QUEUE_FILE, queue):
    print(f"ERROR: Failed to write queue file", file=sys.stderr)
    sys.exit(1)

# Step 3: Create checkpoint
cp = {
    "schema": "checkpoint-v1",
    "taskId": TASK_ID,
    "currentAtom": 1,
    "atoms": atoms,
    "lastUpdated": now
}

cp_path = f"{CHECKPOINT_DIR}/{TASK_ID}.json"
if not atomic_write_json(cp_path, cp):
    print(f"ERROR: Failed to write checkpoint file", file=sys.stderr)
    sys.exit(1)

print(f"Task added: {TASK_ID}")
