#!/bin/bash
# TKT-0338: P1-B File Size Enforcement Regression Tests
# Phase 3: file-size-guard.sh validation + remediation messaging

TEST_COUNT=0
FAIL_COUNT=0

WORKSPACE="/Users/ainchorsoc2a/.openclaw/workspace"
GUARD_SH="$WORKSPACE/scripts/file-size-guard.sh"

# Test 1: --all reports all critical files
echo "Test 1: --all mode"
output=$(zsh "$GUARD_SH" --all 2>&1 || true)
if echo "$output" | grep -q "SOUL.md" && echo "$output" | grep -q "HEARTBEAT.md"; then
  echo "  PASS: all files reported"
  ((TEST_COUNT++))
else
  echo "  FAIL: missing file in report"
  ((FAIL_COUNT++))
fi

# Test 2: --json produces valid JSON
echo "Test 2: --json mode"
json=$(zsh "$GUARD_SH" --json 2>&1)
if echo "$json" | python3 -c "import json,sys; d=json.load(sys.stdin); assert 'files' in d; assert len(d['files']) >= 6" 2>&1; then
  echo "  PASS: valid JSON, 6+ files"
  ((TEST_COUNT++))
else
  echo "  FAIL: JSON validation failed"
  ((FAIL_COUNT++))
fi

# Test 3: --json has severity field
echo "Test 3: JSON severity field"
severity=$(echo "$json" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('severity','MISSING'))" 2>&1)
if [[ "$severity" == "WARN" ]]; then
  echo "  PASS: severity=$severity (HEARTBEAT+AGENTS warn)"
  ((TEST_COUNT++))
else
  echo "  FAIL: severity=$severity"
  ((FAIL_COUNT++))
fi

# Test 4: HEARTBEAT.md at 97% — WARN status
echo "Test 4: HEARTBEAT.md near limit"
hb=$(echo "$json" | python3 -c "import json,sys; d=json.load(sys.stdin); f=d['files']['HEARTBEAT.md']; print(f['status'],f['hardPct'])" 2>&1)
if [[ "$hb" == "WARN 97" ]]; then
  echo "  PASS: HEARTBEAT.md WARN at 97%"
  ((TEST_COUNT++))
else
  echo "  FAIL: HEARTBEAT.md status=$hb"
  ((FAIL_COUNT++))
fi

# Test 5: --check on non-critical file is graceful
echo "Test 5: --check non-critical file"
output=$(zsh "$GUARD_SH" --check /tmp/random-nonexistent-file-xyz.md 2>&1 || true)
if echo "$output" | grep -q "SKIP\|not found"; then
  echo "  PASS: graceful on missing/non-critical file"
  ((TEST_COUNT++))
else
  echo "  FAIL: unexpected output: $output"
  ((FAIL_COUNT++))
fi

# Test 6: Remediation messaging present on WARN
echo "Test 6: Remediation messaging"
output=$(zsh "$GUARD_SH" --check "$WORKSPACE/HEARTBEAT.md" 2>&1 || true)
if echo "$output" | grep -q "Consolidate\|descriptions\|thresholds"; then
  echo "  PASS: remediation guidance present"
  ((TEST_COUNT++))
else
  echo "  FAIL: no remediation in output"
  ((FAIL_COUNT++))
fi

echo "Tests: $TEST_COUNT, Failures: $FAIL_COUNT"
exit $FAIL_COUNT
