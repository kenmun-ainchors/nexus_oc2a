#!/bin/bash
# dispatch-validate.sh — Agent-to-Agent Dispatch Pre-Flight Gate
# TKT-0323 (original) + TKT-0385 (CREST v1.2 extension) + TKT-0403 (checkout-freshness gate)
#
# Validates dispatch JSON against structural + policy checks before
# an orchestrator dispatches work to a specialist.
#
# SKILL GATE: pg-sprint-backlog skill MUST be loaded before use.
source "${SCRIPT_DIR:-$(dirname "$0")}/skill-gate.sh" "pg-sprint-backlog" || exit $?
#
# Legacy (TKT-0323): source_agent, target_agent, discovery_atoms
# CREST (TKT-0385): sub_crest_plan, model phase assignments, escalation handshake
#
# Usage:
#   echo '{...}' | bash scripts/dispatch-validate.sh
#   bash scripts/dispatch-validate.sh --json '{...}'
#   bash scripts/dispatch-validate.sh --json '{...}' --verbose
#   bash scripts/dispatch-validate.sh --help
#
# Exit 0: valid dispatch  → {"status":"ok"}
# Exit 1: invalid dispatch → {"status":"fail","failures":[...]}

set -euo pipefail

JQ="${JQ:-/opt/homebrew/bin/jq}"
VERBOSE=false
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ATOM_VALIDATOR="${SCRIPT_DIR}/atom-validate.sh"
MODEL_POLICY="${SCRIPT_DIR}/../state/model-policy.json"

usage() {
  cat <<'EOF'
dispatch-validate.sh — Agent-to-Agent Dispatch Pre-Flight Gate
TKT-0323 + TKT-0385 CREST v1.2 extension

SYNTAX:
  dispatch-validate.sh --json '{"source_agent":"yoda",...}'   # dispatch as CLI arg
  dispatch-validate.sh --stdin                                 # read from stdin
  cat dispatch.json | dispatch-validate.sh                     # stdin (default)
  dispatch-validate.sh --help                                  # this message

FLAGS:
  --json '...'    Dispatch JSON string
  --stdin         Read JSON from stdin (default when no --json)
  --verbose       Include all field check results in output (pass + fail)
  --help          Show usage

CHECKS:

  LEGACY (TKT-0323) — always applied:
    source_agent  Present, non-empty string
    target_agent  Present, non-empty string
    discovery_atoms  Array with ≥1 entry

  CREST (TKT-0385) — applied when sub_crest_plan field exists:
    sub_crest_plan       Non-empty array of atom objects
    Each atom fields     verb, target, pre_conditions (≥1), post_conditions (≥1), model, phase
    Atom validation      Each atom passes atom-validate.sh (TKT-0384)
    Model assignment     Each atom's model matches CREST phase per model-policy.json
                         Exception: Forge Plan/Execute/Synthesize atoms use flash-tier per CREST v1.3 build role
    Escalation (if set)  Must have reason (non-empty string), source_phase (valid CREST phase)
                         Optional: proposed_remedy (string), severity (low|medium|high|critical)

  ANTI-SUBAGENT-TRAP (Ken directive 2026-06-15, L-138):
    verifier_corpus      Required when ANY atom has phase=execute or phase=verify.
                         Yoda authors the test corpus BEFORE dispatch (string file
                         path or array of file paths). Subagent runs the verifier
                         and reports totals; MUST NOT modify the corpus or verifier.
                         Subagent-written tests always pass — they validate the
                         subagent's own (potentially broken) implementation. The
                         Yoda-side corpus + verifier (L-113 evidence-only) is the
                         catch-all. Cost: ~1-2 min of Yoda-side test authoring per
                         execute/verify atom. Pays for itself after 1 caught bug.

EXIT CODES:
  0  All checks passed → {"status":"ok"}
  1  One or more failures → {"status":"fail","failures":[...]}

AUTHOR:
  Forge 🏗️ — TKT-0385 — 2026-06-10
EOF
  exit 0
}

