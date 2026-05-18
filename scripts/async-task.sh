#!/usr/bin/env bash
# async-task.sh — Execute long-running tasks in background sub-agents
# Usage: async-task.sh --name "task_name" --script "path/to/script.py"
#        async-task.sh --name "task_name" --command "shell command"
#        async-task.sh --status [--name "task_name"]
#
# All async tasks run as isolated subagent sessions that don't block webchat.
# State tracked in state/async-tasks.json

set -euo pipefail

WORKSPACE="/Users/ainchorsangiefpl/.openclaw/workspace"
STATE_FILE="$WORKSPACE/state/async-tasks.json"
SUBCOMMAND="${1:-help}"; shift || true

# Init state file if missing
if [[ ! -f "$STATE_FILE" ]]; then
  /usr/bin/python3 -c "import json; json.dump({'tasks':{}, 'history':[]}, open('$STATE_FILE','w'), indent=2)"
fi

register_task() {
  local name="$1" type="$2" detail="$3"
  local now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  /usr/bin/python3 -c "
import json
d = json.load(open('$STATE_FILE'))
d['tasks']['$name'] = {
    'name': '$name',
    'type': '$type',
    'detail': '${detail//\'/\'\\\'\'}',
    'status': 'running',
    'startedAt': '$now',
    'completedAt': None,
    'error': None
}
json.dump(d, open('$STATE_FILE','w'), indent=2)
print('Registered: $name')
"
}

complete_task() {
  local name="$1" error="${2:-}"
  local now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  /usr/bin/python3 -c "
import json
d = json.load(open('$STATE_FILE'))
if '$name' in d['tasks']:
    d['tasks']['$name']['status'] = 'error' if '$error' else 'done'
    d['tasks']['$name']['completedAt'] = '$now'
    d['tasks']['$name']['error'] = '${error//\'/\'\\\'\'}'
json.dump(d, open('$STATE_FILE','w'), indent=2)
print('Completed: $name')
"
}

if [[ "$SUBCOMMAND" == "exec" ]]; then
  NAME=""; SCRIPT=""; COMMAND=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --name) NAME="$2"; shift 2 ;;
      --script) SCRIPT="$2"; shift 2 ;;
      --command) COMMAND="$2"; shift 2 ;;
      *) echo "Unknown: $1"; exit 1 ;;
    esac
  done
  [[ -z "$NAME" ]] && { echo "ERROR: --name required"; exit 1; }
  
  register_task "$NAME" "exec" "${SCRIPT:-$COMMAND}"
  
  if [[ -n "$SCRIPT" ]]; then
    /usr/bin/python3 -u "$SCRIPT" 2>&1 && complete_task "$NAME" || complete_task "$NAME" "Script failed"
  elif [[ -n "$COMMAND" ]]; then
    eval "$COMMAND" 2>&1 && complete_task "$NAME" || complete_task "$NAME" "Command failed"
  fi

elif [[ "$SUBCOMMAND" == "spawn" ]]; then
  NAME=""; TASK=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --name) NAME="$2"; shift 2 ;;
      --task) TASK="$2"; shift 2 ;;
      *) echo "Unknown: $1"; exit 1 ;;
    esac
  done
  [[ -z "$NAME" ]] && { echo "ERROR: --name required"; exit 1; }
  [[ -z "$TASK" ]] && { echo "ERROR: --task required"; exit 1; }
  
  register_task "$NAME" "spawn" "${TASK:0:200}"
  echo "TASK_SPAWN: $NAME — $TASK"  # This gets picked up by the caller for sessions_spawn

elif [[ "$SUBCOMMAND" == "status" ]]; then
  NAME="${1:-}"
  if [[ -z "$NAME" ]]; then
    /opt/homebrew/bin/jq '.tasks' "$STATE_FILE"
  else
    /opt/homebrew/bin/jq --arg n "$NAME" '.tasks[$n] // "NOT FOUND"' "$STATE_FILE"
  fi

elif [[ "$SUBCOMMAND" == "complete" ]]; then
  NAME="${1:-}"
  ERROR="${2:-}"
  [[ -z "$NAME" ]] && { echo "ERROR: name required"; exit 1; }
  complete_task "$NAME" "$ERROR"

else
  echo "Usage:"
  echo "  async-task.sh exec   --name NAME --script PATH     # Run script async"
  echo "  async-task.sh exec   --name NAME --command CMD      # Run command async"
  echo "  async-task.sh spawn  --name NAME --task DESCRIPTION # Flag for subagent spawn"
  echo "  async-task.sh status [NAME]                         # Check task status"
  echo "  async-task.sh complete NAME [ERROR]                 # Mark task done/failed"
fi
