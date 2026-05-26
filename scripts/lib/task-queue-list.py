import json, sys, os

# Import PG helper with State Checking
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pg_task_queue import sc_read_all_tasks, pg_read_all_tasks  # pg_read_all_tasks kept as fallback

QUEUE_FILE = sys.argv[1]

# Step 1: Try PG read with State Checking (PRIMARY per TKT-0303)
ok, tasks, msg = sc_read_all_tasks()

if ok and tasks is not None and len(tasks) > 0:
    print(f'Total tasks (PG): {len(tasks)}')
    for t in tasks:
        atoms = t.get('atoms', []) or []
        if isinstance(atoms, str):
            try:
                atoms = json.loads(atoms)
            except:
                atoms = []
        pending = sum(1 for a in atoms if a.get('status') == 'pending')
        complete = sum(1 for a in atoms if a.get('status') == 'complete')
        failed = sum(1 for a in atoms if a.get('status') == 'failed')
        total = len(atoms)
        title = t.get('title', '')[:40]
        print(f"  [{t['id']}] {t.get('status', 'unknown'):12} | {complete}/{total} complete | {pending} pending | {failed} failed | {title}...")
else:
    # Step 2: State Check failed or returned empty — try raw read as degraded fallback
    tasks_raw = pg_read_all_tasks()
    if tasks_raw is not None and len(tasks_raw) > 0:
        print(f'Total tasks (PG — degraded, sc failed: {msg}): {len(tasks_raw)}')
        for t in tasks_raw:
            atoms = t.get('atoms', []) or []
            if isinstance(atoms, str):
                try:
                    atoms = json.loads(atoms)
                except:
                    atoms = []
            pending = sum(1 for a in atoms if a.get('status') == 'pending')
            complete = sum(1 for a in atoms if a.get('status') == 'complete')
            failed = sum(1 for a in atoms if a.get('status') == 'failed')
            total = len(atoms)
            title = t.get('title', '')[:40]
            print(f"  [{t['id']}] {t.get('status', 'unknown'):12} | {complete}/{total} complete | {pending} pending | {failed} failed | {title}...")
    else:
        # Step 3: Fallback to JSON file
        try:
            with open(QUEUE_FILE) as f:
                queue = json.load(f)
            tasks = queue.get('queue', [])
            print(f'Total tasks (file): {len(tasks)}')
            for t in tasks:
                pending = sum(1 for a in t.get('atoms',[]) if a['status']=='pending')
                complete = sum(1 for a in t.get('atoms',[]) if a['status']=='complete')
                failed = sum(1 for a in t.get('atoms',[]) if a['status']=='failed')
                total = len(t.get('atoms', []))
                print(f"  [{t['id']}] {t['status']:12} | {complete}/{total} complete | {pending} pending | {failed} failed | {t['title'][:40]}...")
        except (FileNotFoundError, json.JSONDecodeError):
            print('No tasks found (PG and file both unavailable)')
