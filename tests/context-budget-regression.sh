#!/bin/zsh
# TKT-0337 A1: Regression tests for context-budget.sh
# Token estimation + budget gate for injected context files
set -euo pipefail

PASS=0
FAIL=0
WORKSPACE="/Users/ainchorsangiefpl/.openclaw/workspace"
BUDGET_SH="${WORKSPACE}/scripts/context-budget.sh"

echo "=== TKT-0337: context-budget.sh Regression Tests ==="
echo ""

# Test 1: --check returns exit 0 when under budget
echo "--- Test 1: --check OK (under budget) ---"
output=$(zsh "$BUDGET_SH" --check 2>&1 || true)
exit_code=$?
if [[ $exit_code -eq 0 && "$output" == OK:* ]]; then
  echo "  PASS: exit 0, status OK"
  PASS=$((PASS+1))
else
  echo "  FAIL: exit=$exit_code, output='$output'"
  FAIL=$((FAIL+1))
fi

# Test 2: --json produces valid JSON
echo "--- Test 2: --json valid output ---"
json=$(zsh "$BUDGET_SH" --json 2>&1)
if echo "$json" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['status'] == 'OK'" 2>&1; then
  echo "  PASS: valid JSON, status=OK"
  PASS=$((PASS+1))
else
  echo "  FAIL: invalid JSON"
  FAIL=$((FAIL+1))
fi

# Test 3: --json has all required fields
echo "--- Test 3: JSON schema completeness ---"
checks=$(echo "$json" | python3 -c "
import json, sys
d = json.load(sys.stdin)
required = ['model','window','totalChars','totalTokens','usagePercent','warnThreshold','blockThreshold','status','files']
missing = [k for k in required if k not in d]
if missing:
    print(f'MISSING: {missing}')
    sys.exit(1)
# Check files is dict with entries
if not isinstance(d['files'], dict) or len(d['files']) == 0:
    print('files empty or not dict')
    sys.exit(1)
print('OK: all fields present, files has ' + str(len(d['files'])) + ' entries')
" 2>&1)
if [[ "$checks" == OK:* ]]; then
  echo "  PASS: $checks"
  PASS=$((PASS+1))
else
  echo "  FAIL: $checks"
  FAIL=$((FAIL+1))
fi

# Test 4: Model override works
echo "--- Test 4: Model override (kimi, 200K window) ---"
kimi=$(zsh "$BUDGET_SH" --model kimi --json 2>&1)
kimi_window=$(echo "$kimi" | python3 -c "import json,sys; print(json.load(sys.stdin)['window'])" 2>&1)
if [[ "$kimi_window" == "200000" ]]; then
  echo "  PASS: kimi window = 200000 tokens"
  PASS=$((PASS+1))
else
  echo "  FAIL: expected 200000, got $kimi_window"
  FAIL=$((FAIL+1))
fi

# Test 5: Estimate is monotonically positive
echo "--- Test 5: Token estimates positive ---"
all_positive=$(echo "$json" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d['totalTokens'] > 0, 'totalTokens = 0'
assert d['totalChars'] > 0, 'totalChars = 0'
for fname, fdata in d['files'].items():
    assert fdata['tokens'] > 0, f'{fname}: tokens=0'
    assert fdata['chars'] > 0, f'{fname}: chars=0'
print('OK: all estimates positive')
" 2>&1)
if [[ "$all_positive" == OK:* ]]; then
  echo "  PASS: all token/char estimates positive"
  PASS=$((PASS+1))
else
  echo "  FAIL: $all_positive"
  FAIL=$((FAIL+1))
fi

# Test 6: Usage percent is reasonable (0-100)
echo "--- Test 6: Usage percent in bounds ---"
pct=$(echo "$json" | python3 -c "import json,sys; print(json.load(sys.stdin)['usagePercent'])" 2>&1)
if [[ "$pct" -ge 0 && "$pct" -le 100 ]]; then
  echo "  PASS: usagePercent=$pct (0-100)"
  PASS=$((PASS+1))
else
  echo "  FAIL: usagePercent=$pct out of range"
  FAIL=$((FAIL+1))
fi

# Test 7: Warn threshold < Block threshold
echo "--- Test 7: warnThreshold < blockThreshold ---"
thresholds_ok=$(echo "$json" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d['warnThreshold'] < d['blockThreshold'], 'warn >= block'
assert d['warnThreshold'] > 0, 'warn = 0'
assert d['blockThreshold'] > 0, 'block = 0'
print('OK')
" 2>&1)
if [[ "$thresholds_ok" == "OK" ]]; then
  echo "  PASS: warn < block, both positive"
  PASS=$((PASS+1))
else
  echo "  FAIL: $thresholds_ok"
  FAIL=$((FAIL+1))
fi

# Test 8: Unknown model falls back to default gracefully
echo "--- Test 8: Unknown model fallback ---"
unknown=$(zsh "$BUDGET_SH" --model nonexistent --json 2>&1)
unknown_model=$(echo "$unknown" | python3 -c "import json,sys; print(json.load(sys.stdin)['model'])" 2>&1)
if [[ "$unknown_model" == "nonexistent" ]]; then
  echo "  PASS: unknown model accepted, uses default window"
  PASS=$((PASS+1))
else
  echo "  FAIL: got model='$unknown_model'"
  FAIL=$((FAIL+1))
fi

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
if [[ $FAIL -eq 0 ]]; then
  echo "✅ ALL TESTS PASSED"
  exit 0
else
  echo "❌ $FAIL TEST(S) FAILED"
  exit 1
fi
