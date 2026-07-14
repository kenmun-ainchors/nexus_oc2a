#!/bin/bash
# TKT-0303: sc_read wrapper regression test
# Verifies State Checking read wrappers function correctly against PG
set -e

echo "=== TKT-0303: sc_read Task Wrapper Tests ==="

# Test 1: sc_read_task returns valid task
echo -n "Test 1 (sc_read_task — valid task): "
RESULT=$(python3 -c "
import sys
sys.path.insert(0, '/Users/ainchorsoc2a/.openclaw/workspace/scripts/lib')
from pg_task_queue import sc_read_task
ok, task, msg = sc_read_task('task-2026-05-17-2e43e59d')
if ok and task and task['id'] == 'task-2026-05-17-2e43e59d':
    print('PASS')
else:
    print(f'FAIL: {msg}')
" 2>&1)
echo "$RESULT"
[[ "$RESULT" == "PASS" ]] || exit 1

# Test 2: sc_read_task returns False for missing task
echo -n "Test 2 (sc_read_task — missing task): "
RESULT=$(python3 -c "
import sys
sys.path.insert(0, '/Users/ainchorsoc2a/.openclaw/workspace/scripts/lib')
from pg_task_queue import sc_read_task
ok, task, msg = sc_read_task('DOES-NOT-EXIST')
if not ok and task is None:
    print('PASS')
else:
    print(f'FAIL: ok={ok}, task={task}, msg={msg}')
" 2>&1)
echo "$RESULT"
[[ "$RESULT" == "PASS" ]] || exit 1

# Test 3: sc_read_all_tasks returns list
echo -n "Test 3 (sc_read_all_tasks — returns list): "
RESULT=$(python3 -c "
import sys
sys.path.insert(0, '/Users/ainchorsoc2a/.openclaw/workspace/scripts/lib')
from pg_task_queue import sc_read_all_tasks
ok, tasks, msg = sc_read_all_tasks()
if ok and isinstance(tasks, list) and len(tasks) > 0:
    print(f'PASS ({len(tasks)} tasks)')
else:
    print(f'FAIL: ok={ok}, type={type(tasks).__name__}, msg={msg}')
" 2>&1)
echo "$RESULT"
[[ "$RESULT" == *"PASS"* ]] || exit 1

# Test 4: All tasks have required fields
echo -n "Test 4 (sc_read_all_tasks — structural integrity): "
RESULT=$(python3 -c "
import sys
sys.path.insert(0, '/Users/ainchorsoc2a/.openclaw/workspace/scripts/lib')
from pg_task_queue import sc_read_all_tasks
ok, tasks, msg = sc_read_all_tasks()
if not ok:
    print(f'FAIL: {msg}')
    sys.exit(1)
for t in tasks:
    if 'id' not in t or t['id'] is None:
        print(f'FAIL: task missing id')
        sys.exit(1)
    if 'status' not in t:
        print(f'FAIL: task {t.get(\"id\",\"?\")} missing status')
        sys.exit(1)
print(f'PASS ({len(tasks)} tasks all valid)')
" 2>&1)
echo "$RESULT"
[[ "$RESULT" == *"PASS"* ]] || exit 1

# Test 5: sc_read_task returns 3-tuple (ok, task, msg)
echo -n "Test 5 (sc_read_task — return type): "
RESULT=$(python3 -c "
import sys
sys.path.insert(0, '/Users/ainchorsoc2a/.openclaw/workspace/scripts/lib')
from pg_task_queue import sc_read_task
result = sc_read_task('task-2026-05-17-2e43e59d')
if len(result) == 3 and isinstance(result[0], bool) and isinstance(result[2], str):
    print('PASS')
else:
    print(f'FAIL: got {len(result)}-tuple, types={[type(x).__name__ for x in result]}')
" 2>&1)
echo "$RESULT"
[[ "$RESULT" == "PASS" ]] || exit 1

# Test 6: task-queue-status.py works via sc_read_task
echo -n "Test 6 (task-queue-status.py — via sc_read): "
RESULT=$(python3 /Users/ainchorsoc2a/.openclaw/workspace/scripts/lib/task-queue-status.py \
  /Users/ainchorsoc2a/.openclaw/workspace/state/task-queue.json \
  task-2026-05-17-2e43e59d 2>&1 | head -1)
if echo "$RESULT" | grep -q "Task (PG)"; then
    echo "PASS"
else
    echo "FAIL: $RESULT"
    exit 1
fi

# Test 7: task-queue-list.py works via sc_read_all_tasks
echo -n "Test 7 (task-queue-list.py — via sc_read): "
RESULT=$(python3 /Users/ainchorsoc2a/.openclaw/workspace/scripts/lib/task-queue-list.py \
  /Users/ainchorsoc2a/.openclaw/workspace/state/task-queue.json 2>&1 | head -1)
if echo "$RESULT" | grep -q "Total tasks (PG)"; then
    echo "PASS"
else
    echo "FAIL: $RESULT"
    exit 1
fi

echo ""
echo "=== All TKT-0303 tests PASSED ==="
exit 0
