#!/bin/bash
# skill-load.sh — Canonical skill loader
# Enforces that agents load skills from agent-skills/ as canonical SSOT.
# Ticket-First Rule: load skill BEFORE invoking any domain script.
#
# Usage:
#   bash scripts/skill-load.sh <skill-name>
#   bash scripts/skill-load.sh agile

set -euo pipefail

WORKSPACE_ROOT="${WORKSPACE_ROOT:-/Users/ainchorsangiefpl/.openclaw/workspace}"
SKILL_REGISTRY="${SKILL_REGISTRY:-$WORKSPACE_ROOT/state/skill-load-registry.json}"
SKILL_INDEX="${SKILL_INDEX:-$WORKSPACE_ROOT/agent-skills/.index.json}"
SKILL_NAME="${1:-}"

if [[ -z "$SKILL_NAME" ]]; then
  echo "Usage: skill-load.sh <skill-name>" >&2
  echo "  e.g. skill-load.sh agile" >&2
  echo "  Registered skills:" >&2
  if [[ -f "$SKILL_INDEX" ]]; then
    jq -r '.skills[] | "  - \(.name) [\(.category)]"' "$SKILL_INDEX" 2>/dev/null || true
  fi
  exit 1
fi

# ── Fail closed: index must exist ─────────────────────────────────────────
if [[ ! -f "$SKILL_INDEX" ]]; then
  echo "ERROR: Skill index missing: $SKILL_INDEX" >&2
  echo "Cannot load '$SKILL_NAME'. The canonical skill registry is unavailable." >&2
  exit 2
fi

# ── Look up skill in canonical index ─────────────────────────────────────
SKILL_PATH=$(jq -r --arg name "$SKILL_NAME" '.skills[] | select(.name == $name) | .path' "$SKILL_INDEX" 2>/dev/null || true)
SKILL_APPROVED=$(jq -r --arg name "$SKILL_NAME" '.skills[] | select(.name == $name) | .approved' "$SKILL_INDEX" 2>/dev/null || true)
SKILL_FILE=$(jq -r --arg name "$SKILL_NAME" '.skills[] | select(.name == $name) | .skill_file' "$SKILL_INDEX" 2>/dev/null || true)

if [[ -z "$SKILL_PATH" ]]; then
  echo "ERROR: Skill '$SKILL_NAME' not found in canonical index." >&2
  echo "Run 'bash scripts/skill-load.sh' to list registered skills." >&2
  echo "If this is a new skill, add it to $SKILL_INDEX first and get Ken approval." >&2
  exit 3
fi

if [[ "$SKILL_APPROVED" != "true" ]]; then
  echo "ERROR: Skill '$SKILL_NAME' exists in index but is not approved." >&2
  exit 4
fi

FULL_SKILL_PATH="$WORKSPACE_ROOT/$SKILL_PATH"
FULL_SKILL_FILE="$FULL_SKILL_PATH/$SKILL_FILE"

if [[ ! -f "$FULL_SKILL_FILE" ]]; then
  echo "ERROR: Skill file missing: $FULL_SKILL_FILE" >&2
  echo "Skill index references a path that does not exist. Fix the index or restore the skill package." >&2
  exit 5
fi

# ── Register load in session registry ─────────────────────────────────────
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

mkdir -p "$(dirname "$SKILL_REGISTRY")"

python3 -c "
import json, os

path = '${SKILL_REGISTRY}'
skill = '${SKILL_NAME}'
ts = '${TIMESTAMP}'
index_path = '${SKILL_INDEX}'

reg = {}
if os.path.exists(path):
    try:
        with open(path) as f:
            reg = json.load(f)
    except (json.JSONDecodeError, ValueError):
        reg = {}

# Enforce canonical path tracking
reg[skill] = {
    'loaded_at': ts,
    'canonical_path': '${SKILL_PATH}',
    'skill_file': '${SKILL_FILE}',
    'via': 'skill-load.sh'
}

with open(path, 'w') as f:
    json.dump(reg, f, indent=2)

print(f'SKILL-LOAD: {skill} registered at {ts} (canonical: ${SKILL_PATH})')
" 2>&1
