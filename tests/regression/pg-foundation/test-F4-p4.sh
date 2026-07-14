#!/bin/bash
# Cost records exist in PG
set -e
COUNT=$(bash /Users/ainchorsoc2a/.openclaw/workspace/scripts/db-read.sh state_cost 2>&1 | $(command -v jq 2>/dev/null || brew --prefix 2>/dev/null)/bin/jq 'length' 2>/dev/null)
[ "${COUNT:-0}" -gt 0 ] && exit 0 || exit 1
