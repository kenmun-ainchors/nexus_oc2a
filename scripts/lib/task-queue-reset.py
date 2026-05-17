import json, datetime, sys

with open(sys.argv[1]) as f:
    queue = json.load(f)

now = datetime.datetime.now().isoformat()
reset_count = 0

for t in queue.get('tasks', []):
    if t['status'] == 'claimed':
        timeout = t.get('claimTimeout', '1970-01-01')
        if timeout < now:
            t['status'] = 'pending'
            t.pop('claimedBy', None)
            t.pop('claimedAt', None)
            t.pop('claimTimeout', None)
            reset_count += 1

queue['lastUpdated'] = datetime.datetime.now().isoformat()
with open(sys.argv[1], 'w') as f:
    json.dump(queue, f, indent=2)

print(f'Reset {reset_count} stale claims')
