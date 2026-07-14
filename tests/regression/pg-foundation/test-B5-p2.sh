#!/bin/bash
# Five rapid creates produce unique IDs
set -e
for i in 1 2 3 4 5; do
  bash /Users/ainchorsoc2a/.openclaw/workspace/scripts/db.sh -c "INSERT INTO state_tickets (id,title,type,status,priority,sequence,createdat) VALUES ('TKT-REGRESS-B5-$i','[REGRESS] B5-$i','task','open','low','999$i','$(date -u +%Y-%m-%dT%H:%M:%SZ)')" 2>/dev/null
done
DUPS=$(bash /Users/ainchorsoc2a/.openclaw/workspace/scripts/db.sh -c "SELECT COUNT(*) FROM state_tickets WHERE id LIKE 'TKT-REGRESS-B5-%' GROUP BY id HAVING COUNT(*)>1" 2>/dev/null)
for i in 1 2 3 4 5; do
  bash /Users/ainchorsoc2a/.openclaw/workspace/scripts/db.sh -c "DELETE FROM state_tickets WHERE id='TKT-REGRESS-B5-$i'" 2>/dev/null
done
[ -z "$DUPS" ] && exit 0 || exit 1
