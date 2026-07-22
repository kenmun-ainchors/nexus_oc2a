#!/bin/bash
# Cron healthy: Task Monitor (637ecb12)
set -e
# Resolve jq (CHG-0987 / TKT-1035: portable, honours $JQ env override)
JQ="$(command -v jq 2>/dev/null || echo /usr/bin/jq)"
/opt/homebrew/bin/openclaw cron get 637ecb12-eae2-4c16-b174-8acdaa2729cc 2>/dev/null | "$JQ" -e '.state.lastRunStatus == "ok"' >/dev/null 2>&1 && exit 0 || exit 1
