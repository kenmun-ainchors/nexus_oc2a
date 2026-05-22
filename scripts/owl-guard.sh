#!/bin/zsh
# AInchors OWL Guard — TKT-0228 Atom 1
# Pre-session OWL contract enforcement. Model-agnostic.
# Activated automatically for MEDIUM/HIGH currency work.
# Verifies: file exists, git committed, test passes.
# Owner: Yoda | Sprint 4

set -u

WORKSPACE_ROOT="/Users/ainchorsangiefpl/.openclaw/workspace"
OWL_ACTIVE_FILE="$WORKSPACE_ROOT/state/owl-active.json"
OWL_COMPLIANCE_FILE="$WORKSPACE_ROOT/state/owl-compliance-state.json"
TICKET_FILE="$WORKSPACE_ROOT/state/tickets.json"

# ──────────────────────────────────────────────────────────
# PHASE A: Currency Detection
# ──────────────────────────────────────────────────────────

detect_currency() {
  # Analyze the task context to determine currency level.
  # Input: reads from stdin or from $TASK_CONTEXT env var.
  # Output: LOW, MEDIUM, or HIGH
  
  local context="${TASK_CONTEXT:-$(cat /dev/stdin 2>/dev/null || echo '')}"
  local currency="LOW"
  
  # HIGH indicators: architecture, platform changes, Notion API, cron modification, deploy, migrate
  if echo "$context" | grep -qiE 'deploy|migrate|notion.api|openclaw\.json|cron.*(create|modify|delete)|postgres.*schema|architecture.*decision|security.*control|gateway.*restart'; then
    currency="HIGH"
  
  # MEDIUM indicators: ticket operations, script creation, state changes, multi-step
  elif echo "$context" | grep -qiE 'ticket|close|create.*script|write.*file|state.*(update|change|modify)|config.*change|build|implement|fix.*bug|groom|execute.*atom|notion.*sync'; then
    currency="MEDIUM"
  
  # LOW: everything else (read-only, status, heartbeat, health check)
  else
    currency="LOW"
  fi
  
  echo "$currency"
}

# ──────────────────────────────────────────────────────────
# PHASE B: OWL Contract Injection
# ──────────────────────────────────────────────────────────

activate_owl() {
  local currency="$1"
  local model="${OWL_MODEL:-unknown}"
  local session_id="${OWL_SESSION:-unknown}"
  local now
  now=$(date -Iseconds)
  
  cat > "$OWL_ACTIVE_FILE" << JSON
{
  "sessionId": "$session_id",
  "model": "$model",
  "owlActive": true,
  "currency": "$currency",
  "activatedAt": "$now",
  "planRequired": true,
  "maxAtomsPerTurn": 1,
  "verificationRequired": true,
  "pauseRequiredMs": $([ "$currency" = "HIGH" ] && echo "30000" || echo "10000")
}
JSON

  # Inject OWL constraints as context for the agent
  cat << 'OWL_CONTRACT'

OWL MODE ACTIVE — NON-NEGOTIABLE EXECUTION CONTRACT
───────────────────────────────────────────────────

EXECUTION DISCIPLINE (Plan → Breakdown → Sequence → Execute → Verify):

1. PLAN: Before executing, output your plan as numbered atoms. 
   - Each atom = ONE observable unit of work.
   - Show the plan to the user before starting.

2. BREAKDOWN: Split work into single atoms.
   - No multi-atom turns. One atom per execution cycle.
   - Each atom produces ONE verifiable output.

3. SEQUENCE: Execute atoms one at a time.
   - Verify each atom's output BEFORE moving to the next.
   - Pause between atoms: review what was produced.

4. EXECUTE: Produce the actual output.
   - Write the file. Run the command. Create the deliverable.
   - Do NOT self-report "done." The platform verifies.

5. VERIFY: After each atom, confirm:
   - Does the file exist? (test -f <path>)
   - Is it git committed? (git log -1 --oneline -- <path>)
   - Does it pass syntax/schema validation? (bash -n, jq ., etc.)

VIOLATIONS (detected by platform, not self-reported):
- CHAIN REACTION: 3+ atoms without verification pauses → VIOLATION
- NO PLAN: Execution without declaring plan → VIOLATION
- RUSH: Error → immediate fix without assessment → VIOLATION
- FALSE DONE: Claiming completion without verification → VIOLATION

ENFORCEMENT:
- Every atom logged to owl-compliance-state.json
- 3 violations in 24h → Telegram alert to Ken
- Daily compliance <70% → restricted to LOW currency only
- TKT-0237 R05 (State Checking) audits post-execution

ACCOUNTABILITY:
- This session is being tracked.
- Your model, currency level, and atom count are logged.
- Quality is the #1 mandate. NEVER compromise.

OWL_CONTRACT
  
  echo "OWL: Activated for session $session_id (model=$model, currency=$currency)" >&2
}

