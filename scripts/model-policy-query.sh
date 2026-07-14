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

WORKSPACE_ROOT="${WORKSPACE_ROOT:-/Users/ainchorsoc2a/.openclaw/workspace}"
JQ="${JQ:-$JQ}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DECISION_SCRIPT="$SCRIPT_DIR/pg-write-decision.sh"
emit_decision() {
  local kind="$1" entity_id="$2" payload="$3"
  bash "$DECISION_SCRIPT" --actor "model_policy_query" --entity-id "$entity_id" --decision-kind "$kind" --payload "$payload" >/dev/null 2>&1 || true
}

# Load pg-sprint-backlog skill before any DB queries (db.sh has a skill gate)
if ! bash "$SCRIPT_DIR/skill-load.sh" pg-sprint-backlog >/dev/null 2>&1; then
  echo '{"error":"failed to load pg-sprint-backlog skill"}' >&2
  exit 1
fi

# --- Agent ID → CREST role mapping ---
agent_to_role() {
  local agent="$1"
  case "$agent" in
    main)            echo "yoda_master" ;;
    business)        echo "business" ;;  # Aria — business role (CREST v1.3)
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
    # Normalize PG boolean t/f to JSON true/false
    if [[ "$override" == "t" ]]; then override="true"; else override="false"; fi
    echo "{\"model\":\"$model\",\"fallback\":\"$fallback\",\"override_allowed\":$override,\"rationale\":\"$reason\",\"source\":\"pg\"}"
    # Emit routing decision event when model resolved from PG SSOT
    local _route_id="model-${role}-${phase}"
    # Use python to build a clean JSON payload
    _route_payload=$("$JQ" -n \
      --arg role "$role" \
      --arg phase "$phase" \
      --arg model "$model" \
      --arg fallback "$fallback" \
      --arg reason "$reason" \
      '{inputs: {role: $role, phase: $phase}, outputs: {model: $model, fallback: $fallback, source: "pg"}, rationale: $reason}' \
      2>/dev/null || echo '{"error":"payload_build_failed"}')
    emit_decision "routing" "$_route_id" "$_route_payload"
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

  # v1.3 fallback: prefer crest_v13.phase_rules (PG mirror) using agent -> role mapping.
  # Falls back to v1.2 agentTiers only when crest_v13 is unavailable.
  local role
  role=$(agent_to_role "$agent")
  local phase_lower=$(echo "$phase" | tr '[:upper:]' '[:lower:]')
  local phase_cap=$(echo "$phase" | awk '{print toupper(substr($0,1,1)) tolower(substr($0,2))}')

  local model fallback rationale
  if [[ "$role" != "unknown" ]]; then
    model=$("$JQ" -r --arg role "$role" --arg phase "$phase_cap" '.crest_v13.phase_rules[] | select(.role == $role and .phase == $phase) | .default_model // empty' "$policy_file" 2>/dev/null || echo "")
    fallback=$("$JQ" -r --arg role "$role" --arg phase "$phase_cap" '.crest_v13.phase_rules[] | select(.role == $role and .phase == $phase) | .fallback_model // empty' "$policy_file" 2>/dev/null || echo "")
    rationale=$("$JQ" -r --arg role "$role" --arg phase "$phase_cap" '.crest_v13.phase_rules[] | select(.role == $role and .phase == $phase) | .rationale // empty' "$policy_file" 2>/dev/null || echo "")
  fi

  if [[ -n "$model" && "$model" != "null" ]]; then
    echo "{\"model\":\"$model\",\"fallback\":\"$fallback\",\"override_allowed\":false,\"rationale\":\"JSON fallback (crest_v13 mirror): ${rationale:-PG mirror}\",\"source\":\"json\"}"
    return 0
  fi

  # Legacy v1.2 fallback using agentTiers
  local tier
  tier=$("$JQ" -r --arg agent "$agent" '.agents[$agent].tier // empty' "$policy_file" 2>/dev/null || echo "")
  if [[ -z "$tier" || "$tier" == "null" ]]; then
    tier=$("$JQ" -r --arg agent "$agent" '.agentTiers | to_entries[] | select(.value.agentIds[] == $agent) | .key' "$policy_file" 2>/dev/null || echo "")
  fi

  if [[ -z "$tier" || "$tier" == "null" ]]; then
    echo '{"error":"agent not found in any tier","agent":"'"$agent"'"}' >&2
    exit 1
  fi

  local model_tier
  # Plan/Verify/Replan -> strong (primary); Execute/Synthesize -> cheap (cheapModel)
  case "$phase_lower" in
    plan|verify|replan) model_tier="primary" ;;
    execute|synthesize) model_tier="cheapModel" ;;
    *) model_tier="primary" ;;
  esac

  model=$("$JQ" -r --arg tier "$tier" --arg key "$model_tier" '.agentTiers[$tier][$key] // "unknown"' "$policy_file")
  fallback=$("$JQ" -r --arg tier "$tier" '.agentTiers[$tier].fallbacks[0] // "unknown"' "$policy_file")

  echo "{\"model\":\"$model\",\"fallback\":\"$fallback\",\"override_allowed\":false,\"rationale\":\"JSON fallback (v1.2 agentTiers)\",\"source\":\"json\"}"
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
  # Dump all active rules from PG as JSON with effectiveMap
  raw=$(bash "$SCRIPT_DIR/db.sh" -c "
    SELECT role, phase, default_model, fallback_model
    FROM crest_phase_rules
    WHERE matrix_version = (SELECT version FROM policy_matrices WHERE active = TRUE AND tenant_id = 'ainchors')
      AND tenant_id = 'ainchors'
    ORDER BY role, phase;
  " 2>/dev/null) || { echo '{"error":"pg unavailable for --all"}' >&2; exit 1; }

  # Build JSON effectiveMap from pipe-delimited PG output
  # Use temp file to avoid subshell scoping issues
  tmpfile=$(mktemp)
  echo "$raw" | grep -E '^[[:space:]]*[a-z]' > "$tmpfile"
  count=0
  count=$(wc -l < "$tmpfile" | xargs)
  idx=0
  echo -n '{"effectiveMap":['
  while IFS='|' read -r role phase model fallback; do
    role=$(echo "$role" | xargs)
    phase=$(echo "$phase" | xargs)
    model=$(echo "$model" | xargs)
    fallback=$(echo "$fallback" | xargs)
    if [[ -z "$role" || -z "$phase" ]]; then continue; fi
    if [[ $idx -gt 0 ]]; then echo -n ','; fi
    echo -n '{"role":"'"$role"'","phase":"'"$phase"'","default_model":"'"$model"'","fallback_model":"'"$fallback"'"}'
    idx=$((idx+1))
  done < "$tmpfile"
  rm -f "$tmpfile"
  echo ']}'
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
