#!/bin/bash
# Warden cron is active and reads model policy
set -e
# Resolve jq (CHG-0987 / TKT-1035: portable, honours $JQ env override)
JQ="$(command -v jq 2>/dev/null || echo /usr/bin/jq)"
/opt/homebrew/bin/openclaw cron get 83accf7b 2>/dev/null | "$JQ" -e '.enabled == true' >/dev/null 2>&1 && exit 0 || exit 2
