#!/bin/zsh
# tqp-yoda.sh — Yoda Inline TQP Execution Gate Wrapper
# TKT-0309 Phase 2: Lightweight shell wrapper for sc_persist_atom / sc_resume_context
# Usage:
#   tqp-yoda.sh persist <tkt_id> <atom_index> <state_payload_json> [execution_context_json] [persistence_type]
#   tqp-yoda.sh resume  <tkt_id>
#   tqp-yoda.sh check   <tkt_id>

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

  *)
    printf '{"ok":false,"msg":"Unknown action: %s. Use persist | resume | check"}\n' "$ACTION"
    exit 1
    ;;
esac
