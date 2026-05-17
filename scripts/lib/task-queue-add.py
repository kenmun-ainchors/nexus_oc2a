import json, datetime, sys

QUEUE_FILE = sys.argv[1]
CHECKPOINT_DIR = sys.argv[2]
TASK_ID = sys.argv[3]
TITLE = sys.argv[4]
TIER = int(sys.argv[5])
ATOMS_STR = sys.argv[6]
PRIORITY = sys.argv[7]
SOURCE = sys.argv[8]
RELATED_CHG = sys.argv[9]

# Parse atoms
atoms = []
for i, desc in enumerate(ATOMS_STR.split(';')):
    atoms.append({"id": i+1, "description": desc.strip(), "status": "pending"})

# Read queue
with open(QUEUE_FILE) as f:
    queue = json.load(f)

# Create task
task = {
    "id": TASK_ID,
    "title": TITLE,
    "tier": TIER,
    "status": "pending",
    "priority": PRIORITY,
    "source": SOURCE,
    "relatedChg": RELATED_CHG,
    "atoms": atoms,
    "createdAt": datetime.datetime.now().isoformat(),
    "updatedAt": datetime.datetime.now().isoformat()
}

queue["tasks"].append(task)
queue["lastUpdated"] = datetime.datetime.now().isoformat()

with open(QUEUE_FILE, "w") as f:
    json.dump(queue, f, indent=2)

# Create checkpoint
cp = {
    "schema": "checkpoint-v1",
    "taskId": TASK_ID,
    "currentAtom": 1,
    "atoms": atoms,
    "lastUpdated": task["updatedAt"]
}

with open(f"{CHECKPOINT_DIR}/{TASK_ID}.json", "w") as f:
    json.dump(cp, f, indent=2)

print(f"Task added: {TASK_ID}")
