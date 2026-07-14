#!/bin/bash
# flash-dispatcher.sh — CREST Flash Dispatcher (TKT-0386)
# Handles Level 1 (Yoda→Specialist) and Level 2 (Specialist→Executor) dispatch
# using deepseek-v4-flash:cloud with phase-aware model routing.
#
# CREST v1.3: Uses model-policy-query.sh (PG-first) for model resolution.
# Forge exception: Plan/Execute/Synthesize = flash, Verify/Replan = gemma4:31b/deepseek-pro.
#
# Commands:
#   flash-dispatcher.sh dispatch     — Dispatch a CREST atom to an executor session
#   flash-dispatcher.sh verify-phase — Trigger Verify phase for a specialist sub-CREST
#   flash-dispatcher.sh escalate     — Escalate a specialist sub-CREST to Yoda (TKT-0387)
#
# Integration points:
#   - Reads:  state_sub_crest (PG), model-policy.json, atom-validate.sh
#   - Writes: state_sub_crest_atoms (PG), state_sub_crest (PG for phase updates)
#
# Author: Forge 🏗️ — TKT-0386 — 2026-06-10

set -euo pipefail

WORKSPACE="/Users/ainchorsoc2a/.openclaw/workspace"
SCRIPTS="$WORKSPACE/scripts"
JQ="${JQ:-$JQ}"
MODEL_POLICY="$WORKSPACE/state/model-policy.json"
DB_WRITE="$SCRIPTS/db-write.sh"
DB_READ="$SCRIPTS/db-read.sh"
ATOM_VALIDATE="$SCRIPTS/atom-validate.sh"
DB="$SCRIPTS/db-raw.sh"
DECISION_SCRIPT="$SCRIPTS/pg-write-decision.sh"

# ─── Colours ──────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# ─── Decision Event Emission (TKT-0390) ────────────────
emit_decision() {
  local kind="$1" entity_id="$2" payload="$3"
  bash "$DECISION_SCRIPT" --actor "flash_dispatcher" --entity-id "$entity_id" --decision-kind "$kind" --payload "$payload" >/dev/null 2>&1 || true
}

# ────────────────────────────────────────────────────────────

die() { echo -e "${RED}FATAL:${NC} $*" >&2; exit 1; }
warn() { echo -e "${YELLOW}WARN:${NC} $*" >&2; }
info() { echo -e "${CYAN}INFO:${NC} $*" >&2; }
ok() { echo -e "${GREEN}OK:${NC} $*" >&2; }

# ─── Usage ────────────────────────────────────────────────────
usage() {
  cat <<'EOF'
flash-dispatcher.sh — CREST Flash Dispatcher (TKT-0386)

USAGE:
  flash-dispatcher.sh dispatch <args>        Dispatch a CREST sub-ticket atom to an executor
  flash-dispatcher.sh verify-phase <args>    Trigger Verify phase for a specialist
  flash-dispatcher.sh ensure-sub-crest <args> Ensure sub-CREST row exists
  flash-dispatcher.sh escalate <args>        Escalate a specialist sub-CREST to Yoda

DISPATCH ARGS:
  --sub-crest-id <id>      Sub-CREST UUID or parent_ticket_id (e.g. TKT-0381)
  --specialist <agent>     Specialist agent (forge|atlas|thrawn|spark|lando|monMothma|yoda)
  --atom-index <n>         Atom index (0-based ordinal)
  --phase <phase>          CREST phase (plan|execute|verify|replan|synthesize)
  --verb <verb>            Atom verb (read|write|create|delete|test|...)
  --target <target>        Atom target (file, resource, endpoint)
  --pre-conditions <json>  JSON array of pre-conditions
  --post-conditions <json> JSON array of post-conditions
  --atom-desc <desc>       Human-readable atom description
  --model <model>          Override model (default: auto from crestPhaseModelMap)
  --dry-run                Validate only, don't write to PG or spawn

VERIFY-PHASE ARGS:
  --sub-crest-id <id>      Sub-CREST UUID or parent_ticket_id
  --specialist <agent>     Specialist agent
  --phase <phase>          Current phase (verify|replan)
  --model <model>          Override model (default: auto from crestPhaseModelMap)
  --verdict <pass|fail>    Verify verdict
  --dry-run                Validate only

ENSURE-SUB-CREST ARGS:
  --parent-ticket-id <id>  Parent ticket ID (e.g. TKT-0381)
  --specialist <agent>     Specialist agent
  --phase <phase>          Initial phase (default: sub_crest_planning)
  --model <model>          Initial model

ESCALATE ARGS:
  --sub-crest-id <id>      Sub-CREST UUID or parent_ticket_id (e.g. TKT-0381)
  --specialist <agent>     Specialist agent (forge|atlas|thrawn|spark|lando|monMothma|yoda)
  --source-phase <phase>   Phase at which escalation was triggered (plan|execute|verify|replan|synthesize)
  --reason <reason>        Why the escalation is being raised
  --severity <level>       Severity: low|medium|high|critical
  --remedy <suggestion>    Proposed remedy or next step
  --dry-run                Validate only, don't write to PG

EOF
  exit 0
}

