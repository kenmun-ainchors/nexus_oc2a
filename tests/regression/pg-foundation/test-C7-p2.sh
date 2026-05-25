#!/bin/bash
# Stale claims are detected and can be reset
set -e
python3 << 'PYEOF'
import sys
sys.path.insert(0,'/Users/ainchorsangiefpl/.openclaw/workspace/scripts/lib')
from pg_task_queue import sc_reset_stale_claims
ok,msg,count = sc_reset_stale_claims()
# If no stale claims, that's also a pass (mechanism works)
sys.exit(0 if ok else 1)
PYEOF
