#!/bin/bash
# State checking prevents adding task with same ID
set -e
python3 << 'PYEOF'
import sys
sys.path.insert(0,'/Users/ainchorsangiefpl/.openclaw/workspace/scripts/lib')
from pg_task_queue import sc_add_task, pg_upsert_task
import datetime,subprocess

TID = f"task-regress-c4-{int(datetime.datetime.now().timestamp())}"
now = datetime.datetime.now().isoformat()
pg_upsert_task(TID,{'title':'C4 first','tier':3,'status':'pending','priority':'low','source':'regression','atoms':[],'createdAt':now,'updatedAt':now})

ok1,_ = sc_add_task(TID,{'title':'C4 dup','atoms':[],'tier':3,'status':'pending'})

e={'PGHOST':'/tmp','PGPORT':'5432','PGUSER':'ainchorsangiefpl','PGDATABASE':'ainchors_nexus'}
subprocess.run(['/opt/homebrew/bin/psql','-t','-A','-c',f"DELETE FROM state_task_queue WHERE id='{TID}'"],env=e,capture_output=True)
sys.exit(0 if not ok1 else 1)
PYEOF
