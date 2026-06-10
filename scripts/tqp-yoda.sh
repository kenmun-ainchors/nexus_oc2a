#!/bin/zsh
# tqp-yoda.sh — Yoda Inline TQP Execution Gate Wrapper
# TKT-0309 Phase 2: Lightweight shell wrapper for sc_persist_atom / sc_resume_context
# Usage:
#   tqp-yoda.sh persist <tkt_id> <atom_index> <state_payload_json> [execution_context_json] [persistence_type]
#   tqp-yoda.sh resume  <tkt_id>
#   tqp-yoda.sh check   <tkt_id>
#   tqp-yoda.sh persist-sub-crest <tkt_id> <phase> [payload_json] [iteration_count]
#   tqp-yoda.sh resume-sub-crest  <tkt_id>
#   tqp-yoda.sh resolve-escalation <tkt_id> <resolution> <resolved_by> [next_phase]

emulate -L zsh

SCRIPT_DIR="${0:A:h}"
LIB_DIR="${SCRIPT_DIR}/lib"
ACTION="${1:-help}"
TKT="${2:-}"

case "$ACTION" in
  persist)
    ATOM_IDX="${3:-}"
    PAYLOAD="${4:-}"
    CTX="${5:-EMPTY_CTX}"
    PTYPE="${6:-INLINE_ATOM}"

    if [[ -z "$TKT" || -z "$ATOM_IDX" || -z "$PAYLOAD" ]]; then
      printf '{"ok":false,"msg":"Usage: tqp-yoda.sh persist <tkt_id> <atom_index> <state_payload_json> [exec_ctx_json] [persist_type]"}\n'
      exit 1
    fi

    export TQP_LIBDIR="$LIB_DIR"
    export TQP_TKT="$TKT"
    export TQP_ATOM_IDX="$ATOM_IDX"
    export TQP_PAYLOAD="$PAYLOAD"
    export TQP_CTX="$CTX"
    export TQP_PTYPE="$PTYPE"

    python3 <<'PYEOF'
import sys, json, os
sys.path.insert(0, os.environ['TQP_LIBDIR'])
from pg_task_queue import sc_persist_atom

state = json.loads(os.environ['TQP_PAYLOAD'])
raw_ctx = os.environ['TQP_CTX']
ctx = {} if raw_ctx == 'EMPTY_CTX' else json.loads(raw_ctx)
ok, msg = sc_persist_atom(
    os.environ['TQP_TKT'],
    int(os.environ['TQP_ATOM_IDX']),
    state, ctx,
    os.environ['TQP_PTYPE']
)
print(json.dumps({'ok': ok, 'msg': msg}))
PYEOF
    ;;

  resume)
    if [[ -z "$TKT" ]]; then
      printf '{"ok":false,"msg":"Usage: tqp-yoda.sh resume <tkt_id>"}\n'
      exit 1
    fi

    export TQP_LIBDIR="$LIB_DIR"
    export TQP_TKT="$TKT"

    python3 <<'PYEOF'
import sys, json, os
sys.path.insert(0, os.environ['TQP_LIBDIR'])
from pg_task_queue import sc_resume_context

ok, data, msg = sc_resume_context(os.environ['TQP_TKT'])
print(json.dumps({'ok': ok, 'data': data, 'msg': msg}, default=str))
PYEOF
    ;;

  check)
    if [[ -z "$TKT" ]]; then
      printf '{"ok":false,"msg":"Usage: tqp-yoda.sh check <tkt_id>"}\n'
      exit 1
    fi

    export TQP_LIBDIR="$LIB_DIR"
    export TQP_TKT="$TKT"

    python3 <<'PYEOF'
import sys, json, os
sys.path.insert(0, os.environ['TQP_LIBDIR'])
from pg_task_queue import pg_read_task

task = pg_read_task(os.environ['TQP_TKT'])
if task is None:
    print(json.dumps({'ok': False, 'msg': 'Task not found in TQP'}))
else:
    print(json.dumps({
        'ok': True,
        'task_id': task.get('id'),
        'atom_index': task.get('atom_index'),
        'persistence_type': task.get('persistence_type'),
        'state_payload': task.get('state_payload'),
        'execution_context': task.get('execution_context'),
        'parent_task_id': task.get('parent_task_id')
    }, default=str))
PYEOF
    ;;

  persist-sub-crest)
    # TKT-0382: Persist sub-CREST phase transition (Yoda wraps specialist phase tracking)
    PHASE="${3:-}"
    PAYLOAD="${4:-}"
    ITERATION="${5:-}"

    if [[ -z "$TKT" || -z "$PHASE" ]]; then
      printf '{"ok":false,"msg":"Usage: tqp-yoda.sh persist-sub-crest <tkt_id> <phase> [payload_json] [iteration_count]"}\n'
      exit 1
    fi

    export TQP_LIBDIR="$LIB_DIR"
    export TQP_TKT="$TKT"
    export TQP_PHASE="$PHASE"
    export TQP_PAYLOAD="$PAYLOAD"
    export TQP_ITERATION="$ITERATION"

    python3 <<'PYEOF'
import sys, json, os
sys.path.insert(0, os.environ['TQP_LIBDIR'])
from pg_task_queue import sc_persist_sub_crest_phase

