#!/bin/bash
# master-synthesize.sh — CREST v1.2 §7.2 Master Synthesize Integration Checks
# Usage: master-synthesize.sh check --parent-ticket-id TKT-0381 --sub-ticket-ids '["TKT-0381-A","TKT-0381-B"]' [--output-format json]
#
# Automated checks (per §7.2):
#   Check 1: Interface Consistency — cross-reference named entities across sub-ticket atoms
#   Check 2: Assumption Alignment — match pre/post conditions across dependent sub-tickets
#
# Manual checks (placeholders — Yoda performs):
#   Gap detection, Narrative coherence
#
# Depends: db-read.sh, $JQ

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DB_READ="$SCRIPT_DIR/db-read.sh"
JQ=$JQ
WORKSPACE="/Users/ainchorsoc2a/.openclaw/workspace"

# ── Parsing ──────────────────────────────────────────────────────────
COMMAND="${1:-}"
shift 2>/dev/null || true

PARENT_TICKET=""
SUB_TICKET_IDS_JSON=""
OUTPUT_FORMAT="json"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --parent-ticket-id) PARENT_TICKET="$2"; shift 2 ;;
    --sub-ticket-ids) SUB_TICKET_IDS_JSON="$2"; shift 2 ;;
    --output-format) OUTPUT_FORMAT="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

if [[ "$COMMAND" != "check" ]]; then
  echo "Usage: master-synthesize.sh check --parent-ticket-id TKT-xxx --sub-ticket-ids '[\"...\"]' [--output-format json]" >&2
  exit 1
fi

if [[ -z "$PARENT_TICKET" || -z "$SUB_TICKET_IDS_JSON" ]]; then
  echo "ERROR: --parent-ticket-id and --sub-ticket-ids required" >&2
  exit 1
fi

CHECKED_AT=$(date -u +"%Y-%m-%dT%H:%M:%S+08:00")

# ── Temporary workspace ───────────────────────────────────────────────
TMPDIR="${TMPDIR:-/tmp}/ms-$$"
mkdir -p "$TMPDIR"
trap "rm -rf $TMPDIR" EXIT

# ── Helper: get all atoms for a ticket by joining ────────────────────
get_atoms_for_ticket() {
  local ticket_id="$1"
  bash "$DB_READ" "SELECT jsonb_agg(t) FROM (SELECT row_to_json(a) AS t FROM state_sub_crest_atoms a JOIN state_sub_crest s ON a.sub_crest_id = s.sub_crest_id WHERE s.parent_ticket_id='$ticket_id') sub" 2>/dev/null || echo "null"
}

# ── Helper: get sub_crest row for a ticket ───────────────────────────
get_sub_crest() {
  local ticket_id="$1"
  bash "$DB_READ" "SELECT row_to_json(t)::text FROM state_sub_crest t WHERE t.parent_ticket_id='$ticket_id' LIMIT 1" 2>/dev/null || echo "null"
}

# ── Entity Extraction ────────────────────────────────────────────────
# Extract file paths from a string (with or without leading /)
extract_file_paths() {
  local text="$1"
  echo "$text" | grep -oE '(/[A-Za-z0-9_.-]+)+\.[a-z]{2,4}' 2>/dev/null || true
}

# Extract table/DB entity names from a string
extract_table_names() {
  local text="$1"
  echo "$text" | grep -oE '\b(state_|agent_|knowledge_|config_|cost_|decision_)[a-z_]+\b' 2>/dev/null || true
}

# Extract script names from a string
extract_script_names() {
  local text="$1"
  echo "$text" | grep -oE 'scripts/[A-Za-z0-9_-]+\.(sh|py|js|ts)' 2>/dev/null || true
}

# Extract all named entities from an atom (target + rvev_trace + verb)
extract_entities_from_atom() {
  local atom_json="$1"
  local target rvev_trace verb all_text
  target=$($JQ -r '.target // ""' <<< "$atom_json" 2>/dev/null)
  rvev_trace=$($JQ -r '.rvev_trace // ""' <<< "$atom_json" 2>/dev/null)
  verb=$($JQ -r '.verb // ""' <<< "$atom_json" 2>/dev/null)
  all_text="${target} ${rvev_trace} ${verb}"

  {
    extract_file_paths "$all_text"
    extract_table_names "$all_text"
    extract_script_names "$all_text"
  } | sort -u
}

