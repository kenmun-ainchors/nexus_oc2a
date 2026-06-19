#!/bin/bash
# scripts/model-policy-query.sh — Single-source model policy query helper
# TKT-0540 A3
# Reads state/archive/model-policy.json (SSOT) and returns the effective model
# for a given agent + CREST phase, or the full effective map.
#
# Usage:
#   bash scripts/model-policy-query.sh --agent <agent-id> --phase <Plan|Execute|Verify|Replan|Synthesize>
#   bash scripts/model-policy-query.sh --all
#   bash scripts/model-policy-query.sh --agent <agent-id>

set -euo pipefail

WORKSPACE_ROOT="${WORKSPACE_ROOT:-/Users/ainchorsangiefpl/.openclaw/workspace}"
POLICY_FILE="$WORKSPACE_ROOT/state/archive/model-policy.json"
JQ=/opt/homebrew/bin/jq

show_usage() {
  cat <<'EOF'
Usage: model-policy-query.sh --agent <agent-id> --phase <phase>
       model-policy-query.sh --agent <agent-id>
       model-policy-query.sh --all

Phases: Plan, Execute, Verify, Replan, Synthesize
EOF
}

AGENT=""
PHASE=""
ALL=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --agent) AGENT="$2"; shift 2 ;;
    --phase) PHASE="$2"; shift 2 ;;
    --all) ALL=true; shift ;;
    --help|-h) show_usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; show_usage; exit 1 ;;
  esac
done

if [[ ! -f "$POLICY_FILE" ]]; then
  echo '{"error":"policy file not found","path":"'$POLICY_FILE'"}' >&2
  exit 1
fi

if [[ ! -x "$JQ" ]]; then
  echo '{"error":"jq not found","path":"'$JQ'"}' >&2
  exit 1
fi

# Resolve phase override key: byTier then byAgent.
# Returns: "strong", "cheap", or "none".
resolve_phase_override() {
  local agent="$1" phase="$2"
  # Normalize phase to capitalized form used in policy
  phase="$(echo "$phase" | awk '{print toupper(substr($0,1,1)) tolower(substr($0,2))}')"
  # 1. per-agent override
  local byAgent
  byAgent=$("$JQ" -r --arg agent "$agent" --arg phase "$phase" '
    .crestPhaseOverrides.byAgent[$agent][$phase] // empty
  ' "$POLICY_FILE" 2>/dev/null || true)
  if [[ -n "$byAgent" ]]; then
    echo "$byAgent"
    return
  fi

  # 2. tier-level override
  local tier
  tier=$("$JQ" -r --arg agent "$agent" '.agents[$agent].tier // empty' "$POLICY_FILE" 2>/dev/null || true)
  if [[ -n "$tier" ]]; then
    local byTier
    byTier=$("$JQ" -r --arg tier "$tier" --arg phase "$phase" '
      .crestPhaseOverrides.byTier[$tier][$phase] // empty
    ' "$POLICY_FILE" 2>/dev/null || true)
    if [[ -n "$byTier" ]]; then
      echo "$byTier"
      return
    fi
  fi

  # 3. default CREST mapping: Plan/Verify/Replan = strong; Execute/Synthesize = cheap
  case "$phase" in
    Plan|Verify|Replan) echo "strong" ;;
    Execute|Synthesize) echo "cheap" ;;
    *) echo "none" ;;
  esac
}

