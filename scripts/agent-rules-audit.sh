#!/bin/zsh
# agent-rules-audit.sh — Verify every commissioned agent has RULES.md
# TKT-0307 AC4: Permanent prevention
# Exit: 0 = all OK, 1 = missing agents

WORKSPACE_BASE="/Users/ainchorsoc2a/.openclaw"
REPORT_FILE="/Users/ainchorsoc2a/.openclaw/workspace/state/agent-rules-audit.json"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

missing=0
found=0
missing_list=""

check() {
  local label="$1"
  local ws="$2"
  local rules="${ws}/RULES.md"
  
  if [[ -f "$rules" ]]; then
    local sz=$(wc -c < "$rules" 2>/dev/null | tr -d ' ')
    if [[ "$sz" -gt 100 ]]; then
      ((found++))
      return 0
    fi
  fi
  ((missing++))
  missing_list="${missing_list}  ❌ ${label}: no RULES.md at ${ws}\n"
  return 1
}

echo "AGENT_RULES_AUDIT: $(date)"
echo ""

check "business (Aria)"       "${WORKSPACE_BASE}/workspace-business"
check "security (Shield)"     "${WORKSPACE_BASE}/workspace-security"
check "legal (Lex)"           "${WORKSPACE_BASE}/workspace-legal"
check "qa (Sage)"             "${WORKSPACE_BASE}/workspace-qa"
check "governance (Warden)"   "${WORKSPACE_BASE}/workspace-governance"
check "architect (Atlas)"     "${WORKSPACE_BASE}/workspace-architect"
check "platform-arch (Thrawn)" "${WORKSPACE_BASE}/workspace-platform-arch"
check "biz-process (Lando)"   "${WORKSPACE_BASE}/workspace-bpm"
check "change-mgt (Mon Mothma)" "${WORKSPACE_BASE}/workspace-dtcm"
check "social (Spark)"        "${WORKSPACE_BASE}/workspace-social"
check "infra (Forge)"         "${WORKSPACE_BASE}/workspace-infra"
check "ahsoka (Ahsoka)"       "${WORKSPACE_BASE}/workspace-ahsoka"
check "luthen (Luthen)"       "${WORKSPACE_BASE}/workspace-luthen"
check "main (Yoda+Krennic)"   "${WORKSPACE_BASE}/workspace"

total=$((found + missing))

if [[ "$missing" -gt 0 ]]; then
  printf "%b" "$missing_list"
  echo ""
  echo "RESULT: ❌ FAIL — ${found}/${total} have RULES.md, ${missing} missing"
  exit 1
else
  echo "RESULT: ✅ PASS — ${found}/${total} agents have RULES.md"
  python3 -c "
import json
with open('$REPORT_FILE', 'w') as f:
    json.dump({'audit':'agent-rules-audit','version':'1.0.0','ticket':'TKT-0307','timestamp':'$TIMESTAMP','summary':{'total':$total,'found':$found,'missing':0,'status':'OK'}}, f, indent=2)
"
  exit 0
fi