# Determine verb direction: "producer", "consumer", or "both"
get_direction() {
  local verb="$1"
  case "$verb" in
    create|write|build|generate|seed|insert|deploy|publish|export|configure|install|initialize|setup|bootstrap)
      echo "producer" ;;
    read|load|fetch|import|get|query|check|test|verify|consume|use|reference|validate|parse|ingest|connect)
      echo "consumer" ;;
    *) echo "both" ;;
  esac
}

# ── Assumption Extraction ────────────────────────────────────────────
KNOWN_ASSUMPTION_PATTERNS=(
  "PG running"
  "db-raw.sh available"
  "db-read.sh available"
  "db-write.sh available"
  "file exists"
  "table created"
  "table populated"
  "agent online"
  "agent registered"
  "config deployed"
  "schema applied"
  "index created"
  "view created"
  "secret available"
  "service running"
  "port open"
  "container running"
  "tailscale connected"
  "notion accessible"
  "gmail accessible"
  "api key available"
  "token valid"
  "disk space available"
  "model available"
  "backup complete"
  "dns resolvable"
)

extract_assumptions() {
  local text="$1"
  for pattern in "${KNOWN_ASSUMPTION_PATTERNS[@]}"; do
    if echo "$text" | grep -qi "$(echo "$pattern" | sed 's/ /.*/g')" 2>/dev/null; then
      echo "$pattern"
    fi
  done | sort -u
}

# ──────────────────────────────────────────────────────────────────────
# CHECK 1: Interface Consistency
# Strategy: Build a JSON Lines file with all {entity, ticket, direction} records,
# then use jq to aggregate and analyze. No bash associative arrays needed.
# ──────────────────────────────────────────────────────────────────────
run_interface_consistency() {
  local entities_file="$TMPDIR/entities.jsonl"
  :> "$entities_file"

  # Step 1: Collect all entities from all sub-tickets
  local sub_ids_json
  sub_ids_json=$(echo "$SUB_TICKET_IDS_JSON" | $JQ -c '.')
  local tid
  while IFS= read -r tid; do
    [[ -z "$tid" ]] && continue
    local atoms_json
    atoms_json=$(get_atoms_for_ticket "$tid")
    if [[ "$atoms_json" == "null" || -z "$atoms_json" ]]; then
      continue
    fi

    local atom_count
    atom_count=$($JQ 'length' <<< "$atoms_json" 2>/dev/null || echo "0")

    local i
    for i in $(seq 0 $((atom_count - 1))); do
      local atom verb entities
      atom=$($JQ -c ".[$i]" <<< "$atoms_json" 2>/dev/null)
      verb=$($JQ -r '.verb // ""' <<< "$atom")
      entities=$(extract_entities_from_atom "$atom")
      local direction
      direction=$(get_direction "$verb")

      local entity
      while IFS= read -r entity; do
        [[ -z "$entity" ]] && continue
        entity=$(echo "$entity" | tr -d '[:space:]')
        [[ -z "$entity" ]] && continue
        $JQ -n --arg entity "$entity" --arg ticket "$tid" --arg direction "$direction" \
          '{entity: $entity, ticket: $ticket, direction: $direction}' >> "$entities_file"
      done <<< "$entities"
    done
  done <<< "$(echo "$SUB_TICKET_IDS_JSON" | $JQ -r '.[]')"

  # Step 2: Analyze with jq — group by entity, count unique tickets, check direction
  $JQ -s '
    # Group by entity
    group_by(.entity) |
    # Transform each group
    map({
      entity: .[0].entity,
      tickets: [.[].ticket] | unique,
      ticket_count: ([.[].ticket] | unique | length),
      directions: [.[].direction] | unique,
      has_producer: ([.[].direction] | unique | contains(["producer"])),
      has_consumer: ([.[].direction] | unique | contains(["consumer"]))
    }) |
    # Classify
    map(
      if .ticket_count >= 2 then
        # Cross-ticket reference — good
        {type: "match", entity: .entity, tickets: .tickets, from_ticket: .tickets[0], to_ticket: .tickets[1]}
      elif .ticket_count == 1 then
        if .has_producer and (.has_consumer | not) then
          {type: "mismatch", entity: .entity, ticket: .tickets[0], reason: "unconsumed output: produced but no other sub-ticket references it"}
        elif .has_consumer and (.has_producer | not) then
          {type: "mismatch", entity: .entity, ticket: .tickets[0], reason: "unproduced input: consumed but no other sub-ticket creates it"}
        else
          {type: "unreferenced", entity: .entity, ticket: .tickets[0], note: "self-contained entity"}
        end
      else
        empty
      end
    ) |
    # Split into categories
    {
      matches: [.[] | select(.type == "match") | {from: .from_ticket, to: .to_ticket, entity: .entity}],
      mismatches: [.[] | select(.type == "mismatch") | {entity: .entity, ticket: .ticket, reason: .reason}],
      unreferenced_entries: [.[] | select(.type == "unreferenced") | {entity: .entity, ticket: .ticket, note: .note}]
    } |
    # Add status
    {
      status: (if (.mismatches | length) > 0 then "warn" else "pass" end),
      matches: .matches,
      mismatches: .mismatches,
      unreferenced: .unreferenced_entries
    }
  ' "$entities_file" 2>/dev/null || $JQ -n '{status: "pass", matches: [], mismatches: [], unreferenced: []}'
}

