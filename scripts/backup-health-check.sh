#!/usr/bin/env bash
# backup-health-check.sh — Verify backup integrity and freshness
# Created 2026-05-18 (CHG-0400), fixed 2026-05-19 (CHG-0415: wrong state filename + missing size field)

set -euo pipefail

WORKSPACE="/Users/ainchorsoc2a/.openclaw/workspace"
BACKUP_STATE="$WORKSPACE/state/backup-state.json"
BACKUP_DIR="/Users/ainchorsoc2a/Backups/ainchors"

# Check if state file exists
if [[ ! -f "$BACKUP_STATE" ]]; then
    echo "BACKUP: no state file found"
    exit 2
fi

LAST_BACKUP=$JQ -r '.last_backup // .lastBackup // "unknown"' "$BACKUP_STATE")
LAST_SNAP=$JQ -r '.workspace_snapshot // .lastSnap // "unknown"' "$BACKUP_STATE")
STATUS=$JQ -r '.status // "unknown"' "$BACKUP_STATE")

# Check if backup directory actually has content
if [[ -d "$BACKUP_DIR/workspace-incremental" ]]; then
    BACKUP_SIZE=$(du -sh "$BACKUP_DIR/workspace-incremental" 2>/dev/null | cut -f1 || echo "unknown")
    FILE_COUNT=$(find "$BACKUP_DIR/workspace-incremental" -type f 2>/dev/null | wc -l | xargs || echo "0")
else
    BACKUP_SIZE="0"
    FILE_COUNT="0"
fi

# Check freshness: backup must be within 25 hours
# Parse timestamp — try ISO 8601 with timezone, then ISO 8601 Z, then YYYY-MM-DD-HHMM format
BACKUP_EPOCH=0
if [[ "$LAST_BACKUP" == *"+08:00"* ]] || [[ "$LAST_BACKUP" == *"+10:00"* ]] || [[ "$LAST_BACKUP" == *"+11:00"* ]]; then
    CLEAN_TS=$(echo "$LAST_BACKUP" | sed 's/\([+-][0-9][0-9]\):\([0-9][0-9]\)$/\1\2/')
    BACKUP_EPOCH=$(date -j -f "%Y-%m-%dT%H:%M:%S%z" "$CLEAN_TS" +%s 2>/dev/null || echo "0")
elif [[ "$LAST_BACKUP" == *"Z" ]]; then
    # Parse as UTC — strip Z and use TZ=UTC so macOS date doesn't treat it as local MYT
    CLEAN_TS="${LAST_BACKUP%Z}"
    BACKUP_EPOCH=$(TZ=UTC date -j -f "%Y-%m-%dT%H:%M:%S" "$CLEAN_TS" +%s 2>/dev/null || echo "0")
elif [[ "$LAST_BACKUP" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{4}$ ]]; then
    # Format: YYYY-MM-DD-HHMM (e.g. 2026-06-17-0805)
    PARSED=$(echo "$LAST_BACKUP" | sed 's/-\([0-9][0-9]\)\([0-9][0-9]\)$/ \1:\2/')
    BACKUP_EPOCH=$(date -j -f "%Y-%m-%d %H:%M" "$PARSED" +%s 2>/dev/null || echo "0")
fi
NOW_EPOCH=$(date +%s)
AGE_HOURS=$(( (NOW_EPOCH - BACKUP_EPOCH) / 3600 ))

if [[ "$AGE_HOURS" -lt 25 ]] && [[ "$FILE_COUNT" -gt 0 ]]; then
    echo "BACKUP: healthy (snap: ${LAST_SNAP}, age: ${AGE_HOURS}h, size: ${BACKUP_SIZE}, files: ${FILE_COUNT})"
    exit 0
elif [[ "$AGE_HOURS" -ge 25 ]]; then
    echo "BACKUP: stale — last snap ${LAST_SNAP}, age ${AGE_HOURS}h (>25h limit)"
    exit 1
else
    echo "BACKUP: empty — no files in backup directory (${BACKUP_DIR}/workspace-incremental)"
    exit 1
fi
