#!/bin/bash
# ============================================================================
# OpenClaw Canonical Session Cleanup — CHG-0831
# ============================================================================
# Canonical retention handler. leverages OpenClaw `session.maintenance` config
# and `openclaw sessions cleanup --all-agents --enforce` for store-managed
# pruning. This is the PRIMARY retention tool; scripts/retention-cleanup.sh
# is now a fallback manual tool only.
#
# Usage:
#   bash scripts/run-openclaw-sessions-cleanup.sh          # dry-run only
#   bash scripts/run-openclaw-sessions-cleanup.sh --enforce # enforce mode
#   bash scripts/run-openclaw-sessions-cleanup.sh --report  # audit-only
# ============================================================================

set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE_ROOT="${SCRIPT_DIR}/.."
STATE_DIR="${WORKSPACE_ROOT}/state"
LOG_FILE="${STATE_DIR}/chg-0831-cleanup.log"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

ENFORCE=false
REPORT=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --enforce) ENFORCE=true; shift ;;
    --report)  REPORT=true;  shift ;;
    --help|-h)
      echo "Usage: $0 [--enforce] [--report]"
      echo "  (default)  dry-run — preview stale/cap cleanup, no changes"
      echo "  --enforce  apply maintenance now"
      echo "  --report   audit-only via dry-run, log results"
      exit 0
      ;;
    *) echo "ERROR: Unknown flag: $1" >&2; exit 1 ;;
  esac
done

# Ensure log directory exists
mkdir -p "$STATE_DIR"

# Helper: sanitize JSON output for logging
sanitize_json() {
  local raw="$1"
  python3 -c "
import json, sys
try:
    d = json.loads(sys.stdin.read())
    print(json.dumps(d))
except Exception:
    # Not valid JSON, pass through as-is
    sys.stdout.write(sys.stdin.read())
" <<< "$raw" 2>/dev/null || echo "$raw"
}

# ============================================================================
# Phase 1: Dry-run (always runs)
# ============================================================================
echo "=== Phase 1: Dry-run preview ==="
echo "Timestamp: $TIMESTAMP"
echo ""

DRY_RUN_OUTPUT=""
DRY_RUN_OUTPUT=$(openclaw sessions cleanup --dry-run --all-agents --json 2>&1) || {
  echo "WARNING: Dry-run failed, continuing with logs"
  DRY_RUN_OUTPUT='{"error":"dry-run failed"}'
}

echo "$DRY_RUN_OUTPUT" | python3 -m json.tool 2>/dev/null || echo "$DRY_RUN_OUTPUT"

# ============================================================================
# Phase 2: Enforce (only if --enforce flag set)
# ============================================================================
ENFORCE_OUTPUT=""
if [[ "$ENFORCE" == true ]]; then
  echo ""
  echo "=== Phase 2: Enforce cleanup ==="
  ENFORCE_OUTPUT=$(openclaw sessions cleanup --all-agents --enforce --json 2>&1) || {
    echo "WARNING: Enforce step failed, continuing"
    ENFORCE_OUTPUT='{"error":"enforce failed"}'
  }
  echo "$ENFORCE_OUTPUT" | python3 -m json.tool 2>/dev/null || echo "$ENFORCE_OUTPUT"
else
  echo ""
  echo "=== Phase 2: Skipped (no --enforce flag) ==="
fi

# ============================================================================
# Phase 3: Summary & Logging
# ============================================================================
echo ""
echo "=== Phase 3: Summary ==="

# Extract summary from dry-run JSON
DRY_SUMMARY=$(echo "$DRY_RUN_OUTPUT" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    if isinstance(d, list):
        total = len(d)
        summary = {'agents': total}
        for a in d:
            for k in a:
                if k != 'agentId':
                    summary[k] = summary.get(k, 0) + (a[k] if isinstance(a[k], (int,float)) else 0)
        print(json.dumps(summary))
    else:
        print(json.dumps(d))
except Exception as e:
    print(json.dumps({'parse_error': str(e)}))
" 2>/dev/null || echo '{"parse_error":"unknown"}')

ENF_SUMMARY=$(echo "$ENFORCE_OUTPUT" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    if isinstance(d, list):
        total = len(d)
        summary = {'agents': total}
        for a in d:
            for k in a:
                if k != 'agentId':
                    summary[k] = summary.get(k, 0) + (a[k] if isinstance(a[k], (int,float)) else 0)
        print(json.dumps(summary))
    else:
        print(json.dumps(d))
except Exception as e:
    print(json.dumps({'parse_error': str(e)}))
" 2>/dev/null || echo '{"parse_error":"unknown"}')

# Write log entry
LOG_ENTRY=$(cat << LOGEOF
{
  "timestamp": "$TIMESTAMP",
  "mode": "$([ "$ENFORCE" == true ] && echo 'enforce' || echo 'dry-run')",
  "dryRun": $DRY_SUMMARY,
  "enforce": $ENF_SUMMARY
}
LOGEOF
)

echo "$LOG_ENTRY" >> "$LOG_FILE"
echo ""
echo "Log appended to: $LOG_FILE"
echo "$LOG_ENTRY" | python3 -m json.tool 2>/dev/null
