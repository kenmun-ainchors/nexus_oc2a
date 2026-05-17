import json, sys

with open(sys.argv[1]) as f:
    queue = json.load(f)

tasks = queue.get('tasks', [])
print(f'Total tasks: {len(tasks)}')
for t in tasks:
    pending = sum(1 for a in t.get('atoms',[]) if a['status']=='pending')
    complete = sum(1 for a in t.get('atoms',[]) if a['status']=='complete')
    failed = sum(1 for a in t.get('atoms',[]) if a['status']=='failed')
    total = len(t.get('atoms', []))
    print(f"  [{t['id']}] {t['status']:12} | {complete}/{total} complete | {pending} pending | {failed} failed | {t['title'][:40]}...")
