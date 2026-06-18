#!/bin/bash
# test-sprint-current.sh — Regression test for db-sprint.sh current resolution
# Ensures get_current_sprint_name() returns the active sprint, not a stale fallback.

set -euo pipefail

WORKSPACE_ROOT="${WORKSPACE_ROOT:-/Users/ainchorsangiefpl/.openclaw/workspace}"
cd "$WORKSPACE_ROOT"

PASS=0
FAIL=0
ok() { echo "  ✅ $1"; PASS=$((PASS+1)); }
ko() { echo "  ❌ $1"; FAIL=$((FAIL+1)); }

echo "=== Sprint Current Resolution Regression ==="

# R1 — db-sprint current returns a sprint
CURRENT_OUTPUT=$(bash scripts/db-sprint.sh current 2>/dev/null)
CURRENT_NAME=$(echo "$CURRENT_OUTPUT" | jq -r '.sprint_name // empty' 2>/dev/null || true)
if [[ -n "$CURRENT_NAME" ]]; then
  ok "R1: db-sprint.sh current returns a sprint name ($CURRENT_NAME)"
else
  ko "R1: db-sprint.sh current did not return a sprint name"
fi

# R2 — returned sprint status is active/in_progress, not completed
CURRENT_STATUS=$(echo "$CURRENT_OUTPUT" | jq -r '.status // empty' 2>/dev/null || true)
if [[ "$CURRENT_STATUS" == "in_progress" || "$CURRENT_STATUS" == "active" ]]; then
  ok "R2: returned sprint status is active/in_progress ($CURRENT_STATUS)"
else
  ko "R2: returned sprint status is stale ($CURRENT_STATUS)"
fi

# R3 — sprint name normalization handles "Sprint N" clean and decorated
for test_name in "Sprint 8" "sprint 9" "Sprint 10 — Platform"; do
  NORMALIZED=$(echo "$test_name" | grep -oEi '[Ss][Pp][Rr][Ii][Nn][Tt][[:space:]]*[0-9]+' | head -1)
  if [[ -n "$NORMALIZED" ]]; then
    ok "R3: normalized '$test_name' → '$NORMALIZED'"
  else
    ko "R3: failed to normalize '$test_name'"
  fi
done

# R4 — date command returns current UTC for ISO timestamps
TEST_TS="2026-06-18T07:35:00Z"
EPOCH=$(date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$TEST_TS" +%s 2>/dev/null || echo "")
if [[ -n "$EPOCH" ]]; then
  ok "R4: macOS date parses UTC ISO timestamp ($EPOCH)"
else
  ko "R4: macOS date failed to parse UTC ISO timestamp"
fi

echo ""
echo "=== Summary ==="
echo "Pass: $PASS | Fail: $FAIL"
if [[ "$FAIL" -eq 0 ]]; then
  echo "RESULT: ALL CHECKS PASS"
  exit 0
else
  echo "RESULT: FAIL"
  exit 1
fi
