#!/bin/zsh
# state-diff.sh — Post-execution state validation for ticket work
# Usage: zsh scripts/state-diff.sh [snapshot-dir]
# Compares current state against snapshot, reports changes

set -u

WORKSPACE="/Users/ainchorsangiefpl/.openclaw/workspace"
SNAPSHOT="${1:-}"

if [[ -z "$SNAPSHOT" || ! -d "$SNAPSHOT" ]]; then
  echo "Usage: zsh scripts/state-diff.sh [snapshot-dir]"
  echo "  Example: zsh scripts/state-diff.sh state/snapshots/TKT-0196-20260516-104200"
  exit 1
fi

echo "🔍 State diff against: $(basename $SNAPSHOT)"
echo ""

CHANGED=0
WARNINGS=0

# Check each file in snapshot
for file in "$SNAPSHOT"/*.json; do
  [[ -f "$file" ]] || continue
  name=$(basename "$file")
  current="$WORKSPACE/state/$name"
  
  if [[ ! -f "$current" ]]; then
    echo "  ⚠️  $name — current file missing (was deleted?)"
    ((WARNINGS++))
    continue
  fi
  
  if ! diff -q "$file" "$current" > /dev/null 2>&1; then
    echo "  📝 $name — CHANGED"
    diff "$file" "$current" | head -20
    echo "  ---"
    ((CHANGED++))
  fi
done

# Check for new files
echo ""
echo "Checking for new files in state/..."
for file in "$WORKSPACE/state"/*.json; do
  [[ -f "$file" ]] || continue
  name=$(basename "$file")
  if [[ ! -f "$SNAPSHOT/$name" ]]; then
    echo "  🆕 $name — NEW FILE"
    ((CHANGED++))
  fi
done

echo ""
echo "=== DIFF SUMMARY ==="
echo "  Changed files: $CHANGED"
echo "  Warnings: $WARNINGS"

if ((CHANGED > 0)); then
  echo ""
  echo "⚠️  State has changed. Review above diff before proceeding."
  echo "   If changes are unexpected: cp -r $SNAPSHOT/* $WORKSPACE/state/"
  exit 1
else
  echo "  ✅ No unexpected state changes detected"
  exit 0
fi
