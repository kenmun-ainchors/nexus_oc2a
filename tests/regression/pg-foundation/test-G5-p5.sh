#!/bin/bash
# G5: PG write fallback log receives entries when PG is down
if /opt/homebrew/bin/pg_isready -h /tmp -q 2>/dev/null; then
  echo "PG is still running — stop PG first"
  exit 2
fi
# Write a test entry via db-write.sh → should fallback to file
bash /Users/ainchorsangiefpl/.openclaw/workspace/scripts/db-write.sh state_tickets '{"id":"TKT-PHASE5-TEST","title":"Phase 5 fallback test","status":"open","type":"task","priority":"low","sequence":"99999"}' TKT-PHASE5-TEST 2>/dev/null
# Check fallback log exists and has content
FALLBACK="/Users/ainchorsangiefpl/.openclaw/workspace/state/pg-write-fallback-state_tickets.jsonl"
if [ -f "$FALLBACK" ] && [ -s "$FALLBACK" ]; then
  echo "Fallback log exists: $(wc -l < "$FALLBACK") entries"
  exit 0
else
  echo "No fallback log found"
  exit 1
fi
