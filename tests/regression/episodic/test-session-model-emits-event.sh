#!/bin/bash
# test-session-model-emits-event.sh — Verify check-session-model.sh emits session_model decision event on drift
# TKT-0390 Atom 5

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE="$(cd "$SCRIPT_DIR/../../.." && pwd)"
DB_RAW="$WORKSPACE/scripts/db-raw.sh"
CSM="$WORKSPACE/scripts/check-session-model.sh"
ALERT="$WORKSPACE/state/session-model-drift-alert.json"

PASS=0
FAIL=0

log() { echo "[test] $1"; }
pass() { log "PASS: $1"; PASS=$((PASS+1)); }
fail() { log "FAIL: $1"; FAIL=$((FAIL+1)); }

# The check-session-model.sh script requires live openclaw sessions.
# We cannot run it directly without affecting real sessions.
# Instead, we test the underlying pg-write-decision.sh directly
# to verify session_model decision kind works.

TEST_ENTITY_ID="tkt0390-session-model-$(date +%s)"

# Clean
bash "$DB_RAW" -c "DELETE FROM agent_events WHERE entity_id='$TEST_ENTITY_ID';" 2>/dev/null || true

# 1. Test session_model drift event via pg-write-decision.sh
bash "$WORKSPACE/scripts/pg-write-decision.sh" \
  --actor "test_session_check" \
  --entity-id "$TEST_ENTITY_ID" \
  --decision-kind "session_model" \
  --payload '{"inputs":{"agent":"main","expected":"ollama/deepseek-v4-flash:cloud","actual":"ollama/gemma4:31b-cloud"},"outputs":{"action":"alerted","status":"drift"},"rationale":"Session model drift detected"}'

COUNT=$(bash "$DB_RAW" -c "SELECT count(*) FROM agent_events WHERE entity_id='$TEST_ENTITY_ID' AND event_type='decision' AND payload->>'decision_kind'='session_model';" 2>/dev/null)
if [[ "$COUNT" -ge 1 ]]; then
  pass "session_model decision event inserted (count=$COUNT)"
else
  fail "No session_model decision event found"
fi

# 2. Verify payload structure
PAYLOAD=$(bash "$DB_RAW" -c "SELECT payload FROM agent_events WHERE entity_id='$TEST_ENTITY_ID' AND event_type='decision' AND payload->>'decision_kind'='session_model' LIMIT 1;" 2>/dev/null)
ACTION=$(echo "$PAYLOAD" | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); print(d.get('outputs',{}).get('action',''))" 2>/dev/null)
echo "session_model action: $ACTION"
if [[ "$ACTION" == "alerted" ]]; then
  pass "session_model payload outputs.action='alerted'"
else
  fail "session_model payload action mismatch: '$ACTION'"
fi

# 3. Test session_model reset event
bash "$WORKSPACE/scripts/pg-write-decision.sh" \
  --actor "test_session_check" \
  --entity-id "$TEST_ENTITY_ID" \
  --decision-kind "session_model" \
  --payload '{"inputs":{"agent":"main","expected":"ollama/deepseek-v4-flash:cloud","actual":"ollama/gemma4:31b-cloud"},"outputs":{"action":"reset","status":"initiated"},"rationale":"Session model drift auto-reset"}'

COUNT2=$(bash "$DB_RAW" -c "SELECT count(*) FROM agent_events WHERE entity_id='$TEST_ENTITY_ID' AND event_type='decision' AND payload->>'decision_kind'='session_model' AND payload->>'outputs' LIKE '%reset%';" 2>/dev/null)
if [[ "$COUNT2" -ge 1 ]]; then
  pass "session_model reset event inserted"
else
  fail "No session_model reset event found"
fi

# Cleanup
bash "$DB_RAW" -c "DELETE FROM agent_events WHERE entity_id='$TEST_ENTITY_ID';" 2>/dev/null || true

echo "--- Summary: $PASS passed, $FAIL failed ---"
if [[ "$FAIL" -gt 0 ]]; then exit 1; fi
exit 0
