#!/bin/bash
# New tickets get Notion page ID in state file
set -e
# Check recent tickets have notionPageId
WITH_PAGE=$(bash /Users/ainchorsoc2a/.openclaw/workspace/scripts/db.sh -c "SELECT COUNT(*) FROM state_tickets WHERE status='open' AND notionpageid IS NOT NULL AND notionpageid != ''" 2>/dev/null || echo 0)
[ "${WITH_PAGE:-0}" -gt 0 ] && exit 0 || exit 2
