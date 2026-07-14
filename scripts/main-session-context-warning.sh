#!/usr/bin/env bash
# main-session-context-warning.sh — Early-warning context pressure monitor
#
# CHG-0840: Alerts Ken BEFORE the auto-reset watchdog triggers.
# Mirrors main-session-context-watchdog.sh logic but never resets.
#
# Detection:
#   - Queries openclaw sessions list --json for agentId=main and kind=direct
#   - Reads totalTokens, contextTokens, and estimates messages
#   - Warns at ~75% of 262k context limit (~196k tokens / ~270 messages / 75% ratio)
#
# Output:
#   - state/main-session-context-ok.json        → normal, below warning threshold
#   - state/main-session-context-warning.json   → warning threshold crossed
#
# Exit 0 on success, 1 on internal error.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="${WORKSPACE_ROOT:-/Users/ainchorsoc2a/.openclaw/workspace}"
OPENCLAW_BIN="${OPENCLAW_BIN:-/Users/ainchorsoc2a/local/bin/openclaw}"
STATE_DIR="$WORKSPACE_ROOT/state"
OK_FILE="$STATE_DIR/main-session-context-ok.json"
WARNING_FILE="$STATE_DIR/main-session-context-warning.json"

# 75% early-warning thresholds (CHG-0840)
# Auto-reset watchdog (CHG-0828) triggers at 180k/200msg/70%
MAX_TOTAL_TOKENS=196000         # ~75% of 262k context window
MAX_ESTIMATED_MESSAGES=270      # ~75% of the 359 overflow point
MAX_CONTEXT_RATIO=75            # percentage of contextTokens used
AVG_TOKENS_PER_MSG=750

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
AEST_TIMESTAMP=$(date +"%Y-%m-%dT%H:%M:%S%z")

find_dashboard_session() {
  $OPENCLAW_BIN sessions list --agent main --active 1440 --json 2>/dev/null
}

SESSION_JSON=$(find_dashboard_session) || {
  echo "ERROR: Failed to query sessions via openclaw CLI" >&2
  exit 1
}

SESSION_DATA=$(python3 -c "
import json, sys

data = json.loads(sys.stdin.read())
sessions = data.get('sessions', [])

dashboard = None
main_direct = None

for s in sessions:
    key = s.get('key', '')
    kind = s.get('kind', '')
    agent_id = s.get('agentId', '')
    if agent_id != 'main':
        continue
    if kind != 'direct':
        continue
    if 'dashboard' in key:
        if dashboard is None or s.get('updatedAt', 0) > dashboard.get('updatedAt', 0):
            dashboard = s
    elif key.endswith(':main') or key.endswith(':direct'):
        if main_direct is None or s.get('updatedAt', 0) > main_direct.get('updatedAt', 0):
            main_direct = s

selected = dashboard or main_direct
if selected is None:
    print('NO_DASHBOARD_SESSION')
    sys.exit(0)

result = {
    'sessionKey': selected.get('key', 'unknown'),
    'sessionId': selected.get('sessionId', 'unknown'),
    'totalTokens': selected.get('totalTokens', 0),
    'contextTokens': selected.get('contextTokens', 262144),
    'totalTokensFresh': selected.get('totalTokensFresh', False),
    'inputTokens': selected.get('inputTokens', 0),
    'outputTokens': selected.get('outputTokens', 0),
    'model': selected.get('model', 'unknown'),
    'kind': selected.get('kind', 'unknown'),
    'updatedAt': selected.get('updatedAt', 0),
    'source': 'dashboard' if dashboard is not None else 'main_direct'
}
print(json.dumps(result))
" <<< "$SESSION_JSON") || {
  echo "ERROR: Failed to parse session JSON" >&2
  exit 1
}

if [[ "$SESSION_DATA" == "NO_DASHBOARD_SESSION" ]]; then
  echo '{"timestamp":"'"$TIMESTAMP"'","status":"no_session","message":"No dashboard/webchat session found"}' > "$OK_FILE"
  exit 0
fi

