import json, datetime, sys, os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from atomic_write import atomic_write_json
from pg_task_queue import sc_claim_task

with open(sys.argv[1]) as f:
    queue = json.load(f)

AGENT_ID = sys.argv[2]

for t in queue.get('queue', []):
    if t['status'] == 'pending':
        task_id = t['id']
        
        # Step 1: State-checked claim (TKT-0182: READ → VALIDATE → EXECUTE → VERIFY)
        sc_ok, sc_msg = sc_claim_task(task_id, AGENT_ID)
        if not sc_ok:
            print(f"ERROR: {sc_msg}", file=sys.stderr)
            continue
        
        # Step 2: Dual-write to JSON on successful PG claim
        now = datetime.datetime.now().isoformat()
        timeout = (datetime.datetime.now() + datetime.timedelta(minutes=30)).isoformat()
        t['status'] = 'claimed'
        t['claimedBy'] = AGENT_ID
        t['claimedAt'] = now
        t['claimTimeout'] = timeout
        t['updatedAt'] = now
        
        queue['lastUpdated'] = now
        if not atomic_write_json(sys.argv[1], queue):
            print(f"ERROR: Failed to write queue file", file=sys.stderr)
            sys.exit(1)
        
        print(f"Claimed: {t['id']} | {t['title'][:40]}... | Atoms: {len(t.get('atoms', []))}")
        print(f"  SC: {sc_msg}")
        break
else:
    print('No pending tasks')
