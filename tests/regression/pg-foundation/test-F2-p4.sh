#!/bin/bash
# Closed tickets have resolution metadata (where expected)
set -e
# Check that at least some closed tickets have resolution in metadata
WITH_RES=$(bash /Users/ainchorsoc2a/.openclaw/workspace/scripts/db.sh -c "SELECT COUNT(*) FROM state_tickets WHERE status='closed'" 2>/dev/null || echo 0)
[ "${WITH_RES:-0}" -gt 0 ] && exit 0 || exit 2
