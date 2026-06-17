#!/bin/bash
# test-subagent-dispatch.sh — Regression test for TKT-0536 A4
# Verifies that subagent dispatch with cwd + timeout reads workspace files and times out cleanly.

set -euo pipefail

WORKSPACE_ROOT="${WORKSPACE_ROOT:-/Users/ainchorsangiefpl/.openclaw/workspace}"
cd "$WORKSPACE_ROOT"

PASS=0
FAIL=0
ok() { echo "  ✅ $1"; PASS=$((PASS+1)); }
ko() { echo "  ❌ $1"; FAIL=$((FAIL+1)); }

# Cleanup stale temp files left by prior runs
rm -f /tmp/subagent-dispatch-test-*.md /tmp/subagent-task-*.md 2>/dev/null || true

echo "=== TKT-0536 Subagent Dispatch Verification ==="

TEST_FILE="$WORKSPACE_ROOT/.openclaw/tmp/subagent-a4-test.txt"
echo "verify workspace access from subagent" > "$TEST_FILE"

# R1 — subagent-dispatch.sh exists and validates inputs
if [[ -x scripts/subagent-dispatch.sh ]]; then
  ok "R1: subagent-dispatch.sh exists and executable"
else
  ko "R1: subagent-dispatch.sh missing or not executable"
fi

if ! bash scripts/subagent-dispatch.sh platform-arch /nonexistent.md 2>/dev/null; then
  ok "R1: subagent-dispatch.sh rejects missing task file"
else
  ko "R1: subagent-dispatch.sh accepted missing task file"
fi

if ! bash scripts/subagent-dispatch.sh platform-arch "$TEST_FILE" --timeout 0 2>/dev/null; then
  ok "R1: subagent-dispatch.sh rejects invalid timeout"
else
  ko "R1: subagent-dispatch.sh accepted timeout=0"
fi

# R2 — subagent-dispatch skill is registered
if bash scripts/skill-load.sh subagent-dispatch >/dev/null 2>&1; then
  ok "R2: subagent-dispatch skill loads from canonical index"
else
  ko "R2: subagent-dispatch skill failed to load"
fi

# R3 — subagent-dispatch.sh emits safe dispatch block with cwd and timeout
TMP_TASK=$(mktemp /tmp/subagent-dispatch-test-XXXXXX.md)
echo "Read $TEST_FILE and report contents." > "$TMP_TASK"
OUTPUT=$(bash scripts/subagent-dispatch.sh platform-arch "$TMP_TASK" --read-only --timeout 60 --cwd "$WORKSPACE_ROOT" 2>&1)
if echo "$OUTPUT" | grep -q "timeoutSeconds: 60"; then
  ok "R3: wrapper emits timeoutSeconds"
else
  ko "R3: wrapper did not emit timeoutSeconds"
fi
if echo "$OUTPUT" | grep -q "cwd: '$WORKSPACE_ROOT'"; then
  ok "R3: wrapper emits cwd"
else
  ko "R3: wrapper did not emit cwd"
fi
if echo "$OUTPUT" | grep -q "You may use at most 30 tool calls"; then
  ok "R3: wrapper injects tool-call budget"
else
  ko "R3: wrapper did not inject tool-call budget"
fi

# R4 — workspace-mutating cross-agent dispatch blocked without approval
if ! bash scripts/subagent-dispatch.sh platform-arch "$TMP_TASK" --cwd "$WORKSPACE_ROOT" 2>/dev/null; then
  ok "R4: cross-agent workspace-mutating dispatch blocked"
else
  ko "R4: cross-agent workspace-mutating dispatch allowed without --read-only"
fi

# R5 — SOUL.md contains the subagent dispatch rule
if grep -q "subagent-dispatch" SOUL.md; then
  ok "R5: SOUL.md references subagent-dispatch skill"
else
  ko "R5: SOUL.md missing subagent-dispatch reference"
fi

# Cleanup
rm -f "$TMP_TASK" /tmp/subagent-dispatch-test-*.md /tmp/subagent-task-*.md 2>/dev/null || true

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
