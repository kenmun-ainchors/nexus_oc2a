#!/bin/bash
# cost-tracker.sh reads from PG
set -e
grep -q 'db-read\|cost-state\|state_cost' /Users/ainchorsoc2a/.openclaw/workspace/scripts/cost-tracker.sh && exit 0 || exit 1
