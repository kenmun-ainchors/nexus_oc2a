#!/usr/bin/env bash
# main-session-context-watchdog.sh — Monitor and auto-reset main dashboard session context
#
# CHG-0828: Prevents context overflow (CHG-0818) in the agent:main:dashboard:* webchat session.
# Runs every heartbeat (30 min). Idempotent. Safe to run at any frequency.
#
# Detection:
#   - Queries openclaw sessions list --json for sessions with agentId=main and kind=direct
#   - Identifies the dashboard/webchat session (key matching agent:main:dashboard:* or kind=direct from webchat origin)
#   - Reads totalTokens, contextTokens, and estimates messages from totalTokens / avgTokensPerMsg
#   - Checks three thresholds: totalTokens >= 180000, estimated messages >= 200, context ratio >= 70%
#
# Reset:
#   - If threshold crossed: writes state/main-session-context-reset.json with evidence
#   - Resets via openclaw sessions compact <key> --max-lines 200 (graceful truncation)
#   - Does NOT restart gateway. Session-level only.
#
# Output:
#   - state/main-session-context-ok.json  → normal, below threshold
#   - state/main-session-context-reset.json → overflow detected and reset
#   Exit 0 on success, 1 on internal error.
#
# Usage:
#   bash scripts/main-session-context-watchdog.sh [--dry-run]
#   --dry-run: print what would happen without actually resetting

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="${WORKSPACE_ROOT:-/Users/ainchorsoc2a/.openclaw/workspace}"
OPENCLAW_BIN="${OPENCLAW_BIN:-/Users/ainchorsoc2a/local/bin/node /Users/ainchorsoc2a/local/lib/node_modules/openclaw/dist/index.js}"
STATE_DIR="$WORKSPACE_ROOT/state"
OK_FILE="$STATE_DIR/main-session-context-ok.json"
RESET_FILE="$STATE_DIR/main-session-context-reset.json"

# ── Thresholds ────────────────────────────────────────────────────────────────
# CHG-0818: overflow occurred at 359 messages / 262145 tokens / ~100% context
# Safe thresholds (below the 262144 contextTokens ceiling with margin)
MAX_TOTAL_TOKENS=180000         # ~69% of 262k context window
MAX_ESTIMATED_MESSAGES=200      # far below the 359 overflow point
MAX_CONTEXT_RATIO=70            # percentage of contextTokens used

# Average tokens per message heuristic (for estimation when exact counts unavailable)
AVG_TOKENS_PER_MSG=750

# ── Flags ────────────────────────────────────────────────────────────────────
DRY_RUN=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    *) shift ;;
  esac
done

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
LOCAL_TIMESTAMP=$(date +"%Y-%m-%dT%H:%M:%S%z")

# ── Find the main dashboard/webchat session ──────────────────────────────────
# We look at the most recently updated sessions for agent=main with kind=direct
# and a key matching agent:main:dashboard:* or the most recent direct session.
find_dashboard_session() {
  $OPENCLAW_BIN sessions list --agent main --active 1440 --json 2>/dev/null
}

SESSION_JSON=$(find_dashboard_session) || {
  echo "ERROR: Failed to query sessions via openclaw CLI" >&2
  exit 1
}