# ── Parse flags ──────────────────────────────────────────────
JSON_INPUT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --json)
      JSON_INPUT="$2"
      shift 2
      ;;
    --stdin)
      JSON_INPUT=""
      shift
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    --help)
      usage
      ;;
    *)
      echo '{"status":"fail","failures":[{"field":"flags","reason":"unknown flag: '"$1"'"}]}'
      exit 1
      ;;
  esac
done

# ── Acquire JSON ─────────────────────────────────────────────
if [[ -z "$JSON_INPUT" ]]; then
  JSON_INPUT=$(cat)
fi

if [[ -z "$JSON_INPUT" ]]; then
  echo '{"status":"fail","failures":[{"field":"input","reason":"no JSON provided (empty --json or stdin)"}]}'
  exit 1
fi

# ── Validate parseable JSON ──────────────────────────────────
if ! echo "$JSON_INPUT" | "$JQ" -e . >/dev/null 2>&1; then
  echo '{"status":"fail","failures":[{"field":"input","reason":"invalid JSON: cannot parse"}]}'
  exit 1
fi

# ── Helpers ──────────────────────────────────────────────────

# Report a single field check using jq evaluation
check() {
  local field="$1" expr="$2" fail_reason="$3"
  local result
  result=$(echo "$JSON_INPUT" | "$JQ" -r "$expr" 2>/dev/null) || true
  if [[ "$result" == "pass" ]]; then
    if $VERBOSE; then
      "$JQ" -n --arg f "$field" '{"field":$f,"status":"pass"}'
    fi
    return 0
  else
    "$JQ" -n --arg f "$field" --arg r "$fail_reason" '{"field":$f,"reason":$r}'
    return 1
  fi
}

# Emit a failure entry with an optional atom index
fail_atom() {
  local field="$1" reason="$2" idx="${3:-}"
  if [[ -n "$idx" ]]; then
    "$JQ" -n --arg f "$field" --arg r "$reason" --argjson i "$idx" \
      '{"field":$f,"reason":$r,"atom_index":$i}'
  else
    "$JQ" -n --arg f "$field" --arg r "$reason" '{"field":$f,"reason":$r}'
  fi
}

FAILURES=()
PASSES=0

# ── LEGACY CHECKS (TKT-0323) — always applied ────────────────

# 1. source_agent: present and non-empty
if RESULT=$(check "source_agent" \
  'if .source_agent and (.source_agent | type == "string") and ((.source_agent | length) > 0) then "pass" else "fail" end' \
  "missing or empty"); then
  ((PASSES++))
else
  FAILURES+=("$RESULT")
fi

# ── CREST EXECUTION GATE (TKT-0506, CHG-0540) ────────────────
# Pre-flight check before any Yoda→specialist dispatch.
# If source_agent=yoda and the first atom has a mutating verb,
# invoke crest-execute-gate.sh to verify the dispatch is legitimate.

CREST_GATE="${SCRIPT_DIR}/crest-execute-gate.sh"

SOURCE_AGENT=$(echo "$JSON_INPUT" | "$JQ" -r '.source_agent // empty' 2>/dev/null)
FIRST_VERB=$(echo "$JSON_INPUT" | "$JQ" -r '.discovery_atoms[0].verb // .sub_crest_plan[0].verb // empty' 2>/dev/null)
FIRST_TARGET=$(echo "$JSON_INPUT" | "$JQ" -r '.discovery_atoms[0].target // .sub_crest_plan[0].target // empty' 2>/dev/null)
FIRST_DESC=$(echo "$JSON_INPUT" | "$JQ" -r '.discovery_atoms[0].desc // .sub_crest_plan[0].desc // empty' 2>/dev/null)
FIRST_MODEL=$(echo "$JSON_INPUT" | "$JQ" -r '.sub_crest_plan[0].model // .discovery_atoms[0].model // empty' 2>/dev/null)

MUTATING_VERBS="create|write|delete|edit|exec"

