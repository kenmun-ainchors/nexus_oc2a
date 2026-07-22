#!/bin/bash
# Cron healthy: Warden (83accf7b)
set -e
# Resolve jq (CHG-0987 / TKT-1035: portable, honours $JQ env override)
JQ="$(command -v jq 2>/dev/null || echo /usr/bin/jq)"
/opt/homebrew/bin/openclaw cron get 83accf7b-c3e5-4f0a-9a0c-d67d74ffff01 2>/dev/null | "$JQ" -e '.state.lastRunStatus == "ok"' >/dev/null 2>&1 && exit 0 || exit 1
