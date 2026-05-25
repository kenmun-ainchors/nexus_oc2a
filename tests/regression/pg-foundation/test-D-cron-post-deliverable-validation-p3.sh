#!/bin/bash
# Cron healthy: Post-Deliverable Validation (065bd5a9)
set -e
/opt/homebrew/bin/openclaw cron get 065bd5a9-2888-41ca-bc0e-7771f2dfa565 2>/dev/null | /opt/homebrew/bin/jq -e '.state.lastRunStatus == "ok"' >/dev/null 2>&1 && exit 0 || exit 1
