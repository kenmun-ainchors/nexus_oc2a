#!/bin/bash
# Sprint data exists in PG
set -e
SPRINTS=$(bash /Users/ainchorsangiefpl/.openclaw/workspace/scripts/db-read.sh state_sprints 2>&1 | /opt/homebrew/bin/jq 'length' 2>/dev/null)
[ "${SPRINTS:-0}" -gt 0 ] && exit 0 || exit 1
