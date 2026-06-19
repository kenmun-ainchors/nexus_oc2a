#!/bin/bash
# scripts/model-policy-query.sh v2 — PG-first model policy query with JSON fallback
# CREST v1.3 (TKT-0546 A6)
# Queries state_model_policy.crest_phase_rules (PG SSOT) first,
# falls back to state/model-policy.json cache if PG unavailable.
#
# Usage:
#   bash scripts/model-policy-query.sh --agent <agent-id> --phase <Plan|Execute|Verify|Replan|Synthesize>
#   bash scripts/model-policy-query.sh --agent <agent-id> --phase <phase> --data-class <class>
#   bash scripts/model-policy-query.sh --all
#   bash scripts/model-policy-query.sh --agent <agent-id>

set -euo pipefail

WORKSPACE_ROOT="${WORKSPACE_ROOT:-/Users/ainchorsangiefpl/.openclaw/workspace}"
JQ="${JQ:-/opt/homebrew/bin/jq}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Agent ID → CREST role mapping ---
agent_to_role() {
  local agent="$1"
  case "$agent" in
    main)            echo "yoda_master" ;;
    business)        echo "yoda_master" ;;  # Aria uses yoda_master for now
    architect)       echo "design_backend" ;;
    platform-arch)   echo "design_backend" ;;
    biz-process)     echo "design_backend" ;;
    change-mgt)      echo "design_backend" ;;
    infra)           echo "build" ;;
    social)          echo "creative" ;;
    ahsoka)          echo "business" ;;
    luthen)          echo "business" ;;
    security)        echo "governance" ;;
    legal)           echo "governance" ;;
    qa)              echo "governance" ;;
    governance)      echo "governance" ;;
    *)               echo "unknown" ;;
  esac
}

# --- PG query (primary) ---
query_pg() {
  local role="$1" phase="$2" data_class="${3:-}"
  local result

  if [[ -n "$data_class" ]]; then
    result=$(bash "$SCRIPT_DIR/db.sh" -c "
      SELECT default_model, fallback_model, override_allowed, rationale
      FROM crest_phase_rules
      WHERE matrix_version = (SELECT version FROM policy_matrices WHERE active = TRUE AND tenant_id = 'ainchors')
        AND role = '$role'
        AND phase = '$phase'
        AND (data_class_whitelist IS NULL OR '$data_class' = ANY(data_class_whitelist))
        AND tenant_id = 'ainchors'
      ORDER BY data_class_whitelist NULLS LAST
      LIMIT 1;
    " 2>/dev/null)
  else
    result=$(bash "$SCRIPT_DIR/db.sh" -c "
      SELECT default_model, fallback_model, override_allowed, rationale
      FROM crest_phase_rules
      WHERE matrix_version = (SELECT version FROM policy_matrices WHERE active = TRUE AND tenant_id = 'ainchors')
        AND role = '$role'
        AND phase = '$phase'
        AND tenant_id = 'ainchors'
      LIMIT 1;
    " 2>/dev/null)
  fi

  # Parse pipe-delimited PG output (skip header/footer lines)
  result=$(echo "$result" | grep -E '^[[:space:]]*[a-z]' | head -1)

  if [[ -n "$result" ]]; then
    local model=$(echo "$result" | cut -d'|' -f1 | xargs)
    local fallback=$(echo "$result" | cut -d'|' -f2 | xargs)
    local override=$(echo "$result" | cut -d'|' -f3 | xargs)
    local reason=$(echo "$result" | cut -d'|' -f4 | xargs)
    echo "{\"model\":\"$model\",\"fallback\":\"$fallback\",\"override_allowed\":$override,\"rationale\":\"$reason\",\"source\":\"pg\"}"
    return 0
  fi
  return 1
}

# --- JSON fallback (secondary) ---
query_json() {
  local agent="$1" phase="$2"
  local policy_file="$WORKSPACE_ROOT/state/model-policy.json"

  if [[ ! -f "$policy_file" ]]; then
    echo '{"error":"no policy source available","source":"none"}' >&2
    exit 1
  fi

  # Use v1 logic: resolve tier → phase override → model
  local tier
  tier=$("$JQ" -r --arg agent "$agent" '.agentTiers | to_entries[] | select(.value.agentIds[] == $agent) | .key' "$policy_file" 2>/dev/null || echo "")

  if [[ -z "$tier" || "$tier" == "null" ]]; then
    echo '{"error":"agent not found in any tier","agent":"'$agent'"}' >&2
    exit 1
  fi

  local phase_lower=$(echo "$phase" | tr '[:upper:]' '[:lower:]')
  local model_tier
  # Plan/Verify/Replan → strong (primary); Execute/Synthesize → cheap (cheapModel)
  case "$phase_lower" in
    plan|verify|replan) model_tier="primary" ;;
    execute|synthesize) model_tier="cheapModel" ;;
    *) model_tier="primary" ;;
  esac

  local model
  model=$("$JQ" -r --arg tier "$tier" --arg key "$model_tier" '.agentTiers[$tier][$key] // "unknown"' "$policy_file")

  local fallback
  fallback=$("$JQ" -r --arg tier "$tier" '.agentTiers[$tier].fallbacks[0] // "unknown"' "$policy_file")

  echo "{\"model\":\"$model\",\"fallback\":\"$fallback\",\"override_allowed\":false,\"rationale\":\"JSON fallback (v1.2 logic)\",\"source\":\"json\"}"
}

