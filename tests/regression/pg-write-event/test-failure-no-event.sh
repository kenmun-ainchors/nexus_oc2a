#!/bin/bash
# test-failure-no-event.sh — malformed/bad table write does not create a pg_write_events row
# Part of TKT-0357 Atom 4 regression suite

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE="$(cd "$SCRIPT_DIR/../../.." && pwd)"
DB_RAW="$WORKSPACE/scripts/db-raw.sh"
DB_WRITE="$WORKSPACE/scripts/db-write.sh"

TEST_TABLE="_test_t0357_failure"
TEST_ID="TKT-EVT-FAIL-001"
PASS=0
FAIL=0

log() { echo "[test] $1"; }
pass() { log "PASS: $1"; PASS=$((PASS+1)); }
fail() { log "FAIL: $1"; FAIL=$((FAIL+1)); }

# Setup: create a test table WITHOUT allowing metadata or unknown columns
bash "$DB_RAW" -c "DROP TABLE IF EXISTS $TEST_TABLE;" 2>/dev/null
bash "$DB_RAW" -c "CREATE TABLE $TEST_TABLE (id text PRIMARY KEY, title text);" 2>/dev/null

# Clean any previous event
bash "$DB_RAW" -c "DELETE FROM pg_write_events WHERE row_id='$TEST_ID';" 2>/dev/null

# Write to a non-existent table — db-write.sh handles this gracefully
# by degrading to file fallback, returning a non-ok status.
RESULT=$(bash "$DB_WRITE" "_nonexistent_table_$TEST_TABLE" '{"title":"Should not work"}' "$TEST_ID" 2>/dev/null)
WRITE_STATUS=$(echo "$RESULT" | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('status',''))" 2>/dev/null)

if [[ "$WRITE_STATUS" != "ok" ]]; then
  pass "db-write.sh returned non-ok status on non-existent table (status=$WRITE_STATUS)"
else
  fail "db-write.sh returned status=ok on non-existent table (expected non-ok)"
fi

# Verify NO event was created
EVENT_COUNT=$(bash "$DB_RAW" -c "SELECT count(*) FROM pg_write_events WHERE row_id='$TEST_ID';" 2>/dev/null)
if [[ "$EVENT_COUNT" -eq 0 ]]; then
  pass "No pg_write_events row created for failed write"
else
  fail "pg_write_events row found for failed write (count=$EVENT_COUNT)"
fi

# Cleanup
bash "$DB_RAW" -c "DROP TABLE IF EXISTS $TEST_TABLE;" 2>/dev/null

echo "--- Summary: $PASS passed, $FAIL failed ---"
if [[ "$FAIL" -gt 0 ]]; then exit 1; fi
exit 0