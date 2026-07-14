#!/bin/bash
# Checkpoint file updates when atom completes
set -e
TID="task-regress-c5-$(date +%s)"
bash /Users/ainchorsoc2a/.openclaw/workspace/scripts/task-queue.sh add --title "C5 CP test" --atoms "Atom 1;Atom 2" --tier 3 --priority low --source regression 2>/dev/null
ACTUAL_ID=$(ls -t /Users/ainchorsoc2a/.openclaw/workspace/state/checkpoints/ | grep 2026 | head -1 | sed 's/.json//')
bash /Users/ainchorsoc2a/.openclaw/workspace/scripts/task-queue.sh complete "$ACTUAL_ID" 1 '{"result":"ok"}' 2>/dev/null
ATOM1_STATUS=$(python3 -c "
import json
with open('/Users/ainchorsoc2a/.openclaw/workspace/state/checkpoints/$ACTUAL_ID.json') as f:
    cp=json.load(f)
print(cp['atoms'][0]['status'])
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
[ "$ATOM1_STATUS" = "complete" ] && exit 0 || exit 1
