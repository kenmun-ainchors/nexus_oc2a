#!/usr/bin/env zsh
# soul-agents-hygiene-check.sh
# Verify every agent SOUL.md stays lean (identity/values/hard limits only)
# and each active agent has a corresponding AGENTS.md for behavioral rules.
# Reads agent list dynamically from ~/.openclaw/openclaw.json.
# Produces state/soul-agents-hygiene.json for heartbeat/auto-heal consumption.
#
# CHG-0832: Remove hardcoded agent arrays; derive agents and workspace paths
# from openclaw.json agents.list[].id and .workspace. main maps to the
# workspace root; other agents use their configured workspace directory.
set -euo pipefail

WORKSPACE_ROOT="${WORKSPACE_ROOT:-/Users/ainchorsangiefpl/.openclaw/workspace}"
OPENCLAW_CONFIG="${OPENCLAW_CONFIG:-/Users/ainchorsangiefpl/.openclaw/openclaw.json}"
STATE_FILE="${WORKSPACE_ROOT}/state/soul-agents-hygiene.json"
WARN_LIMIT=4000
HARD_LIMIT=5000

mkdir -p "$(dirname "$STATE_FILE")"

cd "$WORKSPACE_ROOT" || exit 1

aesthetic_now() {
  TZ=Australia/Melbourne date '+%Y-%m-%dT%H:%M:%S%z'
}

NOW=$(aesthetic_now)
PASS=0
FAIL=0
WARNINGS=0
REPORT=()

# Build agent list dynamically from openclaw.json.
# Each agent: id, workspace. main is remapped to WORKSPACE_ROOT.
# jq must be available.
if [[ ! -f "$OPENCLAW_CONFIG" ]]; then
  echo "❌ openclaw.json not found: $OPENCLAW_CONFIG" >&2
  exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "❌ jq is required but not installed" >&2
  exit 1
fi

# Read agents as newline-delimited id|workspace|name records.
AGENT_RECORDS=()
while IFS=$'\t' read -r aid ws_path _name; do
  [[ -n "$aid" ]] && AGENT_RECORDS+=("${aid}|${ws_path}")
done < <(jq -r '.agents.list[] | [.id, .workspace, .name] | @tsv' "$OPENCLAW_CONFIG")

for rec in "${AGENT_RECORDS[@]}"; do
  aid="${rec%%|*}"
  ws_path="${rec#*|}"
  aid="$(echo "$rec" | awk -F'\t' '{print $1}')"
  ws_path="$(echo "$rec" | awk -F'\t' '{print $2}')"
  # name unused for checks, but kept for possible future logging

  if [[ "$aid" == "main" ]]; then
    dir="$WORKSPACE_ROOT"
  else
    # Resolve configured workspace to absolute path if relative
    if [[ "$ws_path" != /* ]]; then
      ws_path="${WORKSPACE_ROOT}/${ws_path}"
    fi
    dir="$ws_path"
  fi

  # Relative path used in reports (from WORKSPACE_ROOT)
  rel_dir="$(realpath --relative-to="$WORKSPACE_ROOT" "$dir" 2>/dev/null || echo "$dir")"

  soul="${dir}/SOUL.md"
  agents="${dir}/AGENTS.md"
  identity="${dir}/IDENTITY.md"
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

  # IDENTITY.md is checked where it exists; not mandatory everywhere
  if [[ ! -f "$identity" ]]; then
    # Only warn; many agents don't use IDENTITY.md yet
    if [[ "$st" == "PASS" ]]; then st="WARN"; fi
    messages+=("IDENTITY.md missing for $aid")
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
    --arg dir "$rel_dir" \
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
