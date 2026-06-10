#!/bin/bash
# skill-gate.sh — Structural Skill-Loading Enforcement Gate
# Each domain script sources this as a preamble.
# Blocks execution if the required skill has not been loaded this session.
#
# Usage (in domain script):
#   source "${SCRIPT_DIR:-.}/skill-gate.sh" "pg-sprint-backlog" || exit 1
#
# Contract: agents MUST call scripts/skill-load.sh after loading a skill.
# This gate checks state/skill-load-registry.json for the session's load record.

set -euo pipefail

SKILL_REGISTRY="${SKILL_REGISTRY:-$HOME/.openclaw/workspace/state/skill-load-registry.json}"
REQUIRED_SKILL="${1:-}"

if [[ -z "$REQUIRED_SKILL" ]]; then
  echo "SKILL-GATE: ERROR — no required skill specified. Usage: source skill-gate.sh <skill-name>" >&2
  exit 1
fi

# Allow override for CI/automation (cron jobs, auto-heal, etc.)
# Set SKILL_GATE_BYPASS=1 in cron payloads or auto-heal scripts.
if [[ "${SKILL_GATE_BYPASS:-}" == "1" ]]; then
  exit 0
fi

# In strict mode, always enforce. Non-strict (default): skip if cron/background.
# Detect cron: no TERM and parent is launchd or cron
if [[ "${SKILL_GATE_STRICT:-}" != "1" ]]; then
  # Check if running under cron/launchd (non-interactive system context)
  ppid=$(ps -o ppid= -p $$ 2>/dev/null | tr -d ' ')
  if [[ -n "$ppid" ]]; then
    pname=$(ps -o comm= -p "$ppid" 2>/dev/null || echo "")
    if [[ "$pname" == "launchd" || "$pname" == "cron" || "$pname" == "openclaw" ]]; then
      exit 0
    fi
  fi
fi

if [[ ! -f "$SKILL_REGISTRY" ]]; then
  cat >&2 <<EOF
╔══════════════════════════════════════════════════════════════╗
║  SKILL GATE — BLOCKED                                       ║
╠══════════════════════════════════════════════════════════════╣
║  Required skill: ${REQUIRED_SKILL}
║  Status: NOT LOADED (no registry file)
║
║  This script requires the '${REQUIRED_SKILL}' skill.
║  Load it first:
║    read <skill-path>/SKILL.md
║
║  Then register the load:
║    bash scripts/skill-load.sh "${REQUIRED_SKILL}"
║
║  Registry: ${SKILL_REGISTRY}
╚══════════════════════════════════════════════════════════════╝
EOF
  exit 2
fi

# Check if the required skill has been loaded
LOADED=$(python3 -c "
import json, sys
with open('${SKILL_REGISTRY}') as f:
    reg = json.load(f)
print('yes' if reg.get('${REQUIRED_SKILL}') else 'no')
" 2>/dev/null || echo "no")

if [[ "$LOADED" != "yes" ]]; then
  # List loaded skills for context
  LOADED_LIST=$(python3 -c "
import json
with open('${SKILL_REGISTRY}') as f:
    reg = json.load(f)
loaded = [k for k,v in reg.items() if v is not None]
print(', '.join(sorted(loaded)) if loaded else '(none)')
" 2>/dev/null || echo "(error reading registry)")

  cat >&2 <<EOF
╔══════════════════════════════════════════════════════════════╗
║  SKILL GATE — BLOCKED                                       ║
╠══════════════════════════════════════════════════════════════╣
║  Required skill: ${REQUIRED_SKILL}
║  Status: NOT LOADED
║  Already loaded: ${LOADED_LIST}
║
║  This script requires the '${REQUIRED_SKILL}' skill.
║  Load it first:
║    read <skill-path>/SKILL.md
║
║  Then register the load:
║    bash scripts/skill-load.sh "${REQUIRED_SKILL}"
║
║  Registry: ${SKILL_REGISTRY}
╚══════════════════════════════════════════════════════════════╝
EOF
  exit 2
fi

# If we reach here, the skill is loaded. Pass.
