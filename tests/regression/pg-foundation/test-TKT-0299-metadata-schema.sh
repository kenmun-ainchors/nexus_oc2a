#!/bin/bash
# TKT-0299: JSON Schema contract for metadata JSONB regression test
set -e

echo "=== TKT-0299: Metadata JSONB Schema Validation Tests ==="
SCHEMA="/Users/ainchorsangiefpl/.openclaw/workspace/docs/schemas/metadata-jsonb-schema.json"
DBWRITE="/Users/ainchorsangiefpl/.openclaw/workspace/scripts/db-write.sh"

# Test 1: Schema file exists and is valid JSON
echo -n "Test 1 (schema file exists + valid JSON): "
if [ -f "$SCHEMA" ]; then
    python3 -c "import json; json.load(open('$SCHEMA')); print('PASS')" 2>&1
else
    echo "FAIL: $SCHEMA not found"
    exit 1
fi

# Test 2: Schema covers all 3 tables with metadata columns
echo -n "Test 2 (schema covers required tables): "
python3 -c "
import json
s = json.load(open('$SCHEMA'))
tables = s.get('tables', {})
required = ['state_tickets', 'state_latency', 'changelog']
missing = [t for t in required if t not in tables]
if missing:
    print(f'FAIL: missing tables {missing}')
    exit(1)
print('PASS')
" 2>&1

# Test 3: Known metadata key writes successfully
echo -n "Test 3 (valid metadata — known key, correct type): "
RESULT=$(bash "$DBWRITE" state_tickets \
  '{"title":"TKT-0299 test 3","status":"open","priority":"low","sprint":"S5"}' \
  TEST-299-003 2>&1)
if echo "$RESULT" | grep -q '"postgres"'; then
    echo "PASS"
else
    echo "FAIL: $RESULT"
    exit 1
fi

# Test 4: state_latency rejects unknown keys (allowUnknownKeys=false)
echo -n "Test 4 (state_latency — rejects unknown key): "
RESULT=$(bash "$DBWRITE" state_latency \
  '{"cron_id":"test-299","duration_ms":500,"status":"test","bad_key":"value"}' \
  test-299-lat 2>&1)
if echo "$RESULT" | grep -q '"degraded"'; then
    echo "PASS"
else
    echo "FAIL: should have been rejected"
    exit 1
fi

# Test 5: type mismatch on known key warns but doesn't reject (P1 warn mode)
echo -n "Test 5 (type mismatch — warns, doesn't reject): "
RESULT=$(bash "$DBWRITE" state_tickets \
  '{"title":"TKT-0299 test 5","status":"open","priority":"low","owner":12345}' \
  TEST-299-005 2>&1)
if echo "$RESULT" | grep -q '"postgres"'; then
    echo "PASS"
else
    echo "FAIL: $RESULT"
    exit 1
fi

# Test 6: Verify metadata stored in PG after write
echo -n "Test 6 (metadata persisted correctly): "
python3 -c "
import os, subprocess, json
env = os.environ.copy()
env.update({'PGHOST': '/tmp', 'PGPORT': '5432', 'PGUSER': 'ainchorsangiefpl', 'PGDATABASE': 'ainchors_nexus'})
r = subprocess.run(
    ['/opt/homebrew/bin/psql', '-t', '-A', '-c',
     \"SELECT metadata FROM state_tickets WHERE id = 'TEST-299-003'\"],
    capture_output=True, text=True, env=env)
meta = json.loads(r.stdout.strip())
if meta.get('sprint') == 'S5':
    print('PASS')
else:
    print(f'FAIL: unexpected metadata: {meta}')
    exit(1)
" 2>&1
[[ "$(echo "$RESULT" | tail -1)" == "PASS" ]] || exit 1

# Cleanup
python3 -c "
import os, subprocess
env = os.environ.copy()
env.update({'PGHOST': '/tmp', 'PGPORT': '5432', 'PGUSER': 'ainchorsangiefpl', 'PGDATABASE': 'ainchors_nexus'})
for tid in ['TEST-299-003', 'TEST-299-005', 'TEST-299-005', 'test-299-lat']:
    subprocess.run(['/opt/homebrew/bin/psql', '-c', f\"DELETE FROM state_tickets WHERE id = '{tid}'\"], env=env, capture_output=True)
    subprocess.run(['/opt/homebrew/bin/psql', '-c', f\"DELETE FROM state_latency WHERE cron_id = '{tid}'\"], env=env, capture_output=True)
" 2>/dev/null

echo ""
echo "=== All TKT-0299 tests PASSED ==="
exit 0