if [[ "$SOURCE_AGENT" == "yoda" ]] && echo "$FIRST_VERB" | grep -qE "^($MUTATING_VERBS)$"; then
  if [[ -x "$CREST_GATE" ]]; then
    GATE_RESULT=$(CREST_PHASE=execute \
      CREST_OPERATOR=main \
      CREST_MODEL="${FIRST_MODEL:-}" \
      CREST_ATOM_DESC="$FIRST_DESC" \
      CREST_TARGET="$FIRST_TARGET" \
      bash "$CREST_GATE" 2>/dev/null) || true

    GATE_STATUS=$(echo "$GATE_RESULT" | "$JQ" -r '.status // "unknown"' 2>/dev/null)
    GATE_REASON=$(echo "$GATE_RESULT" | "$JQ" -r '.reason // "no reason given"' 2>/dev/null)

    if [[ "$GATE_STATUS" == "block" ]]; then
      FAILURES+=("$(fail_atom "crest_execution_gate" "CREST execution gate BLOCKED: ${GATE_REASON}")")
    elif [[ "$GATE_STATUS" == "warn" ]]; then
      # Warn but don't block — unknown phase passed through
      if $VERBOSE; then
        echo "WARN: CREST gate returned warn: ${GATE_REASON}" >&2
      fi
    else
      ((PASSES++))
      if $VERBOSE; then
        echo "PASS: CREST execution gate ($GATE_STATUS)" >&2
      fi
    fi
  else
    if $VERBOSE; then
      echo "WARN: crest-execute-gate.sh not found at ${CREST_GATE}; skipping execution gate" >&2
    fi
  fi
else
  if $VERBOSE; then
    echo "SKIP: CREST execution gate (source=$SOURCE_AGENT, verb=$FIRST_VERB)" >&2
  fi
fi

# 2. target_agent: present and non-empty
if RESULT=$(check "target_agent" \
  'if .target_agent and (.target_agent | type == "string") and ((.target_agent | length) > 0) then "pass" else "fail" end' \
  "missing or empty"); then
  ((PASSES++))
else
  FAILURES+=("$RESULT")
fi

# 3. discovery_atoms: array with ≥1 entry
if RESULT=$(check "discovery_atoms" \
  'if .discovery_atoms and (.discovery_atoms | type == "array") and ((.discovery_atoms | length) > 0) then "pass" else "fail" end' \
  "must be non-empty array"); then
  ((PASSES++))
else
  FAILURES+=("$RESULT")
fi

# Capture target_agent for CREST model policy validation
TARGET_AGENT=$(echo "$JSON_INPUT" | "$JQ" -r '.target_agent // empty' 2>/dev/null)

# ── CREST CHECKS (TKT-0385) — only when sub_crest_plan exists ─

HAS_SUB_CREST=$(echo "$JSON_INPUT" | "$JQ" -r 'if .sub_crest_plan then "yes" else "no" end' 2>/dev/null)

