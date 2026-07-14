#!/bin/bash
# test-main-session-resume.sh — Regression test for TKT-0319 Atom 5
# Verifies that scripts/main-session-resume-check.sh detects a dead session
# in state/main-session-resume.json and writes state/main-session-resume-needs-ken.json.

set -euo pipefail

WORKSPACE_ROOT="${WORKSPACE_ROOT:-/Users/ainchorsoc2a/.openclaw/workspace}"
cd "$WORKSPACE_ROOT"

PASS=0
FAIL=0
ok() { echo "  ✅ $1"; PASS=$((PASS+1)); }
ko() { echo "  ❌ $1"; FAIL=$((FAIL+1)); }

echo "=== TKT-0319 Main-Session Resume Registry Verification ==="

# Pre-clean
cat > "$WORKSPACE_ROOT/state/main-session-resume.json" <<'JSON'
{"version":"1.0","tasks":[],"lastCheckAt":""}
JSON
rm -f "$WORKSPACE_ROOT/state/main-session-resume-needs-ken.json"
ok "Pre-cleaned registry and alert files"

# Insert a running task with a session key that is extremely unlikely to be alive
DEAD_KEY="agent:platform-arch:subagent:dead-0000-0000-000000000000"
cat > "$WORKSPACE_ROOT/state/main-session-resume.json" <<JSON
{
  "version": "1.0",
  "tasks": [
    {
      "id": "TKT-0319-TEST-MAIN-RESUME",
      "description": "Test main-session resume task",
      "agentId": "platform-arch",
      "sessionKey": "$DEAD_KEY",
      "startedAt": "2026-06-19T20:00:00+10:00",
      "checkpoint": {"last_completed_step": 1, "context": {"x": 1}},
      "status": "running",
      "attempt": 1,
      "maxAttempts": 3
    }
  ]
}
JSON
ok "Inserted synthetic running task with dead session key"

# Run the check
bash scripts/main-session-resume-check.sh >/dev/null 2>&1
ok "main-session-resume-check.sh ran without error"

# Verify registry updated to session_lost
STATUS=$(python3 -c "import json; print(json.load(open('$WORKSPACE_ROOT/state/main-session-resume.json'))['tasks'][0].get('status',''))")
if [[ "$STATUS" == "session_lost" ]]; then
  ok "Registry task status updated to session_lost"
else
  ko "Registry task status not updated (got $STATUS)"
fi

# Verify NEEDS_KEN alert written
if [[ -f "$WORKSPACE_ROOT/state/main-session-resume-needs-ken.json" ]]; then
  if grep -q "TKT-0319-TEST-MAIN-RESUME" "$WORKSPACE_ROOT/state/main-session-resume-needs-ken.json"; then
    ok "NEEDS_KEN alert contains test task"
  else
    ko "NEEDS_KEN alert missing test task"
  fi
else
  ko "NEEDS_KEN alert not written"
fi

# Cleanup
cat > "$WORKSPACE_ROOT/state/main-session-resume.json" <<'JSON'
{"version":"1.0","tasks":[],"lastCheckAt":""}
JSON
rm -f "$WORKSPACE_ROOT/state/main-session-resume-needs-ken.json"
ok "Cleaned up test files"

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
