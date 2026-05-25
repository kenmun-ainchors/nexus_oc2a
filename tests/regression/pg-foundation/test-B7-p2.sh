#!/bin/bash
# JSON file remains valid after ticket operations
set -e
/opt/homebrew/bin/jq empty /Users/ainchorsangiefpl/.openclaw/workspace/state/tickets.json 2>/dev/null && exit 0 || exit 1
