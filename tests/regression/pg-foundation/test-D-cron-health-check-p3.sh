#!/bin/bash
# Cron healthy: Health Check (c65ace85)
set -e
/opt/homebrew/bin/openclaw cron get c65ace85-c5b0-4e96-ace6-ae925812c09b 2>/dev/null | /opt/homebrew/bin/jq -e '.state.lastRunStatus == "ok"' >/dev/null 2>&1 && exit 0 || exit 1