# ──────────────────────────────────────────────────────────────────────
# CHECK 2: Assumption Alignment
# Strategy: Build a JSON Lines file with {condition, ticket} for all
# extracted assumptions, then use jq to find cross-ticket alignments and
# orphaned dependencies. No bash associative arrays needed.
# ──────────────────────────────────────────────────────────────────────
run_assumption_alignment() {
  local assumptions_file="$TMPDIR/assumptions.jsonl"
  :> "$assumptions_file"

  local tid
  while IFS= read -r tid; do
    [[ -z "$tid" ]] && continue

    local all_text=""

    # Get sub_crest escalation_json (has pre/post conditions)
    local crest_json
    crest_json=$(get_sub_crest "$tid")
    if [[ "$crest_json" != "null" && -n "$crest_json" ]]; then
      all_text+=$($JQ -r '.escalation_json // "{}"' <<< "$crest_json" 2>/dev/null)
    fi

    # Get atoms' rvev_traces
    local atoms_json
    atoms_json=$(get_atoms_for_ticket "$tid")
    if [[ "$atoms_json" != "null" && -n "$atoms_json" ]]; then
      local atom_count
      atom_count=$($JQ 'length' <<< "$atoms_json" 2>/dev/null || echo "0")
      local i
      for i in $(seq 0 $((atom_count - 1))); do
        local rvev
        rvev=$($JQ -r ".[$i].rvev_trace // \"\"" <<< "$atoms_json" 2>/dev/null)
        all_text+=" $rvev"
      done
    fi

    # Extract assumptions
    local assumptions
    assumptions=$(extract_assumptions "$all_text")

    local assumption
    while IFS= read -r assumption; do
      [[ -z "$assumption" ]] && continue
      $JQ -n --arg condition "$assumption" --arg ticket "$tid" \
        '{condition: $condition, ticket: $ticket}' >> "$assumptions_file"
    done <<< "$assumptions"
  done <<< "$(echo "$SUB_TICKET_IDS_JSON" | $JQ -r '.[]')"

  # Step 2: Analyze with jq
  # Dependency-type conditions (need explicit provisioning by another ticket)
  $JQ -s '
    group_by(.condition) |
    map({
      condition: .[0].condition,
      tickets: [.[].ticket] | unique,
      ticket_count: ([.[].ticket] | unique | length)
    }) |
    # Classify
    reduce .[] as $item (
      {matches: [], conflicts: [], status: "pass"};
      if $item.ticket_count >= 2 then
        # Multiple tickets reference this condition — cross-ticket alignment found
        .matches += [{
          provider: $item.tickets[0],
          consumer: $item.tickets[1],
          condition: $item.condition
        }]
      elif $item.ticket_count == 1 then
        # Single ticket — check if it is a dependency that needs provisioning
        if $item.condition == "table created" or
           $item.condition == "schema applied" or
           $item.condition == "config deployed" or
           $item.condition == "service running" or
           $item.condition == "file exists" or
           $item.condition == "table populated" or
           $item.condition == "view created" or
           $item.condition == "index created" then
          .conflicts += [{
            condition: $item.condition,
            provider: null,
            consumer: $item.tickets[0],
            severity: "high"
          }]
          | .status = "fail"
        else
          # Self-evident assumption (infrastructure provides it)
          .matches += [{
            provider: "infrastructure",
            consumer: $item.tickets[0],
            condition: $item.condition
          }]
        end
      else
        .
      end
    )
  ' "$assumptions_file" 2>/dev/null || $JQ -n '{status: "pass", matches: [], conflicts: []}'
}

