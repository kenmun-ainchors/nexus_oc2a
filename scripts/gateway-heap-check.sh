#!/usr/bin/env bash
# Gateway Heap Check — Lightweight gateway memory/heap monitor
#
# CHG-0901: Measures the REAL gateway process memory, not the short-lived
# `node -e` process that this script spawns.
#
# Strategy (in order of preference):
#   1. Find the gateway PID via lsof on the configured port (18789). This is
#      the actual node process started by launchd that users talk to. PID is
#      then confirmed by command-line match on the openclaw gateway binary.
#   2. Use `ps -o rss=` on that PID as the primary pressure signal. Absolute
#      MB thresholds (warn > 2048 MB, critical > 4096 MB) on this 48 GB
#      machine are used. RSS is what matters for "is the host OOMing?", and
#      it's the only signal you can get cross-process on macOS without
#      elevated privileges or a debugger attach.
#   3. V8 heap (heapUsed/heapTotal) of the gateway process is NOT reported
#      here — the previous version measured the script's own ~4 MB node heap
#      and labeled it "the gateway's heap", which was a S1-grade silent
#      structural defect (always reported critical because the script's own
#      process was near its ~4 MB default --max-old-space-size). V8 inspector
#      attach from a non-privileged `ps` context is not feasible without
#      adding a heavy dependency (e.g. chrome-remote-interface) and a CDP
#      port. So we drop the Node-heap comparison entirely and rely on RSS.
#   4. CPU%, uptime, and disk usage are reported as informational context.
#
# Output: state/gateway-heap-state.json
# Exit 0 = ok, 1 = warning or critical threshold crossed (auto-heal will see
# this as a non-zero status from cron and respond accordingly).
#
# Configured thresholds (48 GB machine):
#   WARN_RSS_MB=2048
#   CRIT_RSS_MB=4096

set -euo pipefail

WORKSPACE_ROOT="${WORKSPACE_ROOT:-/Users/ainchorsoc2a/.openclaw/workspace}"
STATE_DIR="$WORKSPACE_ROOT/state"
HEAP_STATE_FILE="$STATE_DIR/gateway-heap-state.json"
GATEWAY_PORT="${OPENCLAW_GATEWAY_PORT:-18789}"
WARN_RSS_MB=2048
CRIT_RSS_MB=4096

mkdir -p "$STATE_DIR"

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
AEST_TIMESTAMP=$(TZ="Australia/Sydney" date +"%Y-%m-%dT%H:%M:%S%z" 2>/dev/null || date +"%Y-%m-%dT%H:%M:%S%z")

# --- Find the REAL gateway PID -------------------------------------------------
# 1) Primary: lsof on the production port (most reliable — only one process
#    can LISTEN on a port at a time).
# 2) Fallback: ps grep on the openclaw gateway command line.
GATEWAY_PID=""
if command -v lsof >/dev/null 2>&1; then
  GATEWAY_PID=$(lsof -nP -iTCP:${GATEWAY_PORT} -sTCP:LISTEN 2>/dev/null \
    | awk 'NR>1 && $1 ~ /node/ {print $2; exit}')
fi
if [[ -z "$GATEWAY_PID" ]]; then
  GATEWAY_PID=$(ps -axo pid=,command= \
    | awk '$2 ~ /node/ && /openclaw.*gateway.*--port/ {print $1; exit}')
fi

# --- Read real process metrics ------------------------------------------------
if [[ -n "$GATEWAY_PID" ]] && ps -p "$GATEWAY_PID" >/dev/null 2>&1; then
  GATEWAY_UPTIME=$(ps -o etime= -p "$GATEWAY_PID" 2>/dev/null | tr -d ' ' || echo "unknown")
  GATEWAY_CPU=$(ps -o %cpu= -p "$GATEWAY_PID" 2>/dev/null | tr -d ' ' || echo "unknown")
  GATEWAY_RSS_KB=$(ps -o rss= -p "$GATEWAY_PID" 2>/dev/null | tr -d ' ' || echo "0")
  # V8 heap of the gateway itself is NOT measurable from a non-privileged
  # process context. Report nulls (not zeros) so downstream readers do not
  # confuse them with the script's own node heap.
  GATEWAY_HEAP_USED_MB="null"
  GATEWAY_HEAP_TOTAL_MB="null"
  GATEWAY_HEAP_USED_PCT="null"
