#!/bin/bash
# Cron healthy: PG Sync Check (f7668f6a)
set -e
/opt/homebrew/bin/openclaw cron get f7668f6a-1c66-40cf-b9af-d1c09be03916 2>/dev/null | /opt/homebrew/bin/jq -e '.state.lastRunStatus == "ok"' >/dev/null 2>&1 && exit 0 || exit 1