# --- Main ---
AGENT=""
PHASE=""
DATA_CLASS=""
ALL=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --agent) AGENT="$2"; shift 2 ;;
    --phase) PHASE="$2"; shift 2 ;;
    --data-class) DATA_CLASS="$2"; shift 2 ;;
    --all) ALL=true; shift ;;
    --help|-h)
      echo "Usage: model-policy-query.sh --agent <id> --phase <phase> [--data-class <class>]"
      echo "       model-policy-query.sh --all"
      echo "       model-policy-query.sh --agent <id>"
      exit 0
      ;;
    *) echo "Unknown: $1" >&2; exit 1 ;;
  esac
done

if $ALL; then
  # Dump all active rules from PG
  bash "$SCRIPT_DIR/db.sh" -c "
    SELECT role, phase, default_model, fallback_model
    FROM crest_phase_rules
    WHERE matrix_version = (SELECT version FROM policy_matrices WHERE active = TRUE AND tenant_id = 'ainchors')
      AND tenant_id = 'ainchors'
    ORDER BY role, phase;
  " 2>/dev/null || echo '{"error":"pg unavailable for --all"}' >&2
  exit 0
fi

if [[ -z "$AGENT" ]]; then
  echo '{"error":"--agent required"}' >&2
  exit 1
fi

ROLE=$(agent_to_role "$AGENT")

if [[ "$ROLE" == "unknown" ]]; then
  echo "{\"error\":\"unknown agent\",\"agent\":\"$AGENT\"}" >&2
  exit 1
fi

# Try PG first
if [[ -n "$PHASE" ]]; then
  if query_pg "$ROLE" "$PHASE" "$DATA_CLASS"; then
    exit 0
  fi
  # Fallback to JSON
  query_json "$AGENT" "$PHASE"
else
  # Agent-only: dump all phases for this role from PG
  bash "$SCRIPT_DIR/db.sh" -c "
    SELECT phase, default_model, fallback_model
    FROM crest_phase_rules
    WHERE matrix_version = (SELECT version FROM policy_matrices WHERE active = TRUE AND tenant_id = 'ainchors')
      AND role = '$ROLE'
      AND tenant_id = 'ainchors'
    ORDER BY phase;
  " 2>/dev/null || query_json "$AGENT" "Plan"  # fallback: just return Plan model
fi
