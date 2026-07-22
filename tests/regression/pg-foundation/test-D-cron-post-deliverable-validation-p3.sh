#!/bin/bash
# Cron healthy: Post-Deliverable Validation (065bd5a9)
set -e
# Resolve jq (CHG-0987 / TKT-1035: portable, honours $JQ env override)
JQ="$(command -v jq 2>/dev/null || echo /usr/bin/jq)"
/opt/homebrew/bin/openclaw cron get 065bd5a9-2888-41ca-bc0e-7771f2dfa565 2>/dev/null | "$JQ" -e '.state.lastRunStatus == "ok"' >/dev/null 2>&1 && exit 0 || exit 1
