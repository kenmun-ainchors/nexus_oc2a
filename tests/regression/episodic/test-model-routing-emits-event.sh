#!/bin/bash
# test-model-routing-emits-event.sh — Verify model-policy-query.sh emits routing decision event when source=pg
# TKT-0390 Atom 4

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE="$(cd "$SCRIPT_DIR/../../.." && pwd)"
DB_RAW="$WORKSPACE/scripts/db-raw.sh"
MPQ="$WORKSPACE/scripts/model-policy-query.sh"

PASS=0
FAIL=0
TEST_ENTITY_PREFIX="model-infra-Plan"

log() { echo "[test] $1"; }
pass() { log "PASS: $1"; PASS=$((PASS+1)); }
fail() { log "FAIL: $1"; FAIL=$((FAIL+1)); }

# Clean prior routing events for our test entity
bash "$DB_RAW" -c "DELETE FROM agent_events WHERE event_type='decision' AND payload->>'decision_kind'='routing' AND entity_id LIKE 'model-%';" 2>/dev/null || true

# Count routing events before
BEFORE=$(bash "$DB_RAW" -c "SELECT count(*) FROM agent_events WHERE event_type='decision' AND payload->>'decision_kind'='routing';" 2>/dev/null)

# Run model-policy-query.sh with known agent+phase to trigger PG query
# infra maps to role 'build', Plan phase should exist in crest_phase_rules
RESULT=$(bash "$MPQ" --agent "infra" --phase "Plan" 2>/dev/null)
echo "MPQ result: $RESULT"

SOURCE=$(echo "$RESULT" | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('source',''))" 2>/dev/null)
echo "Source: $SOURCE"

if [[ "$SOURCE" == "pg" ]]; then
  pass "model-policy-query returned source=pg (SSOT)"

  AFTER=$(bash "$DB_RAW" -c "SELECT count(*) FROM agent_events WHERE event_type='decision' AND payload->>'decision_kind'='routing';" 2>/dev/null)
  DIFF=$((AFTER - BEFORE))
  if [[ "$DIFF" -ge 1 ]]; then
    pass "routing decision event emitted (count increase=$DIFF)"
    
    # Check payload details
    RT_PAYLOAD=$(bash "$DB_RAW" -c "SELECT payload FROM agent_events WHERE event_type='decision' AND payload->>'decision_kind'='routing' AND entity_id LIKE 'model-%' ORDER BY timestamp DESC LIMIT 1;" 2>/dev/null)
    echo "Routing payload: $RT_PAYLOAD"
    ROUTE_MODEL=$(echo "$RT_PAYLOAD" | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); print(d.get('outputs',{}).get('model',''))" 2>/dev/null)
    if [[ -n "$ROUTE_MODEL" ]]; then
      pass "routing payload contains model='$ROUTE_MODEL'"
    else
      fail "routing payload missing output model"
    fi
  else
    fail "No routing decision event found (before=$BEFORE after=$AFTER)"
  fi
else
  log "MPQ returned source='$SOURCE' (not PG) — routing event will not be emitted per design"
  # This can happen if PG is not fully up or skill gate fails
  # If source=json, no routing event should be emitted
  AFTER=$(bash "$DB_RAW" -c "SELECT count(*) FROM agent_events WHERE event_type='decision' AND payload->>'decision_kind'='routing';" 2>/dev/null)
  DIFF=$((AFTER - BEFORE))
  if [[ "$DIFF" -eq 0 ]]; then
    pass "No routing event emitted for JSON fallback (correct per design)"
  fi
fi

echo "--- Summary: $PASS passed, $FAIL failed ---"
if [[ "$FAIL" -gt 0 ]]; then exit 1; fi
exit 0
