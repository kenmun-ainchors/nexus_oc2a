#!/bin/bash
# Cron healthy: Notion AKB Audit (1a7f5d98)
set -e
/opt/homebrew/bin/openclaw cron get 1a7f5d98-6c13-4819-be52-4fa06677f1c4 2>/dev/null | /opt/homebrew/bin/jq -e '.state.lastRunStatus == "ok"' >/dev/null 2>&1 && exit 0 || exit 1