# ─── Run PG query via db.sh ───────────────────────────────────
pg_query() {
  bash "$DB" -c "$1" 2>&1 || true
}

pg_query_scalar() {
  # Returns the first column of the first row, trimmed
  local result
  result=$(bash "$DB" -t -A -c "$1" 2>/dev/null || true)
  echo "$result" | head -1 | tr -d '[:space:]'
}

# ─── Model Resolution ─────────────────────────────────────────
resolve_model() {
  local specialist="$1" phase="$2" override="$3"

  if [[ -n "$override" ]]; then
    echo "$override"
    return 0
  fi

  local phase_key="$phase"

  local tier
  tier=$("$JQ" -r --arg agent "$specialist" --arg ph "$phase_key" \
    '.crestPhaseModelMap.agentPhaseAssignments[$agent][$ph] // empty' \
    "$MODEL_POLICY" 2>/dev/null)

  if [[ -z "$tier" ]]; then
    warn "No phase assignment for specialist=$specialist phase=$phase_key — defaulting to flash"
    tier="flash"
  fi

  local model
  model=$("$JQ" -r --arg tier "$tier" \
    '.crestPhaseModelMap.phaseModels[$tier].primary // empty' \
    "$MODEL_POLICY" 2>/dev/null)

  if [[ -z "$model" ]]; then
    warn "No model for tier=$tier — defaulting to deepseek-v4-flash:cloud"
    model="ollama/deepseek-v4-flash:cloud"
  fi

  echo "$model"
}

# ─── Resolve sub_crest_id UUID from parent_ticket_id + specialist ──
# If parent_ticket_id looks like a UUID (36 chars with dashes), use directly as sub_crest_id.
# Otherwise, look up by parent_ticket_id + specialist, creating if needed.
resolve_sub_crest_uuid() {
  local identifier="$1" specialist="$2"

  # If it's already a UUID, use directly
  if [[ "$identifier" =~ ^[0-9a-fA-F-]{36}$ ]]; then
    echo "$identifier"
    return 0
  fi

  # Look up existing sub_crest by parent_ticket_id + specialist
  local existing
  existing=$(pg_query_scalar "SELECT sub_crest_id FROM state_sub_crest WHERE parent_ticket_id = '$identifier' AND specialist = '$specialist' LIMIT 1")

  if [[ -n "$existing" ]]; then
    echo "$existing"
    return 0
  fi

  # Not found — warn but don't auto-create (caller must use ensure-sub-crest first)
  echo ""
  return 0
}

# ─── Ensure Sub-CREST Row Exists ──────────────────────────────
ensure_sub_crest_row() {
  local parent_ticket_id="$1" specialist="$2" initial_phase="${3:-sub_crest_planning}" initial_model="${4:-}"

  # Resolve model for Plan phase if not provided
  if [[ -z "$initial_model" ]]; then
    initial_model=$(resolve_model "$specialist" "plan" "")
  fi

  # Check if exists
  local existing
  existing=$(pg_query_scalar "SELECT sub_crest_id FROM state_sub_crest WHERE parent_ticket_id = '$parent_ticket_id' AND specialist = '$specialist' LIMIT 1")

  if [[ -n "$existing" ]]; then
    echo "$existing"
    return 0
  fi

  # Validate FK: parent_ticket_id must exist in state_tickets
  local fk_check
  fk_check=$(pg_query_scalar "SELECT id FROM state_tickets WHERE id = '$parent_ticket_id' LIMIT 1")
  if [[ -z "$fk_check" ]]; then
    warn "Parent ticket $parent_ticket_id not found in state_tickets — FK constraint will fail"
    return 1
  fi

  # Create new
  local new_uuid
  new_uuid=$(uuidgen 2>/dev/null || python3 -c "import uuid; print(uuid.uuid4())" 2>/dev/null || echo "")

  if [[ -z "$new_uuid" ]]; then
    die "Cannot generate UUID"
  fi

  local now
  now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  local sql="INSERT INTO state_sub_crest (sub_crest_id, parent_ticket_id, specialist, current_phase, iteration_count, plan_model, verify_verdict, created_at, updated_at) VALUES ('$new_uuid', '$parent_ticket_id', '$specialist', '$initial_phase', 0, '$initial_model', 'pending', '$now', '$now')"

  local result
  result=$(pg_query "$sql" 2>&1) || true

  if [[ "$result" == *"ERROR"* ]]; then
    warn "Sub-CREST row creation failed: $result"
    echo ""
    return 1
  fi

  ok "Sub-CREST created: $new_uuid (parent=$parent_ticket_id, specialist=$specialist, phase=$initial_phase)"
  echo "$new_uuid"
  return 0
}

