#!/bin/bash
# JSON file remains valid after ticket operations
set -e
$(command -v jq 2>/dev/null || brew --prefix 2>/dev/null)/bin/jq empty /Users/ainchorsoc2a/.openclaw/workspace/state/tickets.json 2>/dev/null && exit 0 || exit 1
