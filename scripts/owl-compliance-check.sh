#!/bin/zsh
# AInchors OWL Compliance Check — TKT-0228 Atom 3
# Runs with heartbeat to surface OWL drift alerts.
# Owner: Yoda | Sprint 4

set -u

WORKSPACE_ROOT="/Users/ainchorsangiefpl/.openclaw/workspace"
COMPLIANCE_FILE="$WORKSPACE_ROOT/state/owl-compliance-state.json"
DRIFT_ALERT_FILE="$WORKSPACE_ROOT/state/owl-drift-alert.json"
HEARTBEAT_STATE="$WORKSPACE_ROOT/state/heartbeat-state.json"

die() { echo "OWL-CHECK ERROR: $1" >&2; exit 1; }

[[ ! -f "$COMPLIANCE_FILE" ]] && die "owl-compliance-state.json not found"

# Read compliance data
TOTAL=$(jq '.summary.totalAtoms // 0' "$COMPLIANCE_FILE" 2>/dev/null)
VERIFIED=$(jq '.summary.verifiedAtoms // 0' "$COMPLIANCE_FILE" 2>/dev/null)
DRIFTS=$(jq '.summary.driftsToday // 0' "$COMPLIANCE_FILE" 2>/dev/null)
CHAIN_RXNS=$(jq '.summary.chainReactions // 0' "$COMPLIANCE_FILE" 2>/dev/null)
MODEL=$(jq -r '.summary.model // "unknown"' "$COMPLIANCE_FILE" 2>/dev/null)
LAST_DRIFT=$(jq -r '.summary.lastDriftDetected // "none"' "$COMPLIANCE_FILE" 2>/dev/null)

# Calculate compliance (handle division by zero)
if [[ "$TOTAL" -eq 0 ]]; then
  SCORE=100
else
  SCORE=$((VERIFIED * 100 / TOTAL))
fi

echo "OWL Check: $VERIFIED/$TOTAL atoms verified | Score: $SCORE% | Model: $MODEL | Drifts: $DRIFTS"

# Threshold: <70% triggers alert
if [[ "$SCORE" -lt 70 ]]; then
  echo "OWL Check: ⚠️ Compliance below threshold!"
  
  # Build alert
  jq -n \
    --arg score "$SCORE" \
    --arg model "$MODEL" \
    --argjson drifts "$DRIFTS" \
    --argjson chain "$CHAIN_RXNS" \
    --arg lastDrift "${LAST_DRIFT:-unknown}" \
    --arg detectedAt "$(date -Iseconds)" \
    --arg recommended "Review session logs. If agent model is the cause, consider switching to deepseek-v4-pro. If process issue, re-train agent on OWL execution contract." \
  '{
    alerts: [{
      type: "owl_compliance_low",
      complianceScore: ($score | tonumber),
      model: $model,
      driftsToday: $drifts,
      chainReactions: $chain,
      lastDriftDetected: $lastDrift,
      detectedAt: $detectedAt,
      acknowledged: false,
      recommendedAction: $recommended,
      message: ("OWL Compliance: " + $score + "% today. " + ($drifts | tostring) + " drifts, " + ($chain | tostring) + " chain-reactions. Model: " + $model + ". Last drift: " + $lastDrift + ".")
    }]
  }' > "$DRIFT_ALERT_FILE"
  
  echo "OWL Check: Alert created — compliance at ${SCORE}%"
  exit 1
  
elif [[ "$SCORE" -ge 70 ]]; then
  # Check if previous alert exists and clear it (compliance recovered)
  if [[ -f "$DRIFT_ALERT_FILE" ]]; then
    PREV_SCORE=$(jq '.alerts[0].complianceScore // 100' "$DRIFT_ALERT_FILE" 2>/dev/null)
    if [[ "$PREV_SCORE" -lt 70 ]]; then
      echo "OWL Check: ✅ Compliance recovered ($PREV_SCORE% → $SCORE%). Clearing alert."
      rm -f "$DRIFT_ALERT_FILE"
    fi
  fi
  echo "OWL Check: Compliance OK (${SCORE}%)"
fi

# Update heartbeat state
if [[ -f "$HEARTBEAT_STATE" ]]; then
  jq --arg ts "$(date -Iseconds)" '.lastChecks.owlCompliance = $ts' "$HEARTBEAT_STATE" > "${HEARTBEAT_STATE}.tmp" && mv "${HEARTBEAT_STATE}.tmp" "$HEARTBEAT_STATE"
fi

exit 0