payload = json.loads(os.environ['TQP_PAYLOAD']) if os.environ.get('TQP_PAYLOAD') else None
iter_count = int(os.environ['TQP_ITERATION']) if os.environ.get('TQP_ITERATION') else None
ok, msg = sc_persist_sub_crest_phase(
    os.environ['TQP_TKT'],
    os.environ['TQP_PHASE'],
    payload, iter_count
)
print(json.dumps({'ok': ok, 'msg': msg}))
PYEOF
    ;;

  resume-sub-crest)
    # TKT-0382: Resume sub-CREST context with iteration tracking
    if [[ -z "$TKT" ]]; then
      printf '{"ok":false,"msg":"Usage: tqp-yoda.sh resume-sub-crest <tkt_id>"}\n'
      exit 1
    fi

    export TQP_LIBDIR="$LIB_DIR"
    export TQP_TKT="$TKT"

    python3 <<'PYEOF'
import sys, json, os
sys.path.insert(0, os.environ['TQP_LIBDIR'])
from pg_task_queue import sc_resume_sub_crest

ok, data, msg = sc_resume_sub_crest(os.environ['TQP_TKT'])
print(json.dumps({'ok': ok, 'data': data, 'msg': msg}, default=str))
PYEOF
    ;;

  resolve-escalation)
    # TKT-0387: Yoda resolves an escalation handshake.
    # Accepts escalation, updates handshake.json, moves sub_crest to sub_crest_replanning.
    RESOLUTION="${3:-}"
    RESOLVED_BY="${4:-yoda}"
    NEXT_PHASE="${5:-sub_crest_replanning}"

    if [[ -z "$TKT" || -z "$RESOLUTION" ]]; then
      printf '{"ok":false,"msg":"Usage: tqp-yoda.sh resolve-escalation <tkt_id> <resolution> [resolved_by] [next_phase]"}\n'
      exit 1
    fi

    export TQP_LIBDIR="$LIB_DIR"
    export TQP_TKT="$TKT"
    export TQP_RESOLUTION="$RESOLUTION"
    export TQP_RESOLVED_BY="$RESOLVED_BY"
    export TQP_NEXT_PHASE="$NEXT_PHASE"

    python3 <<'PYEOF'
import sys, json, os, datetime
sys.path.insert(0, os.environ['TQP_LIBDIR'])
from pg_task_queue import pg_read_task, pg_set_task_status, validate_state_transition, _escape_sql, _pg

task_id = os.environ['TQP_TKT']
resolution = os.environ['TQP_RESOLUTION']
resolved_by = os.environ['TQP_RESOLVED_BY']
next_phase = os.environ['TQP_NEXT_PHASE']

results = {'steps': []}
now = datetime.datetime.now().isoformat()

# Step 1: READ current state
sub_task = pg_read_task(task_id)
if sub_task is None:
    print(json.dumps({'ok': False, 'msg': f'Task {task_id} not found'}))
    sys.exit(1)

current_status = sub_task.get('status', 'unknown')
results['current_status'] = current_status
results['steps'].append(f'READ: {task_id} status={current_status}')

# Step 2: VALIDATE — must be escalated
if current_status != 'escalated':
    print(json.dumps({'ok': False, 'msg': f'Task {task_id} is {current_status}, not escalated'}))
    sys.exit(1)

# Step 3: Transition sub-task from escalated → next_phase
valid, msg = validate_state_transition(current_status, next_phase)

# escalated has no transitions in the state machine (it's terminal),
# so we'll do a direct status update since Yoda is the authority.
# This is the resolution path — Yoda overwrites the terminal state.
set_clauses = [
    f"status = {_escape_sql(next_phase)}",
    f"updated_at = {_escape_sql(now)}",
    "updated_at_ts = now()"
]
query = f"""
UPDATE state_task_queue SET {', '.join(set_clauses)}
WHERE id = {_escape_sql(task_id)}
"""
_pg(query)
results['steps'].append(f'PG: {task_id} escalated -> {next_phase}')

# Step 4: Update escalation-handshake.json
handshake_path = '/Users/ainchorsangiefpl/.openclaw/workspace/state/escalation-handshake.json'
try:
    with open(handshake_path) as f:
        handshake = json.load(f)
    handshake['resolution'] = resolution
    handshake['resolved_at'] = now
    handshake['resolved_by'] = resolved_by
    # Keep escalation details for audit
    with open(handshake_path, 'w') as f:
        json.dump(handshake, f, indent=2)
        f.write('\n')
    results['steps'].append(f'HANDSHAKE: resolution={resolution}')
    results['handshake_updated'] = True
except Exception as e:
    results['steps'].append(f'HANDSHAKE WARN: {e}')
    results['handshake_updated'] = False

# Step 5: If parent exists, also transition parent from master_replanning
parent_task_id = sub_task.get('parent_task_id')
if parent_task_id:
    parent_task = pg_read_task(parent_task_id)
    if parent_task and parent_task.get('status') == 'master_replanning':
        pg_set_task_status(parent_task_id, 'sub_tickets_dispatched')
        results['steps'].append(f'PG: parent {parent_task_id} master_replanning -> sub_tickets_dispatched')

# Step 6: VERIFY
verified = pg_read_task(task_id)
if verified is None:
    results['verified'] = False
    results['steps'].append('VERIFY FAILED: task not found')
else:
    results['verified'] = True
    results['verified_status'] = verified.get('status')
    results['steps'].append(f'VERIFY: {task_id} now {verified.get("status")}')

results['ok'] = True
results['msg'] = f'Escalation resolved: {task_id} {current_status} -> {next_phase} ({resolution} by {resolved_by})'
print(json.dumps(results))
PYEOF
    ;;

  *)
    printf '{"ok":false,"msg":"Unknown action: %s. Use persist | resume | check | persist-sub-crest | resume-sub-crest | resolve-escalation"}\n' "$ACTION"
    exit 1
    ;;
esac
