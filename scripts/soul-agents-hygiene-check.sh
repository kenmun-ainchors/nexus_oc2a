#!/usr/bin/env zsh
# soul-agents-hygiene-check.sh
# Verify every agent SOUL.md stays lean (identity/values/hard limits only)
# and each active agent has a corresponding AGENTS.md for behavioral rules.
# Produces state/soul-agents-hygiene.json for heartbeat/auto-heal consumption.
set -euo pipefail

WORKSPACE_ROOT="${WORKSPACE_ROOT:-/Users/ainchorsangiefpl/.openclaw/workspace}"
STATE_FILE="${WORKSPACE_ROOT}/state/soul-agents-hygiene.json"
WARN_LIMIT=4000
HARD_LIMIT=5000

mkdir -p "$(dirname "$STATE_FILE")"

cd "$WORKSPACE_ROOT" || exit 1

# Active runtime agents and their directory names (parallel arrays)
local -a ACTIVE_AGENTS=(
  main
  business
  architect
  platform-arch
  infra
  ahsoka
  social
  biz-process
  change-mgt
  security
  legal
  qa
  governance
)

local -a AGENT_DIRS=(
  .
  business
  architect
  platform-arch
  infra
  agents/ahsoka
  spark
  biz-process
  change-mgt
  security
  legal
  qa
  governance
)

aesthetic_now() {
  TZ=Australia/Melbourne date '+%Y-%m-%dT%H:%M:%S%z'
}

NOW=$(aesthetic_now)
PASS=0
FAIL=0
WARNINGS=0
REPORT=()

for i in {1..$#ACTIVE_AGENTS}; do
  aid="${ACTIVE_AGENTS[$i]}"
  dir="${AGENT_DIRS[$i]}"
  soul="${dir}/SOUL.md"
  agents="${dir}/AGENTS.md"
  local st="PASS"
  local messages=()
  local size=0

  if [[ ! -f "$soul" ]]; then
    st="FAIL"
    messages+=("SOUL.md missing for $aid")
  else
    size=$(wc -c < "$soul" | tr -d ' ')
    if (( size > HARD_LIMIT )); then
      st="FAIL"
      messages+=("SOUL.md size ${size} > hard limit ${HARD_LIMIT}")
    elif (( size > WARN_LIMIT )); then
      st="WARN"
      messages+=("SOUL.md size ${size} > warn limit ${WARN_LIMIT}")
    fi
    if ! grep -q '^## Hard Limits' "$soul"; then
      if [[ "$st" == "PASS" ]]; then st="WARN"; fi
      messages+=("missing ## Hard Limits section")
    fi
  fi

  if [[ ! -f "$agents" ]]; then
    # Only fail for non-root agents; root AGENTS.md is shared
    if [[ "$aid" != "main" ]]; then
      st="FAIL"
      messages+=("AGENTS.md missing for $aid")
    fi
  fi

  if [[ "$st" == "PASS" ]]; then
    PASS=$((PASS + 1))
  elif [[ "$st" == "WARN" ]]; then
    WARNINGS=$((WARNINGS + 1))
  else
    FAIL=$((FAIL + 1))
  fi

  entry=$(jq -n \
    --arg agentId "$aid" \
    --arg dir "$dir" \
    --arg status "$st" \
    --arg soulSize "$size" \
    --argjson messages "$(printf '%s\n' "${messages[@]}" | jq -R . | jq -s .)" \
    '{agentId: $agentId, dir: $dir, status: $status, soulSize: ($soulSize | tonumber), messages: $messages}')
  REPORT+=("$entry")
done

overall="PASS"
if (( FAIL > 0 )); then
  overall="FAIL"
elif (( WARNINGS > 0 )); then
  overall="WARN"
fi

jq -n \
  --arg overall "$overall" \
  --arg generatedAt "$NOW" \
  --argjson pass "$PASS" \
  --argjson warnings "$WARNINGS" \
  --argjson fail "$FAIL" \
  --argjson agents "$(printf '%s\n' "${REPORT[@]}" | jq -s .)" \
  '{
    overall: $overall,
    generatedAt: $generatedAt,
    summary: { pass: $pass, warnings: $warnings, fail: $fail, total: ($pass + $warnings + $fail) },
    agents: $agents
  }' > "$STATE_FILE"

if [[ "$overall" == "FAIL" ]]; then
  echo "FAIL: ${FAIL} agent(s) failed SOUL/AGENTS hygiene. See ${STATE_FILE}"
  exit 1
elif [[ "$overall" == "WARN" ]]; then
  echo "WARN: ${WARNINGS} warning(s). See ${STATE_FILE}"
  exit 0
else
  echo "PASS: all ${PASS} agent(s) meet SOUL/AGENTS hygiene."
  exit 0
fi
