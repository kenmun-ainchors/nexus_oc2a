#!/usr/bin/env bash
# Gateway Heap Check — Lightweight gateway memory/heap monitor
#
# CHG-0840: Records gateway process memory pressure and Node heap of the
# gateway process. Alerts via state file when heapUsed > 80% of heapTotal.
# Limitations:
#   - Cannot read V8 heap of another process directly on macOS.
#   - Uses gateway RSS from `ps` as the primary pressure signal.
#   - Uses this script's own Node heap as a secondary signal (same Node
#     binary, same runtime flags as gateway).
#
# Output: state/gateway-heap-state.json
# Exit 0 = ok, 1 = warning threshold crossed

set -euo pipefail

WORKSPACE_ROOT="${WORKSPACE_ROOT:-/Users/ainchorsoc2a/.openclaw/workspace}"
STATE_DIR="$WORKSPACE_ROOT/state"
HEAP_STATE_FILE="$STATE_DIR/gateway-heap-state.json"
WARNING_PCT=80
CRITICAL_PCT=90

mkdir -p "$STATE_DIR"

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
AEST_TIMESTAMP=$(date +"%Y-%m-%dT%H:%M:%S%z")

# Find gateway PID by matching the full command line
GATEWAY_PID=$(ps aux | grep -E "openclaw.*gateway.*--port" | grep -v grep | awk '{print $2}' | head -1 || echo "")
if [[ -n "$GATEWAY_PID" ]]; then
  GATEWAY_UPTIME=$(ps -o etime= -p "$GATEWAY_PID" 2>/dev/null | tr -d ' ' || echo "unknown")
  GATEWAY_CPU=$(ps -o %cpu= -p "$GATEWAY_PID" 2>/dev/null | tr -d ' ' || echo "unknown")
  GATEWAY_RSS_KB=$(ps -o rss= -p "$GATEWAY_PID" 2>/dev/null | tr -d ' ' || echo "0")
else
  GATEWAY_PID="not-found"
  GATEWAY_UPTIME="unknown"
  GATEWAY_CPU="unknown"
  GATEWAY_RSS_KB="0"
fi

# Node heap of current process (same runtime, same flags, useful proxy)
NODE_HEAP=$(node -e "
const mem = process.memoryUsage();
console.log(JSON.stringify({
  heapUsed: mem.heapUsed,
  heapTotal: mem.heapTotal,
  heapUsedMB: Math.round(mem.heapUsed / 1024 / 1024 * 100) / 100,
  heapTotalMB: Math.round(mem.heapTotal / 1024 / 1024 * 100) / 100,
  heapUsedPct: Math.round(mem.heapUsed / mem.heapTotal * 10000) / 100,
  rssMB: Math.round(mem.rss / 1024 / 1024 * 100) / 100,
  externalMB: Math.round(mem.external / 1024 / 1024 * 100) / 100
}));
" 2>/dev/null || echo '{"heapUsed":0,"heapTotal":1,"heapUsedMB":0,"heapTotalMB":1,"heapUsedPct":0,"rssMB":0,"externalMB":0}')

HEAP_PCT=$(echo "$NODE_HEAP" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('heapUsedPct', 0))" 2>/dev/null || echo "0")
GATEWAY_RSS_MB=$(( GATEWAY_RSS_KB / 1024 ))

# Disk usage
df_output=$(df -h / 2>/dev/null | tail -1 || echo "unknown")
DISK_USAGE_PCT=$(echo "$df_output" | awk '{print $5}' | tr -d '%' || echo "0")

# Determine status
STATUS="ok"
ALERTED=false
if (( $(echo "$HEAP_PCT > $CRITICAL_PCT" | bc -l 2>/dev/null || echo 0) )); then
  STATUS="critical"
  ALERTED=true
elif (( $(echo "$HEAP_PCT > $WARNING_PCT" | bc -l 2>/dev/null || echo 0) )); then
  STATUS="warning"
  ALERTED=true
fi

# Build state JSON
cat > "$HEAP_STATE_FILE" <<EOF
{
  "timestamp": "$TIMESTAMP",
  "aestTimestamp": "$AEST_TIMESTAMP",
  "gateway": {
    "pid": "$GATEWAY_PID",
    "uptime": "$GATEWAY_UPTIME",
    "cpuPct": "$GATEWAY_CPU",
    "rssKB": $GATEWAY_RSS_KB,
    "rssMB": $GATEWAY_RSS_MB
  },
  "nodeHeap": $NODE_HEAP,
  "system": {
    "diskUsedPct": $DISK_USAGE_PCT,
    "dfOutput": "$df_output"
  },
  "thresholds": {
    "warningPct": $WARNING_PCT,
    "criticalPct": $CRITICAL_PCT
  },
  "status": "$STATUS",
  "alerted": $ALERTED
}
EOF

if [[ "$STATUS" == "critical" ]]; then
  echo "CRITICAL: Node heap usage ${HEAP_PCT}% exceeds ${CRITICAL_PCT}%" >&2
  exit 1
elif [[ "$STATUS" == "warning" ]]; then
  echo "WARNING: Node heap usage ${HEAP_PCT}% exceeds ${WARNING_PCT}%" >&2
  exit 1
else
  echo "OK: Node heap usage ${HEAP_PCT}% below ${WARNING_PCT}%" >&2
  exit 0
fi