# ─── Read Sub-CREST Phase from PG ─────────────────────────────
read_sub_crest_phase() {
  local sub_crest_uuid="$1"
  local phase
  phase=$(pg_query_scalar "SELECT current_phase FROM state_sub_crest WHERE sub_crest_id = '$sub_crest_uuid'")

  if [[ -z "$phase" ]]; then
    echo "unknown"
  else
    echo "$phase"
  fi
}

# ─── PG Persistence: Write Atom ───────────────────────────────
persist_atom_to_pg() {
  local sub_crest_uuid="$1" atom_index="$2" verb="$3" target="$4"
  local model="$5" phase="$6" atom_desc="$7"

  local atom_id
  atom_id=$(uuidgen 2>/dev/null || python3 -c "import uuid; print(uuid.uuid4())" 2>/dev/null || echo "")

  if [[ -z "$atom_id" ]]; then
    die "Cannot generate atom UUID"
  fi

  local now
  now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Build rvev_trace as JSON string (single-quoted for SQL)
  local rvev_trace
  rvev_trace=$("$JQ" -n \
    --arg phase "$phase" \
    --arg desc "$atom_desc" \
    '{read: null, validate: null, execute: null, verify: null, phase: $phase, atom_desc: $desc}' | "$JQ" -c .)

  local escaped_trace
  escaped_trace=$(echo "$rvev_trace" | sed "s/'/''/g")

  local sql="INSERT INTO state_sub_crest_atoms (atom_id, sub_crest_id, atom_index, verb, target, model, rvev_trace, status, created_at, updated_at) VALUES ('$atom_id', '$sub_crest_uuid', $atom_index, '${verb//\'/\'\'}', '${target//\'/\'\'}', '${model//\'/\'\'}', '$escaped_trace'::jsonb, 'pending', '$now', '$now') ON CONFLICT (atom_id) DO UPDATE SET atom_index = EXCLUDED.atom_index, verb = EXCLUDED.verb, target = EXCLUDED.target, model = EXCLUDED.model, rvev_trace = EXCLUDED.rvev_trace, status = EXCLUDED.status, updated_at = EXCLUDED.updated_at"

  local result
  result=$(pg_query "$sql" 2>&1) || true

  if [[ "$result" == *"ERROR"* ]]; then
    warn "Atom persistence PG error: $result"
    echo ""
    return 1
  fi

  ok "Atom $atom_id persisted to PG (atom_index=$atom_index)"
  echo "$atom_id"
  return 0
}

# ─── PG Persistence: Update Sub-CREST Phase ───────────────────
update_sub_crest_phase() {
  local sub_crest_uuid="$1" phase="$2" iteration_count="${3:-}"

  local now
  now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  local sql="UPDATE state_sub_crest SET current_phase = '$phase', updated_at = '$now'"
  if [[ -n "$iteration_count" ]]; then
    sql="$sql, iteration_count = $iteration_count"
  fi
  sql="$sql WHERE sub_crest_id = '$sub_crest_uuid'"

  local result
  result=$(pg_query "$sql" 2>&1) || true

  if [[ "$result" != *"ERROR"* ]]; then
    ok "Sub-CREST $sub_crest_uuid phase updated to $phase"
    return 0
  else
    warn "Sub-CREST phase update PG error: $result"
    return 1
  fi
}

# ─── PG Persistence: Update Verify Verdict ────────────────────
update_verify_verdict() {
  local sub_crest_uuid="$1" verdict="$2"

  local now
  now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  local sql="UPDATE state_sub_crest SET verify_verdict = '$verdict', updated_at = '$now' WHERE sub_crest_id = '$sub_crest_uuid'"
  local result
  result=$(pg_query "$sql" 2>&1) || true

  if [[ "$result" != *"ERROR"* ]]; then
    ok "Sub-CREST $sub_crest_uuid verify_verdict set to $verdict"
    return 0
  else
    warn "Verify verdict update PG error: $result"
    return 1
  fi
}

