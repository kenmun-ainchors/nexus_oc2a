#!/bin/bash
# TQP processor picks up queued tasks from PG
set -e
TID="task-regress-c2-$(date +%s)"
python3 -c "
import sys,json,subprocess
sys.path.insert(0,'/Users/ainchorsoc2a/.openclaw/workspace/scripts/lib')
from pg_task_queue import pg_upsert_task
import datetime
now=datetime.datetime.now().isoformat()
pg_upsert_task('$TID',{'title':'C2 test','tier':3,'status':'pending','priority':'low','source':'regression','atoms':[{'id':1,'description':'test','status':'pending'}],'createdAt':now,'updatedAt':now})
" 2>/dev/null
OUTPUT=$(bash /Users/ainchorsoc2a/.openclaw/workspace/scripts/task-queue-processor.sh 2>&1)
# Cleanup
python3 -c "
import subprocess
e={'PGHOST':'/tmp','PGPORT':'5432','PGUSER':'"${PGUSER:-$(whoami)}"','PGDATABASE':'ainchors_nexus'}
subprocess.run(['${PSQL_BIN:-$(brew --prefix postgresql@16 2>/dev/null)/bin/psql}','-t','-A','-c',f\"DELETE FROM state_task_queue WHERE id='$TID'\"],env=e,capture_output=True)
" 2>/dev/null
echo "$OUTPUT" | grep -q 'dispatched' && exit 0 || exit 1