if [[ "$HAS_SUB_CREST" == "yes" ]]; then

  # ─── 1. Sub-CREST Plan Structure Validation ────────────────

  # 1a: sub_crest_plan must be a non-empty array
  if RESULT=$(check "sub_crest_plan" \
    'if (.sub_crest_plan | type == "array") and ((.sub_crest_plan | length) > 0) then "pass" else "fail" end' \
    "must be non-empty array"); then
    ((PASSES++))
  else
    FAILURES+=("$RESULT")
  fi

  # 1b: Each atom in sub_crest_plan must have required fields
  ATOM_COUNT=$(echo "$JSON_INPUT" | "$JQ" -r '.sub_crest_plan | length')
  for ((i=0; i<ATOM_COUNT; i++)); do
    idx_label="atom[$i]"

    # verb
    if RESULT=$(check "${idx_label}.verb" \
      "if .sub_crest_plan[$i].verb and (.sub_crest_plan[$i].verb | type == \"string\") and ((.sub_crest_plan[$i].verb | length) > 0) then \"pass\" else \"fail\" end" \
      "missing or empty"); then
      ((PASSES++))
    else
      FAILURES+=("$RESULT")
    fi

    # target
    if RESULT=$(check "${idx_label}.target" \
      "if .sub_crest_plan[$i].target and (.sub_crest_plan[$i].target | type == \"string\") and ((.sub_crest_plan[$i].target | length) > 0) then \"pass\" else \"fail\" end" \
      "missing or empty"); then
      ((PASSES++))
    else
      FAILURES+=("$RESULT")
    fi

    # pre_conditions: array with ≥1 entry
    if RESULT=$(check "${idx_label}.pre_conditions" \
      "if .sub_crest_plan[$i].pre_conditions and (.sub_crest_plan[$i].pre_conditions | type == \"array\") and ((.sub_crest_plan[$i].pre_conditions | length) > 0) then \"pass\" else \"fail\" end" \
      "must be non-empty array"); then
      ((PASSES++))
    else
      FAILURES+=("$RESULT")
    fi

    # post_conditions: array with ≥1 entry
    if RESULT=$(check "${idx_label}.post_conditions" \
      "if .sub_crest_plan[$i].post_conditions and (.sub_crest_plan[$i].post_conditions | type == \"array\") and ((.sub_crest_plan[$i].post_conditions | length) > 0) then \"pass\" else \"fail\" end" \
      "must be non-empty array"); then
      ((PASSES++))
    else
      FAILURES+=("$RESULT")
    fi

    # model: present, non-empty
    if RESULT=$(check "${idx_label}.model" \
      "if .sub_crest_plan[$i].model and (.sub_crest_plan[$i].model | type == \"string\") and ((.sub_crest_plan[$i].model | length) > 0) then \"pass\" else \"fail\" end" \
      "missing or empty"); then
      ((PASSES++))
    else
      FAILURES+=("$RESULT")
    fi

    # phase: must be valid CREST phase
    if RESULT=$(check "${idx_label}.phase" \
      "if .sub_crest_plan[$i].phase and (.sub_crest_plan[$i].phase | type == \"string\") and (.sub_crest_plan[$i].phase | IN(\"plan\",\"execute\",\"verify\",\"replan\",\"synthesize\")) then \"pass\" else \"fail\" end" \
      "must be valid CREST phase (plan|execute|verify|replan|synthesize)"); then
      ((PASSES++))
    else
      FAILURES+=("$RESULT")
    fi
  done

  # ─── 1a. Parent Ticket PG Existence Check ────────────────
  # TKT-0369 Failure #5: CREST dispatches must verify the parent ticket
  # exists in PG before dispatching execution atoms. Prevents silent
  # failures where tickets were created incorrectly (e.g. wrong flags)
  # and atoms execute against non-existent or degraded tickets.
  PARENT_TICKET_ID=$(echo "$JSON_INPUT" | "$JQ" -r '.parent_ticket_id // empty' 2>/dev/null)
  if [[ -n "$PARENT_TICKET_ID" ]]; then
    if RESULT=$("$SCRIPT_DIR/db-raw.sh" -c "SELECT id FROM state_tickets WHERE id = '$PARENT_TICKET_ID';" 2>/dev/null); then
      if echo "$RESULT" | grep -q "$PARENT_TICKET_ID"; then
        if $VERBOSE; then
          echo "$($JQ -n --arg f "parent_ticket_id" '{"field":$f,"status":"ok","note":"ticket exists in PG"}')"
        fi
        ((PASSES++))
      else
        FAILURES+=("$(fail_atom "parent_ticket_id" "Ticket $PARENT_TICKET_ID not found in PG — may have been created incorrectly or degraded to file-only. Check ticket.sh invocation." "")")
      fi
    else
      FAILURES+=("$(fail_atom "parent_ticket_id" "PG query failed — cannot verify ticket $PARENT_TICKET_ID exists. PG may be degraded." "")")
    fi
  else
    # parent_ticket_id is optional for non-CREST dispatches
    if $VERBOSE; then
      echo "$($JQ -n --arg f "parent_ticket_id" '{"field":$f,"status":"skip","note":"no parent ticket — not a CREST dispatch"}')"
    fi
  fi

  # ─── 2. Atom validation via atom-validate.sh ────────────────

  # Check if atom-validate.sh exists
  if [[ -x "$ATOM_VALIDATOR" ]]; then
    for ((i=0; i<ATOM_COUNT; i++)); do
      idx_label="atom[$i]"

      # Extract this atom as standalone JSON — must include verb, target, pre_conditions, post_conditions, model, atom fields
      # atom-validate.sh checks: verb, target, pre_conditions, post_conditions, atom, model
      # sub_crest_plan atoms may lack 'atom' field — we derive it or skip that check
      ATOM_JSON=$(echo "$JSON_INPUT" | "$JQ" -c --argjson i "$i" '
        .sub_crest_plan[$i] as $a |
        {
          verb: $a.verb,
          target: $a.target,
          pre_conditions: $a.pre_conditions,
          post_conditions: $a.post_conditions,
          atom: ($a.atom // "sub-crest-plan-atom-\($i)"),
          model: $a.model
        }
      ')

      ATOM_RESULT=$(echo "$ATOM_JSON" | "$ATOM_VALIDATOR" 2>&1) || true
      ATOM_STATUS=$(echo "$ATOM_RESULT" | "$JQ" -r '.status' 2>/dev/null || echo "error")

      if [[ "$ATOM_STATUS" != "ok" ]]; then
        ATOM_FAILURES=$(echo "$ATOM_RESULT" | "$JQ" -r '.failures // [] | map(.field + ": " + .reason) | join("; ")' 2>/dev/null || echo "atom-validation-error")
        FAILURES+=("$(fail_atom "${idx_label}.atom_validate" "failed atom-validate.sh: ${ATOM_FAILURES}" "$i")")
      else
        ((PASSES++))
        if $VERBOSE; then
          "$JQ" -n --arg f "${idx_label}.atom_validate" '{"field":$f,"status":"pass"}'
        fi
      fi
    done
  else
    FAILURES+=("$(fail_atom "atom-validate.sh" "not found or not executable at ${ATOM_VALIDATOR}" "")")
  fi

  # ─── 3. Model Assignment Policy Validation (TKT-0540) ─────────────────

  # ─── 3a. Verifier Corpus Required (Ken directive 2026-06-15, L-138) ───
  HAS_EXECUTE_OR_VERIFY=$(echo "$JSON_INPUT" | "$JQ" -r \
    '[.sub_crest_plan[] | select(.phase == "execute" or .phase == "verify")] | length' 2>/dev/null)

  if [[ "${HAS_EXECUTE_OR_VERIFY:-0}" -gt 0 ]]; then
    VERIFIER_CORPUS=$(echo "$JSON_INPUT" | "$JQ" -r '.verifier_corpus // empty' 2>/dev/null)
    VERIFIER_CORPUS_TYPE=$(echo "$JSON_INPUT" | "$JQ" -r '.verifier_corpus | type // "null"' 2>/dev/null)

    if [[ -z "$VERIFIER_CORPUS" || "$VERIFIER_CORPUS" == "null" ]]; then
      FAILURES+=("$(fail_atom "verifier_corpus" "missing — required for any execute/verify atom (L-138 anti-subagent-trap rule). Yoda must author test corpus BEFORE dispatch; subagent runs and reports only." "")")
    elif [[ "$VERIFIER_CORPUS_TYPE" == "string" ]]; then
      if [[ ! -e "$VERIFIER_CORPUS" ]]; then
        FAILURES+=("$(fail_atom "verifier_corpus" "file not found: ${VERIFIER_CORPUS} — Yoda must create the test corpus before dispatch." "")")
      else
        ((PASSES++))
        if $VERBOSE; then
          echo "$($JQ -n --arg f "verifier_corpus" --arg p "$VERIFIER_CORPUS" '{"field":$f,"status":"ok","path":$p}')"
        fi
      fi
    elif [[ "$VERIFIER_CORPUS_TYPE" == "array" ]]; then
      CORPUS_COUNT=$(echo "$JSON_INPUT" | "$JQ" -r '.verifier_corpus | length' 2>/dev/null)
      if [[ "${CORPUS_COUNT:-0}" -eq 0 ]]; then
        FAILURES+=("$(fail_atom "verifier_corpus" "empty array — Yoda must populate test corpus before dispatch." "")")
      else
        MISSING_FILES=0
        while IFS= read -r corpus_file; do
          [[ -z "$corpus_file" ]] && continue
          if [[ ! -e "$corpus_file" ]]; then
            MISSING_FILES=$((MISSING_FILES+1))
            FAILURES+=("$(fail_atom "verifier_corpus[${corpus_file}]" "file not found — Yoda must create the test corpus before dispatch." "")")
          fi
        done < <(echo "$JSON_INPUT" | "$JQ" -r '.verifier_corpus[]' 2>/dev/null)
        if [[ $MISSING_FILES -eq 0 ]]; then
          ((PASSES++))
          if $VERBOSE; then
            echo "$($JQ -n --arg f "verifier_corpus" --argjson c "$CORPUS_COUNT" '{"field":$f,"status":"ok","count":$c}')"
          fi
        fi
      fi
    else
      FAILURES+=("$(fail_atom "verifier_corpus" "invalid type (${VERIFIER_CORPUS_TYPE}) — must be string (file path) or array of file paths." "")")
    fi
  fi

  # ─── 3b. Model assignment per policy helper ─────────────────

  if [[ -x "${SCRIPT_DIR}/model-policy-query.sh" ]]; then
    for ((i=0; i<ATOM_COUNT; i++)); do
      idx_label="atom[$i]"
      ATOM_PHASE=$(echo "$JSON_INPUT" | "$JQ" -r ".sub_crest_plan[$i].phase" 2>/dev/null)
      ATOM_MODEL=$(echo "$JSON_INPUT" | "$JQ" -r ".sub_crest_plan[$i].model" 2>/dev/null)

      EXPECTED_JSON=$(bash "${SCRIPT_DIR}/model-policy-query.sh" --agent "$TARGET_AGENT" --phase "$ATOM_PHASE" 2>/dev/null) || true
      EXPECTED_STATUS=$(echo "$EXPECTED_JSON" | "$JQ" -r '.model // .error // empty' 2>/dev/null || true)

      if [[ -z "$EXPECTED_STATUS" || "$EXPECTED_STATUS" == "not-allowed" ]]; then
        FAILURES+=("$(fail_atom "${idx_label}.model_assignment" \
          "phase '${ATOM_PHASE}' is not allowed for agent '${TARGET_AGENT}' per model-policy.json (TKT-0540)" "$i")")
        continue
      fi

      # Check exact match against expected model
      if [[ "$ATOM_MODEL" == "$EXPECTED_STATUS" ]]; then
        ((PASSES++))
        if $VERBOSE; then
          "$JQ" -n --arg f "${idx_label}.model_assignment" --arg expected "$EXPECTED_STATUS" --arg actual "$ATOM_MODEL" \
            '{"field":$f,"status":"pass","expected":$expected,"actual":$actual}'
        fi
      else
        FAILURES+=("$(fail_atom "${idx_label}.model_assignment" \
          "phase '${ATOM_PHASE}' for agent '${TARGET_AGENT}' expects model '${EXPECTED_STATUS}', but atom uses '${ATOM_MODEL}'" "$i")")
      fi
    done
  else
    FAILURES+=("$(fail_atom "model-policy-query.sh" "not executable at ${SCRIPT_DIR}/model-policy-query.sh; cannot validate model assignments (TKT-0540)" "")")
  fi

  # ─── 4. Escalation Handshake Validation ────────────────────

  HAS_ESCALATION=$(echo "$JSON_INPUT" | "$JQ" -r 'if .escalation and (.escalation != null) then "yes" else "no" end' 2>/dev/null)

  if [[ "$HAS_ESCALATION" == "yes" ]]; then
    # escalation.reason: required, non-empty string
    if RESULT=$(check "escalation.reason" \
      'if .escalation.reason and (.escalation.reason | type == "string") and ((.escalation.reason | length) > 0) then "pass" else "fail" end' \
      "required non-empty string"); then
      ((PASSES++))
    else
      FAILURES+=("$RESULT")
    fi

    # escalation.source_phase: required, valid CREST phase
    if RESULT=$(check "escalation.source_phase" \
      'if .escalation.source_phase and (.escalation.source_phase | type == "string") and (.escalation.source_phase | IN("plan","execute","verify","replan","synthesize")) then "pass" else "fail" end' \
      "must be valid CREST phase (plan|execute|verify|replan|synthesize)"); then
      ((PASSES++))
    else
      FAILURES+=("$RESULT")
    fi

    # escalation.severity: optional, but if present must be valid
    ESC_SEV=$(echo "$JSON_INPUT" | "$JQ" -r '.escalation.severity // ""' 2>/dev/null)
    if [[ -n "$ESC_SEV" ]]; then
      if RESULT=$(check "escalation.severity" \
        'if .escalation.severity | IN("low","medium","high","critical") then "pass" else "fail" end' \
        "must be low|medium|high|critical"); then
        ((PASSES++))
      else
        FAILURES+=("$RESULT")
      fi
    fi

    # escalation.proposed_remedy: optional, if present must be string
    ESC_REMEDY=$(echo "$JSON_INPUT" | "$JQ" -r '.escalation.proposed_remedy // ""' 2>/dev/null)
    if [[ -n "$ESC_REMEDY" && "$ESC_REMEDY" != "null" ]]; then
      if RESULT=$(check "escalation.proposed_remedy" \
        'if .escalation.proposed_remedy and (.escalation.proposed_remedy | type == "string") and ((.escalation.proposed_remedy | length) > 0) then "pass" else "fail" end' \
        "must be non-empty string if provided"); then
        ((PASSES++))
      else
        FAILURES+=("$RESULT")
      fi
    fi
  fi

fi  # end CREST checks

# ── TKT-0403 CHECKOUT-FRESHNESS GATE ────────────────────────
# Agents must NEVER review a cp -r of Yoda working copy.
# Each review runs against a FRESH git fetch/clone at exact SHA.
# Triggered when dispatch includes review_target path or source_files.

REVIEW_TARGET=$(echo "$JSON_INPUT" | "$JQ" -r '.review_target // .source_files // ""' 2>/dev/null)
REVIEW_SHA=$(echo "$JSON_INPUT" | "$JQ" -r '.review_sha // ""' 2>/dev/null)
HAS_REVIEW_MODE=$(echo "$JSON_INPUT" | "$JQ" -r 'if .task and (.task | test("review|REVIEW|Review")) then "yes" else "no" end' 2>/dev/null)

if [[ -n "$REVIEW_TARGET" && "$REVIEW_TARGET" != "null" && "$REVIEW_TARGET" != "" ]]; then
  # Check 1: review_sha MUST be present when review_target is specified
  if [[ -z "$REVIEW_SHA" || "$REVIEW_SHA" == "null" ]]; then
    FAILURES+=("$(fail_atom "review_sha" "REQUIRED when review_target is specified — every review must declare the exact SHA under review (TKT-0403 cp -r prevention)")")
  else
    ((PASSES++))

    # Check 2: Verify the agent workspace at review_target is a fresh git checkout at review_sha
    if [[ -f "$SCRIPT_DIR/checkout-freshness.sh" ]]; then
      if FRESHNESS_OUTPUT=$(zsh "$SCRIPT_DIR/checkout-freshness.sh" "$REVIEW_SHA" "$REVIEW_TARGET" 2>&1); then
        if $VERBOSE; then echo "$FRESHNESS_OUTPUT" >&2; fi
        ((PASSES++))
      else
        FAILURES+=("$(fail_atom "review_target" "Checkout freshness FAILED at $REVIEW_TARGET: $(echo "$FRESHNESS_OUTPUT" | tail -3 | tr '\n' ' ' | sed 's/"/\\\\"/g')")")
      fi
    else
      FAILURES+=("$(fail_atom "review_target" "checkout-freshness.sh not found — cannot verify agent workspace is fresh clone (TKT-0403)")")
    fi
  fi
elif [[ "$HAS_REVIEW_MODE" == "yes" ]]; then
  # Review-mode dispatch without review_target → flag
  FAILURES+=("$(fail_atom "review_target" "Task appears to be a review but no review_target or review_sha specified — TKT-0403 requires explicit SHA + path")")
else
  # Not a review dispatch — skip freshness gate
  if $VERBOSE; then echo "SKIP: checkout-freshness gate (no review_target in dispatch)" >&2; fi
fi

# ── CREST v1.3 CHECKS (TKT-0546 A7) ──────────────────────
# Phase ownership, state_sub_crest, Sage verdict, external loop enforcement

HAS_V13_FIELDS=$(echo "$JSON_INPUT" | "$JQ" -r 'if .crest_v13 then "yes" else "no" end' 2>/dev/null)

if [[ "$HAS_V13_FIELDS" == "yes" ]]; then

  # v1.3a: phase_owner must be present (external loop ownership)
  if RESULT=$(check "crest_v13.phase_owner" \
    'if .crest_v13.phase_owner and (.crest_v13.phase_owner | type == "string") and ((.crest_v13.phase_owner | length) > 0) then "pass" else "fail" end' \
    "missing phase_owner — CREST v1.3 requires external loop ownership"); then
    ((PASSES++))
  else
    FAILURES+=("$RESULT")
  fi

  # v1.3b: phase_owner must NOT be the same as target_agent (no self-driving)
  PHASE_OWNER=$(echo "$JSON_INPUT" | "$JQ" -r '.crest_v13.phase_owner // empty' 2>/dev/null)
  if [[ -n "$PHASE_OWNER" && "$PHASE_OWNER" == "$TARGET_AGENT" ]]; then
    FAILURES+=("$(fail_atom "crest_v13.phase_owner" "phase_owner ($PHASE_OWNER) equals target_agent — agents must not self-drive CREST loops")")
  else
    ((PASSES++))
  fi

  # v1.3c: state_sub_crest fields present if phase is Execute or Verify
  if RESULT=$(check "crest_v13.state_sub_crest" \
    'if .crest_v13.state_sub_crest and (.crest_v13.state_sub_crest | type == "object") then "pass" else "fail" end' \
    "missing state_sub_crest object — CREST v1.3 requires durable phase state"); then
    ((PASSES++))
  else
    FAILURES+=("$RESULT")
  fi

  # v1.3d: if phase=Verify, verdict field must be present (Sage-as-Judge)
  CURRENT_PHASE=$(echo "$JSON_INPUT" | "$JQ" -r '.crest_v13.current_phase // empty' 2>/dev/null)
  if [[ "$CURRENT_PHASE" == "Verify" ]]; then
    if RESULT=$(check "crest_v13.verdict" \
      'if .crest_v13.verdict and (.crest_v13.verdict | type == "string") and (.crest_v13.verdict | IN("pass","fail","needs_human")) then "pass" else "fail" end' \
      "Verify phase requires verdict field (pass/fail/needs_human) — Sage-as-Judge"); then
      ((PASSES++))
    else
      FAILURES+=("$RESULT")
    fi
  fi

  # v1.3e: model must be resolved via model-policy-query.sh v2 (PG-first)
  if [[ -n "$TARGET_AGENT" && -n "$CURRENT_PHASE" ]]; then
    MODEL_QUERY=$(bash "$SCRIPT_DIR/model-policy-query.sh" --agent "$TARGET_AGENT" --phase "$CURRENT_PHASE" 2>/dev/null || echo '{"source":"error"}')
    QUERY_SOURCE=$(echo "$MODEL_QUERY" | "$JQ" -r '.source // "error"' 2>/dev/null)
    if [[ "$QUERY_SOURCE" == "pg" ]]; then
      ((PASSES++))
      if $VERBOSE; then echo "PASS: model resolved via PG (v1.3)" >&2; fi
    elif [[ "$QUERY_SOURCE" == "json" ]]; then
      if $VERBOSE; then echo "WARN: model resolved via JSON fallback (PG unavailable)" >&2; fi
      ((PASSES++))
    else
      FAILURES+=("$(fail_atom "crest_v13.model_routing" "model-policy-query.sh failed for agent=$TARGET_AGENT phase=$CURRENT_PHASE")")
    fi
  fi

fi

# ── Output ───────────────────────────────────────────────────
TOTAL_CHECKS=$((PASSES + ${#FAILURES[@]}))
if [[ ${#FAILURES[@]} -eq 0 ]]; then
  if $VERBOSE; then
    echo "{\"status\":\"ok\",\"checks_passed\":$PASSES,\"checks_total\":$TOTAL_CHECKS}"
  else
    echo '{"status":"ok"}'
  fi
  exit 0
else
  FAIL_JSON=$(printf '%s\n' "${FAILURES[@]}" | "$JQ" -s '.')
  echo "{\"status\":\"fail\",\"checks_passed\":$PASSES,\"checks_total\":$TOTAL_CHECKS,\"failures\":$FAIL_JSON}"
  exit 1
fi
