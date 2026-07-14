#!/bin/bash
# test-db-write.sh — Regression tests for db-write.sh TKT-0311, TKT-0698

DB_WRITE="/Users/ainchorsoc2a/.openclaw/workspace/scripts/db-write.sh"
DB_RAW="/Users/ainchorsoc2a/.openclaw/workspace/scripts/db-raw.sh"
WORKSPACE="/Users/ainchorsoc2a/.openclaw/workspace"

echo "--- Starting db-write.sh Regression Tests ---"

# Helper for cleanup
cleanup() {
    local tid=$1
    echo "Cleaning up $tid..."
    bash "$DB_RAW" -c "DELETE FROM state_tickets WHERE id='$tid';" 2>/dev/null
}

# Test 1: Normal insert with known columns
TID_1="TEST-001"
echo "[Test 1] Normal Insert: $TID_1"
RES_1=$($DB_WRITE state_tickets '{"title":"Test 1 ticket","status":"open","priority":"high"}' $TID_1)
echo "Result: $RES_1"
if echo "$RES_1" | grep -q '"status":"ok"'; then
    echo "✅ SUCCESS"
else
    echo "❌ FAILURE"
fi
cleanup $TID_1

# Test 2: Insert with unknown columns -> metadata routing
TID_2="TEST-002"
echo "[Test 2] Metadata Routing: $TID_2"
RES_2=$($DB_WRITE state_tickets '{"title":"Test 2 ticket","status":"open","custom_field":"value123"}' $TID_2)
echo "Result: $RES_2"
if echo "$RES_2" | grep -q '"status":"ok"'; then
    echo "✅ SUCCESS"
else
    echo "❌ FAILURE"
fi
cleanup $TID_2

# Test 3: Conflict/Upsert
TID_3="TEST-003"
echo "[Test 3] Conflict/Upsert: $TID_3"
$DB_WRITE state_tickets '{"title":"Test 3 ticket","status":"open"}' $TID_3 > /dev/null
RES_3=$($DB_WRITE state_tickets '{"title":"Test 3 ticket updated","status":"closed"}' $TID_3)
echo "Result: $RES_3"
if echo "$RES_3" | grep -q '"status":"ok"'; then
    echo "✅ SUCCESS"
else
    echo "❌ FAILURE"
fi
cleanup $TID_3

# Test 4: Invalid JSON input (error handling)
TID_4="TEST-004"
echo "[Test 4] Invalid JSON: $TID_4"
RES_4=$($DB_WRITE state_tickets '{"invalid-json":' $TID_4 2>&1)
echo "Result: $RES_4"
if echo "$RES_4" | grep -q '"status":"error"'; then
    echo "✅ SUCCESS"
else
    echo "❌ FAILURE"
fi
cleanup $TID_4

# Test 5: Empty SQL Prevention
TID_5="TEST-005"
echo "[Test 5] Empty SQL Prevention: $TID_5"
RES_5=$($DB_WRITE state_tickets '{"title":"Test 5 ticket"}' $TID_5)
echo "Result: $RES_5"
if echo "$RES_5" | grep -q '"status":"ok"'; then
    echo "✅ SUCCESS"
else
    echo "❌ FAILURE"
fi
cleanup $TID_5

# Test 6: TKT-0698 — PG query rejection (type mismatch) must NOT fallback
TID_6="a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11"
echo "[Test 6] PG Rejected Query (type mismatch): $TID_6"
bash "$DB_RAW" -c "INSERT INTO state_sprints (id, sprint_name, sprint_number, start_date, end_date, status, capacity) VALUES ('$TID_6','Test Sprint 6',9999,CURRENT_DATE,CURRENT_DATE + INTERVAL '6 days','planning',6) ON CONFLICT DO NOTHING;" > /dev/null 2>&1
: > "$WORKSPACE/state/pg-write-fallback-state_sprints.jsonl"
FB_BEFORE=$(wc -l < "$WORKSPACE/state/pg-write-fallback-state_sprints.jsonl" | tr -d ' ')
RES_6=$($DB_WRITE state_sprints "{\"id\":\"$TID_6\",\"capacity\":\"not-an-integer\"}" $TID_6 2>&1)
FB_AFTER=$(wc -l < "$WORKSPACE/state/pg-write-fallback-state_sprints.jsonl" | tr -d ' ')
echo "Result: $RES_6"
echo "Fallback entries before=$FB_BEFORE after=$FB_AFTER"
if echo "$RES_6" | grep -q '"status":"error"' && echo "$RES_6" | grep -q 'invalid input syntax' && [ "$FB_BEFORE" -eq "$FB_AFTER" ]; then
    echo "✅ SUCCESS"
else
    echo "❌ FAILURE"
fi
bash "$DB_RAW" -c "DELETE FROM state_sprints WHERE id='$TID_6';" > /dev/null 2>&1

# Test 7: TKT-0698 — PG outage must fallback to file
TID_7="a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a12"
echo "[Test 7] PG Outage (bad PGHOST): $TID_7"
: > "$WORKSPACE/state/pg-write-fallback-state_sprints.jsonl"
FB_BEFORE=$(wc -l < "$WORKSPACE/state/pg-write-fallback-state_sprints.jsonl" | tr -d ' ')
RES_7=$(PGHOST=/nonexistent/socket $DB_WRITE state_sprints "{\"id\":\"$TID_7\",\"capacity\":6}" $TID_7 2>&1)
FB_AFTER=$(wc -l < "$WORKSPACE/state/pg-write-fallback-state_sprints.jsonl" | tr -d ' ')
echo "Result: $RES_7"
echo "Fallback entries before=$FB_BEFORE after=$FB_AFTER"
if echo "$RES_7" | grep -q '"status":"degraded"' && [ "$FB_AFTER" -gt "$FB_BEFORE" ]; then
    echo "✅ SUCCESS"
else
    echo "❌ FAILURE"
fi
# Clean up the test fallback entry
python3 -c "
import json, os
path = '$WORKSPACE/state/pg-write-fallback-state_sprints.jsonl'
if not os.path.exists(path): exit(0)
with open(path) as f: entries = [l.strip() for l in f if l.strip()]
filtered = [l for l in entries if json.loads(l).get('id') != '$TID_7']
with open(path, 'w') as f: f.write('\n'.join(filtered) + '\n' if filtered else '')
"

echo "--- Tests Completed ---"
