#!/bin/bash
# journal-init.sh — Idempotent daily journal bootstrap (CHG-1793)
#
# Creates memory/journal-YYYY-MM-DD.md for today's Asia/Kuala_Lumpur date
# if it does not already exist. Prevents tz-drift-monitor.sh (CHG-0913)
# from firing `journal_date_mismatch` before any human activity in the
# morning grace window (00:05–00:30 +08).
#
# Contract (per task spec):
#   - Writes header "# Journal YYYY-MM-DD\n\n" on first create.
#   - Idempotent: re-runs are no-ops.
#   - Resolves WORKSPACE from script location (no hard-coded user home).
#   - Exits 0 always (idempotent success is the success path).

set -euo pipefail

WORKSPACE="$(cd "$(dirname "$0")/.." && pwd)"
DATE=$(TZ=Asia/Kuala_Lumpur date +%Y-%m-%d)
JOURNAL_FILE="$WORKSPACE/memory/journal-${DATE}.md"

mkdir -p "$(dirname "$JOURNAL_FILE")"

if [[ -f "$JOURNAL_FILE" ]]; then
  echo "JOURNAL_INIT_NOOP: $JOURNAL_FILE already exists (idempotent)"
  exit 0
fi

cat > "$JOURNAL_FILE" <<HEADER_EOF
# Journal ${DATE}

HEADER_EOF

echo "JOURNAL_INIT_OK: created $JOURNAL_FILE"
