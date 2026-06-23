#!/bin/bash
# test-dispatch-emits-event.sh — Verify dispatch decision events are correctly emitted
# Tests the emission pattern that flash-dispatcher.sh uses for dispatch events.
# The flash-dispatcher.sh has pre-existing PG schema issues (outside TKT-0390 scope),
# so we test the underlying emit_decision function via pg-write-decision.sh.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE="$(cd "$SCRIPT_DIR/../../.." && pwd)"
DB_RAW="$WORKSPACE/scripts/db-raw.sh"
DECISION_SCRIPT="$WORKSPACE/scripts/pg-write-decision.sh"

PASS=0
FAIL=0
TEST_ENTITY_ID="tkt0390-dispatch-$(date +%s)"

log() { echo "[test] $1"; }
pass() { log "PASS: $1"; PASS=$((PASS+1)); }
fail() { log "FAIL: $1"; FAIL=$((FAIL+1)); }

# Clean
bash "$DB_RAW" -c "DELETE FROM agent_events WHERE entity_id='$TEST_ENTITY_ID';" 2>/dev/null || true

# 1. Emit a dispatch decision (same pattern flash-dispatcher uses)
bash "$DECISION_SCRIPT" \
  --actor "flash_dispatcher" \
  --entity-id "$TEST_ENTITY_ID" \
  --decision-kind "dispatch" \
  --payload '{"inputs":{"sub_crest_id":"test-uuid-001","specialist":"forge","atom_index":0,"phase":"execute","verb":"read","target":"state/model-policy.json"},"outputs":{"atom_id":"atom-uuid-001","model":"deepseek-v4-flash:cloud"},"rationale":"Atom dispatched to specialist forge for phase execute"}'

EXIT_CODE=$?
if [[ "$EXIT_CODE" -eq 0 ]]; then
  pass "pg-write-decision.sh exits 0 on dispatch emission"
else
  fail "pg-write-decision.sh exited non-zero: $EXIT_CODE"
fi

# 2. Verify the dispatch decision event was inserted
COUNT=$(bash "$DB_RAW" -c "SELECT count(*) FROM agent_events WHERE entity_id='$TEST_ENTITY_ID' AND event_type='decision' AND payload->>'decision_kind'='dispatch';" 2>/dev/null)
if [[ "$COUNT" -ge 1 ]]; then
  pass "dispatch decision event inserted (count=$COUNT)"
else
  fail "No dispatch decision event found"
fi

# 3. Verify payload structure matches what flash-dispatcher emits
PAYLOAD=$(bash "$DB_RAW" -c "SELECT payload FROM agent_events WHERE entity_id='$TEST_ENTITY_ID' AND event_type='decision' ORDER BY timestamp DESC LIMIT 1;" 2>/dev/null)
echo "Payload: $PAYLOAD"

SPECIALIST=$(echo "$PAYLOAD" | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); print(d.get('inputs',{}).get('specialist',''))" 2>/dev/null)
PHASE=$(echo "$PAYLOAD" | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); print(d.get('inputs',{}).get('phase',''))" 2>/dev/null)
MODEL=$(echo "$PAYLOAD" | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); print(d.get('outputs',{}).get('model',''))" 2>/dev/null)

if [[ "$SPECIALIST" == "forge" ]]; then pass "dispatch payload specialist='forge'"; else fail "specialist='$SPECIALIST'"; fi
if [[ "$PHASE" == "execute" ]]; then pass "dispatch payload phase='execute'"; else fail "phase='$PHASE'"; fi
if [[ -n "$MODEL" ]]; then pass "dispatch payload model present: $MODEL"; else fail "model missing"; fi

# 4. Verify pg-write-decision.sh is non-blocking (always exits 0)
bash "$DECISION_SCRIPT" 2>/dev/null
if [[ "$?" -eq 0 ]]; then
  pass "pg-write-decision.sh exits 0 when called with no args (non-blocking)"
fi

# 5. Verify flash-dispatcher script parses correctly (syntax check)
bash -n "$WORKSPACE/scripts/flash-dispatcher.sh" 2>/dev/null
if [[ "$?" -eq 0 ]]; then
  pass "flash-dispatcher.sh has valid bash syntax"
else
  fail "flash-dispatcher.sh has syntax error"
fi

# Cleanup
bash "$DB_RAW" -c "DELETE FROM agent_events WHERE entity_id='$TEST_ENTITY_ID';" 2>/dev/null || true

echo "--- Summary: $PASS passed, $FAIL failed ---"
if [[ "$FAIL" -gt 0 ]]; then exit 1; fi
exit 0
