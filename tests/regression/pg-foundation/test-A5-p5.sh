#!/bin/bash
# A5: db-write.sh falls back to file when PG is down
if /opt/homebrew/bin/pg_isready -h /tmp -q 2>/dev/null; then
  echo "PG is still running — stop PG first"
  exit 2
fi
RESULT=$(bash /Users/ainchorsoc2a/.openclaw/workspace/scripts/db-write.sh state_tickets '{"id":"TKT-A5-TEST","title":"A5 fallback test","status":"open","type":"task","priority":"low","sequence":"99998"}' TKT-A5-TEST 2>&1)
if echo "$RESULT" | grep -q 'degraded\|file'; then
  echo "db-write.sh fell back to file: $RESULT"
  exit 0
else
  echo "Unexpected result: $RESULT"
  exit 1
fi
