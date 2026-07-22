#!/bin/bash
# Cron healthy: Health Check (c65ace85)
set -e
# Resolve jq (CHG-0987 / TKT-1035: portable, honours $JQ env override)
JQ="$(command -v jq 2>/dev/null || echo /usr/bin/jq)"
/opt/homebrew/bin/openclaw cron get c65ace85-c5b0-4e96-ace6-ae925812c09b 2>/dev/null | "$JQ" -e '.state.lastRunStatus == "ok"' >/dev/null 2>&1 && exit 0 || exit 1
