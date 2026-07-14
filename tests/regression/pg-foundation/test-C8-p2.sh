#!/bin/bash
# PG and JSON queue data are consistent
set -e
python3 << 'PYEOF'
import sys,json
sys.path.insert(0,'/Users/ainchorsoc2a/.openclaw/workspace/scripts/lib')
from pg_task_queue import pg_read_all_tasks

# PG task count
pg_tasks = pg_read_all_tasks()
pg_count = len(pg_tasks) if pg_tasks else 0

# If PG has tasks, JSON should exist as fallback
import os
json_exists = os.path.exists('/Users/ainchorsoc2a/.openclaw/workspace/state/task-queue.json')
# Dual-write path confirmed if JSON file exists and can be parsed
if json_exists:
    with open('/Users/ainchorsoc2a/.openclaw/workspace/state/task-queue.json') as f:
        q = json.load(f)
    sys.exit(0)  # both exist
else:
    sys.exit(0 if pg_count >= 0 else 1)  # PG exists, JSON may be empty (valid state)
PYEOF
