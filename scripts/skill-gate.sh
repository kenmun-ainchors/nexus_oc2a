#!/bin/bash
# skill-gate.sh — Structural Skill-Loading Enforcement Gate
# Each domain script sources this as a preamble.
# Blocks execution if the required skill has not been loaded this session.
#
# Usage (in domain script):
#   source "${SCRIPT_DIR:-$(dirname "$0")}/skill-gate.sh" "pg-sprint-backlog" || exit 1
#
# Contract: agents MUST call scripts/skill-load.sh after loading a skill.
# This gate checks state/skill-load-registry.json for the session's load record.

set -euo pipefail

WORKSPACE_ROOT="${WORKSPACE_ROOT:-$HOME/.openclaw/workspace}"
SKILL_REGISTRY="${SKILL_REGISTRY:-$WORKSPACE_ROOT/state/skill-load-registry.json}"
SKILL_INDEX="${SKILL_INDEX:-$WORKSPACE_ROOT/agent-skills/.index.json}"
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
  ppid=$(ps -o ppid= -p $$ 2>/dev/null | tr -d ' ')
  if [[ -n "$ppid" ]]; then
    pname=$(ps -o comm= -p "$ppid" 2>/dev/null || echo "")
    if [[ "$pname" == "launchd" || "$pname" == "cron" || "$pname" == "openclaw" ]]; then
      exit 0
    fi
  fi
fi

# ── Canonical index check ───────────────────────────────────────────────
if [[ ! -f "$SKILL_INDEX" ]]; then
  echo "SKILL-GATE: ERROR — Skill index missing: $SKILL_INDEX" >&2
  exit 2
fi

if ! jq -e --arg name "$REQUIRED_SKILL" '.skills[] | select(.name == $name and .approved == true)' "$SKILL_INDEX" >/dev/null 2>&1; then
  echo "SKILL-GATE: ERROR — Skill '$REQUIRED_SKILL' is not approved in canonical index." >&2
  exit 2
fi

INDEX_PATH=$(jq -r --arg name "$REQUIRED_SKILL" '.skills[] | select(.name == $name) | .path' "$SKILL_INDEX" 2>/dev/null || true)

# ── Registry presence check ───────────────────────────────────────────────
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
║    bash scripts/skill-load.sh "${REQUIRED_SKILL}"
║
║  Registry: ${SKILL_REGISTRY}
╚══════════════════════════════════════════════════════════════╝
EOF
  exit 2
fi

# ── Session-aware freshness check ─────────────────────────────────────────
# A skill load is only valid for the current session. Require load within
# the last 60 minutes to prevent stale entries from previous sessions.
NOW_EPOCH=$(date -u +%s)
CUTOFF_EPOCH=$((NOW_EPOCH - 3600))

LOADED_AT=$(jq -r --arg name "$REQUIRED_SKILL" '.[$name].loaded_at // ""' "$SKILL_REGISTRY" 2>/dev/null || true)
CANONICAL_PATH=$(jq -r --arg name "$REQUIRED_SKILL" '.[$name].canonical_path // ""' "$SKILL_REGISTRY" 2>/dev/null || true)

if [[ -z "$LOADED_AT" || -z "$CANONICAL_PATH" ]]; then
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
║  Status: NOT LOADED THIS SESSION
║  Already loaded: ${LOADED_LIST}
║
║  This script requires the '${REQUIRED_SKILL}' skill.
║  Load it first:
║    bash scripts/skill-load.sh "${REQUIRED_SKILL}"
║
║  Registry: ${SKILL_REGISTRY}
╚══════════════════════════════════════════════════════════════╝
EOF
  exit 2
fi

LOAD_EPOCH=$(date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$LOADED_AT" +%s 2>/dev/null \
  || python3 -c "from datetime import datetime, timezone; print(int(datetime.strptime('$LOADED_AT', '%Y-%m-%dT%H:%M:%SZ').replace(tzinfo=timezone.utc).timestamp()))" 2>/dev/null \
  || echo "0")

if [[ -z "$LOAD_EPOCH" || "$LOAD_EPOCH" -lt "$CUTOFF_EPOCH" || "$LOAD_EPOCH" -gt "$NOW_EPOCH" ]]; then
  cat >&2 <<EOF
╔══════════════════════════════════════════════════════════════╗
║  SKILL GATE — BLOCKED                                       ║
╠══════════════════════════════════════════════════════════════╣
║  Required skill: ${REQUIRED_SKILL}
║  Status: LOAD RECORD STALE OR INVALID
║  Loaded at: ${LOADED_AT}
║
║  Re-load the skill:
║    bash scripts/skill-load.sh "${REQUIRED_SKILL}"
║
║  Registry: ${SKILL_REGISTRY}
╚══════════════════════════════════════════════════════════════╝
EOF
  exit 2
fi

if [[ "$CANONICAL_PATH" != "$INDEX_PATH" ]]; then
  echo "SKILL-GATE: ERROR — Skill '$REQUIRED_SKILL' registry path '$CANONICAL_PATH' does not match canonical index path '$INDEX_PATH'." >&2
  exit 2
fi

# If we reach here, the skill is loaded, fresh, and canonical. Pass.