# ═══════════════════════════════════════════════════════════════
# COMMAND: ensure-sub-crest
# ═══════════════════════════════════════════════════════════════
cmd_ensure_sub_crest() {
  local parent_ticket_id="" specialist="" phase="sub_crest_planning" model="" dry_run=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --parent-ticket-id) parent_ticket_id="$2"; shift 2 ;;
      --specialist)       specialist="$2"; shift 2 ;;
      --phase)            phase="$2"; shift 2 ;;
      --model)            model="$2"; shift 2 ;;
      --dry-run)          dry_run=true; shift ;;
      --help)             usage ;;
      *) die "Unknown ensure-sub-crest arg: $1" ;;
    esac
  done

  if [[ -z "$parent_ticket_id" || -z "$specialist" ]]; then
    die "Missing required args. Required: --parent-ticket-id --specialist"
  fi

  if $dry_run; then
    info "DRY-RUN: Would create sub-CREST for $parent_ticket_id / $specialist"
    echo '{"status":"dry_run","parent_ticket_id":"'"$parent_ticket_id"'","specialist":"'"$specialist"'","phase":"'"$phase"'"}'
    return 0
  fi

  local uuid
  uuid=$(ensure_sub_crest_row "$parent_ticket_id" "$specialist" "$phase" "$model")

  if [[ -z "$uuid" ]]; then
    die "Failed to ensure sub-CREST row"
  fi

  echo "{\"status\":\"ok\",\"sub_crest_id\":\"$uuid\",\"parent_ticket_id\":\"$parent_ticket_id\",\"specialist\":\"$specialist\",\"phase\":\"$phase\"}"
  return 0
}

# ═══════════════════════════════════════════════════════════════
# COMMAND: dispatch
# ═══════════════════════════════════════════════════════════════
cmd_dispatch() {
  local sub_crest_id="" specialist="" atom_index="" phase="" verb="" target=""
  local pre_conditions="" post_conditions="" atom_desc="" model="" dry_run=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --sub-crest-id)   sub_crest_id="$2"; shift 2 ;;
      --specialist)     specialist="$2"; shift 2 ;;
      --atom-index)     atom_index="$2"; shift 2 ;;
      --phase)          phase="$2"; shift 2 ;;
      --verb)           verb="$2"; shift 2 ;;
      --target)         target="$2"; shift 2 ;;
      --pre-conditions) pre_conditions="$2"; shift 2 ;;
      --post-conditions) post_conditions="$2"; shift 2 ;;
      --atom-desc)      atom_desc="$2"; shift 2 ;;
      --model)          model="$2"; shift 2 ;;
      --dry-run)        dry_run=true; shift ;;
      --help)           usage ;;
      *) die "Unknown dispatch arg: $1" ;;
    esac
  done

  # Validate required args
  if [[ -z "$sub_crest_id" || -z "$specialist" || -z "$atom_index" || -z "$phase" || -z "$verb" || -z "$target" ]]; then
    die "Missing required args. Required: --sub-crest-id --specialist --atom-index --phase --verb --target"
  fi

  info "DISPATCH: sub_crest=$sub_crest_id specialist=$specialist atom=$atom_index phase=$phase verb=$verb target=$target"

  # Step 1: Resolve sub_crest UUID
  local sub_crest_uuid
  sub_crest_uuid=$(resolve_sub_crest_uuid "$sub_crest_id" "$specialist")

  if [[ -z "$sub_crest_uuid" ]]; then
    if $dry_run; then
      sub_crest_uuid="DRY-RUN-UUID-00000000-0000-0000-0000-000000000000"
      warn "Dry-run: no sub_crest row for $sub_crest_id / $specialist — using fake UUID"
    else
      die "No sub_crest row for $sub_crest_id / $specialist. Run 'ensure-sub-crest' first."
    fi
  fi

  # Step 2: Read current phase
  local current_phase
  current_phase=$(read_sub_crest_phase "$sub_crest_uuid")
  info "Sub-CREST current phase: $current_phase (uuid=$sub_crest_uuid)"

  # Step 3: Resolve model
  local resolved_model
  resolved_model=$(resolve_model "$specialist" "$phase" "$model")
  info "Resolved model: $resolved_model (specialist=$specialist, phase=$phase)"

  # Step 4: Pre-flight atom validation
  local atom_json
  atom_json=$("$JQ" -n \
    --arg verb "$verb" \
    --arg target "$target" \
    --argjson pre_conditions "${pre_conditions:-[]}" \
    --argjson post_conditions "${post_conditions:-[]}" \
    --arg atom "$atom_desc" \
    --arg model "$resolved_model" \
    '{verb: $verb, target: $target, pre_conditions: $pre_conditions, post_conditions: $post_conditions, atom: $atom, model: $model}')

  local validation_result
  if validation_result=$(echo "$atom_json" | bash "$ATOM_VALIDATE" --stdin 2>&1); then
    ok "Atom validation PASSED"
  else
    die "Atom validation FAILED: $validation_result"
  fi

  # Step 5: PG Persistence
  local persisted_atom_id=""
  if $dry_run; then
    info "DRY-RUN: skipping PG persistence"
    persisted_atom_id="DRY-RUN-ATOM-$atom_index"
  else
    persisted_atom_id=$(persist_atom_to_pg "$sub_crest_uuid" "$atom_index" "$verb" "$target" "$resolved_model" "$phase" "$atom_desc")
    if [[ -z "$persisted_atom_id" ]]; then
      die "Failed to persist atom to PG"
    fi

    # Step 6: Update sub-CREST phase if needed
    local pg_phase
    case "$phase" in
      plan)        pg_phase="sub_crest_planning" ;;
      execute)     pg_phase="sub_crest_executing" ;;
      verify)      pg_phase="sub_crest_verifying" ;;
      replan)      pg_phase="sub_crest_replanning" ;;
      synthesize)  pg_phase="sub_crest_synthesizing" ;;
      *)           pg_phase="" ;;
    esac

    if [[ -n "$pg_phase" ]] && [[ "$current_phase" != "$pg_phase" ]]; then
      local _prev_phase_before="$current_phase"
      update_sub_crest_phase "$sub_crest_uuid" "$pg_phase"
      # Emit phase_transition decision event
      emit_decision "phase_transition" "$sub_crest_uuid" \
        '{"inputs":{"sub_crest_id":"'"$sub_crest_id"'","specialist":"'"$specialist"'","previous_phase":"'"$_prev_phase_before"'","new_phase":"'"$pg_phase"'"},"outputs":{"updated":true},"rationale":"Phase transition via dispatch"}'
    fi

    # Emit dispatch decision event (after sessions_spawn decision)
    emit_decision "dispatch" "$sub_crest_uuid" \
      '{"inputs":{"sub_crest_id":"'"$sub_crest_id"'","specialist":"'"$specialist"'","atom_index":'"$atom_index"',"phase":"'"$phase"'","verb":"'"$verb"'","target":"'"$target"'"},"outputs":{"atom_id":"'"${persisted_atom_id:-pending}"'","model":"'"$resolved_model"'"},"rationale":"Atom dispatched to specialist '"$specialist"' for phase '"$phase"'"}'
  fi

  # Step 7 (now Step 9): Emit dispatch JSON
  local dispatch_json
  dispatch_json=$("$JQ" -n \
    --arg sub_crest_id "$sub_crest_id" \
    --arg sub_crest_uuid "$sub_crest_uuid" \
    --arg specialist "$specialist" \
    --argjson atom_index "$atom_index" \
    --arg phase "$phase" \
    --arg verb "$verb" \
    --arg target "$target" \
    --argjson pre_conditions "${pre_conditions:-[]}" \
    --argjson post_conditions "${post_conditions:-[]}" \
    --arg atom_desc "$atom_desc" \
    --arg model "$resolved_model" \
    --arg atom_id "${persisted_atom_id:-pending}" \
    --arg current_phase "$current_phase" \
    --argjson dry_run "$dry_run" \
    '{
      status: "dispatched",
      sub_crest_id: $sub_crest_id,
      sub_crest_uuid: $sub_crest_uuid,
      specialist: $specialist,
      atom: {
        index: $atom_index,
        verb: $verb,
        target: $target,
        description: $atom_desc,
        phase: $phase,
        model: $model,
        atom_id: $atom_id,
        pre_conditions: $pre_conditions,
        post_conditions: $post_conditions
      },
      context: {
        sub_crest_phase: $current_phase,
        dry_run: $dry_run
      },
      timestamp: (now | strftime("%Y-%m-%dT%H:%M:%SZ"))
    }')

  echo "$dispatch_json"
  ok "Dispatch complete: $sub_crest_id atom $atom_index → $resolved_model"
  return 0
}

