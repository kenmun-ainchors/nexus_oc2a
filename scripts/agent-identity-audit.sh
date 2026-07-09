#!/usr/bin/env zsh
# agent-identity-audit.sh — Verify all agents have commissioned identity in their sandbox
# Run: daily via auto-heal, on-demand before CHG-0421 workspace changes
# Exit 0 = all agents have proper identity | Exit 1 = drift detected, needs fix

set -euo pipefail

WORKSPACE="/Users/ainchorsangiefpl/.openclaw/workspace"
AGENTS_DIR="/Users/ainchorsangiefpl/.openclaw/agents"
AUDIT_FILE="$WORKSPACE/state/agent-identity-audit.json"

VANILLA_SIGNATURE="# SOUL.md - Who You Are"
FAILURES=0
RESULTS=()

# Agent list from openclaw.json agents.list
AGENT_IDS=(
  "main" "business" "security" "legal" "qa" "governance"
  "infra" "architect" "platform-arch" "biz-process" "change-mgt"
  "ahsoka" "spark" "atlas" "thrawn" "forge"
)

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Agent Identity Audit"
echo "  $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# CHG-0857: Runtime-only agents (business, qa, infra, spark, atlas, ahsoka, platform-arch, forge)
# live under ~/.openclaw/agents/ and don't have workspace/<agent>/ directories.
# Skip them from identity drift checks — they are properly commissioned via their
# agentDir in openclaw.json, not via workspace subdirectories.
RUNTIME_ONLY_AGENTS=("business" "qa" "infra" "spark" "atlas" "ahsoka" "platform-arch" "forge")

for agent_id in "${AGENT_IDS[@]}"; do
  # Skip main (Yoda) — uses workspace root SOUL.md
  if [[ "$agent_id" == "main" ]]; then
    continue
  fi

  # CHG-0857: Skip runtime-only agents — they live under ~/.openclaw/agents/ not workspace/<agent>/
  _is_runtime=false
  for _ra in "${RUNTIME_ONLY_AGENTS[@]}"; do
    if [[ "$agent_id" == "$_ra" ]]; then
      _is_runtime=true
      break
    fi
  done
  if [[ "$_is_runtime" == "true" ]]; then
    echo "  ⏭️  $agent_id — runtime-only agent (under ~/.openclaw/agents/), skipping workspace directory check"
    RESULTS+=("{\"agent\":\"$agent_id\",\"status\":\"runtime_only_skip\",\"issue\":null}")
    continue
  fi

  # Check 1: Workspace subdir exists
  WS_SUBDIR="$WORKSPACE/$agent_id"
  if [[ ! -d "$WS_SUBDIR" ]]; then
    echo "  ❌ $agent_id — no workspace subdirectory"
    RESULTS+=("{\"agent\":\"$agent_id\",\"status\":\"missing_workspace_dir\",\"issue\":\"No workspace/$agent_id/ directory exists\"}")
    ((FAILURES++))
    continue
  fi

  # Check 2: SOUL.md exists
  SOUL_FILE="$WS_SUBDIR/SOUL.md"
  if [[ ! -f "$SOUL_FILE" ]]; then
    echo "  ❌ $agent_id — SOUL.md missing"
    RESULTS+=("{\"agent\":\"$agent_id\",\"status\":\"missing_soul\",\"issue\":\"No SOUL.md in workspace/$agent_id/\"}")
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

  # Check 4: RULES.md exists (recommended, not mandatory for all)
  RULES_FILE="$WS_SUBDIR/RULES.md"
  if [[ -f "$RULES_FILE" ]]; then
    echo "  ✅ $agent_id — commissioned SOUL + RULES"
    RESULTS+=("{\"agent\":\"$agent_id\",\"status\":\"ok\",\"issue\":null}")
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
