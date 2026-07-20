#!/bin/zsh
# agent-rules-audit.sh — Verify every commissioned agent has RULES.md at the canonical runtime path
# Canonical layout: ~/.openclaw/agents/<agent_id>/agent/RULES.md
# (per openclaw.json agents.list[*].agentDir — see CHG-0857, CHG-0945)
# TKT-0307 AC4: Permanent prevention
# Exit: 0 = all OK, 1 = missing agents

set -euo pipefail

WORKSPACE_BASE="/Users/ainchorsoc2a/.openclaw"
AGENTS_BASE="${WORKSPACE_BASE}/agents"
OPENCLAW_JSON="${WORKSPACE_BASE}/openclaw.json"
REPORT_FILE="${WORKSPACE_BASE}/workspace/state/agent-rules-audit.json"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

missing=0
found=0
missing_list=""

# Pull active agent IDs from runtime registry.
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
    sys.stderr.write(f'rules-audit: registry parse failed: {e}\n')
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

# Display-name hint per registry id (cosmetic only — does not change path).
# Using simple lookup function so script runs under both bash and zsh.
_display_name() {
  case "$1" in
    main) echo "Yoda" ;;
    business) echo "Aria" ;;
    architect) echo "Atlas" ;;
    platform-arch) echo "Thrawn" ;;
    infra) echo "Forge" ;;
    ahsoka) echo "Ahsoka" ;;
    social) echo "Spark" ;;
    biz-process) echo "Lando" ;;
    change-mgt) echo "Mon Mothma" ;;
    security) echo "Shield" ;;
    legal) echo "Lex" ;;
    qa) echo "Sage" ;;
    governance) echo "Warden" ;;
    luthen) echo "Luthen" ;;
    *) echo "$1" ;;
  esac
}

check() {
  local label="$1"
  local rules="$2"

  if [[ -f "$rules" ]]; then
    local sz=$(wc -c < "$rules" 2>/dev/null | tr -d ' ')
    if [[ "$sz" -gt 100 ]]; then
      ((found++))
      return 0
    fi
  fi
  ((missing++))
  missing_list="${missing_list}  ❌ ${label}: no RULES.md at ${rules}\n"
  return 1
}

echo "AGENT_RULES_AUDIT: $(date)"
echo "Source: $AGENTS_BASE/<agent>/agent/RULES.md  (CHG-0857, CHG-0945)"
echo ""

for agent_id in "${AGENT_IDS[@]}"; do
  display=$(_display_name "$agent_id")
  check "${agent_id} (${display})" "${AGENTS_BASE}/${agent_id}/agent/RULES.md" || true
done

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
    json.dump({'audit':'agent-rules-audit','version':'1.1.0','ticket':'TKT-0307','timestamp':'$TIMESTAMP','summary':{'total':$total,'found':$found,'missing':0,'status':'OK'}}, f, indent=2)
"
  exit 0
fi
