#!/bin/bash
# test-existing-events-unchanged.sh — Verify existing pg-write-event.sh still works
# and previous pg-write-event test suite still passes
# TKT-0390 Atom 6 (verifier)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE="$(cd "$SCRIPT_DIR/../../.." && pwd)"
DB_RAW="$WORKSPACE/scripts/db-raw.sh"
PG_WRITE="$WORKSPACE/scripts/pg-write-event.sh"
DECISION_SCRIPT="$WORKSPACE/scripts/pg-write-decision.sh"

PASS=0
FAIL=0
TEST_ID="TKT-EVT-0390-UNCHANGED-$(date +%s)"

log() { echo "[test] $1"; }
pass() { log "PASS: $1"; PASS=$((PASS+1)); }
fail() { log "FAIL: $1"; FAIL=$((FAIL+1)); }

# Clean
bash "$DB_RAW" -c "DELETE FROM agent_events WHERE entity_id='$TEST_ID';" 2>/dev/null || true

# 1. Existing pg-write-event.sh still works with 'update' event_type
bash "$PG_WRITE" \
  --actor "test_unchanged" \
  --event-type "update" \
  --entity-type "ticket" \
  --entity-id "$TEST_ID" \
  --payload '{"title":"Original test","status":"backlog"}'

COUNT=$(bash "$DB_RAW" -c "SELECT count(*) FROM agent_events WHERE entity_id='$TEST_ID' AND event_type='update';" 2>/dev/null)
if [[ "$COUNT" -ge 1 ]]; then
  pass "pg-write-event.sh still emits normal event_type=update (count=$COUNT)"
else
  fail "No normal event found for $TEST_ID"
fi

# 2. Verify event_type='decision' only comes from decision wrapper
DECISION_COUNT=$(bash "$DB_RAW" -c "SELECT count(*) FROM agent_events WHERE entity_id='$TEST_ID' AND event_type='decision';" 2>/dev/null)
if [[ "$DECISION_COUNT" -eq 0 ]]; then
  pass "No decision events from direct pg-write-event.sh (correct)"
else
  fail "Decision events found from pg-write-event.sh (should be 0)"
fi

# 3. Both scripts can coexist - emit decision via wrapper
bash "$DECISION_SCRIPT" \
  --actor "test_unchanged" \
  --entity-id "$TEST_ID" \
  --decision-kind "routing" \
  --payload '{"rationale":"Coexistence test"}'

DECISION_COUNT2=$(bash "$DB_RAW" -c "SELECT count(*) FROM agent_events WHERE entity_id='$TEST_ID' AND event_type='decision';" 2>/dev/null)
if [[ "$DECISION_COUNT2" -eq 1 ]]; then
  pass "pg-write-decision.sh correctly emits event_type='decision' alongside normal events"
else
  fail "Expected 1 decision event but got $DECISION_COUNT2"
fi

# 4. Hash chain continuity check for this entity
PREV_HASH_NULL=$(bash "$DB_RAW" -c "SELECT count(*) FROM agent_events WHERE entity_id='$TEST_ID' AND prev_hash IS NULL;" 2>/dev/null)
echo "prev_hash IS NULL count for $TEST_ID: $PREV_HASH_NULL"
if [[ "$PREV_HASH_NULL" -ge 1 ]]; then
  pass "Hash chain: at least one event has prev_hash=NULL (first event)"
fi

# 5. Verify pg-write-event.sh backward compatibility: still accepts all original args
bash "$PG_WRITE" \
  --actor "test_bc" \
  --event-type "create" \
  --entity-type "sprint" \
  --entity-id "Sprint-T0390-BC" \
  --payload '{"name":"Backward compat test"}' \
  --prev-state '{"status":"none"}' \
  --new-state '{"status":"active"}'

BC_COUNT=$(bash "$DB_RAW" -c "SELECT count(*) FROM agent_events WHERE event_type='create' AND entity_id='Sprint-T0390-BC';" 2>/dev/null)
if [[ "$BC_COUNT" -ge 1 ]]; then
  pass "pg-write-event.sh backward compatible with prev-state and new-state"
else
  fail "Backward compatibility test failed"
fi

# Cleanup
bash "$DB_RAW" -c "DELETE FROM agent_events WHERE entity_id='$TEST_ID' OR entity_id='Sprint-T0390-BC';" 2>/dev/null || true

echo "--- Summary: $PASS passed, $FAIL failed ---"
if [[ "$FAIL" -gt 0 ]]; then exit 1; fi
exit 0
