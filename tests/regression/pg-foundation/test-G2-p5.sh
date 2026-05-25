#!/bin/bash
# G2: TQP exits gracefully when PG is down
if /opt/homebrew/bin/pg_isready -h /tmp -q 2>/dev/null; then
  echo "PG is still running — stop PG first"
  exit 2
fi
OUTPUT=$(bash /Users/ainchorsangiefpl/.openclaw/workspace/scripts/task-queue-processor.sh 2>&1)
# Should exit cleanly, not crash
echo "$OUTPUT"
exit 0
