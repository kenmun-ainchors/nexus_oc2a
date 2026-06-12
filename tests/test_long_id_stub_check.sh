#!/bin/bash
# L-085: Unit test for long-id-stub-check.sh
# Verifies:
#  1. No long-ID stubs → 0 findings
#  2. Long-ID stub without short-ID match → 1 finding, "review manually"
#  3. Long-ID stub with short-ID match → 1 finding, "superseded by"
#  4. Stub < 7 days old → not flagged

set -euo pipefail
cd "$(dirname "$0")/.."

CHECK_SCRIPT="scripts/long-id-stub-check.sh"
OUTPUT_FILE="state/long-id-stubs.json"
DB_SCRIPT="scripts/db.sh"

TESTS_PASSED=0
TESTS_FAILED=0

assert_eq() {
  local test_name="$1"
  local actual="$2"
  local expected="$3"
  if [[ "$actual" == "$expected" ]]; then
    echo "  PASS: $test_name"
    TESTS_PASSED=$((TESTS_PASSED+1))
  else
    echo "  FAIL: $test_name"
    echo "    Expected: $expected"
    echo "    Actual:   $actual"
    TESTS_FAILED=$((TESTS_FAILED+1))
  fi
}

cleanup_stubs() {
  bash "$DB_SCRIPT" -c "DELETE FROM state_tickets WHERE id LIKE 'TKT-9999:%' OR id LIKE 'TKT-0407:%L-085%';" 2>&1 >/dev/null || true
}

# Make sure we start clean
cleanup_stubs

echo "=== Test 1: No long-ID stubs → 0 findings ==="
bash "$CHECK_SCRIPT" >/dev/null 2>&1
COUNT=$(python3 -c "import json; print(json.load(open('$OUTPUT_FILE')).get('count', -1))")
assert_eq "Empty DB → 0 findings" "$COUNT" "0"

echo ""
echo "=== Test 2: Stub without short-ID match → 1 finding, 'review manually' ==="
bash "$DB_SCRIPT" -c "
INSERT INTO state_tickets (id, title, status, created_at, updated_at, metadata)
VALUES (
  'TKT-9999: L-085 test stub 2',
  'L-085 test stub 2',
  'open',
  NOW() - INTERVAL '10 days',
  NOW() - INTERVAL '10 days',
  '{\"notion_sync\": {\"status\": \"pending\"}}'::jsonb
) ON CONFLICT (id) DO NOTHING;
" >/dev/null 2>&1

bash "$CHECK_SCRIPT" >/dev/null 2>&1
COUNT=$(python3 -c "import json; print(json.load(open('$OUTPUT_FILE')).get('count', -1))")
assert_eq "Stub without match → 1 finding" "$COUNT" "1"

REC=$(python3 -c "import json; d=json.load(open('$OUTPUT_FILE')); print(d['findings'][0].get('recommendation', ''))")
assert_eq "Stub without match → 'Review manually'" \
  "$(echo $REC | grep -c 'Review manually')" "1"

# Cleanup
bash "$DB_SCRIPT" -c "DELETE FROM state_tickets WHERE id = 'TKT-9999: L-085 test stub 2';" >/dev/null 2>&1

echo ""
echo "=== Test 3: Stub with short-ID match → 1 finding, 'superseded by' ==="
bash "$DB_SCRIPT" -c "
INSERT INTO state_tickets (id, title, status, created_at, updated_at, metadata)
VALUES (
  'TKT-0407: L-085 test stub 3',
  'L-085 test stub 3',
  'open',
  NOW() - INTERVAL '10 days',
  NOW() - INTERVAL '10 days',
  '{\"notion_sync\": {\"status\": \"pending\"}}'::jsonb
) ON CONFLICT (id) DO NOTHING;
" >/dev/null 2>&1

bash "$CHECK_SCRIPT" >/dev/null 2>&1
COUNT=$(python3 -c "import json; print(json.load(open('$OUTPUT_FILE')).get('count', -1))")
assert_eq "Stub with match → 1 finding" "$COUNT" "1"

SHORT_EXISTS=$(python3 -c "import json; d=json.load(open('$OUTPUT_FILE')); print(d['findings'][0].get('short_id_exists', 'none'))")
assert_eq "Stub with match → short_id_exists = TKT-0407" "$SHORT_EXISTS" "TKT-0407"

REC=$(python3 -c "import json; d=json.load(open('$OUTPUT_FILE')); print(d['findings'][0].get('recommendation', ''))")
assert_eq "Stub with match → 'Close as superseded by TKT-0407'" \
  "$(echo $REC | grep -c 'Close as superseded by TKT-0407')" "1"

# Cleanup
bash "$DB_SCRIPT" -c "DELETE FROM state_tickets WHERE id = 'TKT-0407: L-085 test stub 3';" >/dev/null 2>&1

echo ""
echo "=== Test 4: Stub < 7 days old → not flagged ==="
bash "$DB_SCRIPT" -c "
INSERT INTO state_tickets (id, title, status, created_at, updated_at, metadata)
VALUES (
  'TKT-9999: L-085 test stub 4 (recent)',
  'L-085 test stub 4 (recent)',
  'open',
  NOW() - INTERVAL '3 days',
  NOW() - INTERVAL '3 days',
  '{\"notion_sync\": {\"status\": \"pending\"}}'::jsonb
) ON CONFLICT (id) DO NOTHING;
" >/dev/null 2>&1

bash "$CHECK_SCRIPT" >/dev/null 2>&1
COUNT=$(python3 -c "import json; print(json.load(open('$OUTPUT_FILE')).get('count', -1))")
assert_eq "Recent stub (3 days) → 0 findings" "$COUNT" "0"

# Cleanup
bash "$DB_SCRIPT" -c "DELETE FROM state_tickets WHERE id = 'TKT-9999: L-085 test stub 4 (recent)';" >/dev/null 2>&1

echo ""
echo "=== Final cleanup ==="
cleanup_stubs
bash "$CHECK_SCRIPT" >/dev/null 2>&1

echo ""
echo "=== Test Summary ==="
echo "  Passed: $TESTS_PASSED"
echo "  Failed: $TESTS_FAILED"
echo "  Total:  $((TESTS_PASSED + TESTS_FAILED))"

if [[ $TESTS_FAILED -gt 0 ]]; then
  exit 1
fi
exit 0