SESSION_KEY=$(echo "$SESSION_DATA" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('sessionKey') or 'unknown')")
SESSION_ID=$(echo "$SESSION_DATA" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('sessionId') or 'unknown')")
TOTAL_TOKENS=$(echo "$SESSION_DATA" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('totalTokens') or 0)")
CONTEXT_TOKENS=$(echo "$SESSION_DATA" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('contextTokens') or 262144)")
MODEL_NAME=$(echo "$SESSION_DATA" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('model') or 'unknown')")

ESTIMATED_MESSAGES=$(( (TOTAL_TOKENS + AVG_TOKENS_PER_MSG - 1) / AVG_TOKENS_PER_MSG ))
if [[ "$CONTEXT_TOKENS" -gt 0 ]]; then
  CONTEXT_RATIO=$(( TOTAL_TOKENS * 100 / CONTEXT_TOKENS ))
else
  CONTEXT_RATIO=0
fi

WARNING=false
REASON=""

if [[ "$TOTAL_TOKENS" -ge "$MAX_TOTAL_TOKENS" ]]; then
  WARNING=true
  REASON="totalTokens ($TOTAL_TOKENS) >= $MAX_TOTAL_TOKENS"
elif [[ "$ESTIMATED_MESSAGES" -ge "$MAX_ESTIMATED_MESSAGES" ]]; then
  WARNING=true
  REASON="estimatedMessages ($ESTIMATED_MESSAGES) >= $MAX_ESTIMATED_MESSAGES"
elif [[ "$CONTEXT_RATIO" -ge "$MAX_CONTEXT_RATIO" ]]; then
  WARNING=true
  REASON="contextRatio ($CONTEXT_RATIO%) >= $MAX_CONTEXT_RATIO%"
fi

mkdir -p "$STATE_DIR"

if [[ "$WARNING" == "true" ]]; then
  cat > "$WARNING_FILE" <<EOF
{
  "timestamp": "$TIMESTAMP",
  "aestTimestamp": "$AEST_TIMESTAMP",
  "sessionKey": "$SESSION_KEY",
  "sessionId": "$SESSION_ID",
  "totalTokens": $TOTAL_TOKENS,
  "contextTokens": $CONTEXT_TOKENS,
  "contextRatio": $CONTEXT_RATIO,
  "estimatedMessages": $ESTIMATED_MESSAGES,
  "model": "$MODEL_NAME",
  "reason": "$REASON",
  "warningThresholds": {
    "totalTokens": $MAX_TOTAL_TOKENS,
    "estimatedMessages": $MAX_ESTIMATED_MESSAGES,
    "contextRatio": $MAX_CONTEXT_RATIO
  },
  "status": "warning",
  "nextAction": "Auto-reset watchdog (CHG-0828) will trigger at 180k tokens / 200 messages / 70%"
}
EOF
  echo "WARNING: Main session context pressure detected." >&2
  echo "  Session: $SESSION_KEY" >&2
  echo "  Reason: $REASON" >&2
  echo "  Tokens: $TOTAL_TOKENS / $CONTEXT_TOKENS ($CONTEXT_RATIO%), Est. msgs: $ESTIMATED_MESSAGES" >&2
  exit 0
else
  cat > "$OK_FILE" <<EOF
{
  "timestamp": "$TIMESTAMP",
  "aestTimestamp": "$AEST_TIMESTAMP",
  "sessionKey": "$SESSION_KEY",
  "sessionId": "$SESSION_ID",
  "totalTokens": $TOTAL_TOKENS,
  "contextTokens": $CONTEXT_TOKENS,
  "contextRatio": $CONTEXT_RATIO,
  "estimatedMessages": $ESTIMATED_MESSAGES,
  "model": "$MODEL_NAME",
  "status": "ok",
  "warningThresholds": {
    "totalTokens": $MAX_TOTAL_TOKENS,
    "estimatedMessages": $MAX_ESTIMATED_MESSAGES,
    "contextRatio": $MAX_CONTEXT_RATIO
  }
}
EOF
  rm -f "$WARNING_FILE"
  exit 0
fi
