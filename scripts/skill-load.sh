#!/bin/bash
# skill-load.sh — Register a skill as loaded for the current session
# Call AFTER reading a skill's SKILL.md. This satisfies the skill-gate.
#
# Usage:
#   bash scripts/skill-load.sh "pg-sprint-backlog"
#   bash scripts/skill-load.sh "changelog"

set -euo pipefail

SKILL_REGISTRY="${SKILL_REGISTRY:-$HOME/.openclaw/workspace/state/skill-load-registry.json}"
SKILL_NAME="${1:-}"

if [[ -z "$SKILL_NAME" ]]; then
  echo "Usage: skill-load.sh <skill-name>" >&2
  echo "  e.g. skill-load.sh pg-sprint-backlog" >&2
  exit 1
fi

TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Create or update registry
python3 -c "
import json, os

path = '${SKILL_REGISTRY}'
skill = '${SKILL_NAME}'
ts = '${TIMESTAMP}'

reg = {}
if os.path.exists(path):
    try:
        with open(path) as f:
            reg = json.load(f)
    except (json.JSONDecodeError, ValueError):
        reg = {}

reg[skill] = ts

with open(path, 'w') as f:
    json.dump(reg, f, indent=2)

print(f'SKILL-LOAD: {skill} registered at {ts}')
" 2>&1
