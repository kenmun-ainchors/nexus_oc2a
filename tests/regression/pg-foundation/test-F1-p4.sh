#!/bin/bash
# Zero duplicate ticket IDs in PG
set -e
DUPS=$(bash /Users/ainchorsangiefpl/.openclaw/workspace/scripts/db.sh -c "SELECT COUNT(*) FROM (SELECT id FROM state_tickets GROUP BY id HAVING COUNT(*) > 1) sub" 2>/dev/null || echo 0)
[ "${DUPS:-0}" -eq 0 ] && exit 0 || exit 1
