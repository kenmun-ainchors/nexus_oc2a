#!/bin/bash
# No orphaned task_queue entries (PG entries with atoms have checkpoints)
set -e
PG_IDS=$(bash /Users/ainchorsoc2a/.openclaw/workspace/scripts/db.sh -c "SELECT id FROM state_task_queue WHERE atoms IS NOT NULL AND atoms != '' AND atoms != 'null' AND atoms != 'ATOMIC TASK: UAT-TQP-001'" 2>/dev/null)
ORPHANS=0
for tid in $PG_IDS; do
  [ "$tid" = "UAT-TQP-001" ] && continue
  if [ ! -f "/Users/ainchorsoc2a/.openclaw/workspace/state/checkpoints/${tid}.json" ]; then
    ORPHANS=$((ORPHANS + 1))
  fi
done
[ $ORPHANS -eq 0 ] && exit 0 || exit 1
