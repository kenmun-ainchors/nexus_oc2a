#!/usr/bin/env bash
# backup-health-check.sh — Verify backup integrity and freshness
# Created 2026-05-18 (CHG-0400) — script was missing, cron e08e19ad was failing silently

set -euo pipefail

WORKSPACE="/Users/ainchorsangiefpl/.openclaw/workspace"
BACKUP_STATE="$WORKSPACE/state/backup-status.json"

# Check if state file exists and is recent
if [[ -f "$BACKUP_STATE" ]]; then
    LAST_BACKUP=$(/usr/bin/python3 -c "import json; d=json.load(open('$BACKUP_STATE')); print(d.get('lastBackup','unknown'))" 2>/dev/null || echo "unknown")
    SIZE=$(/usr/bin/python3 -c "import json; d=json.load(open('$BACKUP_STATE')); print(d.get('size',0))" 2>/dev/null || echo "0")
    
    # Check if backup is within 25 hours
    BACKUP_EPOCH=$(date -j -f "%Y-%m-%dT%H:%M:%S" "${LAST_BACKUP}" +%s 2>/dev/null || echo "0")
    NOW_EPOCH=$(date +%s)
    AGE_HOURS=$(( (NOW_EPOCH - BACKUP_EPOCH) / 3600 ))
    
    if [[ "$AGE_HOURS" -lt 25 ]] && [[ "$SIZE" -gt 0 ]]; then
        echo "BACKUP: healthy (last: ${LAST_BACKUP}, size: ${SIZE})"
        exit 0
    else
        echo "BACKUP: stale (last: ${LAST_BACKUP}, age: ${AGE_HOURS}h, size: ${SIZE})"
        exit 1
    fi
else
    echo "BACKUP: no state file found"
    exit 2
fi
