#!/bin/zsh
# process-count-heartbeat.sh — Record process count + ulimit every 5 minutes
#
# CHG-0863 | CRESTv2-P1-EXEC-INTERCEPT-SCOPE-001 §5
#
# Records every 5 minutes:
#   - ISO8601 UTC timestamp
#   - ps aux | wc -l (trim whitespace)
#   - ulimit -u
#
# Appends to state/process-count-history.log in format:
#   YYYY-MM-DDTHH:MM:SSZ procs=NNN ulimit=MMMM
#
# Also writes current sample to state/process-count-current.json.
# On each write, trims entries older than 24h from the log.
#
# DoD:
#   - Heartbeat emits entry every 5 min confirmed over 30-minute window
#   - state/process-count-history.log holds 24h of samples with no gaps
#   - No heartbeat performance impact

set -euo pipefail

WORKSPACE="${WORKSPACE:-$HOME/.openclaw/workspace}"
HISTORY_LOG="$WORKSPACE/state/process-count-history.log"
CURRENT_JSON="$WORKSPACE/state/process-count-current.json"

# ── Gather metrics ──────────────────────────────────────────────────────────
TS_UTC=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
PROC_COUNT=$(ps aux 2>/dev/null | wc -l | tr -d ' ')
ULIMIT_U=$(ulimit -u 2>/dev/null || echo "unknown")

# ── Append to rolling log ───────────────────────────────────────────────────
# Format: YYYY-MM-DDTHH:MM:SSZ procs=NNN ulimit=MMMM
echo "$TS_UTC procs=$PROC_COUNT ulimit=$ULIMIT_U" >> "$HISTORY_LOG"

# ── Trim entries older than 24h ─────────────────────────────────────────────
# 24h ago in UTC epoch seconds
NOW_EPOCH=$(date -u +%s)
CUTOFF_EPOCH=$((NOW_EPOCH - 86400))

# Use a temp file for atomic trim
TRIM_TMP=$(mktemp -t pchb_trim.XXXXXX)
trap 'rm -f "$TRIM_TMP"' EXIT INT TERM

while IFS= read -r line; do
    # Extract timestamp from start of line
    TS_LINE=$(echo "$line" | cut -d' ' -f1)
    # Convert to epoch for comparison
    LINE_EPOCH=$(date -u -j -f '%Y-%m-%dT%H:%M:%SZ' "$TS_LINE" +%s 2>/dev/null || echo 0)
    if [[ "$LINE_EPOCH" -ge "$CUTOFF_EPOCH" ]]; then
        echo "$line" >> "$TRIM_TMP"
    fi
done < "$HISTORY_LOG"

mv "$TRIM_TMP" "$HISTORY_LOG"
trap - EXIT INT TERM

# ── Write current sample to JSON ────────────────────────────────────────────
cat > "$CURRENT_JSON" << JSONEOF
{"ts":"$TS_UTC","process_count":$PROC_COUNT,"ulimit_u":$ULIMIT_U}
JSONEOF

# ── Log success (stderr so it doesn't pollute stdout if called from cron) ───
echo "[process-heartbeat] $TS_UTC procs=$PROC_COUNT ulimit=$ULIMIT_U — $(wc -l < "$HISTORY_LOG" | tr -d ' ') entries in history" >&2
