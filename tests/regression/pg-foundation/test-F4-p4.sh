#!/bin/bash
# Cost records exist in PG
set -e
COUNT=$(bash /Users/ainchorsangiefpl/.openclaw/workspace/scripts/db-read.sh state_cost 2>&1 | /opt/homebrew/bin/jq 'length' 2>/dev/null)
[ "${COUNT:-0}" -gt 0 ] && exit 0 || exit 1
