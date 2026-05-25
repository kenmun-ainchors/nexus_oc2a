import json, datetime, sys, os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from atomic_write import atomic_write_json
from pg_task_queue import sc_reset_stale_claims

with open(sys.argv[1]) as f:
    queue = json.load(f)

now = datetime.datetime.now().isoformat()

# Step 1: State-checked reset (TKT-0182: READ → VALIDATE → EXECUTE → VERIFY)
sc_ok, sc_msg, reset_count = sc_reset_stale_claims()

# Step 2: Also reset in JSON for consistency
json_reset = 0
for t in queue.get('queue', []):
    if t['status'] == 'claimed':
        timeout = t.get('claimTimeout', '1970-01-01')
        if timeout < now:
            t['status'] = 'pending'
            t.pop('claimedBy', None)
            t.pop('claimedAt', None)
            t.pop('claimTimeout', None)
            json_reset += 1

queue['lastUpdated'] = now
if not atomic_write_json(sys.argv[1], queue):
    print(f"ERROR: Failed to write queue file", file=sys.stderr)
    sys.exit(1)

print(f'Reset {json_reset} stale claims (JSON)')
if reset_count > 0:
    print(f'  SC: {sc_msg}')
