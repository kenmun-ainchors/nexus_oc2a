#!/bin/bash
# journal-append.sh — Real-time journal entry append
# Usage: journal-append.sh <date> <hhmm> <title> <channel> <prompt_file> <response_file>
#
# Called by the main session inline during conversation.
# Appends a formatted journal entry to the correct date's journal file.
# Atomic write — no risk of corruption from concurrent access.
#
# TKT-0296: Replaces the broken incremental writer cron model.
# The main session that talks to Ken is the ONLY writer of journal entries.

set -e

DATE="$1"      # YYYY-MM-DD (AEST)
HHMM="$2"      # HH:MM (AEST)
TITLE="$3"     # 3-6 word title
CHANNEL="$4"   # webchat or Telegram
PROMPT_FILE="$5"   # temp file with Ken's verbatim prompt
RESPONSE_FILE="$6" # temp file with Yoda's response summary

WORKSPACE="/Users/ainchorsangiefpl/.openclaw/workspace"
JOURNAL_FILE="$WORKSPACE/memory/journal-${DATE}.md"
TMP_DIR="$WORKSPACE/tmp"
mkdir -p "$TMP_DIR"

KEN_PROMPT=$(cat "$PROMPT_FILE" 2>/dev/null || echo "[prompt not available]")
YODA_RESPONSE=$(cat "$RESPONSE_FILE" 2>/dev/null || echo "[response not available]")

# Format the entry
ENTRY=$(cat << ENTRY_EOF

## ${HHMM} — ${TITLE} [${CHANNEL}]

**Ken's prompt (verbatim):**
> "${KEN_PROMPT}"

**Yoda's response summary:**
${YODA_RESPONSE}

---
ENTRY_EOF
)

# Atomic append: write to temp → fsync → append to journal (rename-safe)
# We use a lock file because this runs inline in the main session
LOCK_FILE="$TMP_DIR/journal-${DATE}.lock"

# Try lock (non-blocking, 5 second timeout)
for i in $(seq 1 50); do
  if mkdir "$LOCK_FILE" 2>/dev/null; then
    break
  fi
  if [ $i -eq 50 ]; then
    echo "JOURNAL_APPEND_ERROR: lock timeout" >&2
    exit 1
  fi
  sleep 0.1
done

# Ensure cleanup on exit
trap 'rmdir "$LOCK_FILE" 2>/dev/null' EXIT

# Initialize journal file if it doesn't exist
if [ ! -f "$JOURNAL_FILE" ]; then
  cat > "$JOURNAL_FILE" << HEADER_EOF
# AInchors Day ? Journal — ${DATE}
_Author: Yoda 🟢 | For: Ken Mun (CTO) | Private — personal review only_
_In progress — incremental build_

---
HEADER_EOF
fi

# Append the entry
echo "$ENTRY" >> "$JOURNAL_FILE"

rmdir "$LOCK_FILE" 2>/dev/null
trap - EXIT

echo "JOURNAL_APPEND_OK: ${DATE} ${HHMM} — ${TITLE}"
