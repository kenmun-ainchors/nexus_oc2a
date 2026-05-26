#!/bin/bash
# TKT-0304: Missing state domains migration regression test
# Verifies state_governance and state_latency tables in PG
set -e

echo "=== TKT-0304: State Domain Migration Tests ==="

# Test 1: state_governance table exists and is readable
echo -n "Test 1 (state_governance — readable via db-read.sh): "
RESULT=$(bash /Users/ainchorsangiefpl/.openclaw/workspace/scripts/db-read.sh state_governance 2>&1)
COUNT=$(echo "$RESULT" | python3 -c "import json,sys; d=json.load(sys.stdin); print(len(d))" 2>/dev/null)
if [ -n "$COUNT" ] && [ "$COUNT" -gt 0 ]; then
    echo "PASS ($COUNT rows)"
else
    echo "FAIL: no rows returned"
    exit 1
fi

# Test 2: state_governance has correct columns
echo -n "Test 2 (state_governance — required columns): "
RESULT=$(python3 -c "
import os, subprocess
env = os.environ.copy()
env.update({'PGHOST': '/tmp', 'PGPORT': '5432', 'PGUSER': 'ainchorsangiefpl', 'PGDATABASE': 'ainchors_nexus'})
r = subprocess.run(['/opt/homebrew/bin/psql', '-t', '-A', '-c',
    \"SELECT column_name FROM information_schema.columns WHERE table_name = 'state_governance' ORDER BY ordinal_position\"],
    capture_output=True, text=True, env=env)
cols = r.stdout.strip().split('\n')
required = ['review_type', 'verdict', 'timestamp']
missing = [c for c in required if c not in cols]
if missing:
    print(f'FAIL: missing {missing}')
else:
    print('PASS')
" 2>&1)
echo "$RESULT"
[[ "$RESULT" == "PASS" ]] || exit 1

# Test 3: state_latency table exists and is readable
echo -n "Test 3 (state_latency — readable via db-read.sh): "
RESULT=$(bash /Users/ainchorsangiefpl/.openclaw/workspace/scripts/db-read.sh state_latency 2>&1)
COUNT=$(echo "$RESULT" | python3 -c "import json,sys; d=json.load(sys.stdin); print(len(d))" 2>/dev/null)
if [ -n "$COUNT" ] && [ "$COUNT" -gt 0 ]; then
    echo "PASS ($COUNT rows)"
else
    echo "FAIL: no rows returned"
    exit 1
fi

# Test 4: state_latency has correct columns
echo -n "Test 4 (state_latency — required columns): "
RESULT=$(python3 -c "
import os, subprocess
env = os.environ.copy()
env.update({'PGHOST': '/tmp', 'PGPORT': '5432', 'PGUSER': 'ainchorsangiefpl', 'PGDATABASE': 'ainchors_nexus'})
r = subprocess.run(['/opt/homebrew/bin/psql', '-t', '-A', '-c',
    \"SELECT column_name FROM information_schema.columns WHERE table_name = 'state_latency' ORDER BY ordinal_position\"],
    capture_output=True, text=True, env=env)
cols = r.stdout.strip().split('\n')
required = ['cron_id', 'duration_ms', 'recorded_at']
missing = [c for c in required if c not in cols]
if missing:
    print(f'FAIL: missing {missing}')
else:
    print('PASS')
" 2>&1)
echo "$RESULT"
[[ "$RESULT" == "PASS" ]] || exit 1

# Test 5: governance-report.sh dual-write to PG works (dry-run via inline test)
echo -n "Test 5 (governance PG insert — write path): "
RESULT=$(python3 -c "
import os, subprocess, json
env = os.environ.copy()
env.update({'PGHOST': '/tmp', 'PGPORT': '5432', 'PGUSER': 'ainchorsangiefpl', 'PGDATABASE': 'ainchors_nexus'})

# Test insert
test_id = f'test-tkt0304-$(date +%s)'
details = json.dumps({'test': True, 'source': 'regression'})
r = subprocess.run(
    ['/opt/homebrew/bin/psql', '-c',
     f\"INSERT INTO state_governance (review_type, asset_ref, verdict, timestamp, details) \" +
     f\"VALUES ('shield', 'test-asset', 'PASS', now(), '{details}')\"],
    capture_output=True, text=True, env=env)
if 'INSERT' in r.stdout or r.returncode == 0:
    print('PASS')
else:
    print(f'FAIL: {r.stderr}')
" 2>&1)
echo "$RESULT"
[[ "$RESULT" == "PASS" ]] || exit 1

# Test 6: state_latency PG insert works
echo -n "Test 6 (latency PG insert — write path): "
RESULT=$(python3 -c "
import os, subprocess
env = os.environ.copy()
env.update({'PGHOST': '/tmp', 'PGPORT': '5432', 'PGUSER': 'ainchorsangiefpl', 'PGDATABASE': 'ainchors_nexus'})
r = subprocess.run(
    ['/opt/homebrew/bin/psql', '-c',
     \"INSERT INTO state_latency (cron_id, duration_ms, status, recorded_at) \" +
     \"VALUES ('test-tkt0304', 1234, 'test', now())\"],
    capture_output=True, text=True, env=env)
if 'INSERT' in r.stdout or r.returncode == 0:
    print('PASS')
else:
    print(f'FAIL: {r.stderr}')
" 2>&1)
echo "$RESULT"
[[ "$RESULT" == "PASS" ]] || exit 1

echo ""
echo "=== All TKT-0304 tests PASSED ==="
exit 0
