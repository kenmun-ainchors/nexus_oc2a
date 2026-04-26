#!/usr/bin/env bash
# task-complete.sh — Mark a task done, failed, or blocked
# Usage: task-complete.sh <task-id> <final-status> [summary]
# Final status: completed | failed | blocked | cancelled

WORKSPACE="/Users/ainchorsangiefpl/.openclaw/workspace"
HANDOFF="$WORKSPACE/handoff"
STATE="$WORKSPACE/state/async-tasks.json"
ARCHIVE="$HANDOFF/archive"

TASK_ID="${1:-}"
FINAL_STATUS="${2:-completed}"
SUMMARY="${3:-}"

if [[ -z "$TASK_ID" ]]; then
  echo "Usage: task-complete.sh <task-id> <final-status> [summary]" >&2
  exit 1
fi

TASK_FILE="$HANDOFF/${TASK_ID}.md"
TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
FINAL_UPPER="$(echo "$FINAL_STATUS" | tr '[:lower:]' '[:upper:]')"

if [[ ! -f "$TASK_FILE" ]]; then
  echo "ERROR: Task file not found: $TASK_FILE" >&2
  exit 1
fi

# Final entry
cat >> "$TASK_FILE" << DONEEOF

---
## FINAL STATUS: ${FINAL_UPPER}
- **Completed at:** ${TIMESTAMP}
- **Summary:** ${SUMMARY}
DONEEOF

sed -i '' "s|^- \*\*Current:\*\* .*|- **Current:** ${FINAL_STATUS}|" "$TASK_FILE"
sed -i '' "s|^- \*\*Last updated:\*\* .*|- **Last updated:** ${TIMESTAMP}|" "$TASK_FILE"

echo "Task $TASK_ID marked: $FINAL_STATUS"

# Archive if completed or cancelled
if [[ "$FINAL_STATUS" == "completed" || "$FINAL_STATUS" == "cancelled" ]]; then
  mkdir -p "$ARCHIVE"
  mv "$TASK_FILE" "$ARCHIVE/${TASK_ID}-${FINAL_STATUS}.md"
  echo "Archived to: $ARCHIVE/${TASK_ID}-${FINAL_STATUS}.md"
fi

python3 - "$STATE" "$TASK_ID" "$FINAL_STATUS" "$TIMESTAMP" "$SUMMARY" << 'PYEOF'
import json, os, sys

state_file, task_id, final_status, timestamp, summary = sys.argv[1:]

if not os.path.exists(state_file):
    sys.exit(0)

with open(state_file) as f:
    tasks = json.load(f)

t = tasks.get("activeTasks", {}).pop(task_id, None)
if t:
    t["status"] = final_status
    t["completedAt"] = timestamp
    t["summary"] = summary
    tasks.setdefault("completedTasks", {})[task_id] = t

tasks["lastUpdated"] = timestamp

tmp = state_file + ".tmp"
with open(tmp, "w") as f:
    json.dump(tasks, f, indent=2)
os.rename(tmp, state_file)
print("Moved to completedTasks")
PYEOF
