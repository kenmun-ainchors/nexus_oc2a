#!/bin/bash
# Special characters survive PG write/read round-trip
TID="TKT-REGRESS-B3"
TITLE="REGRESSION special chars test"
bash /Users/ainchorsangiefpl/.openclaw/workspace/scripts/db.sh -c "INSERT INTO state_tickets (id,title,type,status,priority,sequence,createdat) VALUES ('$TID','$TITLE','task','open','low','9997','$(date -u +%Y-%m-%dT%H:%M:%SZ)') ON CONFLICT(id) DO UPDATE SET title=EXCLUDED.title" 2>/dev/null
READBACK=$(bash /Users/ainchorsangiefpl/.openclaw/workspace/scripts/db-read.sh state_tickets id "$TID" 2>&1 | /opt/homebrew/bin/jq -r '.title')
bash /Users/ainchorsangiefpl/.openclaw/workspace/scripts/db.sh -c "DELETE FROM state_tickets WHERE id='$TID'" 2>/dev/null
[ "$READBACK" = "$TITLE" ] && exit 0 || exit 1
