#!/bin/bash
# journal-append.sh — Real-time journal entry append (v2.0)
# Usage: journal-append.sh "<title>" "<summary>"
#
# Called by the main session inline after every meaningful exchange.
# Date and time are auto-derived. Content is passed directly — no temp files.
# Atomic write via mkdir lock — safe for concurrent access.
#
# TKT-0296 v2.0: Simplified from 6-arg temp-file model to 2-arg inline model.
# v1.0 was never being called because 6 args + temp files was too heavy.
# v2.0: just title + summary, always callable in a single exec.
#
# CHG-0475

set -euo pipefail

TITLE="${1:-}"
SUMMARY="${2:-}"
WORKSPACE="/Users/ainchorsangiefpl/.openclaw/workspace"
LOCK_DIR="$WORKSPACE/tmp/journal-append.lock"

if [[ -z "$TITLE" || -z "$SUMMARY" ]]; then
  echo "Usage: journal-append.sh \"<title>\" \"<summary>\"" >&2
  exit 1
fi

# Date/time in AEST
DATE=$(TZ=Australia/Melbourne date +%Y-%m-%d)
HHMM=$(TZ=Australia/Melbourne date +%H:%M)
JOURNAL_FILE="$WORKSPACE/memory/journal-${DATE}.md"

mkdir -p "$(dirname "$JOURNAL_FILE")" "$(dirname "$LOCK_DIR")"

# ── Lock (mkdir is atomic on macOS) ────────────────────────────────────────
for i in $(seq 1 50); do
  if mkdir "$LOCK_DIR" 2>/dev/null; then
    trap 'rmdir "$LOCK_DIR" 2>/dev/null' EXIT
    break
  fi
  if [[ $i -eq 50 ]]; then
    echo "JOURNAL_APPEND_ERROR: lock timeout" >&2
    exit 1
  fi
  sleep 0.1
done

# ── Initialize if needed ───────────────────────────────────────────────────
if [[ ! -f "$JOURNAL_FILE" ]]; then
  cat > "$JOURNAL_FILE" << HEADER_EOF
# AInchors Day ? Journal — ${DATE}
_Author: Yoda 🟢 | For: Ken Mun (CTO) | Private — personal review only_
_In progress — incremental build_

---
HEADER_EOF
fi

# ── Append entry ───────────────────────────────────────────────────────────
cat >> "$JOURNAL_FILE" << ENTRY_EOF

## ${HHMM} — ${TITLE}

${SUMMARY}

---
ENTRY_EOF

rmdir "$LOCK_DIR" 2>/dev/null
trap - EXIT

echo "JOURNAL_OK: ${DATE} ${HHMM} — ${TITLE}"
