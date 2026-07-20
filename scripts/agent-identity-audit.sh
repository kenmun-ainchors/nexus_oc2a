#!/usr/bin/env zsh
# agent-identity-audit.sh — Verify all agents have commissioned identity at the canonical runtime path
# Canonical layout: ~/.openclaw/agents/<agent_id>/agent/{SOUL.md,RULES.md}
# (per openclaw.json agents.list[*].agentDir — see CHG-0857, CHG-0945)
# Run: daily via auto-heal, on-demand before CHG-0421 workspace changes
# Exit 0 = all agents have proper identity | Exit 1 = drift detected, needs fix

set -euo pipefail

WORKSPACE="/Users/ainchorsoc2a/.openclaw/workspace"
AGENTS_BASE="/Users/ainchorsoc2a/.openclaw/agents"
OPENCLAW_JSON="/Users/ainchorsoc2a/.openclaw/openclaw.json"
AUDIT_FILE="$WORKSPACE/state/agent-identity-audit.json"

VANILLA_SIGNATURE="# SOUL.md - Who You Are"
FAILURES=0
RESULTS=()

# Pull active agent IDs from runtime registry (openclaw.json agents.list[*].id).
# Fallback to legacy static list if openclaw.json cannot be parsed.
AGENT_IDS=()
if [[ -r "$OPENCLAW_JSON" ]] && command -v python3 >/dev/null 2>&1; then
  _ids_raw=$(python3 -c "
import json, sys
try:
    with open('$OPENCLAW_JSON') as f:
        cfg = json.load(f)
    for a in cfg.get('agents', {}).get('list', []):
        i = a.get('id')
        if i:
            print(i)
except Exception as e:
    sys.stderr.write(f'identity-audit: registry parse failed: {e}\n')
    sys.exit(1)
" 2>/dev/null) || _ids_raw=""
  if [[ -n "$_ids_raw" ]]; then
    while IFS= read -r line; do
      AGENT_IDS+=("$line")
    done <<< "$_ids_raw"
  fi
fi
if [[ ${#AGENT_IDS[@]} -eq 0 ]]; then
  AGENT_IDS=(
    "main" "business" "architect" "platform-arch" "infra" "ahsoka"
    "social" "biz-process" "change-mgt" "security" "legal" "qa"
    "governance" "luthen"
  )
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Agent Identity Audit (canonical runtime path)"
echo "  $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo "  Source: $AGENTS_BASE/<agent>/agent/  (CHG-0857, CHG-0945)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

for agent_id in "${AGENT_IDS[@]}"; do
  # Canonical agentDir: ~/.openclaw/agents/<agent_id>/agent
  AGENT_DIR="$AGENTS_BASE/$agent_id/agent"
  SOUL_FILE="$AGENT_DIR/SOUL.md"
  RULES_FILE="$AGENT_DIR/RULES.md"

  # Check 1: Canonical agent directory exists
  if [[ ! -d "$AGENT_DIR" ]]; then
    echo "  ❌ $agent_id — no canonical agentDir ($AGENT_DIR)"
    RESULTS+=("{\"agent\":\"$agent_id\",\"status\":\"missing_agent_dir\",\"issue\":\"No $AGENT_DIR directory exists\"}")
    ((FAILURES++))
    continue
  fi

  # Check 2: SOUL.md exists at canonical path
  if [[ ! -f "$SOUL_FILE" ]]; then
    echo "  ❌ $agent_id — SOUL.md missing at canonical path"
    RESULTS+=("{\"agent\":\"$agent_id\",\"status\":\"missing_soul\",\"issue\":\"No SOUL.md at $AGENT_DIR/\"}")
    ((FAILURES++))
    continue
  fi

  # Check 3: SOUL.md is NOT vanilla template
  FIRST_LINE=$(head -1 "$SOUL_FILE")
  if echo "$FIRST_LINE" | grep -qF "$VANILLA_SIGNATURE"; then
    echo "  ⚠️  $agent_id — VANILLA SOUL.md (not commissioned)"
    RESULTS+=("{\"agent\":\"$agent_id\",\"status\":\"vanilla_soul\",\"issue\":\"SOUL.md is generic template — no agent identity\"}")
    ((FAILURES++))
    continue
  fi

  # Check 4: RULES.md exists (recommended, not mandatory for verdict-only agents)
  if [[ -f "$RULES_FILE" ]]; then
    RULES_SIZE=$(wc -c < "$RULES_FILE" 2>/dev/null | tr -d ' ')
    if [[ "${RULES_SIZE:-0}" -gt 100 ]]; then
      echo "  ✅ $agent_id — commissioned SOUL + RULES (${RULES_SIZE}B)"
      RESULTS+=("{\"agent\":\"$agent_id\",\"status\":\"ok\",\"issue\":null}")
    else
      echo "  ⚠️  $agent_id — commissioned SOUL, RULES.md too small (${RULES_SIZE}B)"
      RESULTS+=("{\"agent\":\"$agent_id\",\"status\":\"ok_rules_tiny\",\"issue\":\"RULES.md only ${RULES_SIZE} bytes\"}")
    fi
  else
    echo "  ✅ $agent_id — commissioned SOUL (no RULES.md — may be ok for verdict-only agents)"
    RESULTS+=("{\"agent\":\"$agent_id\",\"status\":\"ok_no_rules\",\"issue\":null}")
  fi
done

# Write audit file
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
JSON="{\"auditedAt\":\"$NOW\",\"failures\":$FAILURES,\"results\":[$(IFS=,; echo "${RESULTS[*]}")]}"
echo "$JSON" | python3 -m json.tool > "$AUDIT_FILE" 2>/dev/null || echo "$JSON" > "$AUDIT_FILE"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [[ $FAILURES -eq 0 ]]; then
  echo "  ✅ All agents: commissioned identity verified"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  exit 0
else
  echo "  ❌ $FAILURES agent(s) with identity issues detected"
  echo "  Audit file: $AUDIT_FILE"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  exit 1
fi
