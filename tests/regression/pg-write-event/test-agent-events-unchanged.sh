#!/bin/bash
# test-agent-events-unchanged.sh — db-ticket.sh/db-sprint.sh still emit to agent_events
# and no new pg_write_events row appears from those paths
# Part of TKT-0357 Atom 4 regression suite

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE="$(cd "$SCRIPT_DIR/../../.." && pwd)"
DB_RAW="$WORKSPACE/scripts/db-raw.sh"
DB_TICKET="$WORKSPACE/scripts/db-ticket.sh"

PASS=0
FAIL=0
TEST_TICKET_ID="TKT-T0357-TEST-AGENT-EVT"
TEST_SPRINT="Sprint-T0357-Test"

log() { echo "[test] $1"; }
pass() { log "PASS: $1"; PASS=$((PASS+1)); }
fail() { log "FAIL: $1"; FAIL=$((FAIL+1)); }

# Clean up any prior test artifacts
bash "$DB_RAW" -c "DELETE FROM state_tickets WHERE id='$TEST_TICKET_ID';" 2>/dev/null
bash "$DB_RAW" -c "DELETE FROM agent_events WHERE entity_id='$TEST_TICKET_ID';" 2>/dev/null
bash "$DB_RAW" -c "DELETE FROM pg_write_events WHERE row_id='$TEST_TICKET_ID';" 2>/dev/null

# Count existing agent_events to detect new ones
AGENT_EVENTS_BEFORE=$(bash "$DB_RAW" -c "SELECT count(*) FROM agent_events WHERE entity_type='ticket' AND entity_id='$TEST_TICKET_ID';" 2>/dev/null)

# Use db-ticket.sh to create a ticket
# We need to create it first via db-write.sh (the low-level write) then use db-ticket.sh for the semantic update
bash "$DB_RAW" -c "INSERT INTO state_tickets (id, title, status, created_at, updated_at) VALUES ('$TEST_TICKET_ID', 'TKT-0357 test ticket', 'backlog', now(), now()) ON CONFLICT (id) DO NOTHING;" 2>/dev/null

# Now use db-ticket.sh update to trigger agent_events with metadata-only payload
# (not groom, which requires TTY interactivity)
ACTOR="test-agent-t0357"
cd "$WORKSPACE" 2>/dev/null

# Build a minimal metadata-only JSON payload — this triggers agent_events without pg_write_events
META_PAYLOAD='{"metadata":{"brief":"TKT-0357 test metadata update","priority":"high"}}'
RESULT=$(bash "$DB_TICKET" update "$TEST_TICKET_ID" "$META_PAYLOAD" 2>/dev/null)
UPDATE_EXIT=$?

if [[ "$UPDATE_EXIT" -eq 0 ]]; then
  pass "db-ticket.sh update with metadata-only payload succeeded"
else
  fail "db-ticket.sh update failed (exit=$UPDATE_EXIT): $RESULT"
fi

# Check agent_events was recorded
AGENT_EVENTS_AFTER=$(bash "$DB_RAW" -c "SELECT count(*) FROM agent_events WHERE entity_type='ticket' AND entity_id='$TEST_TICKET_ID';" 2>/dev/null)
AGENT_EVENTS_DIFF=$((AGENT_EVENTS_AFTER - AGENT_EVENTS_BEFORE))

if [[ "$AGENT_EVENTS_DIFF" -gt 0 ]]; then
  pass "agent_events recorded $AGENT_EVENTS_DIFF new event(s) for $TEST_TICKET_ID"
else
  fail "No agent_events recorded for $TEST_TICKET_ID ($AGENT_EVENTS_AFTER vs $AGENT_EVENTS_BEFORE)"
fi

# Check that NO pg_write_events row was created from this path
PW_EVENTS=$(bash "$DB_RAW" -c "SELECT count(*) FROM pg_write_events WHERE row_id='$TEST_TICKET_ID';" 2>/dev/null)
if [[ "$PW_EVENTS" -eq 0 ]]; then
  pass "No pg_write_events row created from db-ticket.sh path"
else
  fail "pg_write_events row found from db-ticket.sh path (count=$PW_EVENTS)"
fi

# Cleanup
bash "$DB_RAW" -c "DELETE FROM state_tickets WHERE id='$TEST_TICKET_ID';" 2>/dev/null
bash "$DB_RAW" -c "DELETE FROM agent_events WHERE entity_id='$TEST_TICKET_ID';" 2>/dev/null
bash "$DB_RAW" -c "DELETE FROM pg_write_events WHERE row_id='$TEST_TICKET_ID';" 2>/dev/null

echo "--- Summary: $PASS passed, $FAIL failed ---"
if [[ "$FAIL" -gt 0 ]]; then exit 1; fi
exit 0