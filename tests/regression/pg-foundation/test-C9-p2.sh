#!/bin/bash
# task-queue.sh list outputs PG-sourced data
set -e
OUTPUT=$(bash /Users/ainchorsoc2a/.openclaw/workspace/scripts/task-queue.sh list 2>&1)
echo "$OUTPUT" | grep -q 'Total tasks' && exit 0 || exit 1
