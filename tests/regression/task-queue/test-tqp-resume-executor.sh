#!/bin/bash
# test-tqp-resume-executor.sh — Regression test for TKT-0319 Atom 4
# Verifies that task-queue-processor.sh can claim a resumable atom and
# tqp-executor.sh spawns an exec-atom carrying last_checkpoint, then the
# finalizer copies the child's terminal status back to the parent.

set -euo pipefail

WORKSPACE_ROOT="${WORKSPACE_ROOT:-/Users/ainchorsoc2a/.openclaw/workspace}"
cd "$WORKSPACE_ROOT"

TEST_ID="TKT-0319-TEST-RESUME-EXEC"
EXEC_PREFIX="${TEST_ID}-EXEC"
PASS=0
FAIL=0
ok() { echo "  ✅ $1"; PASS=$((PASS+1)); }
ko() { echo "  ❌ $1"; FAIL=$((FAIL+1)); }

echo "=== TKT-0319 TQP Resume Executor Verification ==="

# Pre-clean
${PSQL_BIN:-$(brew --prefix postgresql@16 2>/dev/null)/bin/psql} -U ${PGUSER:-$(whoami)} -d ainchors_nexus -c "
DELETE FROM state_task_queue WHERE id='${TEST_ID}' OR parent_task_id='${TEST_ID}' OR id LIKE '${EXEC_PREFIX}-%';
" >/dev/null 2>&1 || true
rm -f /tmp/task-queue-processor.lock
rm -rf "$WORKSPACE_ROOT/state/tqp-executor.lock.dir"
ok "Pre-cleaned test rows and locks"

# Insert a resumable atom with a checkpoint
${PSQL_BIN:-$(brew --prefix postgresql@16 2>/dev/null)/bin/psql} -U ${PGUSER:-$(whoami)} -d ainchors_nexus -c "
INSERT INTO state_task_queue (id, title, tier, status, priority, source, created_at, updated_at, created_at_ts, updated_at_ts, atoms_jsonb, state_payload, last_checkpoint)
VALUES (
  '${TEST_ID}',
  'Resume executor test atom',
  'S',
  'resumable',
  'normal',
  'agent:tqp',
  now()::text,
  now()::text,
  now(),
  now(),
  '{\"model\": \"flash\", \"task\": \"report checkpoint\", \"agent\": \"forge\", \"parent_ticket\": \"TKT-0319\", \"ac\": \"AC-TEST\"}'::jsonb,
  '{\"failure_reason\": \"stalled\", \"resumed_from_status\": \"running\"}'::jsonb,
  '{\"version\": \"1.0\", \"last_completed_step\": 2, \"context\": {\"foo\": \"bar\"}}'::jsonb
);
" >/dev/null 2>&1 || {
  ko "Failed to insert synthetic resumable atom"
  exit 1
}
ok "Inserted synthetic resumable atom with checkpoint"

# Run task-queue-processor to claim the resumable atom
zsh scripts/task-queue-processor.sh >/dev/null 2>&1 || true
ok "task-queue-processor.sh ran"

# Verify parent is dispatched/running and an exec child exists
STATUS=${PSQL_BIN:-$(brew --prefix postgresql@16 2>/dev/null)/bin/psql} -U ${PGUSER:-$(whoami)} -d ainchors_nexus -t -A -c "SELECT status FROM state_task_queue WHERE id='${TEST_ID}';" 2>/dev/null)
if [[ "$STATUS" == "running" || "$STATUS" == "dispatched" ]]; then
  ok "Parent atom claimed ($STATUS)"
else
  ko "Parent atom not claimed (status=$STATUS)"
fi

# Run tqp-executor to spawn child
bash scripts/tqp-executor.sh --limit 1 >/dev/null 2>&1 || true
ok "tqp-executor.sh ran"

EXEC_ID=${PSQL_BIN:-$(brew --prefix postgresql@16 2>/dev/null)/bin/psql} -U ${PGUSER:-$(whoami)} -d ainchors_nexus -t -A -c "SELECT id FROM state_task_queue WHERE parent_task_id='${TEST_ID}' LIMIT 1;" 2>/dev/null)
if [[ -n "$EXEC_ID" ]]; then
  ok "Exec-atom child spawned: $EXEC_ID"
else
  ko "No exec-atom child spawned"
fi

# Verify checkpoint carried into exec-atom payload
if ${PSQL_BIN:-$(brew --prefix postgresql@16 2>/dev/null)/bin/psql} -U ${PGUSER:-$(whoami)} -d ainchors_nexus -t -A -c "SELECT atoms_jsonb::text FROM state_task_queue WHERE id='${EXEC_ID}';" 2>/dev/null | grep -q '"last_completed_step": 2'; then
  ok "Exec-atom payload carries checkpoint (last_completed_step=2)"
else
  ko "Exec-atom payload missing checkpoint"
fi

# Simulate child completion
${PSQL_BIN:-$(brew --prefix postgresql@16 2>/dev/null)/bin/psql} -U ${PGUSER:-$(whoami)} -d ainchors_nexus -c "UPDATE state_task_queue SET status='done', updated_at_ts=now() WHERE id='${EXEC_ID}';" >/dev/null 2>&1
ok "Marked exec-atom child as done"

# Run finalizer (tqp-executor with no new atoms)
bash scripts/tqp-executor.sh --limit 0 >/dev/null 2>&1 || true
ok "tqp-executor finalizer ran"

# Verify parent copied child status
FINAL_STATUS=${PSQL_BIN:-$(brew --prefix postgresql@16 2>/dev/null)/bin/psql} -U ${PGUSER:-$(whoami)} -d ainchors_nexus -t -A -c "SELECT status FROM state_task_queue WHERE id='${TEST_ID}';" 2>/dev/null)
if [[ "$FINAL_STATUS" == "done" ]]; then
  ok "Parent atom status copied from child (done)"
else
  ko "Parent atom not updated (status=$FINAL_STATUS)"
fi

# Cleanup
${PSQL_BIN:-$(brew --prefix postgresql@16 2>/dev/null)/bin/psql} -U ${PGUSER:-$(whoami)} -d ainchors_nexus -c "
DELETE FROM state_task_queue WHERE id='${TEST_ID}' OR parent_task_id='${TEST_ID}' OR id LIKE '${EXEC_PREFIX}-%';
" >/dev/null 2>&1 || true
rm -f /tmp/task-queue-processor.lock
rm -rf "$WORKSPACE_ROOT/state/tqp-executor.lock.dir"
ok "Cleaned up test rows"

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