# Parse session data using python3 (available in the environment)
SESSION_DATA=$(python3 -c "
import json, sys

data = json.loads(sys.stdin.read())
sessions = data.get('sessions', [])

# Prefer dashboard session (agent:main:dashboard:*)
# Fall back to most recent kind=direct session (agent:main:main)
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

# Extract fields
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
  echo "INFO: No dashboard/webchat session found for agent=main" >&2
  echo '{"timestamp":"'"$TIMESTAMP"'","status":"no_session","message":"No dashboard/webchat session found"}' > "$OK_FILE"
  exit 0
fi

SESSION_KEY=$(echo "$SESSION_DATA" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('sessionKey') or 'unknown')")
SESSION_ID=$(echo "$SESSION_DATA" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('sessionId') or 'unknown')")
TOTAL_TOKENS=$(echo "$SESSION_DATA" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('totalTokens') or 0)")
CONTEXT_TOKENS=$(echo "$SESSION_DATA" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('contextTokens') or 262144)")
INPUT_TOKENS=$(echo "$SESSION_DATA" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('inputTokens') or 0)")
OUTPUT_TOKENS=$(echo "$SESSION_DATA" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('outputTokens') or 0)")
MODEL_NAME=$(echo "$SESSION_DATA" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('model') or 'unknown')")
SESSION_SOURCE=$(echo "$SESSION_DATA" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('source') or 'unknown')")

# ── Compute derived metrics ─────────────────────────────────────────────────
# Estimated messages: totalTokens / avgTokensPerMsg (rounded up)
ESTIMATED_MESSAGES=$(( (TOTAL_TOKENS + AVG_TOKENS_PER_MSG - 1) / AVG_TOKENS_PER_MSG ))
# Context ratio: percentage of contextTokens used
if [[ "$CONTEXT_TOKENS" -gt 0 ]]; then
  CONTEXT_RATIO=$(( TOTAL_TOKENS * 100 / CONTEXT_TOKENS ))
else
  CONTEXT_RATIO=0
fi

# ── Threshold check ──────────────────────────────────────────────────────────
OVERFLOW=false
REASON=""

if [[ "$TOTAL_TOKENS" -ge "$MAX_TOTAL_TOKENS" ]]; then
  OVERFLOW=true
  REASON="totalTokens ($TOTAL_TOKENS) >= $MAX_TOTAL_TOKENS"
elif [[ "$ESTIMATED_MESSAGES" -ge "$MAX_ESTIMATED_MESSAGES" ]]; then
  OVERFLOW=true
  REASON="estimatedMessages ($ESTIMATED_MESSAGES) >= $MAX_ESTIMATED_MESSAGES"
elif [[ "$CONTEXT_RATIO" -ge "$MAX_CONTEXT_RATIO" ]]; then
  OVERFLOW=true
  REASON="contextRatio ($CONTEXT_RATIO%) >= $MAX_CONTEXT_RATIO%"
fi

# ── Dry-run output ──────────────────────────────────────────────────────────
if [[ "$DRY_RUN" == "true" ]]; then
  echo "=== DRY RUN ==="
  echo "Session Key:     $SESSION_KEY"
  echo "Session ID:      $SESSION_ID"
  echo "Source:          $SESSION_SOURCE"
  echo "Model:           $MODEL_NAME"
  echo "Total Tokens:    $TOTAL_TOKENS"
  echo "Context Tokens:  $CONTEXT_TOKENS"
  echo "Context Ratio:   $CONTEXT_RATIO%"
  echo "Input Tokens:    $INPUT_TOKENS"
  echo "Output Tokens:   $OUTPUT_TOKENS"
  echo "Est. Messages:   $ESTIMATED_MESSAGES"
  echo "Thresholds:"
  echo "  totalTokens >= $MAX_TOTAL_TOKENS:  $([ "$TOTAL_TOKENS" -ge "$MAX_TOTAL_TOKENS" ] && echo YES || echo no)"
  echo "  messages >= $MAX_ESTIMATED_MESSAGES: $([ "$ESTIMATED_MESSAGES" -ge "$MAX_ESTIMATED_MESSAGES" ] && echo YES || echo no)"
  echo "  contextRatio >= $MAX_CONTEXT_RATIO%:  $([ "$CONTEXT_RATIO" -ge "$MAX_CONTEXT_RATIO" ] && echo YES || echo no)"
  echo "Overflow:        $OVERFLOW"
  echo "Reason:          ${REASON:-N/A}"
  if [[ "$OVERFLOW" == "true" ]]; then
    echo "Would reset:     YES (openclaw sessions compact \"$SESSION_KEY\" --max-lines 200)"
  else
    echo "Would reset:     no"
  fi
  exit 0
fi

# ── Write state file and optionally reset ────────────────────────────────────
mkdir -p "$STATE_DIR"

if [[ "$OVERFLOW" == "true" ]]; then
  # ── Overflow detected — write reset event and reset session ────────────────
  RESET_PAYLOAD=$(cat << EOF
{
  "timestamp": "$TIMESTAMP",
  "localTimestamp": "$LOCAL_TIMESTAMP",
  "sessionKey": "$SESSION_KEY",
  "sessionId": "$SESSION_ID",
  "totalTokens": $TOTAL_TOKENS,
  "contextTokens": $CONTEXT_TOKENS,
  "contextRatio": $CONTEXT_RATIO,
  "estimatedMessages": $ESTIMATED_MESSAGES,
  "model": "$MODEL_NAME",
  "reason": "$REASON",
  "resetAction": "compact --max-lines 200",
  "status": "reset"
}
EOF
)
  echo "$RESET_PAYLOAD" > "$RESET_FILE"
  echo "WARNING: Main session context overflow detected. Resetting." >&2
  echo "  Session: $SESSION_KEY" >&2
  echo "  Reason: $REASON" >&2
  echo "  Tokens: $TOTAL_TOKENS / $CONTEXT_TOKENS ($CONTEXT_RATIO%), Est. msgs: $ESTIMATED_MESSAGES" >&2

  # ── Reset the session via openclaw sessions compact ───────────────────────
  # Keeps the last 200 lines of transcript, which is enough for meaningful
  # continuation but frees the context budget.
  if $OPENCLAW_BIN sessions compact "$SESSION_KEY" --agent main --max-lines 200 --json 2>/dev/null; then
    echo "SUCCESS: Session compacted: $SESSION_KEY" >&2
  else
    echo "ERROR: Session compact failed for $SESSION_KEY" >&2
    # Update the reset file with the failure
    python3 -c "
import json
with open('$RESET_FILE') as f:
    d = json.load(f)
d['resetAction'] = 'compact FAILED'
d['status'] = 'reset_failed'
with open('$RESET_FILE', 'w') as f:
    json.dump(d, f, indent=2)
" 2>/dev/null || true
    exit 1
  fi
else
  # ── Below threshold — write ok state ──────────────────────────────────────
  OK_PAYLOAD=$(cat << EOF
{
  "timestamp": "$TIMESTAMP",
  "localTimestamp": "$LOCAL_TIMESTAMP",
  "sessionKey": "$SESSION_KEY",
  "sessionId": "$SESSION_ID",
  "totalTokens": $TOTAL_TOKENS,
  "contextTokens": $CONTEXT_TOKENS,
  "contextRatio": $CONTEXT_RATIO,
  "estimatedMessages": $ESTIMATED_MESSAGES,
  "model": "$MODEL_NAME",
  "status": "ok"
}
EOF
)
  echo "$OK_PAYLOAD" > "$OK_FILE"
  # Remove any stale reset file (cleanup)
  rm -f "$RESET_FILE"
fi

exit 0