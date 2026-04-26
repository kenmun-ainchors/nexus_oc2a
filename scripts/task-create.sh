#!/usr/bin/env bash
# task-create.sh — Create a new async TASK file and register it
# Usage: task-create.sh <task-id> <goal> <steps-json> [agent]

WORKSPACE="/Users/ainchorsangiefpl/.openclaw/workspace"
HANDOFF="$WORKSPACE/handoff"
STATE="$WORKSPACE/state/async-tasks.json"

TASK_ID="${1:-}"
GOAL="${2:-}"
STEPS_JSON="${3:-[]}"
AGENT="${4:-yoda}"

if [[ -z "$TASK_ID" || -z "$GOAL" ]]; then
  echo "Usage: task-create.sh <task-id> <goal> <steps-json> [agent]" >&2
  exit 1
fi

TASK_FILE="$HANDOFF/${TASK_ID}.md"
CREATED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

mkdir -p "$HANDOFF"

cat > "$TASK_FILE" << TASKEOF
# ${TASK_ID}
_Created: ${CREATED_AT} | Agent: ${AGENT} | Status: pending_

## Goal
${GOAL}

## Steps
\`\`\`json
${STEPS_JSON}
\`\`\`

## Checkpoints
_Outputs written after each step completes._

## Status
- **Current:** pending
- **Current step:** —
- **Last updated:** ${CREATED_AT}
- **Blocked reason:** —

## Notes
TASKEOF

echo "Created: $TASK_FILE"

python3 - "$STATE" "$TASK_ID" "$GOAL" "$AGENT" "$CREATED_AT" "$STEPS_JSON" "$TASK_FILE" << 'PYEOF'
import json, os, sys

state_file, task_id, goal, agent, created_at, steps_json, task_file = sys.argv[1:]

tasks = {}
if os.path.exists(state_file):
    try:
        with open(state_file) as f:
            tasks = json.load(f)
    except Exception:
        tasks = {}

tasks.setdefault("activeTasks", {})
tasks.setdefault("completedTasks", {})

try:
    steps = json.loads(steps_json)
except Exception:
    steps = []

tasks["activeTasks"][task_id] = {
    "id": task_id,
    "goal": goal,
    "agent": agent,
    "status": "pending",
    "currentStep": None,
    "stepsTotal": len(steps),
    "stepsCompleted": 0,
    "createdAt": created_at,
    "lastUpdatedAt": created_at,
    "taskFile": task_file
}
tasks["lastUpdated"] = created_at

tmp = state_file + ".tmp"
with open(tmp, "w") as f:
    json.dump(tasks, f, indent=2)
os.rename(tmp, state_file)
print("Registered in async-tasks.json")
PYEOF
