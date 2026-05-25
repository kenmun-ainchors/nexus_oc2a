#!/bin/bash
# Cron healthy: Warden (83accf7b)
set -e
/opt/homebrew/bin/openclaw cron get 83accf7b-c3e5-4f0a-9a0c-d67d74ffff01 2>/dev/null | /opt/homebrew/bin/jq -e '.state.lastRunStatus == "ok"' >/dev/null 2>&1 && exit 0 || exit 1
