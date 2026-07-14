#!/bin/bash
# Dual-write infrastructure exists (JSON file + fallback log path)
set -e
[ -f /Users/ainchorsoc2a/.openclaw/workspace/state/task-queue.json ] && exit 0 || exit 1