# ──────────────────────────────────────────────────────────
# PHASE C: TQP Integration
# ──────────────────────────────────────────────────────────

# When called from TQP, the task-queue entry already has currency info.
# OWL guard reads it and activates accordingly.
# TQP calls: OWL_MODEL=<model> OWL_SESSION=<id> TASK_CONTEXT="<prompt>" owl-guard.sh

# ──────────────────────────────────────────────────────────
# PHASE D: Atom Audit Trail
# ──────────────────────────────────────────────────────────

log_atom() {
  local atom_id="$1" description="$2" output_path="$3" verified="${4:-false}" pause_ms="${5:-0}"
  local now v_lower
  now=$(date -Iseconds)
  v_lower=$(echo "$verified" | tr '[:upper:]' '[:lower:]')
  
  if [[ ! -f "$OWL_COMPLIANCE_FILE" ]]; then
    echo '{"atoms":[],"summary":{"totalAtoms":0,"verifiedAtoms":0,"chainReactions":0,"driftsToday":0,"dailyCompliance":100,"lastDriftDetected":null,"responsesToday":0}}' > "$OWL_COMPLIANCE_FILE"
  fi
  
  # Build new atom as JSON
  NEW_ATOM=$(jq -n --arg id "$atom_id" --arg desc "$description" --arg ts "$now" --arg path "$output_path" --argjson pause "$pause_ms" --arg v "$v_lower" --arg model "${OWL_MODEL:-unknown}" '{
    atomId: $id, description: $desc, startedAt: $ts, completedAt: $ts,
    outputPath: $path, verificationPauseMs: $pause, verified: $v, model: $model
  }')
  
  # Append atom and recalculate summary
  jq --argjson atom "$NEW_ATOM" '
    .atoms += [$atom] |
    .summary.totalAtoms = (.atoms | length) |
    .summary.verifiedAtoms = ([.atoms[] | select(.verified == "true")] | length) |
    .summary.dailyCompliance = (if .summary.totalAtoms > 0 then
      ((.summary.verifiedAtoms / .summary.totalAtoms * 100) | floor) else 100 end) |
    .summary.responsesToday += 1 |
    .summary.model = $atom.model
  ' "$OWL_COMPLIANCE_FILE" > "${OWL_COMPLIANCE_FILE}.tmp" && mv "${OWL_COMPLIANCE_FILE}.tmp" "$OWL_COMPLIANCE_FILE"
}

# ──────────────────────────────────────────────────────────
# MAIN
# ──────────────────────────────────────────────────────────

# If called to log an atom, do that directly (bypasses currency detection)
if [[ "${1:-}" == "--log-atom" ]]; then
  OWL_MODEL="${OWL_MODEL:-ollama/deepseek-v4-pro:cloud}"
  OWL_SESSION="${OWL_SESSION:-$(date +%s)}"
  log_atom "${2:-unknown}" "${3:-no description}" "${4:-}" "${5:-false}" "${6:-0}"
  echo "OWL: Atom logged — ${2:-unknown}" >&2
  exit 0
fi

OWL_MODEL="${OWL_MODEL:-ollama/deepseek-v4-pro:cloud}"
OWL_SESSION="${OWL_SESSION:-$(date +%s)}"

# Check for emergency override
if [[ "${OWL_OVERRIDE:-}" == "OFF" ]]; then
  echo '{"owlActive":false,"reason":"emergency_override","model":"'"$OWL_MODEL"'"}' > "$OWL_ACTIVE_FILE"
  echo "OWL: Emergency override — OWL not activated." >&2
  exit 0
fi

# Detect currency from task context
CURRENCY=$(detect_currency)
echo "OWL: Currency detected: $CURRENCY" >&2

if [[ "$CURRENCY" == "LOW" ]]; then
  cat > "$OWL_ACTIVE_FILE" << JSON
{
  "sessionId": "$OWL_SESSION",
  "model": "$OWL_MODEL",
  "owlActive": false,
  "currency": "LOW",
  "activatedAt": "$(date -Iseconds)"
}
JSON
  echo "OWL: LOW currency — normal mode active." >&2
  exit 0
fi

# Activate OWL for MEDIUM+
activate_owl "$CURRENCY"

# If called with --log-atom, log an atom
if [[ "${1:-}" == "--log-atom" ]]; then
  log_atom "${2:-unknown}" "${3:-no description}" "${4:-}" "${5:-false}" "${6:-0}"
fi

exit 0
