#!/bin/bash
# TKT-0336: P0 Tilde-Path Normalization Regression Tests
# Phase 1: safe-path.sh + cron-write.sh functional tests

TEST_COUNT=0
FAIL_COUNT=0

WORKSPACE="/Users/ainchorsangiefpl/.openclaw/workspace"
SAFE_PATH="$WORKSPACE/scripts/safe-path.sh"
CRON_WRITE="$WORKSPACE/scripts/cron-write.sh"

# Test 1: Tilde expansion
output=$(zsh "$SAFE_PATH" '~/MEMORY.md' 2>&1)
if [[ "$output" == "/Users/ainchorsangiefpl/MEMORY.md" ]]; then
  ((TEST_COUNT++))
else
  echo "FAIL: tilde expansion — expected /Users/ainchorsangiefpl/MEMORY.md, got '$output'"
  ((FAIL_COUNT++))
fi

# Test 2: Absolute path unchanged
output=$(zsh "$SAFE_PATH" "$WORKSPACE/MEMORY.md" 2>&1)
if [[ "$output" == "$WORKSPACE/MEMORY.md" ]]; then
  ((TEST_COUNT++))
else
  echo "FAIL: absolute path — got '$output'"
  ((FAIL_COUNT++))
fi

# Test 3: Empty input
output=$(zsh "$SAFE_PATH" "" 2>&1 || true)
if [[ "$output" == *"Usage"* ]]; then
  ((TEST_COUNT++))
else
  echo "FAIL: empty input — got '$output'"
  ((FAIL_COUNT++))
fi

# Test 4: cron-write.sh with literal tilde in content (should preserve)
tmpdir=$(mktemp -d)
echo "cd ~/project" | zsh "$CRON_WRITE" "$tmpdir/with-tilde.txt" 2>/dev/null
if [[ -f "$tmpdir/with-tilde.txt" ]]; then
  content=$(cat "$tmpdir/with-tilde.txt")
  if [[ "$content" == "cd ~/project" ]]; then
    ((TEST_COUNT++))
  else
    echo "FAIL: tilde in content expanded to '$content'"
    ((FAIL_COUNT++))
  fi
else
  echo "FAIL: cron-write.sh did not create file"
  ((FAIL_COUNT++))
fi
rm -rf "$tmpdir"

echo "Tests: $TEST_COUNT, Failures: $FAIL_COUNT"
exit $FAIL_COUNT
