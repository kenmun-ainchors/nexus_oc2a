import json, datetime, sys, os

# Import atomic write helper
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from atomic_write import atomic_write_json

with open(sys.argv[1]) as f:
    queue = json.load(f)

AGENT_ID = sys.argv[2]

for t in queue.get('tasks', []):
    if t['status'] == 'pending':
        t['status'] = 'claimed'
        t['claimedBy'] = AGENT_ID
        t['claimedAt'] = datetime.datetime.now().isoformat()
        t['claimTimeout'] = (datetime.datetime.now() + datetime.timedelta(minutes=30)).isoformat()
        t['updatedAt'] = datetime.datetime.now().isoformat()
        
        queue['lastUpdated'] = datetime.datetime.now().isoformat()
        
        # Atomic write queue file
        if not atomic_write_json(sys.argv[1], queue):
            print(f"ERROR: Failed to write queue file", file=sys.stderr)
            sys.exit(1)
        
        print(f"Claimed: {t['id']} | {t['title'][:40]}... | Atoms: {len(t.get('atoms', []))}")
        break
else:
    print('No pending tasks')
