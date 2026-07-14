#!/usr/bin/env bash
# nightly-restart-verify.sh — Post-restart verification (runs ~03:05 AEST)
# Created 2026-05-19 (CHG-0411)
#
# Checks:
# 1. Does the restart marker exist? (if not, restart cron didn't fire — silent exit)
# 2. Is the gateway alive?
#    - YES: clear marker, output success summary → cron delivers to Telegram
#    - NO:  output failure alert → cron delivers to Telegram

set -euo pipefail

MARKER="/Users/ainchorsoc2a/.openclaw/workspace/state/nightly-restart-marker.json"

if [[ ! -f "$MARKER" ]]; then
    echo "OK — no restart marker found, nothing to verify."
    exit 0
fi

TRIGGERED=$JQ -r '.triggeredAt' "$MARKER" 2>/dev/null || echo "unknown")

# Check gateway health
if curl -sf -o /dev/null --max-time 5 http://localhost:18789/health 2>/dev/null; then
    PID=$(pgrep -f "openclaw.*gateway" | head -1 || echo "unknown")
    UPTIME=$(ps -o etime= -p "$PID" 2>/dev/null | xargs || echo "unknown")

    # Success! Clear marker
    SNAPSHOT_DIR=$JQ -r '.snapshotDir // "unknown"' "$MARKER" 2>/dev/null || echo "unknown")
    rm -f "$MARKER"

    cat <<EOF
✅ **Nightly Gateway Restart — SUCCESS**

| Item | Value |
|---|---|
| Triggered | ${TRIGGERED} |
| Verified | $(date -u +%Y-%m-%dT%H:%M:%SZ) |
| Gateway PID | ${PID} |
| Uptime | ${UPTIME} |
| Session snapshot | ${SNAPSHOT_DIR} |

Session transcripts snapshotted pre-restart. Marker cleared. All good.
EOF
    exit 0
else
    # Gateway is DOWN
    cat <<EOF
🚨 **Nightly Gateway Restart — FAILED**

| Item | Value |
|---|---|
| Triggered | ${TRIGGERED} |
| Checked at | $(date -u +%Y-%m-%dT%H:%M:%SZ) |
| Gateway | UNREACHABLE |

Marker preserved for investigation. Check OC1 manually.
EOF
    exit 1
fi
