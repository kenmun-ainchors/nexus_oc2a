#!/bin/bash
# Checkpoint file updates when atom fails with retry count
set -e
TID="task-regress-c6-$(date +%s)"
bash /Users/ainchorsoc2a/.openclaw/workspace/scripts/task-queue.sh add --title "C6 CP fail test" --atoms "Atom 1;Atom 2" --tier 3 --priority low --source regression 2>/dev/null
ACTUAL_ID=$(ls -t /Users/ainchorsoc2a/.openclaw/workspace/state/checkpoints/ | grep 2026 | head -1 | sed 's/.json//')
bash /Users/ainchorsoc2a/.openclaw/workspace/scripts/task-queue.sh fail "$ACTUAL_ID" 1 "C6 test failure" 2>/dev/null
ATOM1_STATUS=$(python3 -c "
import json
with open('/Users/ainchorsoc2a/.openclaw/workspace/state/checkpoints/$ACTUAL_ID.json') as f:
    cp=json.load(f)
a=cp['atoms'][0]
print(f\"{a['status']}:{a.get('retryCount',0)}\")
")
# Cleanup
python3 -c "
import sys,subprocess,os
e={'PGHOST':'/tmp','PGPORT':'5432','PGUSER':'"${PGUSER:-$(whoami)}"','PGDATABASE':'ainchors_nexus'}
subprocess.run(['${PSQL_BIN:-$(brew --prefix postgresql@16 2>/dev/null)/bin/psql}','-t','-A','-c',f\"DELETE FROM state_task_queue WHERE id='$ACTUAL_ID'\"],env=e,capture_output=True)
cp=f'/Users/ainchorsoc2a/.openclaw/workspace/state/checkpoints/$ACTUAL_ID.json'
if os.path.exists(cp): os.remove(cp)
" 2>/dev/null
python3 -c "import json,datetime; f=open('/Users/ainchorsoc2a/.openclaw/workspace/state/task-queue.json'); q=json.load(f); f.close(); q['queue']=[]; q['lastUpdated']=datetime.datetime.now().isoformat(); f=open('/Users/ainchorsoc2a/.openclaw/workspace/state/task-queue.json','w'); json.dump(q,f,indent=2); f.close()" 2>/dev/null
echo "$ATOM1_STATUS" | grep -q 'failed:1' && exit 0 || exit 1
