#!/bin/bash
# Create ticket writes to PG
set -e
TID="TKT-REGRESS-$(date +%s)"
bash /Users/ainchorsoc2a/.openclaw/workspace/scripts/db.sh -c "INSERT INTO state_tickets (id,title,type,status,priority,sequence,createdat) VALUES ('$TID','[REGRESS] B1 test','task','open','low','9999','$(date -u +%Y-%m-%dT%H:%M:%SZ)')" 2>/dev/null
STATUS=$(bash /Users/ainchorsoc2a/.openclaw/workspace/scripts/db-read.sh state_tickets id "$TID" 2>&1 | $(command -v jq 2>/dev/null || brew --prefix 2>/dev/null)/bin/jq -r '.status')
bash /Users/ainchorsoc2a/.openclaw/workspace/scripts/db.sh -c "DELETE FROM state_tickets WHERE id='$TID'" 2>/dev/null
[ "$STATUS" = "open" ] && exit 0 || exit 1
