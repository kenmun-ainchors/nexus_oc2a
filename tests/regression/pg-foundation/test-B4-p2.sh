#!/bin/bash
# Close ticket writes closed status to PG
set -e
TID="TKT-REGRESS-B4"
bash /Users/ainchorsoc2a/.openclaw/workspace/scripts/db.sh -c "INSERT INTO state_tickets (id,title,type,status,priority,sequence,createdat) VALUES ('$TID','[REGRESS] B4 close test','task','open','low','9996','$(date -u +%Y-%m-%dT%H:%M:%SZ)') ON CONFLICT(id) DO UPDATE SET status=EXCLUDED.status" 2>/dev/null
bash /Users/ainchorsoc2a/.openclaw/workspace/scripts/db.sh -c "UPDATE state_tickets SET status='closed', metadata=metadata||'{\"resolution\":\"B4 test\"}' WHERE id='$TID'" 2>/dev/null
STATUS=$(bash /Users/ainchorsoc2a/.openclaw/workspace/scripts/db-read.sh state_tickets id "$TID" 2>&1 | $(command -v jq 2>/dev/null || brew --prefix 2>/dev/null)/bin/jq -r '.status')
bash /Users/ainchorsoc2a/.openclaw/workspace/scripts/db.sh -c "DELETE FROM state_tickets WHERE id='$TID'" 2>/dev/null
[ "$STATUS" = "closed" ] && exit 0 || exit 1
