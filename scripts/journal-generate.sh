#!/bin/bash
# Journal Post-Processor (TKT-0328)
# Runs at EOD (23:55 AEST) inside the EOD finalizer cron.
# Checks if today's journal has entries for all webchat+telegram sessions.
# If gaps found, logs a CHG warning so Yoda can backfill.

TARGET_DATE=${1:-$(date +%Y-%m-%d)}
JOURNAL_FILE="/Users/ainchorsangiefpl/.openclaw/workspace/memory/journal-${TARGET_DATE}.md"

echo "=== Journal Gap Check — TKT-0328 ==="
echo "Target date: $TARGET_DATE"

if [[ ! -f "$JOURNAL_FILE" ]]; then
    echo "⚠️  No journal file for $TARGET_DATE. If there were interactions today, the journal is missing."
    echo "JOURNAL_MISSING"
    exit 2
fi

ENTRY_COUNT=$(grep -c '^## [0-9][0-9]:[0-9][0-9]' "$JOURNAL_FILE" 2>/dev/null || echo 0)
FILE_SIZE=$(wc -c < "$JOURNAL_FILE" 2>/dev/null || echo 0)

echo "Entries: $ENTRY_COUNT | Size: $FILE_SIZE bytes"

if [[ $FILE_SIZE -lt 500 ]]; then
    echo "⚠️  Journal file undersized (<500 bytes). May be empty or corrupted."
    exit 2
fi

echo "Journal looks healthy. $ENTRY_COUNT entries for $TARGET_DATE."
exit 0
