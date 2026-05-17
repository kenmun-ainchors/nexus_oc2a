import json, sys

with open(sys.argv[1]) as f:
    queue = json.load(f)

TASK_ID = sys.argv[2]

for t in queue.get('tasks', []):
    if t['id'] == TASK_ID:
        print(f"Task: {t['id']}")
        print(f"Title: {t['title']}")
        print(f"Status: {t['status']}")
        print(f"Atoms: {len(t.get('atoms', []))}")
        for a in t.get('atoms', []):
            print(f"  Atom {a['id']}: {a['status']:12} | {a['description'][:50]}")
        break
else:
    print(f'Task {TASK_ID} not found')
