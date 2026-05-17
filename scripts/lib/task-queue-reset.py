import json, datetime, sys, os

# Import atomic write helper
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from atomic_write import atomic_write_json

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

# Atomic write queue file
if not atomic_write_json(sys.argv[1], queue):
    print(f"ERROR: Failed to write queue file", file=sys.stderr)
    sys.exit(1)

print(f'Reset {reset_count} stale claims')
