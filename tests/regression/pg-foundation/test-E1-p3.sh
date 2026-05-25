#!/bin/bash
# ticket.sh writes to PG via db-write.sh on create/update/close
set -e
grep -q 'db-write.sh.*state_tickets' /Users/ainchorsangiefpl/.openclaw/workspace/scripts/ticket.sh && exit 0 || exit 1
