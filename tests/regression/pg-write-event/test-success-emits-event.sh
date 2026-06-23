#!/bin/bash
# test-success-emits-event.sh — db-write.sh to a temp/test table creates a queryable pg_write_events row
# Part of TKT-0357 Atom 4 regression suite

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE="$(cd "$SCRIPT_DIR/../../.." && pwd)"
DB_RAW="$WORKSPACE/scripts/db-raw.sh"
DB_WRITE="$WORKSPACE/scripts/db-write.sh"

TEST_TABLE="_test_t0357_success"
TEST_ID="TKT-EVT-SUCCESS-001"
PASS=0
FAIL=0

log() { echo "[test] $1"; }
pass() { log "PASS: $1"; PASS=$((PASS+1)); }
fail() { log "FAIL: $1"; FAIL=$((FAIL+1)); }

# Setup: create test table
bash "$DB_RAW" -c "DROP TABLE IF EXISTS $TEST_TABLE;" 2>/dev/null
bash "$DB_RAW" -c "CREATE TABLE $TEST_TABLE (id text PRIMARY KEY, title text, status text);" 2>/dev/null

# Clean any previous event for this ID
bash "$DB_RAW" -c "DELETE FROM pg_write_events WHERE row_id='$TEST_ID';" 2>/dev/null

# Execute the write
RESULT=$(bash "$DB_WRITE" "$TEST_TABLE" '{"title":"Success Test","status":"active"}' "$TEST_ID" 2>/dev/null)
WRITE_STATUS=$(echo "$RESULT" | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('status',''))" 2>/dev/null)

if [[ "$WRITE_STATUS" != "ok" ]]; then
  fail "db-write.sh did not return status=ok (got: $WRITE_STATUS)"
  bash "$DB_RAW" -c "DROP TABLE IF EXISTS $TEST_TABLE;" 2>/dev/null
  echo "--- Summary: $PASS passed, $FAIL failed ---"
  exit 1
fi
pass "db-write.sh returned status=ok"

# Verify the event row was created
EVENT_COUNT=$(bash "$DB_RAW" -c "SELECT count(*) FROM pg_write_events WHERE row_id='$TEST_ID';" 2>/dev/null)
if [[ "$EVENT_COUNT" -ge 1 ]]; then
  pass "pg_write_events row created for $TEST_ID"
else
  fail "No pg_write_events row found for $TEST_ID"
fi

# Verify specific fields
EVENT_JSON=$(bash "$DB_RAW" -c "SELECT row_to_json(pwe.*) FROM pg_write_events pwe WHERE row_id='$TEST_ID' LIMIT 1;" 2>/dev/null)
ACTOR=$(echo "$EVENT_JSON" | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('actor',''))" 2>/dev/null)
TABLE=$(echo "$EVENT_JSON" | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('table_name',''))" 2>/dev/null)
COMMAND=$(echo "$EVENT_JSON" | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('command',''))" 2>/dev/null)
SUCCESS=$(echo "$EVENT_JSON" | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('success', False))" 2>/dev/null)

if [[ -n "$ACTOR" ]]; then pass "actor is set: $ACTOR"; else fail "actor is empty"; fi
if [[ "$TABLE" == "$TEST_TABLE" ]]; then pass "table_name matches: $TABLE"; else fail "table_name mismatch: $TABLE vs $TEST_TABLE"; fi
if [[ "$COMMAND" == "db-write.sh" ]]; then pass "command is db-write.sh"; else fail "command is not db-write.sh: $COMMAND"; fi
if [[ "$SUCCESS" == "True" ]]; then pass "success is true"; else fail "success is not true: $SUCCESS"; fi

# Cleanup
bash "$DB_RAW" -c "DELETE FROM pg_write_events WHERE row_id='$TEST_ID';" 2>/dev/null
bash "$DB_RAW" -c "DROP TABLE IF EXISTS $TEST_TABLE;" 2>/dev/null

echo "--- Summary: $PASS passed, $FAIL failed ---"
if [[ "$FAIL" -gt 0 ]]; then exit 1; fi
exit 0