# Return the concrete model alias for an agent + phase.
# Prints only the model string on success; prints JSON error to stderr and returns non-zero on failure.
resolve_model() {
  local agent="$1" phase="$2"
  local tier override primary cheap

  tier=$("$JQ" -r --arg agent "$agent" '.agents[$agent].tier // empty' "$POLICY_FILE" 2>/dev/null || true)
  if [[ -z "$tier" ]]; then
    echo '{"error":"agent not found","agent":"'$agent'"}' >&2
    return 1
  fi

  override=$(resolve_phase_override "$agent" "$phase")

  if [[ "$override" == "none" ]]; then
    echo '{"error":"phase not allowed for agent","agent":"'$agent'","phase":"'$phase'"}' >&2
    return 1
  fi

  if [[ "$override" == "strong" ]]; then
    primary=$("$JQ" -r --arg tier "$tier" '.agentTiers[$tier].primary // empty' "$POLICY_FILE" 2>/dev/null || true)
    if [[ -z "$primary" ]]; then
      primary=$("$JQ" -r --arg agent "$agent" '.agents[$agent].requiredPrimary // empty' "$POLICY_FILE" 2>/dev/null || true)
    fi
    echo "$primary"
  else
    cheap=$("$JQ" -r --arg tier "$tier" '.agentTiers[$tier].cheapModel // empty' "$POLICY_FILE" 2>/dev/null || true)
    if [[ -z "$cheap" || "$cheap" == "null" ]]; then
      cheap=$("$JQ" -r --arg agent "$agent" '.agents[$agent].requiredCheap // empty' "$POLICY_FILE" 2>/dev/null || true)
    fi
    if [[ -z "$cheap" || "$cheap" == "null" ]]; then
      # fallback: use the first fallback that looks like a cheap/flash model
      cheap=$("$JQ" -r --arg tier "$tier" '
        .agentTiers[$tier].fallbacks // [] | map(select(contains("flash"))) | first // empty
      ' "$POLICY_FILE" 2>/dev/null || true)
    fi
    if [[ -z "$cheap" || "$cheap" == "null" ]]; then
      echo '{"error":"no cheap model defined for tier","tier":"'$tier'","agent":"'$agent'"}' >&2
      return 1
    fi
    echo "$cheap"
  fi
}

if $ALL; then
  "$JQ" -r '
    .agents | keys_unsorted | sort | .[]
  ' "$POLICY_FILE" | while IFS= read -r agent; do
    out=$("$JQ" -n --arg agent "$agent" '
      {
        agent: $agent,
        Plan: null,
        Execute: null,
        Verify: null,
        Replan: null,
        Synthesize: null
      }
    ')
    for phase in Plan Execute Verify Replan Synthesize; do
      if model=$(resolve_model "$agent" "$phase" 2>/dev/null); then
        out=$(echo "$out" | "$JQ" --arg phase "$phase" --arg model "$model" '.[$phase] = $model')
      else
        out=$(echo "$out" | "$JQ" --arg phase "$phase" '.[$phase] = "not-allowed"')
      fi
    done
    echo "$out"
  done | "$JQ" -s '{effectiveMap: .}'
  exit 0
fi

if [[ -z "$AGENT" ]]; then
  show_usage >&2
  exit 1
fi

if [[ -z "$PHASE" ]]; then
  # return agent summary
  tier=$("$JQ" -r --arg agent "$AGENT" '.agents[$AGENT].tier // empty' "$POLICY_FILE" 2>/dev/null || true)
  primary=$("$JQ" -r --arg agent "$AGENT" '.agents[$AGENT].requiredPrimary // empty' "$POLICY_FILE" 2>/dev/null || true)
  cheap=$("$JQ" -r --arg agent "$AGENT" '.agents[$AGENT].requiredCheap // empty' "$POLICY_FILE" 2>/dev/null || true)
  "$JQ" -n \
    --arg agent "$AGENT" \
    --arg tier "$tier" \
    --arg primary "$primary" \
    --arg cheap "$cheap" \
    '{agent:$agent,tier:$tier,primary:$primary,cheapModel:$cheap}'
  exit 0
fi

model=$(resolve_model "$AGENT" "$PHASE")
"$JQ" -n \
  --arg agent "$AGENT" \
  --arg phase "$PHASE" \
  --arg model "$model" \
  '{agent:$agent,phase:$phase,model:$model,source:"state/archive/model-policy.json"}'