else
  GATEWAY_PID="not-found"
  GATEWAY_UPTIME="unknown"
  GATEWAY_CPU="unknown"
  GATEWAY_RSS_KB="0"
  GATEWAY_HEAP_USED_MB="null"
  GATEWAY_HEAP_TOTAL_MB="null"
  GATEWAY_HEAP_USED_PCT="null"
fi

GATEWAY_RSS_MB=$(( GATEWAY_RSS_KB / 1024 ))

# --- Determine status from real RSS ------------------------------------------
# If PID is not found, that's a critical problem — gateway is not listening.
STATUS="ok"
ALERTED=false
REASON="rss ${GATEWAY_RSS_MB}MB within thresholds (warn=${WARN_RSS_MB}MB, crit=${CRIT_RSS_MB}MB)"

if [[ "$GATEWAY_PID" == "not-found" ]]; then
  STATUS="critical"
  ALERTED=true
  REASON="gateway process not found on port ${GATEWAY_PORT}"
elif [[ "$GATEWAY_RSS_MB" -ge "$CRIT_RSS_MB" ]]; then
  STATUS="critical"
  ALERTED=true
  REASON="gateway RSS ${GATEWAY_RSS_MB}MB >= critical ${CRIT_RSS_MB}MB"
elif [[ "$GATEWAY_RSS_MB" -ge "$WARN_RSS_MB" ]]; then
  STATUS="warning"
  ALERTED=true
  REASON="gateway RSS ${GATEWAY_RSS_MB}MB >= warning ${WARN_RSS_MB}MB"
fi

# --- Informational: this script's own node heap --------------------------------
# Kept as a sanity check (does the script's own node even start?) but NOT
# used for status determination. Node CLI default heap is small (~4 MB) so
# the percentage is misleading and was the root cause of the prior false
# alarms (CHG-0901).
SELF_NODE_HEAP=$(node -e '
const mem = process.memoryUsage();
console.log(JSON.stringify({
  heapUsedMB: Math.round(mem.heapUsed / 1024 / 1024 * 100) / 100,
  heapTotalMB: Math.round(mem.heapTotal / 1024 / 1024 * 100) / 100,
  rssMB: Math.round(mem.rss / 1024 / 1024 * 100) / 100,
  note: "this is the scripts own short-lived node -e process, NOT the gateway"
}));
' 2>/dev/null || echo '{"heapUsedMB":0,"heapTotalMB":0,"rssMB":0,"note":"node -e failed"}')

df_output=$(df -h / 2>/dev/null | tail -1 || echo "unknown")
DISK_USAGE_PCT=$(echo "$df_output" | awk '{print $5}' | tr -d '%' || echo "0")

# --- Write state JSON ---------------------------------------------------------
cat > "$HEAP_STATE_FILE" <<EOF
{
  "timestamp": "$TIMESTAMP",
  "aestTimestamp": "$AEST_TIMESTAMP",
  "gateway": {
    "pid": "$GATEWAY_PID",
    "port": $GATEWAY_PORT,
    "uptime": "$GATEWAY_UPTIME",
    "cpuPct": "$GATEWAY_CPU",
    "rssKB": $GATEWAY_RSS_KB,
    "rssMB": $GATEWAY_RSS_MB,
    "heapUsedMB": $GATEWAY_HEAP_USED_MB,
    "heapTotalMB": $GATEWAY_HEAP_TOTAL_MB,
    "heapUsedPct": $GATEWAY_HEAP_USED_PCT,
    "heapMeasurement": "rss-only (v8-inspector not attached; CHG-0901)"
  },
  "selfNodeHeap": $SELF_NODE_HEAP,
  "system": {
    "diskUsedPct": $DISK_USAGE_PCT,
    "dfOutput": "$df_output"
  },
  "thresholds": {
    "warnRssMB": $WARN_RSS_MB,
    "critRssMB": $CRIT_RSS_MB
  },
  "status": "$STATUS",
  "alerted": $ALERTED,
  "reason": "$REASON",
  "chgRef": "CHG-0901"
}
EOF

# --- Emit to stderr for cron logs and exit with appropriate code --------------
case "$STATUS" in
  critical)
    echo "CRITICAL: $REASON" >&2
    exit 1
    ;;
  warning)
    echo "WARNING: $REASON" >&2
    exit 1
    ;;
  ok)
    echo "OK: $REASON (pid=$GATEWAY_PID, rss=${GATEWAY_RSS_MB}MB)" >&2
    exit 0
    ;;
esac
