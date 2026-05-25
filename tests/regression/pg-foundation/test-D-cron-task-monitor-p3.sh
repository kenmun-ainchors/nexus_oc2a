#!/bin/bash
# Cron healthy: Task Monitor (637ecb12)
set -e
/opt/homebrew/bin/openclaw cron get 637ecb12-eae2-4c16-b174-8acdaa2729cc 2>/dev/null | /opt/homebrew/bin/jq -e '.state.lastRunStatus == "ok"' >/dev/null 2>&1 && exit 0 || exit 1
