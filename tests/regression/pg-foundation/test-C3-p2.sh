#!/bin/bash
# State checking blocks double-claim of dispatched task
set -e
python3 << 'PYEOF'
import sys
sys.path.insert(0,'/Users/ainchorsoc2a/.openclaw/workspace/scripts/lib')
from pg_task_queue import sc_claim_task, pg_upsert_task
import datetime,subprocess,os

TID = f"task-regress-c3-{int(datetime.datetime.now().timestamp())}"
now = datetime.datetime.now().isoformat()
pg_upsert_task(TID,{'title':'C3 test','tier':3,'status':'pending','priority':'low','source':'regression','atoms':[],'createdAt':now,'updatedAt':now})

ok1,_ = sc_claim_task(TID, 'agent:test')
ok2,_ = sc_claim_task(TID, 'agent:hijacker')

# Cleanup
e={'PGHOST':'/tmp','PGPORT':'5432','PGUSER':'"${PGUSER:-$(whoami)}"','PGDATABASE':'ainchors_nexus'}
subprocess.run(['${PSQL_BIN:-$(brew --prefix postgresql@16 2>/dev/null)/bin/psql}','-t','-A','-c',f"DELETE FROM state_task_queue WHERE id='{TID}'"],env=e,capture_output=True)

sys.exit(0 if (ok1 and not ok2) else 1)
PYEOF
