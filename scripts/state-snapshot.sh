#!/bin/zsh
# state-snapshot.sh — Pre-execution state backup for ticket work
# Usage: zsh scripts/state-snapshot.sh [TKT-NNNN] [description]
# Output: state/snapshots/TKT-NNNN-YYYYMMDD-HHMMSS/

set -euo pipefail

WORKSPACE="/Users/ainchorsangiefpl/.openclaw/workspace"
SNAPSHOT_DIR="$WORKSPACE/state/snapshots"
TKT="${1:-unknown}"
DESC="${2:-ticket-work}"
TIMESTAMP=$(date '+%Y%m%d-%H%M%S')
SNAPSHOT="$SNAPSHOT_DIR/${TKT}-${TIMESTAMP}"

mkdir -p "$SNAPSHOT"

echo "📸 State snapshot: ${TKT}-${TIMESTAMP}"
echo "  Description: $DESC"

# Core state files
for file in \
  "state/health-state.json" \
  "state/cost-state.json" \
  "state/tickets.json" \
  "state/sprint-current.json" \
  "state/critical-config-baseline.json" \
  "state/allowlist-sync-state.json" \
  "state/warden-escalation-pending.json" \
  "state/model-drift-state.json" \
  "state/chg-triggers.json" \
  "state/standup-state.json"
do
  src="$WORKSPACE/$file"
  if [[ -f "$src" ]]; then
    cp "$src" "$SNAPSHOT/"
    echo "  ✅ $(basename $file)"
  else
    echo "  ⚠️  $(basename $file) — not found"
  fi
done

# Git state
git -C "$WORKSPACE" rev-parse HEAD > "$SNAPSHOT/git-head.txt" 2>/dev/null || true
git -C "$WORKSPACE" status --short > "$SNAPSHOT/git-status.txt" 2>/dev/null || true

# Cron jobs
cp "$HOME/.openclaw/cron/jobs.json" "$SNAPSHOT/cron-jobs.json" 2>/dev/null || true

# Gateway config
cp "$HOME/.openclaw/openclaw.json" "$SNAPSHOT/openclaw.json" 2>/dev/null || true

# Metadata
cat > "$SNAPSHOT/snapshot-meta.json" <<JSON
{
  "ticket": "$TKT",
  "description": "$DESC",
  "timestamp": "$(date -u '+%Y-%m-%dT%H:%M:%SZ')",
  "timestampLocal": "$(date '+%Y-%m-%d %H:%M %Z')",
  "snapshotDir": "$SNAPSHOT"
}
JSON

echo ""
echo "Snapshot complete: $SNAPSHOT"
echo "  Rollback: cp -r $SNAPSHOT/* $WORKSPACE/state/"
