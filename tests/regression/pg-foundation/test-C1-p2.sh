#!/bin/bash
# task-queue.sh add writes PG with status=queued
set -e
TID="task-regress-c1-$(date +%s)"
bash /Users/ainchorsoc2a/.openclaw/workspace/scripts/task-queue.sh add --title "C1 test" --atoms "A1" --tier 3 --priority low --source regression 2>/dev/null
# Find the actual ID created (add appends UUID)
ACTUAL_ID=$(ls -t /Users/ainchorsoc2a/.openclaw/workspace/state/checkpoints/ | grep 2026 | head -1 | sed 's/.json//')
STATUS=$(python3 -c "
import sys; sys.path.insert(0,'/Users/ainchorsoc2a/.openclaw/workspace/scripts/lib')
from pg_task_queue import pg_read_task
t = pg_read_task('$ACTUAL_ID')
print(t['status'] if t else 'NOT_FOUND')
")
# Cleanup
python3 -c "
import sys,json,os,subprocess
sys.path.insert(0,'/Users/ainchorsoc2a/.openclaw/workspace/scripts/lib')
e={'PGHOST':'/tmp','PGPORT':'5432','PGUSER':'"${PGUSER:-$(whoami)}"','PGDATABASE':'ainchors_nexus'}
subprocess.run(['${PSQL_BIN:-$(brew --prefix postgresql@16 2>/dev/null)/bin/psql}','-t','-A','-c',f\"DELETE FROM state_task_queue WHERE id='$ACTUAL_ID'\"],env=e,capture_output=True)
cp=f'/Users/ainchorsoc2a/.openclaw/workspace/state/checkpoints/$ACTUAL_ID.json'
if os.path.exists(cp): os.remove(cp)
" 2>/dev/null
# Clean JSON queue
python3 -c "
import json,datetime
with open('/Users/ainchorsoc2a/.openclaw/workspace/state/task-queue.json') as f: q=json.load(f)
q['queue']=[]
q['lastUpdated']=datetime.datetime.now().isoformat()
with open('/Users/ainchorsoc2a/.openclaw/workspace/state/task-queue.json','w') as f: json.dump(q,f,indent=2)
" 2>/dev/null
[ "$STATUS" = "queued" ] && exit 0 || exit 1