# ═══════════════════════════════════════════════════════════════
# COMMAND: verify-phase
# ═══════════════════════════════════════════════════════════════
cmd_verify_phase() {
  local sub_crest_id="" specialist="" phase="verify" model="" verdict="" dry_run=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --sub-crest-id)  sub_crest_id="$2"; shift 2 ;;
      --specialist)    specialist="$2"; shift 2 ;;
      --phase)         phase="$2"; shift 2 ;;
      --model)         model="$2"; shift 2 ;;
      --verdict)       verdict="$2"; shift 2 ;;
      --dry-run)       dry_run=true; shift ;;
      --help)          usage ;;
      *) die "Unknown verify-phase arg: $1" ;;
    esac
  done

  if [[ -z "$sub_crest_id" || -z "$specialist" ]]; then
    die "Missing required args. Required: --sub-crest-id --specialist"
  fi

  info "VERIFY-PHASE: sub_crest=$sub_crest_id specialist=$specialist phase=$phase verdict=${verdict:-auto}"

  # Step 1: Resolve sub_crest UUID
  local sub_crest_uuid
  sub_crest_uuid=$(resolve_sub_crest_uuid "$sub_crest_id" "$specialist")

  if [[ -z "$sub_crest_uuid" ]]; then
    if $dry_run; then
      sub_crest_uuid="DRY-RUN-UUID-00000000-0000-0000-0000-000000000000"
    else
      die "No sub_crest row for $sub_crest_id / $specialist"
    fi
  fi

  # Step 2: Read current sub-CREST state
  local current_phase
  current_phase=$(read_sub_crest_phase "$sub_crest_uuid")
  info "Sub-CREST current phase: $current_phase"

  # Step 3: Resolve model (Verify/Replan use gemma4:31b-cloud/deepseek-v4-pro per CREST v1.3 capability matrix)
  local resolved_model
  resolved_model=$(resolve_model "$specialist" "$phase" "$model")
  info "Resolved model: $resolved_model"

  # Step 4: Read all atoms for this sub-CREST
  local atoms_json
  atoms_json=$(pg_query "SELECT jsonb_agg(row_to_json(a) ORDER BY a.atom_index) FROM state_sub_crest_atoms a WHERE a.sub_crest_id = '$sub_crest_uuid'" 2>/dev/null || echo "[]")
  if [[ "$atoms_json" == "null" || -z "$atoms_json" ]]; then
    atoms_json="[]"
  fi

  local atom_count
  atom_count=$(echo "$atoms_json" | "$JQ" 'length // 0' 2>/dev/null || echo 0)

  local completed_count
  completed_count=$(echo "$atoms_json" | "$JQ" '[.[] | select(.status == "completed")] | length' 2>/dev/null || echo 0)

  local failed_count
  failed_count=$(echo "$atoms_json" | "$JQ" '[.[] | select(.status == "failed")] | length' 2>/dev/null || echo 0)

  local pending_count
  pending_count=$(echo "$atoms_json" | "$JQ" '[.[] | select(.status == "pending" or .status == "running")] | length' 2>/dev/null || echo 0)

  info "Atoms: $atom_count total, $completed_count completed, $failed_count failed, $pending_count pending"

  # Step 5: Determine verdict
  local final_verdict="$verdict"
  local next_phase=""

  if [[ -z "$final_verdict" ]]; then
    if [[ "$pending_count" -gt 0 ]]; then
      final_verdict="fail"
      info "Auto-verdict: FAIL — $pending_count atoms still pending"
    elif [[ "$failed_count" -gt 0 ]]; then
      final_verdict="fail"
      info "Auto-verdict: FAIL — $failed_count atoms failed"
    else
      final_verdict="pass"
      info "Auto-verdict: PASS — all $atom_count atoms completed"
    fi
  fi

  # Step 6: Phase transition
  if [[ "$final_verdict" == "pass" ]]; then
    next_phase="sub_crest_synthesizing"
    info "Verdict PASS → advancing to $next_phase"
  else
    next_phase="sub_crest_replanning"
    info "Verdict FAIL → advancing to $next_phase"
  fi

  # Step 7: Persist to PG
  if $dry_run; then
    info "DRY-RUN: skipping PG persistence"
  else
    update_verify_verdict "$sub_crest_uuid" "$final_verdict"
    update_sub_crest_phase "$sub_crest_uuid" "$next_phase"
    # Emit phase_transition decision event
    emit_decision "phase_transition" "$sub_crest_uuid" \
      '{"inputs":{"sub_crest_id":"'"$sub_crest_id"'","specialist":"'"$specialist"'","previous_phase":"'"$current_phase"'","new_phase":"'"$next_phase"'","verdict":"'"$final_verdict"'"},"outputs":{"phase_updated":true},"rationale":"Phase transition via verify-phase verdict='"$final_verdict"'"}'
  fi

  # Step 8: Emit verify JSON
  local verify_json
  verify_json=$("$JQ" -n \
    --arg sub_crest_id "$sub_crest_id" \
    --arg sub_crest_uuid "$sub_crest_uuid" \
    --arg specialist "$specialist" \
    --arg verdict "$final_verdict" \
    --arg next_phase "$next_phase" \
    --arg model "$resolved_model" \
    --argjson atom_count "$atom_count" \
    --argjson completed_count "$completed_count" \
    --argjson failed_count "$failed_count" \
    --argjson pending_count "$pending_count" \
    --argjson dry_run "$dry_run" \
    '{
      status: "verified",
      sub_crest_id: $sub_crest_id,
      sub_crest_uuid: $sub_crest_uuid,
      specialist: $specialist,
      verify: {
        verdict: $verdict,
        next_phase: $next_phase,
        model: $model
      },
      atoms: {
        total: $atom_count,
        completed: $completed_count,
        failed: $failed_count,
        pending: $pending_count
      },
      context: {
        dry_run: $dry_run
      },
      timestamp: (now | strftime("%Y-%m-%dT%H:%M:%SZ"))
    }')

  echo "$verify_json"
  ok "Verify-phase complete: $sub_crest_id verdict=$final_verdict → $next_phase"
  return 0
}

