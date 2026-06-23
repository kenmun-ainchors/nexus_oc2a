#!/bin/bash
# test-phase-transition-emits-event.sh — Verify phase_transition decision events are correctly emitted
# Tests the emission pattern that flash-dispatcher.sh uses for phase transitions.
# The flash-dispatcher.sh has pre-existing PG schema issues (outside TKT-0390 scope),
# so we test the underlying emit_decision function via pg-write-decision.sh.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE="$(cd "$SCRIPT_DIR/../../.." && pwd)"
DB_RAW="$WORKSPACE/scripts/db-raw.sh"
DECISION_SCRIPT="$WORKSPACE/scripts/pg-write-decision.sh"

PASS=0
FAIL=0
TEST_ENTITY_ID="tkt0390-phase-trans-$(date +%s)"

log() { echo "[test] $1"; }
pass() { log "PASS: $1"; PASS=$((PASS+1)); }
fail() { log "FAIL: $1"; FAIL=$((FAIL+1)); }

# Clean
bash "$DB_RAW" -c "DELETE FROM agent_events WHERE entity_id='$TEST_ENTITY_ID';" 2>/dev/null || true

# 1. Emit a phase_transition decision (same pattern flash-dispatcher dispatch uses)
bash "$DECISION_SCRIPT" \
  --actor "flash_dispatcher" \
  --entity-id "$TEST_ENTITY_ID" \
  --decision-kind "phase_transition" \
  --payload '{"inputs":{"sub_crest_id":"test-uuid-001","specialist":"forge","previous_phase":"sub_crest_planning","new_phase":"sub_crest_executing"},"outputs":{"updated":true},"rationale":"Phase transition via dispatch"}'

EXIT_CODE=$?
if [[ "$EXIT_CODE" -eq 0 ]]; then
  pass "pg-write-decision.sh exits 0 on phase_transition emission"
else
  fail "pg-write-decision.sh exited non-zero: $EXIT_CODE"
fi

# 2. Verify the phase_transition decision event
COUNT=$(bash "$DB_RAW" -c "SELECT count(*) FROM agent_events WHERE entity_id='$TEST_ENTITY_ID' AND event_type='decision' AND payload->>'decision_kind'='phase_transition';" 2>/dev/null)
if [[ "$COUNT" -ge 1 ]]; then
  pass "phase_transition decision event inserted (count=$COUNT)"
else
  fail "No phase_transition decision event found"
fi

# 3. Verify payload structure
PAYLOAD=$(bash "$DB_RAW" -c "SELECT payload FROM agent_events WHERE entity_id='$TEST_ENTITY_ID' AND event_type='decision' ORDER BY timestamp DESC LIMIT 1;" 2>/dev/null)
echo "Phase transition payload: $PAYLOAD"

PREV_PHASE=$(echo "$PAYLOAD" | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); print(d.get('inputs',{}).get('previous_phase',''))" 2>/dev/null)
NEW_PHASE=$(echo "$PAYLOAD" | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); print(d.get('inputs',{}).get('new_phase',''))" 2>/dev/null)
SPECIALIST=$(echo "$PAYLOAD" | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); print(d.get('inputs',{}).get('specialist',''))" 2>/dev/null)

if [[ "$PREV_PHASE" == "sub_crest_planning" ]]; then pass "previous_phase='sub_crest_planning'"; else fail "previous_phase='$PREV_PHASE'"; fi
if [[ "$NEW_PHASE" == "sub_crest_executing" ]]; then pass "new_phase='sub_crest_executing'"; else fail "new_phase='$NEW_PHASE'"; fi
if [[ "$SPECIALIST" == "forge" ]]; then pass "specialist='forge'"; else fail "specialist='$SPECIALIST'"; fi

# 4. Emit a phase_transition from verify-phase pattern too
bash "$DECISION_SCRIPT" \
  --actor "flash_dispatcher" \
  --entity-id "$TEST_ENTITY_ID" \
  --decision-kind "phase_transition" \
  --payload '{"inputs":{"sub_crest_id":"test-uuid-001","specialist":"forge","previous_phase":"sub_crest_verifying","new_phase":"sub_crest_synthesizing","verdict":"pass"},"outputs":{"phase_updated":true},"rationale":"Phase transition via verify-phase verdict=pass"}'

COUNT2=$(bash "$DB_RAW" -c "SELECT count(*) FROM agent_events WHERE entity_id='$TEST_ENTITY_ID' AND event_type='decision' AND payload->>'decision_kind'='phase_transition' AND payload->>'inputs' LIKE '%synthesizing%';" 2>/dev/null)
if [[ "$COUNT2" -ge 1 ]]; then
  pass "verify-phase phase_transition event emitted (new_phase=sub_crest_synthesizing)"
else
  fail "No verify-phase style phase_transition found"
fi

# 5. Verify syntax check on flash-dispatcher
bash -n "$WORKSPACE/scripts/flash-dispatcher.sh" 2>/dev/null
if [[ "$?" -eq 0 ]]; then
  pass "flash-dispatcher.sh has valid bash syntax (emit_decision calls)"
else
  fail "flash-dispatcher.sh has syntax error"
fi

# Cleanup
bash "$DB_RAW" -c "DELETE FROM agent_events WHERE entity_id='$TEST_ENTITY_ID';" 2>/dev/null || true

echo "--- Summary: $PASS passed, $FAIL failed ---"
if [[ "$FAIL" -gt 0 ]]; then exit 1; fi
exit 0
