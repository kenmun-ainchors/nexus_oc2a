#!/bin/bash
# crest-execute-gate.sh — CREST Path A: Strict Enforcement Gate
# TKT-0506 / CHG-0540 / TKT-0540
#
# Pre-flight gate for operator Execute/Synthesize work. Compares the intended
# model against the effective model resolved from state/archive/model-policy.json
# via scripts/model-policy-query.sh.
#
# Path A is strict: an operator may only execute a phase if:
#   1. The phase is allowed for that operator in model-policy.json.
#   2. The model being used matches the policy-effective model.
#   3. The operator is not Yoda on an Execute phase (unless Ken override).
#   4. A Ken-approved override is present (CREST_OVERRIDE=1).
#   5. The atom is a self-read/diagnostic or triage/systemEvent.
#
# Usage:
#   bash scripts/crest-execute-gate.sh
#   CREST_PHASE=execute CREST_OPERATOR=infra CREST_MODEL=ollama/deepseek-v4-flash:cloud \
#     CREST_ATOM_DESC="backup gateway config" bash scripts/crest-execute-gate.sh
#
# Exit 0: ALLOW
# Exit 1: BLOCK
# Exit 2: ERROR

set -euo pipefail

WORKSPACE="${WORKSPACE:-/Users/ainchorsangiefpl/.openclaw/workspace}"
SCRIPTS="$WORKSPACE/scripts"
LOG="$WORKSPACE/state/crest-execute-gate-log.json"
MODEL_POLICY="$WORKSPACE/state/archive/model-policy.json"
QUERY="$SCRIPTS/model-policy-query.sh"

# Default values (caller can override)
CREST_PHASE="${CREST_PHASE:-execute}"
CREST_MODEL="${CREST_MODEL:-}"
CREST_ATOM_DESC="${CREST_ATOM_DESC:-}"
CREST_TARGET="${CREST_TARGET:-}"
CREST_OPERATOR="${CREST_OPERATOR:-yoda}"

# Resolve expected model for operator+phase from policy.
resolve_expected_model() {
  local op="$1" ph="$2"
  if [[ ! -x "$QUERY" ]]; then
    echo '{"error":"model-policy-query.sh not found"}'
    return 1
  fi
  bash "$QUERY" --agent "$op" --phase "$ph" 2>/dev/null
}

# Helper: is this atom a "self-read" / diagnostic / triage?
is_self_read() {
  local desc="$1" target="$2"
  if echo "$desc $target" | grep -qiE "self|heartbeat|triage|diagnostic|read own|state/heartbeat|state/skill-load|monitor"; then
    return 0
  fi
  return 1
}

# Helper: log the decision
log_decision() {
  local _decision="$1" _reason="$2"
  DECISION="$_decision" REASON="$_reason" python3 - <<'PYEOF'
import json, os, datetime
LOG = os.environ.get("CREST_GATE_LOG", "/Users/ainchorsangiefpl/.openclaw/workspace/state/crest-execute-gate-log.json")
d = {"history": []}
if os.path.exists(LOG):
    try: d = json.load(open(LOG))
    except: d = {"history": []}
if "history" not in d: d["history"] = []
entry = {
    "ts": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    "operator": os.environ.get("CREST_OPERATOR", "yoda"),
    "phase": os.environ.get("CREST_PHASE", "execute"),
    "model": os.environ.get("CREST_MODEL", ""),
    "atomDesc": os.environ.get("CREST_ATOM_DESC", ""),
    "target": os.environ.get("CREST_TARGET", ""),
    "decision": os.environ["DECISION"],
    "reason": os.environ["REASON"]
}
d["history"].append(entry)
d["history"] = d["history"][-200:]
d["lastDecision"] = {"ts": entry["ts"], "decision": entry["decision"], "reason": entry["reason"]}
with open(LOG, "w") as f: json.dump(d, f, indent=2)
PYEOF
}

# ─── Main gate logic ──────────────────────────────────────────
if [[ "${CREST_OVERRIDE:-0}" == "1" ]]; then
  log_decision "allow" "CREST_OVERRIDE=1 explicit Ken approval"
  echo '{"status":"allow","reason":"Ken override active"}'
  exit 0
fi

# Triage / systemEvent is exempt
if [[ "$CREST_PHASE" == "systemEvent" || "$CREST_PHASE" == "triage" || "$CREST_PHASE" == "monitor" ]]; then
  log_decision "allow" "triage/systemEvent phase exempt"
  echo '{"status":"allow","reason":"triage phase exempt from gate"}'
  exit 0
fi

# Self-reads are exempt
if is_self_read "$CREST_ATOM_DESC" "$CREST_TARGET"; then
  log_decision "allow" "self-read / diagnostic exempt"
  echo '{"status":"allow","reason":"self-read or diagnostic"}'
  exit 0
fi

# Resolve expected model from policy
EXPECTED_JSON=$(resolve_expected_model "$CREST_OPERATOR" "$CREST_PHASE" 2>/dev/null) || true
EXPECTED_MODEL=$(echo "$EXPECTED_JSON" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('model',''))" 2>/dev/null || true)
EXPECTED_ERROR=$(echo "$EXPECTED_JSON" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('error',''))" 2>/dev/null || true)

# If the phase is not allowed for this operator, block (Yoda Execute, etc.)
if [[ -n "$EXPECTED_ERROR" || -z "$EXPECTED_MODEL" ]]; then
  log_decision "block" "phase '$CREST_PHASE' not allowed for operator '$CREST_OPERATOR' per model-policy.json"
  cat <<JSON
{"status":"block","reason":"phase '$CREST_PHASE' is not allowed for operator '$CREST_OPERATOR' per model-policy.json","expected":"not-allowed","actual":"$CREST_MODEL"}
JSON
  exit 1
fi

# Yoda (main) on Execute is always blocked — even if policy somehow allowed it
if [[ "$CREST_OPERATOR" == "yoda" || "$CREST_OPERATOR" == "main" ]] && [[ "$CREST_PHASE" == "execute" ]]; then
  log_decision "block" "Yoda direct Execute blocked per CHG-0545"
  cat <<JSON
{"status":"block","reason":"Yoda cannot directly Execute. Dispatch to a specialist or obtain Ken override (CHG-0545).","expected":"not-allowed","actual":"$CREST_MODEL"}
JSON
  exit 1
fi

# Model mismatch: actual model does not match policy-effective model
if [[ -n "$CREST_MODEL" && "$CREST_MODEL" != "$EXPECTED_MODEL" ]]; then
  log_decision "block" "model mismatch: actual=$CREST_MODEL expected=$EXPECTED_MODEL"
  cat <<JSON
{"status":"block","reason":"model mismatch for $CREST_OPERATOR/$CREST_PHASE","expected":"$EXPECTED_MODEL","actual":"$CREST_MODEL"}
JSON
  exit 1
fi

# All checks passed
log_decision "allow" "matches policy-effective model $EXPECTED_MODEL"
echo "{\"status\":\"allow\",\"reason\":\"matches policy-effective model\",\"expected\":\"$EXPECTED_MODEL\",\"actual\":\"$CREST_MODEL\"}"
exit 0
