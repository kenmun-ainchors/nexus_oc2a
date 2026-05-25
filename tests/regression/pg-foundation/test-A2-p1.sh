#!/bin/bash
# All 8 state tables are readable via db-read.sh
set -e
for t in state_tickets state_cost state_task_queue state_model_policy state_config_baseline state_sprints state_linkedin state_standups; do
  COUNT=$(bash /Users/ainchorsangiefpl/.openclaw/workspace/scripts/db-read.sh "$t" 2>&1 | /opt/homebrew/bin/jq 'length' 2>/dev/null)
  [ -z "$COUNT" ] || [ "$COUNT" = "null" ] && echo "TABLE $t FAILED" && exit 1
done
exit 0
