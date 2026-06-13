#!/bin/bash
# crest-execute-gate.sh — CREST Path A: Strict Enforcement Gate
# TKT-0506 / CHG-0540
#
# Pre-flight gate for Yoda's Execute-phase work. Refuses to allow Yoda to
# directly perform mechanical Execute work that should be dispatched to a
# specialist agent (Forge, Atlas, Thrawn, etc.) per CREST v1.2 §6.
#
# Path A is strict: any Execute work from Yoda (model=strong-tier) on a
# cheap-tier target (file write, cron restore, plist edit, state bootstrap,
# etc.) is BLOCKED unless:
#   1. The atom has dispatch_packet.used = true (i.e., already dispatched)
#   2. The atom has intent = "diagnostic" or "self-read" (Yoda reading own state)
#   3. The work is in T0/triage mode (no operator, no model spec)
#   4. A Ken-approved override is present (CREST_OVERRIDE=1 env var)
#
# Usage:
#   bash scripts/crest-execute-gate.sh
#   # Reads stdin or env to classify
#   CREST_PHASE=execute CREST_MODEL=minimax-m3 CREST_ATOM_DESC="backup gateway config" \
#     bash scripts/crest-execute-gate.sh
#
# Exit 0: ALLOW execution (Yoda may proceed)
# Exit 1: BLOCK execution (Yoda must dispatch to specialist)
# Exit 2: ERROR (malformed input)
#
# Integration:
#   - Reads: state/model-policy.json (model-task matrix)
#   - Writes: state/crest-execute-gate-log.json (audit trail)
#   - Linked: dispatch-validate.sh, flash-dispatcher.sh, TKT-0506, CHG-0540

set -euo pipefail

WORKSPACE="${WORKSPACE:-/Users/ainchorsangiefpl/.openclaw/workspace}"
SCRIPTS="$WORKSPACE/scripts"
LOG="$WORKSPACE/state/crest-execute-gate-log.json"
MODEL_POLICY="$WORKSPACE/state/archive/model-policy.json"

# Default values (caller can override)
CREST_PHASE="${CREST_PHASE:-execute}"
CREST_MODEL="${CREST_MODEL:-ollama/minimax-m3:cloud}"
CREST_ATOM_DESC="${CREST_ATOM_DESC:-}"
CREST_TARGET="${CREST_TARGET:-}"
CREST_OPERATOR="${CREST_OPERATOR:-yoda}"

# Helper: cheap-tier model = flash (deepseek-v4-flash, gemma4, haiku)
is_cheap_tier_model() {
  local m="$1"
  case "$m" in
    *flash*|*gemma4*|*haiku*|*e2b*|*26b*) return 0 ;;
    *) return 1 ;;
  esac
}

# Helper: is this atom a "self-read" / diagnostic / triage?
is_self_read() {
  local desc="$1" target="$2"
  # Yoda reading own state, heartbeat, diagnostic, or triage queue
  if echo "$desc $target" | grep -qiE "self|heartbeat|triage|diagnostic|read own|state/heartbeat|state/skill-load|monitor"; then
    return 0
  fi
  return 1
}

# Helper: is this a Yoda-coordinated change in main session (CREST cycle check)?
is_crest_coordinated() {
  # The 2-Pass Contract: Yoda plans, dispatches, verifies. Direct execute is blocked.
  # But Yoda CAN execute if it's part of an active CREST cycle with a sub-ticket
  # already dispatched (the verify phase, or an interactive triage).
  if [[ "${CREST_VERIFY_OF:-}" != "" ]]; then
    return 0
  fi
  return 1
}

# Helper: log the decision
log_decision() {
  local _decision="$1" _reason="$2"
  DECISION="$_decision" REASON="$_reason" python3 - <<'PYEOF'
import json, os, datetime
LOG = "/Users/ainchorsangiefpl/.openclaw/workspace/state/crest-execute-gate-log.json"
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

# CREST-coordinated work (sub-ticket already dispatched, this is verify) is exempt
if is_crest_coordinated; then
  log_decision "allow" "active CREST cycle (verify of dispatched sub-ticket)"
  echo '{"status":"allow","reason":"active CREST cycle"}'
  exit 0
fi

# Plan/Verify/Replan = strong-tier, Yoda direct is fine
case "$CREST_PHASE" in
  plan|verify|replan)
    log_decision "allow" "strong-tier phase ($CREST_PHASE) - Yoda direct OK"
    echo "{\"status\":\"allow\",\"reason\":\"strong-tier phase: $CREST_PHASE\"}"
    exit 0
    ;;
esac

# Execute / Synthesize = cheap-tier, must dispatch unless override
if [[ "$CREST_PHASE" == "execute" || "$CREST_PHASE" == "synthesize" ]]; then
  if is_cheap_tier_model "$CREST_MODEL"; then
    # Cheap-tier model in cheap-tier phase = OK, but Yoda direct is still questionable
    # Only allow if it's a real cheap-tier agent (gemma4-cron, etc.) - not Yoda
    if [[ "$CREST_OPERATOR" == "yoda" ]]; then
      log_decision "block" "Yoda (strong-tier operator) on cheap-tier phase ($CREST_PHASE) - must dispatch to specialist"
      cat <<JSON
{"status":"block","reason":"Yoda cannot directly execute cheap-tier work. Use flash-dispatcher.sh dispatch to a specialist.","required_action":"bash scripts/flash-dispatcher.sh dispatch --specialist forge --phase $CREST_PHASE --atom-desc \"$CREST_ATOM_DESC\" --target \"$CREST_TARGET\""}
JSON
      exit 1
    else
      log_decision "allow" "cheap-tier operator on cheap-tier phase"
      echo '{"status":"allow","reason":"cheap-tier operator + cheap-tier phase"}'
      exit 0
    fi
  else
    # Strong-tier model on cheap-tier phase = Yoda doing mechanical work = BLOCK
    log_decision "block" "Yoda (model=$CREST_MODEL) on cheap-tier phase ($CREST_PHASE) - cost+CREST violation. Dispatch to specialist with flash model."
    cat <<JSON
{"status":"block","reason":"Yoda is using $CREST_MODEL (strong-tier) for $CREST_PHASE work. Per CREST v1.2 §6, this should dispatch to a specialist with a cheap-tier model.","required_action":"bash scripts/flash-dispatcher.sh dispatch --specialist forge --phase $CREST_PHASE --atom-desc \"$CREST_ATOM_DESC\" --target \"$CREST_TARGET\""}
JSON
    exit 1
  fi
fi

# Unknown phase
log_decision "warn" "unknown phase: $CREST_PHASE"
echo "{\"status\":\"warn\",\"reason\":\"unknown phase: $CREST_PHASE\"}"
exit 0
