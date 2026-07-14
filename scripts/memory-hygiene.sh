#!/usr/bin/env bash
# memory-hygiene.sh — Daily Memory Hygiene sweep
# Cleans old state files, archived memory, and stale backups
# Created 2026-05-18 (CHG-0400) — script was missing, cron 0afc4d20 was failing silently

set -euo pipefail

WORKSPACE="/Users/ainchorsoc2a/.openclaw/workspace"
cd "$WORKSPACE"

CLEANED=0
REMOVED=0

# 1. Remove memory archive files older than 90 days
if [[ -d state/memory-archive ]]; then
    COUNT=$(find state/memory-archive -name "*.md" -mtime +90 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$COUNT" -gt 0 ]]; then
        find state/memory-archive -name "*.md" -mtime +90 -delete
        REMOVED=$((REMOVED + COUNT))
    fi
fi

# 2. Remove old cost-state backups older than 30 days
if compgen -G "state/cost-state.json.bak-*" > /dev/null 2>&1; then
    COUNT=$(find state -name "cost-state.json.bak-*" -mtime +30 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$COUNT" -gt 0 ]]; then
        find state -name "cost-state.json.bak-*" -mtime +30 -delete
        REMOVED=$((REMOVED + COUNT))
    fi
fi

# 3. Clean tmp files older than 48 hours
if [[ -d tmp ]]; then
    COUNT=$(find tmp -type f -mtime +2 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$COUNT" -gt 0 ]]; then
        find tmp -type f -mtime +2 -delete
        CLEANED=$((CLEANED + COUNT))
    fi
fi

if [[ $REMOVED -gt 0 ]] || [[ $CLEANED -gt 0 ]]; then
    echo "HYGIENE: ${CLEANED} files cleaned, ${REMOVED} removed"
else
    echo "HYGIENE: no cleanup needed"
fi

exit 0
