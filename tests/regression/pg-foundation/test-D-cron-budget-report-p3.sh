#!/bin/bash
# Cron healthy: Budget Report (3ea986bf)
set -e
# Resolve jq (CHG-0987 / TKT-1035: portable, honours $JQ env override)
JQ="$(command -v jq 2>/dev/null || echo /usr/bin/jq)"
/opt/homebrew/bin/openclaw cron get 3ea986bf-5dfc-4805-a13c-80427b4d29c7 2>/dev/null | "$JQ" -e '.state.lastRunStatus == "ok"' >/dev/null 2>&1 && exit 0 || exit 1
