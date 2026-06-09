#!/bin/bash
# TKT-0337: P1-A Context Budget Guards Regression Tests
# Phase 2: Token estimation + budget gate checks

TEST_COUNT=0
FAIL_COUNT=0

WORKSPACE="/Users/ainchorsangiefpl/.openclaw/workspace"
BUDGET_SH="$WORKSPACE/scripts/context-budget.sh"

# Test 1: --check returns OK when under budget
output=$(zsh "$BUDGET_SH" --check 2>&1 || true)
if [[ "$output" == OK:* ]]; then
  ((TEST_COUNT++))
else
  echo "FAIL: --check not OK: $output"
  ((FAIL_COUNT++))
fi

# Test 2: --json produces valid JSON with all required fields
json=$(zsh "$BUDGET_SH" --json 2>&1)
if echo "$json" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d['status'] == 'OK'
assert 'model' in d and 'window' in d
assert 'totalTokens' in d and d['totalTokens'] > 0
assert 'files' in d and isinstance(d['files'], dict)
assert d['warnThreshold'] < d['blockThreshold']
" 2>&1; then
  ((TEST_COUNT++))
else
  echo "FAIL: JSON validation failed"
  ((FAIL_COUNT++))
fi

# Test 3: Model override (kimi = 200K window)
kimi_json=$(zsh "$BUDGET_SH" --model kimi --json 2>&1)
kimi_window=$(echo "$kimi_json" | python3 -c "import json,sys; print(json.load(sys.stdin)['window'])" 2>&1)
if [[ "$kimi_window" == "200000" ]]; then
  ((TEST_COUNT++))
else
  echo "FAIL: kimi window = $kimi_window, expected 200000"
  ((FAIL_COUNT++))
fi

# Test 4: Usage percent is in bounds (0-100)
pct=$(echo "$json" | python3 -c "import json,sys; print(json.load(sys.stdin)['usagePercent'])" 2>&1)
if [[ "$pct" -ge 0 && "$pct" -le 100 ]]; then
  ((TEST_COUNT++))
else
  echo "FAIL: usagePercent=$pct out of range"
  ((FAIL_COUNT++))
fi

echo "Tests: $TEST_COUNT, Failures: $FAIL_COUNT"
exit $FAIL_COUNT
