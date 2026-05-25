#!/bin/bash
# Cron healthy: Morning Standup (3c279099)
set -e
/opt/homebrew/bin/openclaw cron get 3c279099-bddb-4ef3-bfea-fc22f342abd8 2>/dev/null | /opt/homebrew/bin/jq -e '.state.lastRunStatus == "ok"' >/dev/null 2>&1 && exit 0 || exit 1
