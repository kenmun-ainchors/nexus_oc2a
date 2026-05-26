import json, sys, os

# Import PG helper with State Checking
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pg_task_queue import sc_read_task, pg_read_task  # pg_read_task kept as fallback

QUEUE_FILE = sys.argv[1]
TASK_ID = sys.argv[2]

# Step 1: Try PG read with State Checking (PRIMARY per TKT-0303)
ok, task, msg = sc_read_task(TASK_ID)

if ok and task is not None:
    atoms = task.get('atoms', [])
    if isinstance(atoms, str):
        try:
            atoms = json.loads(atoms)
        except:
            atoms = []
    print(f"Task (PG): {task['id']}")
    print(f"Title: {task.get('title', 'N/A')}")
    print(f"Status: {task.get('status', 'unknown')}")
    print(f"Atoms: {len(atoms)}")
    for a in atoms:
        desc = str(a.get('description', ''))[:50]
        print(f"  Atom {a.get('id', '?')}: {a.get('status', '?'):12} | {desc}")
else:
    # Step 2: State Check failed — try raw read as last resort
    task_raw = pg_read_task(TASK_ID)
    if task_raw is not None:
        atoms = task_raw.get('atoms', [])
        if isinstance(atoms, str):
            try:
                atoms = json.loads(atoms)
            except:
                atoms = []
        print(f"Task (PG — degraded, sc failed: {msg}): {task_raw['id']}")
        print(f"Title: {task_raw.get('title', 'N/A')}")
        print(f"Status: {task_raw.get('status', 'unknown')}")
        print(f"Atoms: {len(atoms)}")
        for a in atoms:
            desc = str(a.get('description', ''))[:50]
            print(f"  Atom {a.get('id', '?')}: {a.get('status', '?'):12} | {desc}")
    else:
        # Step 3: Fallback to JSON file
        try:
            with open(QUEUE_FILE) as f:
                queue = json.load(f)

            for t in queue.get('queue', []):
                if t['id'] == TASK_ID:
                    print(f"Task (file): {t['id']}")
                    print(f"Title: {t['title']}")
                    print(f"Status: {t['status']}")
                    print(f"Atoms: {len(t.get('atoms', []))}")
                    for a in t.get('atoms', []):
                        print(f"  Atom {a['id']}: {a['status']:12} | {a['description'][:50]}")
                    break
            else:
                print(f'Task {TASK_ID} not found')
        except (FileNotFoundError, json.JSONDecodeError):
            print(f'Task {TASK_ID} not found (PG and file both unavailable)')
