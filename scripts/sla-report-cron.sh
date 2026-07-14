#!/usr/bin/env bash
# sla-report-cron.sh — Monthly SLA Report cron wrapper
# Computes the previous month in AEST and invokes sla-report.sh.
# Run: bash /Users/ainchorsoc2a/.openclaw/workspace/scripts/sla-report-cron.sh

set -euo pipefail

WORKSPACE="${WORKSPACE:-/Users/ainchorsoc2a/.openclaw/workspace}"

# Previous month in YYYY-MM (macOS/BSD date compatible)
PREV_MONTH=$(python3 -c "from datetime import datetime, timedelta; d=datetime.now()+timedelta(hours=10)-timedelta(days=1); d=d.replace(day=1)-timedelta(days=1); print(f'{d.year:04d}-{d.month:02d}')")

echo "[sla-report] generating for $PREV_MONTH"

zsh "$WORKSPACE/scripts/sla-report.sh" "$PREV_MONTH"

REPORT_FILE="$WORKSPACE/reports/sla-$PREV_MONTH.md"
if [[ -f "$REPORT_FILE" ]]; then
    echo "[sla-report] OK: $REPORT_FILE ($(wc -c < "$REPORT_FILE") bytes)"
else
    echo "[sla-report] ERROR: expected report not found: $REPORT_FILE" >&2
    exit 1
fi
