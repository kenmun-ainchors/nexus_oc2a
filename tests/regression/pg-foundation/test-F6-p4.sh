#!/bin/bash
# LinkedIn data exists in PG
set -e
LI_COUNT=$(bash /Users/ainchorsoc2a/.openclaw/workspace/scripts/db-read.sh state_linkedin 2>&1 | $(command -v jq 2>/dev/null || brew --prefix 2>/dev/null)/bin/jq 'length' 2>/dev/null)
[ "${LI_COUNT:-0}" -gt 0 ] && exit 0 || exit 1
