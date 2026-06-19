#!/bin/bash
# test-resume-detector.sh — Regression test for TKT-0319 Atom 3
# Verifies that task-watchdog.sh transitions stale running/dispatched
# state_task_queue rows to 'resumable'.

set -euo pipefail

WORKSPACE_ROOT="${WORKSPACE_ROOT:-/Users/ainchorsangiefpl/.openclaw/workspace}"
cd "$WORKSPACE_ROOT"

TEST_ID="TKT-0319-TEST-RESUME-DETECTOR"
PASS=0
FAIL=0
ok() { echo "  ✅ $1"; PASS=$((PASS+1)); }
ko() { echo "  ❌ $1"; FAIL=$((FAIL+1)); }

echo "=== TKT-0319 Resume Detector Verification ==="

# Pre-clean
/opt/homebrew/bin/psql -U ainchorsangiefpl -d ainchors_nexus -c "DELETE FROM state_task_queue WHERE id='${TEST_ID}';" >/dev/null 2>&1 || true
rm -f "$WORKSPACE_ROOT/state/resumable-atoms.json" 2>/dev/null || true

# Insert synthetic stale running atom
/opt/homebrew/bin/psql -U ainchorsangiefpl -d ainchors_nexus -c "
INSERT INTO state_task_queue (id, title, tier, status, priority, source, created_at, updated_at, created_at_ts, updated_at_ts, atoms_jsonb)
VALUES ('${TEST_ID}', 'Resume detector test atom', 'S', 'running', 'normal', 'test', now()::text, now()::text, now() - interval '30 minutes', now() - interval '30 minutes', '{}'::jsonb)
ON CONFLICT (id) DO UPDATE SET status='running', updated_at_ts=now() - interval '30 minutes', resume_attempts=0;
" >/dev/null 2>&1 || {
  ko "Failed to insert synthetic running atom"
  exit 1
}
ok "Inserted synthetic stale running atom"

# Run watchdog. It may exit 1 due to pre-existing JSON/PG divergence (L-075),
# but the resume detector section runs first and should still transition the row.
bash scripts/task-watchdog.sh >/dev/null 2>&1 || true
ok "task-watchdog.sh ran (divergence exit ignored)"

# Verify PG state
RES=$(/opt/homebrew/bin/psql -U ainchorsangiefpl -d ainchors_nexus -t -A -c "SELECT status, previous_status, resume_attempts FROM state_task_queue WHERE id='${TEST_ID}';" 2>/dev/null)
if [[ "$RES" == "resumable|running|1" ]]; then
  ok "PG row transitioned to resumable with previous_status=running, resume_attempts=1"
else
  ko "PG row not transitioned (got: $RES)"
fi

# Verify state/resumable-atoms.json
if [[ -f "$WORKSPACE_ROOT/state/resumable-atoms.json" ]]; then
  if grep -q "${TEST_ID}" "$WORKSPACE_ROOT/state/resumable-atoms.json"; then
    ok "resumable-atoms.json contains test atom"
  else
    ko "resumable-atoms.json missing test atom"
  fi
else
  ko "resumable-atoms.json not written"
fi

# Cleanup
/opt/homebrew/bin/psql -U ainchorsangiefpl -d ainchors_nexus -c "DELETE FROM state_task_queue WHERE id='${TEST_ID}';" >/dev/null 2>&1 || true
rm -f "$WORKSPACE_ROOT/state/resumable-atoms.json" 2>/dev/null || true
ok "Cleaned up test atom and resumable-atoms.json"

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
