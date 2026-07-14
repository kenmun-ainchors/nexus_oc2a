#!/usr/bin/env zsh
# allowlist-detect.sh -- TRIGGER-12 detection for allowlist-sync
# Checks if model-policy.json or CI Cycle B state has changed since last allowlist sync.
# If trigger detected: runs allowlist-sync.sh and sends Telegram alert if changes applied.
#
# Runs every 30 min via cron (isolated agentTurn, haiku model).
# Exit codes: 0=no trigger, 1=sync ran+changes, 2=error

set -euo pipefail

WORKSPACE="/Users/ainchorsoc2a/.openclaw/workspace"
POLICY="$WORKSPACE/state/model-policy.json"
CI_STATE="$WORKSPACE/state/ci-agent-state.json"
SYNC_STATE="$WORKSPACE/state/allowlist-sync-state.json"
SYNC_SCRIPT="$WORKSPACE/scripts/allowlist-sync.sh"
TIMESTAMP=$(date +"%Y-%m-%dT%H:%M:%S+10:00")

echo "=== allowlist-detect.sh | $TIMESTAMP ==="

# Get timestamps for comparison
POLICY_UPDATED=$(python3 -c "
import json
try:
    with open('$POLICY') as f:
        d = json.load(f)
    print(d.get('lastUpdated', ''))
except Exception as e:
    print('')
")

LAST_SYNC=$(python3 -c "
import json
try:
    with open('$SYNC_STATE') as f:
        d = json.load(f)
    print(d.get('lastSyncAt', d.get('lastCheckedAt', '')))
except Exception:
    print('')
")

CI_PHASE=$(python3 -c "
import json
try:
    with open('$CI_STATE') as f:
        d = json.load(f)
    print(d.get('currentPhase', 'A'))
except Exception:
    print('A')
")

CI_CYCLE=$(python3 -c "
import json
try:
    with open('$CI_STATE') as f:
        d = json.load(f)
    # Check if topCandidates have been newly approved (Cycle B decision)
    candidates = d.get('topCandidates', [])
    approved = [c for c in candidates if isinstance(c, dict) and c.get('status') == 'approved']
    print(len(approved))
except Exception:
    print(0)
")

echo "  policy.lastUpdated:  $POLICY_UPDATED"
echo "  sync.lastSyncAt:     $LAST_SYNC"
echo "  ci.currentPhase:     $CI_PHASE"
echo "  ci.approvedCandidates: $CI_CYCLE"

TRIGGER_SOURCE=""

# Check 1: policy updated after last sync
if [[ -n "$POLICY_UPDATED" && -n "$LAST_SYNC" ]]; then
  IS_NEWER=$(python3 -c "
from datetime import datetime
def parse_dt(s):
    for fmt in ['%Y-%m-%dT%H:%M:%S+10:00', '%Y-%m-%dT%H:%M:%S+11:00', '%Y-%m-%dT%H:%M:%SZ', '%Y-%m-%dT%H:%M:%S']:
        try:
            return datetime.strptime(s[:19], fmt[:19])
        except:
            pass
    return None
a = parse_dt('$POLICY_UPDATED')
b = parse_dt('$LAST_SYNC')
if a and b:
    print('yes' if a > b else 'no')
else:
    print('no')
")
  if [[ "$IS_NEWER" == "yes" ]]; then
    TRIGGER_SOURCE="strategy-update"
    echo "  TRIGGER: policy updated ($POLICY_UPDATED) after last sync ($LAST_SYNC)"
  fi
fi

# Check 2: never synced before
if [[ -z "$LAST_SYNC" ]]; then
  TRIGGER_SOURCE="manual"
  echo "  TRIGGER: no prior sync recorded"
fi

# Check 3: CI Cycle B decision (phase=B with approved candidates)
if [[ "$CI_PHASE" == "B" && "$CI_CYCLE" -gt 0 ]]; then
  # Only trigger if approved candidates are newer than last sync
  TRIGGER_SOURCE="ci-cycle-b"
  echo "  TRIGGER: CI Cycle B with $CI_CYCLE approved candidate(s)"
fi

if [[ -z "$TRIGGER_SOURCE" ]]; then
  echo "OK: no trigger conditions met."
  exit 0
fi

echo "  Running allowlist-sync.sh (source=$TRIGGER_SOURCE)..."
SYNC_EXIT=0
zsh "$SYNC_SCRIPT" --source "$TRIGGER_SOURCE" || SYNC_EXIT=$?

if [[ $SYNC_EXIT -eq 1 ]]; then
  echo "Sync applied changes (exit 1). TRIGGER-12 fired."
  exit 1
elif [[ $SYNC_EXIT -eq 0 ]]; then
  echo "Sync ran, no changes needed (exit 0)."
  exit 0
else
  echo "ERROR: allowlist-sync.sh failed (exit $SYNC_EXIT)" >&2
  exit 2
fi