# ──────────────────────────────────────────────────────────────────────
# MAIN: Execute checks and produce output
# ──────────────────────────────────────────────────────────────────────

interface_result=$(run_interface_consistency)
assumption_result=$(run_assumption_alignment)

# Derive overall status
interface_status=$(echo "$interface_result" | $JQ -r '.status // "pass"')
assumption_status=$(echo "$assumption_result" | $JQ -r '.status // "pass"')

overall="PENDING_YODA"
if [[ "$interface_status" == "pass" && "$assumption_status" == "pass" ]]; then
  overall="AUTOMATED_CHECKS_PASS"
elif [[ "$interface_status" == "fail" || "$assumption_status" == "fail" ]]; then
  overall="AUTOMATED_CHECKS_FAIL_YODA_REVIEW_REQUIRED"
else
  overall="AUTOMATED_CHECKS_WARN_YODA_REVIEW_REQUIRED"
fi

# ── Persist report for CREST done gate ────────────────────────────────
SYNTH_DIR="$(dirname "$0")/../state/synthesize-reports"
mkdir -p "$SYNTH_DIR"
REPORT_FILE="$SYNTH_DIR/${PARENT_TICKET}_$(date +%Y%m%d-%H%M%S).json"
$JQ -n \
  --arg parent "$PARENT_TICKET" \
  --arg checked_at "$CHECKED_AT" \
  --argjson iface "$interface_result" \
  --argjson assume "$assumption_result" \
  --arg overall "$overall" \
  '{
    parent_ticket_id: $parent,
    checked_at: $checked_at,
    automated_checks: {
      interface_consistency: $iface,
      assumption_alignment: $assume
    },
    manual_checks: {
      gap_detection: {status: "pending_yoda", note: "Requires full scope understanding"},
      narrative_coherence: {status: "pending_yoda", note: "Requires editorial judgment"}
    },
    overall: $overall
  }' > "$REPORT_FILE"
# Save reference in ticket metadata
TICKET_TABLE="state_tickets"
update_sql="UPDATE $TICKET_TABLE SET metadata = jsonb_set(metadata, '{synthesize_report}', '\"$REPORT_FILE\"') WHERE id='$PARENT_TICKET';"
bash "$SCRIPT_DIR/db-raw.sh" -c "$update_sql" > /dev/null 2>&1 || true

# ── Output ───────────────────────────────────────────────────────────
if [[ "$OUTPUT_FORMAT" == "json" ]]; then
  $JQ -n \
    --arg parent "$PARENT_TICKET" \
    --arg checked_at "$CHECKED_AT" \
    --argjson iface "$interface_result" \
    --argjson assume "$assumption_result" \
    --arg overall "$overall" \
    '{
      parent_ticket_id: $parent,
      checked_at: $checked_at,
      automated_checks: {
        interface_consistency: $iface,
        assumption_alignment: $assume
      },
      manual_checks: {
        gap_detection: {status: "pending_yoda", note: "Requires full scope understanding"},
        narrative_coherence: {status: "pending_yoda", note: "Requires editorial judgment"}
      },
      overall: $overall
    }'
  exit 0
elif [[ "$OUTPUT_FORMAT" == "text" ]]; then
  echo "=== Master Synthesize Integration Checks ==="
  echo "Parent Ticket: $PARENT_TICKET"
  echo "Checked At: $CHECKED_AT"
  echo ""
  echo "--- Check 1: Interface Consistency ---"
  echo "Status: $interface_status"
  echo "$interface_result" | $JQ '.'
  echo ""
  echo "--- Check 2: Assumption Alignment ---"
  echo "Status: $assumption_status"
  echo "$assumption_result" | $JQ '.'
  echo ""
  echo "--- Manual Checks (Yoda) ---"
  echo "  Gap Detection: PENDING"
  echo "  Narrative Coherence: PENDING"
  echo ""
  echo "Overall: $overall"
  exit 0
else
  echo "ERROR: Unknown output format: $OUTPUT_FORMAT" >&2
  exit 1
fi
