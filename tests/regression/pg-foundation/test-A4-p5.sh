#!/bin/bash
# A4: db-read.sh falls back to file when PG is down
if /opt/homebrew/bin/pg_isready -h /tmp -q 2>/dev/null; then
  echo "PG is still running — stop PG first"
  exit 2
fi
RESULT=$(bash /Users/ainchorsoc2a/.openclaw/workspace/scripts/db-read.sh state_tickets 2>&1)
if echo "$RESULT" | $(command -v jq 2>/dev/null || brew --prefix 2>/dev/null)/bin/jq -e 'length > 0' >/dev/null 2>&1; then
  COUNT=$(echo "$RESULT" | $(command -v jq 2>/dev/null || brew --prefix 2>/dev/null)/bin/jq 'length')
  echo "File fallback returned $COUNT tickets"
  exit 0
else
  echo "File fallback FAILED"
  exit 1
fi
