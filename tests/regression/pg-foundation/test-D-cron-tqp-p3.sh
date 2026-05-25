#!/bin/bash
# Cron healthy: TQP (a89d00ef)
set -e
/opt/homebrew/bin/openclaw cron get a89d00ef-6d96-4aaf-8759-504c4ac72a3c 2>/dev/null | /opt/homebrew/bin/jq -e '.state.lastRunStatus == "ok"' >/dev/null 2>&1 && exit 0 || exit 1
