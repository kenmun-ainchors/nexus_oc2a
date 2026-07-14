#!/bin/bash
# Sprint data exists in PG
set -e
SPRINTS=$(bash /Users/ainchorsoc2a/.openclaw/workspace/scripts/db-read.sh state_sprints 2>&1 | $(command -v jq 2>/dev/null || brew --prefix 2>/dev/null)/bin/jq 'length' 2>/dev/null)
[ "${SPRINTS:-0}" -gt 0 ] && exit 0 || exit 1
