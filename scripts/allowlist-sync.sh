#!/usr/bin/env zsh
# allowlist-sync.sh -- Agent Allowlist Sync Engine
# Propagates approved Tier 2 cloud models to per-agent allowedInCrons based on
# model-policy.json tierStrategy + per-agent eligibility matrix.
#
# Triggers:
#   CI Cycle B decision (new models approved/deprecated by CI process)
#   Model strategy update (tierStrategy or globalAllowedModels changed)
#   Manual: zsh scripts/allowlist-sync.sh --source manual
#
# Usage:
#   zsh scripts/allowlist-sync.sh --source <ci-cycle-b|strategy-update|manual> [--dry-run]
#
# Exit codes:
#   0 = clean, no changes needed
#   1 = changes applied successfully
#   2 = error

set -euo pipefail

WORKSPACE="/Users/ainchorsangiefpl/.openclaw/workspace"
POLICY="$WORKSPACE/state/model-policy.json"
SYNC_STATE="$WORKSPACE/state/allowlist-sync-state.json"
CORE_PY="$WORKSPACE/scripts/allowlist_sync_core.py"
CHANGELOG_SCRIPT="$WORKSPACE/scripts/changelog-append.sh"
TIMESTAMP=$(date +"%Y-%m-%dT%H:%M:%S+10:00")
DRY_RUN=false
SOURCE="manual"

# Parse args
while (( $# > 0 )); do
  case "$1" in
    --source)   SOURCE="$2"; shift 2 ;;
    --dry-run)  DRY_RUN=true; shift ;;
    *)          echo "Unknown arg: $1"; exit 2 ;;
  esac
done

echo "=== allowlist-sync.sh | source=$SOURCE | dry-run=$DRY_RUN | $TIMESTAMP ==="

# Validate inputs
if [[ ! -f "$POLICY" ]]; then
  echo "ERROR: model-policy.json not found at $POLICY" >&2
  exit 2
fi
if [[ ! -f "$CORE_PY" ]]; then
  echo "ERROR: allowlist_sync_core.py not found at $CORE_PY" >&2
  exit 2
fi

# Run core sync logic (dry-run first to get the diff)
RESULT=$(python3 "$CORE_PY" --policy "$POLICY" --timestamp "$TIMESTAMP" --source "$SOURCE" 2>&1)

HAS_CHANGES=$(echo "$RESULT" | python3 -c "import json,sys; d=json.load(sys.stdin); print(str(d['hasChanges']).lower())")
APPROVED_MODELS=$(echo "$RESULT" | python3 -c "import json,sys; d=json.load(sys.stdin); print(', '.join(d['approvedCloudModels']))")
CHANGE_COUNT=$(echo "$RESULT" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['changeCount'])")

echo "Approved Tier 2 cloud models: $APPROVED_MODELS"

if [[ "$HAS_CHANGES" == "false" ]]; then
  echo "OK: no changes needed -- all allowlists already current."
  # Update last-checked timestamp in sync state
  python3 - "$SYNC_STATE" "$TIMESTAMP" "$SOURCE" <<'PYEOF'
import json, sys
state_file, ts, source = sys.argv[1], sys.argv[2], sys.argv[3]
state = {}
try:
    with open(state_file) as f:
        state = json.load(f)
except Exception:
    pass
state.update({"lastCheckedAt": ts, "lastSource": source, "lastResult": "no-changes"})
with open(state_file, "w") as f:
    json.dump(state, f, indent=2)
PYEOF
  exit 0
fi

# Show what will change
CHANGES_SUMMARY=$(echo "$RESULT" | python3 -c "
import json,sys
d=json.load(sys.stdin)
for c in d['changes']:
    agent = c['agent']
    added = c.get('added', [])
    removed = c.get('removed', [])
    prohibited = c.get('prohibitedAdded', [])
    if added:
        print(f'  {agent}: +{added}')
    if removed:
        print(f'  {agent}: -{removed}')
    if prohibited:
        print(f'  {agent}: prohibitedInCrons+{prohibited}')
")

echo ""
echo "Changes detected ($CHANGE_COUNT):"
echo "$CHANGES_SUMMARY"
echo ""

if [[ "$DRY_RUN" == "true" ]]; then
  echo "DRY RUN -- no files written."
  exit 1
fi

# Apply changes
APPLY_RESULT=$(python3 "$CORE_PY" --apply --policy "$POLICY" --timestamp "$TIMESTAMP" --source "$SOURCE" 2>&1)
echo "  apply result: $(echo "$APPLY_RESULT" | python3 -c "import json,sys; d=json.load(sys.stdin); print('applied=', d['applied'])" 2>/dev/null || echo 'done')"

# Verify JSON is still valid
python3 -m json.tool "$POLICY" > /dev/null && echo "JSON valid." || { echo "ERROR: JSON invalid after write!" >&2; exit 2; }

# Update sync state (write result to temp file to avoid heredoc+pipe conflict)
TMP_RESULT=$(mktemp)
echo "$APPLY_RESULT" > "$TMP_RESULT"
python3 - "$TMP_RESULT" "$SYNC_STATE" "$TIMESTAMP" "$SOURCE" <<'PYEOF'
import json, sys
result_file, state_file, ts, source = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
with open(result_file) as f:
    d = json.load(f)
state = {}
try:
    with open(state_file) as f:
        state = json.load(f)
except Exception:
    pass
state.update({
    "lastSyncAt":          ts,
    "lastCheckedAt":       ts,
    "lastSource":          source,
    "lastResult":          "changes-applied",
    "changeCount":         d["changeCount"],
    "lastChanges":         d["changes"],
    "approvedCloudModels": d["approvedCloudModels"],
})
with open(state_file, "w") as f:
    json.dump(state, f, indent=2)
print("allowlist-sync-state.json updated.")
PYEOF
rm -f "$TMP_RESULT"

# Log CHG
CHANGES_ONELINE=$(echo "$CHANGES_SUMMARY" | tr '\n' ';' | sed 's/;$//')
CHG_ID=$(zsh "$CHANGELOG_SCRIPT" \
  --type "config" \
  --source "ken-prompt" \
  --title "Auto allowlist sync -- Tier 2 propagation ($SOURCE)" \
  --trigger "allowlist-sync.sh triggered by: $SOURCE at $TIMESTAMP" \
  --changed "model-policy.json allowedInCrons updated. $CHANGES_ONELINE" \
  --why "CI Cycle B decision or model strategy update. Allowlists auto-propagated per eligibility matrix." \
  --verified "allowlist-sync-state.json written, model-policy.json JSON valid" \
  2>&1 | grep "^CHG-" | head -1)

echo "CHG logged: $CHG_ID"
echo ""
echo "=== Sync complete. $CHANGE_COUNT change(s) applied. ==="
exit 1
