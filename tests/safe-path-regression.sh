#!/bin/zsh
# TKT-0336 A1: Regression test for safe-path.sh
# Simulates isolated cron session where model outputs literal tilde paths
set -euo pipefail

PASS=0
FAIL=0
WORKSPACE="/Users/ainchorsangiefpl/.openclaw/workspace"
SAFE_PATH="${WORKSPACE}/scripts/safe-path.sh"

echo "=== TKT-0336 A1: safe-path.sh Regression Tests ==="
echo ""

# Test 1: Tilde expansion (agent outputs literal ~ string, not shell-expanded)
echo "--- Test 1: Tilde expansion (literal ~ string) ---"
output=$(zsh "$SAFE_PATH" '~/MEMORY.md' 2>&1)
if [[ "$output" == "/Users/ainchorsangiefpl/MEMORY.md" ]]; then
  echo "  PASS: ~/MEMORY.md → $output"
  PASS=$((PASS+1))
else
  echo "  FAIL: expected /Users/ainchorsangiefpl/MEMORY.md, got '$output'"
  FAIL=$((FAIL+1))
fi

# Test 2: Absolute path unchanged
echo "--- Test 2: Absolute path unchanged ---"
output=$(zsh "$SAFE_PATH" "${WORKSPACE}/MEMORY.md" 2>&1)
if [[ "$output" == "${WORKSPACE}/MEMORY.md" ]]; then
  echo "  PASS: absolute path preserved"
  PASS=$((PASS+1))
else
  echo "  FAIL: absolute path changed to '$output'"
  FAIL=$((FAIL+1))
fi

# Test 3: Subdirectory tilde expansion
echo "--- Test 3: Subdirectory tilde expansion ---"
output=$(zsh "$SAFE_PATH" '~/.openclaw/canvas/test.html' 2>&1)
if [[ "$output" == "/Users/ainchorsangiefpl/.openclaw/canvas/test.html" ]]; then
  echo "  PASS: nested tilde path normalized"
  PASS=$((PASS+1))
else
  echo "  FAIL: got '$output'"
  FAIL=$((FAIL+1))
fi

# Test 4: Empty input shows usage
echo "--- Test 4: Empty input rejected with usage ---"
output=$(zsh "$SAFE_PATH" "" 2>&1 || true)
if [[ "$output" == *"Usage"* ]]; then
  echo "  PASS: empty input shows usage"
  PASS=$((PASS+1))
else
  echo "  FAIL: got '$output'"
  FAIL=$((FAIL+1))
fi

# Test 5: cron-write.sh with wrong HOME
echo "--- Test 5: cron-write.sh path normalization ---"
CRON_WRITE="${WORKSPACE}/scripts/cron-write.sh"
tmpdir=$(mktemp -d)
echo "test content" | zsh "$CRON_WRITE" "${tmpdir}/regression-test.txt" 2>&1
if [[ -f "${tmpdir}/regression-test.txt" ]]; then
  content=$(cat "${tmpdir}/regression-test.txt")
  if [[ "$content" == "test content" ]]; then
    echo "  PASS: cron-write.sh wrote correct content"
    PASS=$((PASS+1))
  else
    echo "  FAIL: wrong content: '$content'"
    FAIL=$((FAIL+1))
  fi
else
  echo "  FAIL: file not created"
  FAIL=$((FAIL+1))
fi
rm -rf "$tmpdir"

# Test 6: Content with literal tilde preserved (not expanded)
echo "--- Test 6: Content with literal tilde ---"
tmpdir=$(mktemp -d)
echo "cd ~/project" | zsh "$CRON_WRITE" "${tmpdir}/with-tilde.txt" 2>&1
if [[ -f "${tmpdir}/with-tilde.txt" ]]; then
  content=$(cat "${tmpdir}/with-tilde.txt")
  if [[ "$content" == "cd ~/project" ]]; then
    echo "  PASS: literal tilde in content preserved"
    PASS=$((PASS+1))
  else
    echo "  FAIL: tilde in content expanded to: '$content'"
    FAIL=$((FAIL+1))
  fi
else
  echo "  FAIL: file not created"
  FAIL=$((FAIL+1))
fi
rm -rf "$tmpdir"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
if [[ $FAIL -eq 0 ]]; then
  echo "✅ ALL TESTS PASSED"
  exit 0
else
  echo "❌ $FAIL TEST(S) FAILED"
  exit 1
fi
