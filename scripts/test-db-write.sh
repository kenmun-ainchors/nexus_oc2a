#!/bin/bash
# test-db-write.sh — Regression tests for db-write.sh TKT-0311

DB_WRITE="/Users/ainchorsangiefpl/.openclaw/workspace/scripts/db-write.sh"
WORKSPACE="/Users/ainchorsangiefpl/.openclaw/workspace"

echo "--- Starting db-write.sh Regression Tests ---"

# Helper for cleanup
cleanup() {
    local tid=$1
    echo "Cleaning up $tid..."
    bash /Users/ainchorsangiefpl/.openclaw/workspace/scripts/db.sh -c "DELETE FROM state_tickets WHERE id='$tid';" 2>/dev/null
}

# Test 1: Normal insert with known columns
TID_1="TEST-001"
echo "[Test 1] Normal Insert: $TID_1"
RES_1=$($DB_WRITE state_tickets '{"status":"open","priority":"high"}' $TID_1)
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
RES_2=$($DB_WRITE state_tickets '{"status":"open","custom_field":"value123"}' $TID_2)
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
$DB_WRITE state_tickets '{"status":"open"}' $TID_3 > /dev/null
RES_3=$($DB_WRITE state_tickets '{"status":"closed"}' $TID_3)
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
RES_5=$($DB_WRITE state_tickets '{}' $TID_5)
echo "Result: $RES_5"
if echo "$RES_5" | grep -q '"status":"ok"'; then
    echo "✅ SUCCESS"
else
    echo "❌ FAILURE"
fi
cleanup $TID_5

echo "--- Tests Completed ---"
