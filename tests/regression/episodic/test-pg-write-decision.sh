#!/bin/bash
# test-pg-write-decision.sh — Verify pg-write-decision.sh emits decision events correctly
# TKT-0390 Atom 2

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE="$(cd "$SCRIPT_DIR/../../.." && pwd)"
DB_RAW="$WORKSPACE/scripts/db-raw.sh"
DECISION_SCRIPT="$WORKSPACE/scripts/pg-write-decision.sh"

PASS=0
FAIL=0
TEST_ENTITY_ID="tkt0390-test-decision-$(date +%s)"

log() { echo "[test] $1"; }
pass() { log "PASS: $1"; PASS=$((PASS+1)); }
fail() { log "FAIL: $1"; FAIL=$((FAIL+1)); }

# Clean any prior events
bash "$DB_RAW" -c "DELETE FROM agent_events WHERE entity_id='$TEST_ENTITY_ID';" 2>/dev/null || true

# 1. Emit a dispatch decision event
bash "$DECISION_SCRIPT" \
  --actor "test_actor" \
  --entity-id "$TEST_ENTITY_ID" \
  --decision-kind "dispatch" \
  --payload '{"inputs":{"phase":"execute"},"outputs":{"atom_id":"test-001"},"rationale":"Test dispatch"}'
EXIT_CODE=$?

if [[ "$EXIT_CODE" -eq 0 ]]; then
  pass "pg-write-decision.sh exits 0 on success"
else
  fail "pg-write-decision.sh exited non-zero: $EXIT_CODE"
fi

# 2. Verify the decision event was inserted
COUNT=$(bash "$DB_RAW" -c "SELECT count(*) FROM agent_events WHERE entity_id='$TEST_ENTITY_ID' AND event_type='decision';" 2>/dev/null)
if [[ "$COUNT" -ge 1 ]]; then
  pass "Decision event inserted for $TEST_ENTITY_ID (count=$COUNT)"
else
  fail "No decision event found for $TEST_ENTITY_ID"
fi

# 3. Verify decision_kind in payload
PAYLOAD_KIND=$(bash "$DB_RAW" -c "SELECT payload->>'decision_kind' FROM agent_events WHERE entity_id='$TEST_ENTITY_ID' AND event_type='decision' LIMIT 1;" 2>/dev/null)
echo "Payload decision_kind: $PAYLOAD_KIND"
if [[ "$PAYLOAD_KIND" == "dispatch" ]]; then
  pass "payload.decision_kind = 'dispatch'"
else
  fail "payload.decision_kind is '$PAYLOAD_KIND' expected 'dispatch'"
fi

# 4. Emit another decision kind
bash "$DECISION_SCRIPT" \
  --actor "test_actor" \
  --entity-id "$TEST_ENTITY_ID" \
  --decision-kind "routing" \
  --payload '{"inputs":{"role":"business","phase":"Execute"},"outputs":{"model":"flash"},"rationale":"Test routing"}'

COUNT2=$(bash "$DB_RAW" -c "SELECT count(*) FROM agent_events WHERE entity_id='$TEST_ENTITY_ID' AND event_type='decision' AND payload->>'decision_kind'='routing';" 2>/dev/null)
if [[ "$COUNT2" -ge 1 ]]; then
  pass "Routing decision event inserted"
else
  fail "Routing decision event not found"
fi

# 5. Test non-blocking behavior: emit with empty args (should exit 0)
bash "$DECISION_SCRIPT" --actor "" --entity-id "" --decision-kind "" 2>/dev/null
if [[ "$?" -eq 0 ]]; then
  pass "pg-write-decision.sh exits 0 even with empty required args"
else
  fail "pg-write-decision.sh exited non-zero with empty args"
fi

# Cleanup
bash "$DB_RAW" -c "DELETE FROM agent_events WHERE entity_id='$TEST_ENTITY_ID';" 2>/dev/null || true

echo "--- Summary: $PASS passed, $FAIL failed ---"
if [[ "$FAIL" -gt 0 ]]; then exit 1; fi
exit 0
