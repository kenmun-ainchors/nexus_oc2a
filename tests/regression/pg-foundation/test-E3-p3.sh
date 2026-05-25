#!/bin/bash
# Heartbeat budget check references cost state
set -e
grep -q 'cost-state\|cost-alert' /Users/ainchorsangiefpl/.openclaw/workspace/HEARTBEAT.md && exit 0 || exit 1
