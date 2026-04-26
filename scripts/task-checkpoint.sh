#!/usr/bin/env bash
# task-checkpoint.sh — Write a step checkpoint to a TASK file
# Usage: task-checkpoint.sh <task-id> <step-name> <status> <output-summary>
# Status: running | done | blocked | failed

WORKSPACE="/Users/ainchorsangiefpl/.openclaw/workspace"
HANDOFF="$WORKSPACE/handoff"
STATE="$WORKSPACE/state/async-tasks.json"

TASK_ID="${1:-}"
STEP="${2:-}"
STEP_STATUS="${3:-running}"
OUTPUT="${4:-}"

if [[ -z "$TASK_ID" || -z "$STEP" ]]; then
  echo "Usage: task-checkpoint.sh <task-id> <step-name> <status> <output-summary>" >&2
  exit 1
fi

TASK_FILE="$HANDOFF/${TASK_ID}.md"
TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

if [[ ! -f "$TASK_FILE" ]]; then
  echo "ERROR: Task file not found: $TASK_FILE" >&2
  exit 1
fi

# Append checkpoint to task file
cat >> "$TASK_FILE" << CPEOF

### Checkpoint: ${STEP} @ ${TIMESTAMP}
- **Status:** ${STEP_STATUS}
- **Output:** ${OUTPUT}
CPEOF

# Update status fields in task file (macOS sed uses '' for in-place)
sed -i '' "s|^- \*\*Current:\*\* .*|- **Current:** ${STEP_STATUS}|" "$TASK_FILE"
sed -i '' "s|^- \*\*Current step:\*\* .*|- **Current step:** ${STEP}|" "$TASK_FILE"
sed -i '' "s|^- \*\*Last updated:\*\* .*|- **Last updated:** ${TIMESTAMP}|" "$TASK_FILE"

echo "Checkpoint written: $TASK_ID / $STEP ($STEP_STATUS)"

python3 - "$STATE" "$TASK_ID" "$STEP" "$STEP_STATUS" "$TIMESTAMP" << 'PYEOF'
import json, os, sys

state_file, task_id, step, step_status, timestamp = sys.argv[1:]

if not os.path.exists(state_file):
    print("No state file — skipping")
    sys.exit(0)

with open(state_file) as f:
    tasks = json.load(f)

t = tasks.get("activeTasks", {}).get(task_id)
if not t:
    print("Task not in registry — skipping")
    sys.exit(0)

t["currentStep"] = step
t["status"] = step_status
t["lastUpdatedAt"] = timestamp
if step_status == "done":
    t["stepsCompleted"] = t.get("stepsCompleted", 0) + 1

tasks["lastUpdated"] = timestamp

tmp = state_file + ".tmp"
with open(tmp, "w") as f:
    json.dump(tasks, f, indent=2)
os.rename(tmp, state_file)
print("Registry updated")
PYEOF
