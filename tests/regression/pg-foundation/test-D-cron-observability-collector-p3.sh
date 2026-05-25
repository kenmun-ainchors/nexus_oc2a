#!/bin/bash
# Cron healthy: Observability Collector (d3b1e203)
set -e
/opt/homebrew/bin/openclaw cron get d3b1e203-741b-444a-9852-7bb8839d2c99 2>/dev/null | /opt/homebrew/bin/jq -e '.state.lastRunStatus == "ok"' >/dev/null 2>&1 && exit 0 || exit 1
