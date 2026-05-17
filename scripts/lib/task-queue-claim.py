import json, datetime, sys

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
        with open(sys.argv[1], 'w') as f:
            json.dump(queue, f, indent=2)
        
        print(f"Claimed: {t['id']} | {t['title'][:40]}... | Atoms: {len(t.get('atoms', []))}")
        break
else:
    print('No pending tasks')