# ═══════════════════════════════════════════════════════════════
# COMMAND: escalate (TKT-0387)
# ═══════════════════════════════════════════════════════════════
cmd_escalate() {
  local sub_crest_id="" specialist="" source_phase="" reason="" severity="medium" remedy="" dry_run=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --sub-crest-id)  sub_crest_id="$2"; shift 2 ;;
      --specialist)    specialist="$2"; shift 2 ;;
      --source-phase)  source_phase="$2"; shift 2 ;;
      --reason)        reason="$2"; shift 2 ;;
      --severity)      severity="$2"; shift 2 ;;
      --remedy)        remedy="$2"; shift 2 ;;
      --dry-run)       dry_run=true; shift ;;
      --help)          usage ;;
      *) die "Unknown escalate arg: $1" ;;
    esac
  done

  if [[ -z "$sub_crest_id" || -z "$specialist" || -z "$source_phase" || -z "$reason" ]]; then
    die "Missing required args. Required: --sub-crest-id --specialist --source-phase --reason"
  fi

  local HANDSHAKE_FILE="$WORKSPACE/state/escalation-handshake.json"
  local ALERT_FILE="$WORKSPACE/state/cron-dead-letter-alert.json"

  info "ESCALATE: sub_crest=$sub_crest_id specialist=$specialist source_phase=$source_phase reason=$reason severity=$severity"

  # Step 1: Resolve sub_crest UUID
  local sub_crest_uuid
  sub_crest_uuid=$(resolve_sub_crest_uuid "$sub_crest_id" "$specialist")

  if [[ -z "$sub_crest_uuid" ]]; then
    if $dry_run; then
      sub_crest_uuid="DRY-RUN-UUID-00000000-0000-0000-0000-000000000000"
      warn "Dry-run: no sub_crest row for $sub_crest_id / $specialist — using fake UUID"
    else
      die "No sub_crest row for $sub_crest_id / $specialist. Run 'ensure-sub-crest' first."
    fi
  fi

  # Step 2: Look up parent_ticket_id from sub-CREST
  local parent_ticket_id=""
  if ! $dry_run; then
    parent_ticket_id=$(pg_query_scalar "SELECT parent_ticket_id FROM state_sub_crest WHERE sub_crest_id = '$sub_crest_uuid'")
  fi

  # Step 3: Resolve the task_queue ID from sub_crest
  # The sub_crest_uuid is the UUID in state_sub_crest, but sc_escalate_task
  # needs the task ID from state_task_queue (which is the specialist's sub-ticket ID).
  local task_queue_id=""
  if ! $dry_run; then
    task_queue_id=$(pg_query_scalar "SELECT id FROM state_task_queue WHERE parent_task_id = '$parent_ticket_id' AND status LIKE 'sub_crest%' ORDER BY updated_at_ts DESC LIMIT 1")
    if [[ -z "$task_queue_id" ]]; then
      warn "No sub_crest task_queue entry found for parent=$parent_ticket_id specialist=$specialist"
      task_queue_id="$sub_crest_uuid"  # fallback: try UUID directly
    fi
  fi

  # Step 4: Call sc_escalate_task via Python
  local now
  now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  local escalate_result=""
  if $dry_run; then
    info "DRY-RUN: skipping PG escalation"
    escalate_result='{"ok": true, "msg": "DRY-RUN: escalation validated — would set sub='$sub_crest_id' to escalated, parent to master_replanning"}'
  else
    export ESC_LIBDIR="$SCRIPTS/lib"
    export ESC_SUB_TASK="$task_queue_id"
    export ESC_REASON="$reason"

    escalate_result=$(python3 <<'PYEOF'
import sys, json, os
sys.path.insert(0, os.environ['ESC_LIBDIR'])
from pg_task_queue import sc_escalate_task

ok, msg = sc_escalate_task(os.environ['ESC_SUB_TASK'], os.environ['ESC_REASON'])
print(json.dumps({'ok': ok, 'msg': msg}))
PYEOF
)
    ok "sc_escalate_task result: $escalate_result"

    # Also write escalation_json to state_sub_crest (for PG audit trail)
    local esc_json_payload
    esc_json_payload=$("$JQ" -n \
      --arg escalated_at "$now" \
      --arg source_agent "$specialist" \
      --arg source_phase "$source_phase" \
      --arg reason "$reason" \
      --arg severity "$severity" \
      --arg remedy "${remedy:-}" \
      '{
        escalated_at: $escalated_at,
        source_agent: $source_agent,
        source_phase: $source_phase,
        reason: $reason,
        severity: $severity,
        proposed_remedy: $remedy,
        resolution: "pending"
      }' | sed "s/'/''/g")
    bash "$DB" -c "UPDATE state_sub_crest SET escalation_json = '$esc_json_payload'::jsonb WHERE sub_crest_id = '$sub_crest_uuid'" 2>/dev/null || true
  fi

  # Step 5: Write escalation-handshake.json

  local handshake_json
  handshake_json=$("$JQ" -n \
    --arg escalated_at "$now" \
    --arg source_agent "$specialist" \
    --arg sub_crest_id "$sub_crest_id" \
    --arg parent_ticket_id "${parent_ticket_id:-N/A}" \
    --arg source_phase "$source_phase" \
    --arg reason "$reason" \
    --arg severity "$severity" \
    --arg remedy "${remedy:-}" \
    '{
      escalated_at: $escalated_at,
      source_agent: $source_agent,
      sub_crest_id: $sub_crest_id,
      parent_ticket_id: $parent_ticket_id,
      source_phase: $source_phase,
      escalation_reason: $reason,
      severity: $severity,
      proposed_remedy: $remedy,
      resolution: "pending",
      resolved_at: null,
      resolved_by: null
    }')

  echo "$handshake_json" > "$HANDSHAKE_FILE"
  ok "Escalation handshake written to $HANDSHAKE_FILE"

  # Step 5: Write alert for Yoda's heartbeat to pick up
  local alert_json
  alert_json=$("$JQ" -n \
    --arg type "escalation" \
    --arg sub_crest_id "$sub_crest_id" \
    --arg specialist "$specialist" \
    --arg source_phase "$source_phase" \
    --arg reason "$reason" \
    --arg severity "$severity" \
    --arg remedy "${remedy:-}" \
    --arg escalated_at "$now" \
    --arg parent_ticket_id "${parent_ticket_id:-N/A}" \
    --argjson dry_run "$dry_run" \
    '{
      alert_type: "escalation",
      severity: $severity,
      sub_crest_id: $sub_crest_id,
      specialist: $specialist,
      source_phase: $source_phase,
      reason: $reason,
      proposed_remedy: $remedy,
      escalated_at: $escalated_at,
      parent_ticket_id: $parent_ticket_id,
      dry_run: $dry_run
    }')

  # Append to dead-letter-alert.json (create if not exists)
  if [[ -f "$ALERT_FILE" ]]; then
    # Append to existing array
    local existing_alerts
    existing_alerts=$("$JQ" -c '. // []' "$ALERT_FILE" 2>/dev/null || echo '[]')
    local updated_alerts
    updated_alerts=$(echo "$existing_alerts" | "$JQ" -c --argjson new "$alert_json" '. + [$new]' 2>/dev/null || echo "[$alert_json]")
    echo "$updated_alerts" > "$ALERT_FILE"
  else
    echo "[$alert_json]" > "$ALERT_FILE"
  fi
  ok "Escalation alert written to $ALERT_FILE (Yoda heartbeat will pick up)"

  # Step 6: Emit result JSON
  local result_json
  local escalate_ok
  escalate_ok=$(echo "$escalate_result" | "$JQ" -r '.ok // false' 2>/dev/null || echo "dry_run")

  result_json=$("$JQ" -n \
    --arg status "escalated" \
    --arg sub_crest_id "$sub_crest_id" \
    --arg specialist "$specialist" \
    --arg source_phase "$source_phase" \
    --arg reason "$reason" \
    --arg severity "$severity" \
    --arg remedy "${remedy:-}" \
    --arg escalated_at "$now" \
    --arg pg_result "$escalate_ok" \
    --argjson dry_run "$dry_run" \
    '{
      status: "escalated",
      sub_crest_id: $sub_crest_id,
      specialist: $specialist,
      escalation: {
        source_phase: $source_phase,
        reason: $reason,
        severity: $severity,
        proposed_remedy: $remedy,
        escalated_at: $escalated_at
      },
      pg_escalate: $pg_result,
      handshake_file: "/Users/ainchorsoc2a/.openclaw/workspace/state/escalation-handshake.json",
      alert_file: "/Users/ainchorsoc2a/.openclaw/workspace/state/cron-dead-letter-alert.json",
      dry_run: $dry_run
    }')

  echo "$result_json"
  ok "Escalate complete: $sub_crest_id escalated to Yoda (severity=$severity)"
  return 0
}

# ═══════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════
case "${1:-help}" in
  dispatch)
    shift
    cmd_dispatch "$@"
    ;;
  verify-phase)
    shift
    cmd_verify_phase "$@"
    ;;
  ensure-sub-crest)
    shift
    cmd_ensure_sub_crest "$@"
    ;;
  escalate)
    shift
    cmd_escalate "$@"
    ;;
  help|--help|-h)
    usage
    ;;
  *)
    echo "Unknown command: ${1:-none}" >&2
    usage
    ;;
esac
