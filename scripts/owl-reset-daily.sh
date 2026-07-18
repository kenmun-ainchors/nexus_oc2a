#!/bin/zsh
# Daily OWL compliance reset — runs at midnight MYT (Asia/Kuala_Lumpur)
set -u
WORKSPACE_ROOT="/Users/ainchorsoc2a/.openclaw/workspace"
COMPLIANCE_FILE="$WORKSPACE_ROOT/state/owl-compliance-state.json"
ARCHIVE_DIR="$WORKSPACE_ROOT/state/owl-archive"
TODAY=$(date '+%Y-%m-%d')

[[ ! -f "$COMPLIANCE_FILE" ]] && exit 0

# Archive today's atoms
mkdir -p "$ARCHIVE_DIR"
cp "$COMPLIANCE_FILE" "$ARCHIVE_DIR/owl-compliance-${TODAY}.json" 2>/dev/null

# Reset counters for new day
jq '{
  atoms: [],
  summary: {
    totalAtoms: 0,
    verifiedAtoms: 0,
    chainReactions: 0,
    driftsToday: 0,
    dailyCompliance: 100,
    lastDriftDetected: null,
    responsesToday: 0,
    model: "none"
  }
}' "$COMPLIANCE_FILE" > "${COMPLIANCE_FILE}.tmp" && mv "${COMPLIANCE_FILE}.tmp" "$COMPLIANCE_FILE"

echo "OWL: Daily reset complete — archived to $ARCHIVE_DIR/owl-compliance-${TODAY}.json"
