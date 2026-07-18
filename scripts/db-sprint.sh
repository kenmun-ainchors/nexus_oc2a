#!/bin/bash
# db-sprint.sh - Sprint Operations PG-First (TKT-0369-B, TKT-0725-A6)
# Author: Forge (Infrastructure & SRE Agent)
# Created: 2026-06-10
# Updated: 2026-06-22 — TKT-0725 A6: use sprint_id FK joins instead of text matching
#
# SKILL GATE: pg-sprint-backlog skill MUST be loaded before use.
source "${SCRIPT_DIR:-$(dirname "$0")}/skill-gate.sh" "pg-sprint-backlog" || exit $?

# TKT-0720: Source entity_links helper for live-write hooks
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/db-link.sh"
#
# Subcommands:
#   current                        - Current sprint as JSON from PG
#   commit <TKT-ID> <seq> <effort> <agent> [--sprint <name>] - Commit ticket to sprint in PG
#   status [--sprint Sprint7]      - Sprint progress with dependency graph
#   plan [--sprint Sprint7]        - Sprint planning view
#   create "<Sprint X>" "<dates>"  - Create a new sprint in PG
#   defer <TKT-ID> --to <Sprint X> --reason "..." - Defer ticket to another sprint
#   migrate [--sprint Sprint7]     - Migrate sprint JSON data to PG
#   ceremony complete <review|planning> [--sprint Sprint7] - Log ceremony completion to PG

set -u

# --- CONSTANTS ---
WORKSPACE_ROOT="/Users/ainchorsoc2a/.openclaw/workspace"
DB_SCRIPT="$WORKSPACE_ROOT/scripts/db.sh"
JQ_BIN=$(command -v jq 2>/dev/null || true)
if [[ -z "$JQ_BIN" || ! -x "$JQ_BIN" ]]; then
  JQ_BIN="$(brew --prefix 2>/dev/null)/bin/jq"
fi
JQ="$JQ_BIN"
TICKET_TABLE="state_tickets"
TICKET_SCRIPT="$WORKSPACE_ROOT/scripts/db-ticket.sh"
SPRINT_TABLE="state_sprints"
TICKET_FILE="$WORKSPACE_ROOT/state/tickets.json"
EVENT_SCRIPT="$WORKSPACE_ROOT/scripts/pg-write-event.sh"

# --- EVENT HELPER ---
resolve_actor() {
  local a="${NEXUS_ACTOR:-}"
  if [[ -z "$a" ]]; then
    a="${USER:-}"
  fi
  if [[ -z "$a" ]]; then
    a="system"
  fi
  echo "$a"
}

emit_event() {
  local actor event_type entity_type entity_id payload prev_state new_state
  actor="$1"
  event_type="$2"
  entity_type="$3"
  entity_id="$4"
  payload="$5"
  prev_state="${6:-}"
  new_state="${7:-}"
  local args=(--actor "$actor" --event-type "$event_type" --entity-type "$entity_type" --entity-id "$entity_id" --payload "$payload")
  if [[ -n "$prev_state" ]]; then
    args+=(--prev-state "$prev_state")
  fi
  if [[ -n "$new_state" ]]; then
    args+=(--new-state "$new_state")
  fi
  bash "$EVENT_SCRIPT" "${args[@]}" > /dev/null 2>&1 || log "WARNING: event write failed for ${entity_type}:${entity_id} (${event_type})"
}

# --- UTILITIES ---
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] db-sprint: $1" >&2; }
die() { echo "ERROR: $1" >&2; exit 1; }

usage() {
  cat <<'USAGE'
Usage: db-sprint.sh <subcommand> [args...]

Subcommands:
  current                              - Return current sprint as JSON from PG
  next-ticket [--agent <name>]        - Return next ticket to work as JSON (TKT-0728)
  activate [--dry-run]                 - Transition committed sprints whose start_date <= today to in_progress
  commit <TKT-ID> <seq> <effort> <agent> [--sprint <name>] - Commit ticket to sprint (sets metadata.sprint_target)
  status [--sprint <name>]             - Sprint progress with dependency graph
  plan [--sprint <name>]               - Sprint planning view: all committed items
  create "<Sprint X>" "<dates>"        - Create a new sprint in PG
  defer <TKT-ID> --to <Sprint X> --reason "..." - Defer ticket to another sprint
  migrate [--sprint <name>]            - Migrate sprint JSON → PG metadata
  ceremony complete <review|planning> [--sprint <name>] - Log ceremony to PG + auto-gen sprint-current.json
  complete "<Sprint N>" [--dry-run]    - Mark sprint completed (updates status, logs ceremony, regenerates cache)
  export [--sprint <name>]             - Export read-only JSON summary of sprint (derived from PG)
  help                                 - Show this usage
USAGE
  exit 0
}

# --- PG QUERY HELPERS ---

pg_query() {
  bash "$DB_SCRIPT" -c "$1" 2>/dev/null
}

pg_query_json() {
  bash "$DB_SCRIPT" -c "$1" -t -A 2>/dev/null
}

ticket_exists() {
  local tkt_id="$1"
  local result
  result=$(pg_query "SELECT id FROM $TICKET_TABLE WHERE id='$tkt_id';")
  [[ -n "$result" && "$result" == *"$tkt_id"* ]]
}

get_metadata() {
  local tkt_id="$1"
  local meta
  meta=$(pg_query "SELECT metadata::text FROM $TICKET_TABLE WHERE id='$tkt_id';" 2>/dev/null)
  if [[ -z "$meta" || "$meta" == "null" ]]; then
    echo "{}"
  else
    echo "$meta"
  fi
}

write_metadata() {
  local tkt_id="$1"
  local meta_json="$2"

  if ! echo "$meta_json" | $JQ empty 2>/dev/null; then
    die "Invalid JSON for metadata update"
  fi

  local escaped
  escaped=$(echo "$meta_json" | sed "s/'/''/g")

  pg_query "UPDATE $TICKET_TABLE SET metadata='$escaped'::jsonb, updated_at=NOW() WHERE id='$tkt_id';" > /dev/null 2>&1
  local ret=$?

  if [[ $ret -eq 0 ]]; then
    return 0
  else
    log "PG write failed for $tkt_id metadata update"
    return 1
  fi
}

# Sprint table schema (existing):
# id (uuid), sprint_number (int), sprint_name (text), start_date (date),
# end_date (date), status (text), capacity (int), committed_at (timestamptz),
# committed_by (text), items (jsonb), notes (text), created_at, updated_at, tenant_id

get_current_sprint_name() {
  # Find current sprint using the following precedence:
  # 1. Sprint with status='in_progress' (canonical active state)
  # 2. Sprint whose date window contains today (start_date <= today <= end_date)
  # 3. Next upcoming committed/planning sprint by start_date
  # 4. Most recent sprint by start_date
  # 5. Most common sprint_target in open tickets
  # 6. Hard fallback: Sprint 7
  #
  # TKT-0728: Added date-window awareness (step 2) before falling through to
  # "next committed by start_date". This ensures a committed sprint whose date
  # window contains today is correctly identified as the current sprint.
  local name
  # 1. Active sprint takes precedence (exclude Unassigned sentinel).
  name=$(pg_query "SELECT sprint_name FROM $SPRINT_TABLE WHERE (status='in_progress' OR status='active') AND sprint_number > 0 ORDER BY sprint_number DESC LIMIT 1;" 2>/dev/null | head -1)
  if [[ -z "$name" ]]; then
    # 2. Date-window match: any sprint whose start_date <= today AND end_date >= today.
    #    This catches committed sprints that are currently in their execution window.
    name=$(pg_query "SELECT sprint_name FROM $SPRINT_TABLE WHERE start_date <= CURRENT_DATE AND end_date >= CURRENT_DATE AND sprint_number > 0 ORDER BY sprint_number DESC LIMIT 1;" 2>/dev/null | head -1)
  fi
  if [[ -z "$name" ]]; then
    # 3. Next upcoming committed/planning sprint by start_date (not highest number).
    #    This supports sequenced multi-sprint plans where Sprints 9-11 are all committed.
    name=$(pg_query "SELECT sprint_name FROM $SPRINT_TABLE WHERE status IN ('committed','planning') AND start_date >= CURRENT_DATE ORDER BY start_date ASC LIMIT 1;" 2>/dev/null | head -1)
  fi
  if [[ -z "$name" ]]; then
    # 4. If every sprint is in the past, fall back to the latest one.
    name=$(pg_query "SELECT sprint_name FROM $SPRINT_TABLE ORDER BY start_date DESC NULLS LAST LIMIT 1;" 2>/dev/null | head -1)
  fi
  if [[ -z "$name" ]]; then
    # 5. Most common sprint_target in open tickets.
    name=$(pg_query "SELECT metadata->>'sprint_target' FROM $TICKET_TABLE WHERE status IN ('open','in-progress','pending','backlog','grooming') AND metadata->>'sprint_target' IS NOT NULL GROUP BY metadata->>'sprint_target' ORDER BY COUNT(*) DESC LIMIT 1;" 2>/dev/null | head -1)
  fi
  # Normalize: extract just "Sprint N" from potentially longer names like "Sprint 7 - ..."
  if [[ -n "$name" ]]; then
    name=$(echo "$name" | grep -oEi '[Ss][Pp][Rr][Ii][Nn][Tt][[:space:]]*[0-9]+' | head -1)
    [[ -z "$name" ]] && echo "Sprint 7" || echo "$name"
  else
    echo "Sprint 7"
  fi
}

sprint_name_to_number() {
  # "Sprint 7" → "7", "Sprint7" → "7", "Sprint 8" → "8"
  local name="$1"
  echo "$name" | sed 's/[Ss][Pp][Rr][Ii][Nn][Tt][[:space:]]*//' | grep -oE '[0-9]+'
}

# ──────────────────────────────────────────────
# SUBCOMMAND: current
# ──────────────────────────────────────────────
cmd_current() {
  local sprint_name
  sprint_name=$(get_current_sprint_name)
  local sprint_num
  sprint_num=$(sprint_name_to_number "$sprint_name")

  log "Current sprint: $sprint_name (number: $sprint_num)"

  # Get sprint row from PG - try exact name match, then prefix match
  local sprint_json
  sprint_json=$(pg_query "SELECT row_to_json(s)::text FROM $SPRINT_TABLE s WHERE sprint_number=$sprint_num ORDER BY updated_at DESC LIMIT 1;" 2>/dev/null)

  if [[ -z "$sprint_json" || "$sprint_json" == "null" ]]; then
    # Fallback: build from JSON file
    local json_file="$WORKSPACE_ROOT/state/sprint-${sprint_num}.json"
    if [[ -f "$json_file" ]]; then
      log "No PG sprint row for $sprint_name, falling back to $json_file"
      cat "$json_file"
    else
      log "No PG sprint row or JSON file for $sprint_name"
      echo "{}"
    fi
    return 0
  fi

  # Get ticket counts for this sprint via sprint_id FK join (TKT-0725-A6)
  local ticket_count
  ticket_count=$(pg_query "SELECT COUNT(*) FROM $TICKET_TABLE WHERE sprint_id = (SELECT id FROM $SPRINT_TABLE WHERE sprint_number=$sprint_num ORDER BY updated_at DESC LIMIT 1);" 2>/dev/null | head -1)
  local done_count
  done_count=$(pg_query "SELECT COUNT(*) FROM $TICKET_TABLE WHERE sprint_id = (SELECT id FROM $SPRINT_TABLE WHERE sprint_number=$sprint_num ORDER BY updated_at DESC LIMIT 1) AND status IN ('closed','done','folded');" 2>/dev/null | head -1)

  # Merge counts into sprint JSON
  echo "$sprint_json" | $JQ \
    --arg ticket_count "${ticket_count:-0}" \
    --arg done_count "${done_count:-0}" \
    --arg sprint_name "$sprint_name" \
    '. + {
      sprint_name: $sprint_name,
      ticket_count: ($ticket_count | tonumber),
      done_count: ($done_count | tonumber)
    }' 2>/dev/null

}

# ──────────────────────────────────────────────
# SUBCOMMAND: commit <TKT-ID> <seq> <effort> <agent>
# ──────────────────────────────────────────────
cmd_commit() {
  local tkt_id=""
  local seq=""
  local effort=""
  local agent=""
  local sprint_override=""

  # Parse flags first, then positional args
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --sprint)
        sprint_override="$2"
        shift 2
        ;;
      --*)
        die "ERROR: db-sprint.sh commit unknown flag: $1. Use --sprint <name> for target sprint."
        ;;
      *)
        # Positional args consumed in order
        if [[ -z "$tkt_id" ]]; then
          tkt_id="$1"
        elif [[ -z "$seq" ]]; then
          seq="$1"
        elif [[ -z "$effort" ]]; then
          effort="$1"
        elif [[ -z "$agent" ]]; then
          agent="$1"
        fi
        shift
        ;;
    esac
  done

  if [[ -z "$tkt_id" || -z "$seq" ]]; then
    die "Usage: db-sprint.sh commit <TKT-ID> <seq> [effort] [agent] [--sprint <name>]"
  fi

  if ! ticket_exists "$tkt_id"; then
    die "Ticket $tkt_id not found in PG"
  fi

  local sprint_name
  if [[ -n "$sprint_override" ]]; then
    sprint_name="$sprint_override"
    log "Using sprint override: $sprint_name"
  else
    sprint_name=$(get_current_sprint_name)
    log "Using active sprint: $sprint_name"
  fi

  # Resolve sprint_num immediately (TKT-0726-A6: must be before any $sprint_num usage)
  local sprint_num
  sprint_num=$(sprint_name_to_number "$sprint_name")

  # Get sprint_id for the target sprint (TKT-0725-A6)
  local sprint_id
  sprint_id=$(pg_query "SELECT id FROM $SPRINT_TABLE WHERE sprint_number=$sprint_num ORDER BY updated_at DESC LIMIT 1;" 2>/dev/null | head -1)
  if [[ -z "$sprint_id" || "$sprint_id" == "null" ]]; then
    die "Sprint $sprint_name not found in state_sprints (no sprint_id)"
  fi

  log "Committing $tkt_id to $sprint_name (sprint_id=$sprint_id, seq=$seq, effort=$effort, agent=$agent)"

  # Get current metadata
  local current_meta
  current_meta=$(get_metadata "$tkt_id")

  # Update sprint metadata fields
  local updated_meta
  updated_meta=$(echo "$current_meta" | $JQ \
    --arg sprint "$sprint_name" \
    --arg seq "$seq" \
    --arg effort "$effort" \
    --arg agent "$agent" \
    --arg ts "$(date -u '+%Y-%m-%dT%H:%M:%S+08:00')" \
    '. + {
      sprint_target: $sprint,
      sprint_seq: ($seq | tonumber),
      sprint_effort: $effort,
      sprint_agent: $agent,
      sprint_committed_at: $ts
    }' 2>/dev/null)

  write_metadata "$tkt_id" "$updated_meta"

  # Also populate the proper sprint columns (TKT-0391, TKT-0725-A6: use sprint_id FK)
  pg_query "UPDATE $TICKET_TABLE SET sprint='$sprint_name', sprint_id='$sprint_id', sprint_seq=$seq, updated_at=NOW() WHERE id='$tkt_id';" > /dev/null 2>&1 || true

  # Also update state_sprints.items if sprint row exists
  local items_json
  items_json=$(pg_query "SELECT items::text FROM $SPRINT_TABLE WHERE sprint_number=$sprint_num ORDER BY updated_at DESC LIMIT 1;" 2>/dev/null)

  if [[ -n "$items_json" && "$items_json" != "null" ]]; then
    local new_item
    new_item=$($JQ -n \
      --arg tkt_id "$tkt_id" \
      --arg seq "$seq" \
      --arg effort "$effort" \
      --arg agent "$agent" \
      '{
        tkt: $tkt_id,
        seq: ($seq | tonumber),
        effort: $effort,
        agent: $agent,
        committed_at: now
      }')

    local updated_items
    updated_items=$(echo "$items_json" | $JQ --argjson item "$new_item" '
      . as $items |
      ($items | map(select(.tkt == $item.tkt)) | length) as $existing |
      if $existing > 0 then
        $items | map(if .tkt == $item.tkt then $item else . end)
      else
        $items + [$item]
      end
    ' 2>/dev/null)

    if [[ -n "$updated_items" ]]; then
      local escaped_items
      escaped_items=$(echo "$updated_items" | sed "s/'/''/g")
      pg_query "UPDATE $SPRINT_TABLE SET items='$escaped_items'::jsonb, updated_at=NOW() WHERE sprint_number=$sprint_num;" > /dev/null 2>&1
    fi
  fi

  log "✓ $tkt_id committed to $sprint_name (seq $seq)"
    # TKT-0726: Emit committed event for sprint (best-effort)
    local actor
    actor=$(resolve_actor)
    local commit_payload
    commit_payload=$($JQ -n --arg tkt "$tkt_id" --arg sprint "$sprint_name" --arg seq "$seq" --arg effort "$effort" --arg agent "$agent" '{ticket: $tkt, sprint: $sprint, seq: ($seq | tonumber), effort: $effort, agent: $agent}' 2>/dev/null || echo '{"ticket":"'"$tkt_id"'"}')
    emit_event "$actor" "committed" "sprint" "$sprint_id" "$commit_payload"
    # TKT-0720: Insert entity_links edge from sprint to committed ticket (best-effort)
    insert_entity_links "sprint" "$sprint_num" "relates-to" "live-write:sprint-commit" "ticket:$tkt_id" > /dev/null 2>&1 || true

  # TKT-0406: Trigger Notion sync for sprint assignment
  bash "$TICKET_SCRIPT" sync "$tkt_id" > /dev/null 2>&1 &

  echo "{\"tkt\":\"$tkt_id\",\"sprint\":\"$sprint_name\",\"seq\":$seq,\"effort\":\"$effort\",\"agent\":\"$agent\",\"status\":\"committed\"}"
}

# ──────────────────────────────────────────────
# SUBCOMMAND: status [--sprint <name>]
# ──────────────────────────────────────────────
cmd_status() {
  local sprint_name=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --sprint)
        sprint_name="$2"
        shift 2
        ;;
      --help)
        echo "Usage: db-sprint.sh status [--sprint <name>]"
        return 0
        ;;
      *)
        die "Unknown flag: $1. Use --sprint <name>"
        ;;
    esac
  done

  [[ -z "$sprint_name" ]] && sprint_name=$(get_current_sprint_name)

  log "Sprint status: $sprint_name"

  # Query all tickets in this sprint via sprint_id FK join (TKT-0725-A6)
  local sprint_id
  sprint_id=$(pg_query "SELECT id FROM $SPRINT_TABLE WHERE sprint_name='$sprint_name' ORDER BY updated_at DESC LIMIT 1;" 2>/dev/null | head -1)
  if [[ -z "$sprint_id" || "$sprint_id" == "null" ]]; then
    echo "No sprint found for $sprint_name."
    echo ""
    echo "=== Summary ==="
    echo "Total: 0 | Open: 0 | In Progress: 0 | Done: 0 | Blocked: 0 | Ready: 0"
    return 0
  fi

  local tickets
  tickets=$(pg_query "SELECT id, title, status, metadata FROM $TICKET_TABLE WHERE sprint_id = '$sprint_id' ORDER BY COALESCE(sprint_seq, 999), id;" 2>/dev/null)

  if [[ -z "$tickets" ]]; then
    echo "No tickets found in sprint $sprint_name."
    echo ""
    echo "=== Summary ==="
    echo "Total: 0 | Open: 0 | In Progress: 0 | Done: 0 | Blocked: 0 | Ready: 0"
    return 0
  fi

  # Collect stats
  local total=0 open=0 in_prog=0 done_ct=0 blocked_ct=0 ready_ct=0 pending=0

  # Parse results: use a subquery to allow ORDER BY in jsonb_agg
  local ticket_json
  ticket_json=$(pg_query "SELECT jsonb_agg(t ORDER BY seq_num, id) FROM (SELECT t.*, COALESCE(t.sprint_seq, 999) AS seq_num FROM $TICKET_TABLE t WHERE t.sprint_id = '$sprint_id') t;" 2>/dev/null)

  if [[ -z "$ticket_json" || "$ticket_json" == "null" ]]; then
    echo "No tickets found in sprint $sprint_name (JSON query returned null)."
    return 0
  fi

  echo ""
  echo "=== Sprint: $sprint_name ==="
  echo ""
  printf "%-6s %-14s %-52s %-12s %-8s %-8s %-8s\n" "SEQ" "ID" "TITLE" "STATUS" "FLAG" "EFFORT" "AGENT"
  printf "%-6s %-14s %-52s %-12s %-8s %-8s %-8s\n" "──" "────────────" "────────────────────────────────────────────────────" "────────" "──────" "──────" "──────"

  # Process each ticket and compute dependency-aware status
  local rows
  rows=$(echo "$ticket_json" | $JQ -r '.[] |
    .id as $id |
    .title as $title |
    .status as $status |
    .metadata as $meta |
    (.sprint_seq // "---") as $seq |
    ($meta.sprint_effort // "?") as $effort |
    ($meta.sprint_agent // "?") as $agent |
    ($meta.depends_on // []) as $deps |
    [
      $seq,
      $id,
      ($title | .[0:50]),
      $status,
      ($deps | length),
      $effort,
      $agent
    ] | @tsv' 2>/dev/null)

  # Build closed-set for dep checking
  local closed_set
  closed_set=$(echo "$ticket_json" | $JQ -r '[.[] | select(.status == "closed" or .status == "done" or .status == "folded") | .id] | join(" ")' 2>/dev/null)

  while IFS=$'\t' read -r seq id title status dep_count effort agent; do
    [[ -z "$id" ]] && continue
    # TKT-0409 / L-069: Initialize all counters defensively. `set -u` + uninitialized
    # local in arithmetic context errors out. Also guard dep_count (TSV may produce empty).
    : "${total:=0}"; : "${open:=0}"; : "${in_prog:=0}"; : "${done_ct:=0}"; : "${pending:=0}"
    : "${dep_count:=0}"
    ((total++))

    case "$status" in
      open|backlog|grooming) ((open++)) ;;
      in-progress|in_progress) ((in_prog++)) ;;
      closed|done|folded) ((done_ct++)) ;;
      pending|blocked) ((pending++)) ;;
    esac

    # Determine blocked/ready by checking actual dependency status in PG
    local flag="READY"
    if [[ "$dep_count" -gt 0 ]]; then
      # Check each dependency
      local all_deps_closed=true
      local deps_list
      deps_list=$(echo "$ticket_json" | $JQ -r --arg tid "$id" '.[] | select(.id == $tid) | (.metadata.depends_on // []) | .[]' 2>/dev/null)
      for dep_id in $deps_list; do
        local dep_status
        dep_status=$(pg_query "SELECT status FROM $TICKET_TABLE WHERE id='$dep_id';" 2>/dev/null | head -1)
        if [[ "$dep_status" != "closed" && "$dep_status" != "done" && "$dep_status" != "folded" ]]; then
          all_deps_closed=false
          break
        fi
      done
      if [[ "$all_deps_closed" == "false" ]]; then
        flag="BLOCKED"
        ((blocked_ct++))
      elif [[ "$status" != "closed" && "$status" != "done" && "$status" != "folded" ]]; then
        ((ready_ct++))
      fi
    else
      if [[ "$status" != "closed" && "$status" != "done" && "$status" != "folded" ]]; then
        ((ready_ct++))
      fi
    fi

    printf "%-6s %-14s %-52s %-12s %-8s %-8s %-8s\n" "$seq" "$id" "${title:0:50}" "$status" "$flag" "$effort" "$agent"
  done <<< "$rows"

  echo ""
  echo "=== Summary ==="
  echo "Total: $total | Open: $open | In Progress: $in_prog | Done: $done_ct | Pending: $pending"
  echo "Blocked: $blocked_ct | Ready (open): $ready_ct |"

  # Compute completion percentage
  if [[ $total -gt 0 ]]; then
    local pct=$(( done_ct * 100 / total ))
    echo "Completion: ${pct}% ($done_ct/$total)"
  fi
}

# ──────────────────────────────────────────────
# SUBCOMMAND: plan [--sprint <name>]
# ──────────────────────────────────────────────
cmd_plan() {
  local sprint_name=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --sprint)
        sprint_name="$2"
        shift 2
        ;;
      --help)
        echo "Usage: db-sprint.sh plan [--sprint <name>]"
        return 0
        ;;
      *)
        die "Unknown flag: $1. Use --sprint <name>"
        ;;
    esac
  done

  [[ -z "$sprint_name" ]] && sprint_name=$(get_current_sprint_name)

  log "Sprint plan: $sprint_name"

  # Get sprint details from PG
  local sprint_info
  sprint_info=$(pg_query "SELECT sprint_name, start_date, end_date, status, capacity FROM $SPRINT_TABLE WHERE sprint_name='$sprint_name' ORDER BY updated_at DESC LIMIT 1;" 2>/dev/null)

  echo ""
  echo "=== Sprint Plan: $sprint_name ==="
  if [[ -n "$sprint_info" ]]; then
    local s_name s_start s_end s_status s_cap
    IFS='|' read -r s_name s_start s_end s_status s_cap <<< "$sprint_info"
    echo "  Dates: ${s_start:-?} to ${s_end:-?}"
    echo "  Status: ${s_status:-?}"
    echo "  Capacity: ${s_cap:-?}"
  else
    echo "  (No PG sprint row found - showing ticket-level data only)"
  fi
  echo ""

  # Query all committed tickets via sprint_id FK join (TKT-0725-A6)
  local sprint_id
  sprint_id=$(pg_query "SELECT id FROM $SPRINT_TABLE WHERE sprint_name='$sprint_name' ORDER BY updated_at DESC LIMIT 1;" 2>/dev/null | head -1)
  if [[ -z "$sprint_id" || "$sprint_id" == "null" ]]; then
    echo "No tickets committed to $sprint_name (sprint not found)."
    return 0
  fi

  local ticket_json
  ticket_json=$(pg_query "SELECT jsonb_agg(row_to_json(t) ORDER BY COALESCE(t.sprint_seq, 999), t.id) FROM $TICKET_TABLE t WHERE t.sprint_id = '$sprint_id';" 2>/dev/null)

  if [[ -z "$ticket_json" || "$ticket_json" == "null" || "$ticket_json" == "[null]" ]]; then
    echo "No tickets committed to $sprint_name."
    return 0
  fi

  echo "=== Committed Items ==="
  echo ""
  printf "%-6s %-14s %-48s %-8s %-8s %-8s %-12s\n" "SEQ" "ID" "TITLE" "EFFORT" "AGENT" "STATUS" "DEPS"
  printf "%-6s %-14s %-48s %-8s %-8s %-8s %-12s\n" "──" "────────────" "────────────────────────────────────────────────" "──────" "──────" "──────" "────────"

  local rows
  rows=$(echo "$ticket_json" | $JQ -r '.[] |
    [
      (.sprint_seq // "?"),
      .id,
      (.title | .[0:46]),
      (.metadata.sprint_effort // "?"),
      (.metadata.sprint_agent // "?"),
      .status,
      ((.metadata.depends_on // []) | join(",") | .[0:10])
    ] | @tsv' 2>/dev/null)

  while IFS=$'\t' read -r seq id title effort agent status deps; do
    [[ -z "$id" ]] && continue
    printf "%-6s %-14s %-48s %-8s %-8s %-8s %-12s\n" "$seq" "$id" "${title:0:46}" "$effort" "$agent" "$status" "${deps:0:10}"
  done <<< "$rows"

  echo ""

  # Show folded/deferred metadata for tickets with it
  local deferred
  deferred=$(echo "$ticket_json" | $JQ -r '[.[] | select(.metadata.deferred_from != null)] | length' 2>/dev/null)
  if [[ "${deferred:-0}" -gt 0 ]]; then
    echo "=== Deferred Items ==="
    echo "$ticket_json" | $JQ -r '.[] | select(.metadata.deferred_from != null) | "  \(.id): from \(.metadata.deferred_from) → \(.metadata.sprint_target) - \(.metadata.deferred_reason // "no reason")"' 2>/dev/null
    echo ""
  fi

  # Show folded tickets in this sprint
  local folded
  folded=$(echo "$ticket_json" | $JQ -r '[.[] | select(.status == "folded")] | length' 2>/dev/null)
  if [[ "${folded:-0}" -gt 0 ]]; then
    echo "=== Folded Items ==="
    echo "$ticket_json" | $JQ -r '.[] | select(.status == "folded") | "  \(.id): \(.title)"' 2>/dev/null
    echo ""
  fi
}

# ──────────────────────────────────────────────
# SUBCOMMAND: create "<Sprint X>" "<dates>"
# ──────────────────────────────────────────────
cmd_create() {
  local sprint_name="$1"
  local dates="$2"

  if [[ -z "$sprint_name" ]]; then
    die "Usage: db-sprint.sh create \"<Sprint X>\" \"<dates>\""
  fi

  local sprint_num
  sprint_num=$(sprint_name_to_number "$sprint_name")

  if [[ -z "$sprint_num" ]]; then
    die "Could not extract sprint number from '$sprint_name'. Use format: 'Sprint 8' or 'Sprint8'"
  fi

  # Check for existing sprint
  local existing
  existing=$(pg_query "SELECT id FROM $SPRINT_TABLE WHERE sprint_number=$sprint_num;" 2>/dev/null)
  if [[ -n "$existing" && "$existing" != "null" ]]; then
    die "Sprint $sprint_name already exists in PG (number: $sprint_num)"
  fi

  # Parse dates: "2026-06-15 to 2026-06-21" → start, end
  local start_date=""
  local end_date=""
  if [[ -n "$dates" ]]; then
    start_date=$(echo "$dates" | sed -n 's/^\s*\([0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\).*/\1/p')
    end_date=$(echo "$dates" | sed -n 's/.*\([0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\)\s*$/\1/p')
  fi

  log "Creating $sprint_name (number: $sprint_num, dates: ${start_date:-?} to ${end_date:-?})"

  # Build INSERT
  local sql
  if [[ -n "$start_date" && -n "$end_date" ]]; then
    sql="INSERT INTO $SPRINT_TABLE (sprint_number, sprint_name, start_date, end_date, status, items, notes) VALUES ($sprint_num, '$sprint_name', '$start_date'::date, '$end_date'::date, 'planning', '[]'::jsonb, 'Created via db-sprint.sh');"
  else
    sql="INSERT INTO $SPRINT_TABLE (sprint_number, sprint_name, status, items, notes) VALUES ($sprint_num, '$sprint_name', 'planning', '[]'::jsonb, 'Created via db-sprint.sh');"
  fi

  pg_query "$sql" > /dev/null 2>&1
  local ret=$?

  if [[ $ret -eq 0 ]]; then
    log "✓ Sprint $sprint_name created in PG"
    # TKT-0726: Emit created event for sprint (best-effort)
    local actor
    actor=$(resolve_actor)
    local sprint_payload
    sprint_payload=$($JQ -n --arg name "$sprint_name" --arg num "$sprint_num" --arg dates "$dates" '{sprint_name: $name, sprint_number: ($num | tonumber), dates: $dates}' 2>/dev/null || echo '{"sprint_name":"'"$sprint_name"'"}')
    emit_event "$actor" "created" "sprint" "$sprint_name" "$sprint_payload" "{}" "$sprint_payload"
    echo "{\"sprint\":\"$sprint_name\",\"number\":$sprint_num,\"status\":\"planning\",\"created\":true}"
  else
    die "Failed to create sprint $sprint_name in PG"
  fi
}

# ──────────────────────────────────────────────
# SUBCOMMAND: defer <TKT-ID> --to <Sprint X> --reason "..."
# ──────────────────────────────────────────────
cmd_defer() {
  local tkt_id="$1"
  local target_sprint=""
  local reason=""

  shift
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --to)
        target_sprint="$2"
        shift 2
        ;;
      --reason)
        reason="$2"
        shift 2
        ;;
      *)
        die "Unknown flag: $1. Use --to <Sprint X> --reason \"...\""
        ;;
    esac
  done

  if [[ -z "$tkt_id" || -z "$target_sprint" ]]; then
    die "Usage: db-sprint.sh defer <TKT-ID> --to <Sprint X> --reason \"...\""
  fi

  if ! ticket_exists "$tkt_id"; then
    die "Ticket $tkt_id not found"
  fi

  log "Deferring $tkt_id → $target_sprint"
  log "Reason: ${reason:-no reason given}"

  local current_sprint
  current_sprint=$(get_current_sprint_name)

  # Get current metadata
  local current_meta
  current_meta=$(get_metadata "$tkt_id")

  local from_sprint
  from_sprint=$(echo "$current_meta" | $JQ -r '.sprint_target // ""' 2>/dev/null)

  # Update metadata
  local updated_meta
  updated_meta=$(echo "$current_meta" | $JQ \
    --arg to "$target_sprint" \
    --arg from "${from_sprint:-$current_sprint}" \
    --arg reason "$reason" \
    --arg ts "$(date -u '+%Y-%m-%dT%H:%M:%S+08:00')" \
    '. + {
      sprint_target: $to,
      deferred: true,
      deferred_from: $from,
      deferred_reason: $reason,
      deferred_at: $ts
    } | del(.sprint_seq) | del(.sprint_effort)' 2>/dev/null)

  write_metadata "$tkt_id" "$updated_meta"

  # Also update the proper sprint columns (TKT-0391, TKT-0725-A6: use sprint_id FK)
  local target_sprint_id
  target_sprint_id=$(pg_query "SELECT id FROM $SPRINT_TABLE WHERE sprint_name='$target_sprint' ORDER BY updated_at DESC LIMIT 1;" 2>/dev/null | head -1)
  if [[ -n "$target_sprint_id" && "$target_sprint_id" != "null" ]]; then
    pg_query "UPDATE $TICKET_TABLE SET sprint='$target_sprint', sprint_id='$target_sprint_id', sprint_seq=NULL, updated_at=NOW() WHERE id='$tkt_id';" > /dev/null 2>&1 || true
  else
    pg_query "UPDATE $TICKET_TABLE SET sprint='$target_sprint', sprint_seq=NULL, updated_at=NOW() WHERE id='$tkt_id';" > /dev/null 2>&1 || true
  fi

  # Remove deferred ticket from source sprint's items array (fix gap TKT-0326/T0293)
  local from_sprint_num
  from_sprint_num=$(sprint_name_to_number "${from_sprint:-$current_sprint}")
  local source_items
  source_items=$(pg_query "SELECT items::text FROM $SPRINT_TABLE WHERE sprint_number=$from_sprint_num ORDER BY updated_at DESC LIMIT 1;" 2>/dev/null)

  if [[ -n "$source_items" && "$source_items" != "null" ]]; then
    local cleaned_items
    cleaned_items=$(echo "$source_items" | $JQ --arg tkt_id "$tkt_id" 'map(select(.tkt != $tkt_id))' 2>/dev/null)
    if [[ -n "$cleaned_items" ]]; then
      local escaped_cleaned
      escaped_cleaned=$(echo "$cleaned_items" | sed "s/'/''/g")
      pg_query "UPDATE $SPRINT_TABLE SET items='$escaped_cleaned'::jsonb, updated_at=NOW() WHERE sprint_number=$from_sprint_num;" > /dev/null 2>&1
      log "  removed $tkt_id from $from_sprint items"
    fi
  fi

  log "✓ $tkt_id deferred $from_sprint → $target_sprint"

  # TKT-0406: Trigger Notion sync for sprint reassignment
  bash "$TICKET_SCRIPT" sync "$tkt_id" > /dev/null 2>&1 &

  echo "{\"tkt\":\"$tkt_id\",\"from\":\"$from_sprint\",\"to\":\"$target_sprint\",\"reason\":\"$reason\",\"status\":\"deferred\"}"
}

# ──────────────────────────────────────────────
# SUBCOMMAND: migrate [--sprint <name>]
# AC8: Migrate sprint JSON data to PG metadata
# ──────────────────────────────────────────────
cmd_migrate() {
  local sprint_name=""
  local dry_run="false"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --sprint)
        sprint_name="$2"
        shift 2
        ;;
      --dry-run)
        dry_run="true"
        shift
        ;;
      --help)
        echo "Usage: db-sprint.sh migrate [--sprint <name>] [--dry-run]"
        echo "  Migrates sprint JSON data to PG metadata.sprint_target"
        echo "  --dry-run: Show what would change without writing"
        return 0
        ;;
      *)
        die "Unknown flag: $1. Use --sprint <name>"
        ;;
    esac
  done

  [[ -z "$sprint_name" ]] && sprint_name=$(get_current_sprint_name)

  local sprint_num
  sprint_num=$(sprint_name_to_number "$sprint_name")

  local mode_label="LIVE"
  [[ "$dry_run" == "true" ]] && mode_label="DRY RUN"
  log "Migration: $sprint_name → PG ($mode_label)"
  echo ""
  echo "=== Migration Report: $sprint_name ==="
  echo ""

  # Find JSON files
  local sprint_file="$WORKSPACE_ROOT/state/sprint-${sprint_num}.json"
  local assessed_file="$WORKSPACE_ROOT/state/sprint-${sprint_num}-assessed.json"

  local migrated=0
  local already_set=0
  local conflicts=0
  local skipped=0
  local not_in_pg=0

  # Helper: process a JSON sprint file
  process_sprint_file() {
    local file="$1"
    local source_label="$2"

    if [[ ! -f "$file" ]]; then
      log "  $source_label: file not found ($file)"
      return
    fi

    log "  Processing $source_label..."

    # Extract tickets from sequence array
    local items
    items=$($JQ -r '.sequence[]? | "\(.tkt // .id // "")|\(.seq // .order // "")|\(.effort // "")|\(.agent // "")"' "$file" 2>/dev/null)

    if [[ -z "$items" ]]; then
      log "  $source_label: no sequence items found"
      return
    fi

    while IFS='|' read -r tkt_id seq effort agent; do
      [[ -z "$tkt_id" ]] && continue

      # Check if ticket exists in PG
      if ! ticket_exists "$tkt_id"; then
        echo "  NOT IN PG: $tkt_id (title from JSON)"
        ((not_in_pg++))
        continue
      fi

      # Check current sprint_target in PG
      local current_target
      current_target=$(pg_query "SELECT metadata->>'sprint_target' FROM $TICKET_TABLE WHERE id='$tkt_id';" 2>/dev/null | head -1)
      local current_status
      current_status=$(pg_query "SELECT status FROM $TICKET_TABLE WHERE id='$tkt_id';" 2>/dev/null | head -1)

      if [[ "$current_target" == "$sprint_name" ]]; then
        echo "  ALREADY SET: $tkt_id (status=$current_status)"
        ((already_set++))
        continue
      fi

      if [[ -n "$current_target" && "$current_target" != "$sprint_name" && "$current_target" != "null" ]]; then
        echo "  CONFLICT: $tkt_id - PG says '$current_target', JSON says '$sprint_name' (status=$current_status)"
        ((conflicts++))
        continue
      fi

      # Ready to migrate
      if [[ "$dry_run" == "true" ]]; then
        echo "  WOULD MIGRATE: $tkt_id → $sprint_name (seq=$seq, effort=$effort, agent=$agent)"
        ((migrated++))
        continue
      fi

      # Write to PG
      local current_meta
      current_meta=$(get_metadata "$tkt_id")

      local updated_meta
      updated_meta=$(echo "$current_meta" | $JQ \
        --arg sprint "$sprint_name" \
        --arg seq "${seq:-}" \
        --arg effort "${effort:-}" \
        --arg agent "${agent:-}" \
        '{
          sprint_target: $sprint
        } + (if $seq != "" and $seq != "null" then {sprint_seq: ($seq | tonumber)} else {} end) +
          (if $effort != "" and $effort != "null" then {sprint_effort: $effort} else {} end) +
          (if $agent != "" and $agent != "null" then {sprint_agent: $agent} else {} end) +
          .
      ' 2>/dev/null)

      write_metadata "$tkt_id" "$updated_meta"
      # Also populate the proper sprint columns (TKT-0391, TKT-0725-A6: use sprint_id FK)
      local sprint_id
      sprint_id=$(pg_query "SELECT id FROM $SPRINT_TABLE WHERE sprint_number=$sprint_num ORDER BY updated_at DESC LIMIT 1;" 2>/dev/null | head -1)
      if [[ -n "$sprint_id" && "$sprint_id" != "null" ]]; then
        pg_query "UPDATE $TICKET_TABLE SET sprint='$sprint_name', sprint_id='$sprint_id', sprint_seq=$seq, updated_at=NOW() WHERE id='$tkt_id';" > /dev/null 2>&1 || true
      else
        pg_query "UPDATE $TICKET_TABLE SET sprint='$sprint_name', sprint_seq=$seq, updated_at=NOW() WHERE id='$tkt_id';" > /dev/null 2>&1 || true
      fi
      echo "  MIGRATED: $tkt_id → $sprint_name (seq=$seq, effort=$effort, agent=$agent)"
      ((migrated++))

    done <<< "$items"
  }

  # Also migrate from priority_queue in assessed file
  process_assessed_file() {
    local file="$1"

    if [[ ! -f "$file" ]]; then
      return
    fi

    log "  Processing assessed priority_queue..."

    local items
    items=$($JQ -r '.priority_queue[]? | "\(.tkt)|\(.seq)|\(.effort)|\(.agent)"' "$file" 2>/dev/null)

    if [[ -z "$items" ]]; then
      return
    fi

    while IFS='|' read -r tkt_id seq effort agent; do
      [[ -z "$tkt_id" ]] && continue

      # Skip if already processed in sprint file
      if ticket_exists "$tkt_id"; then
        local current_target
        current_target=$(pg_query "SELECT metadata->>'sprint_target' FROM $TICKET_TABLE WHERE id='$tkt_id';" 2>/dev/null | head -1)
        if [[ "$current_target" == "$sprint_name" ]]; then
          continue
        fi
      fi

      if ! ticket_exists "$tkt_id"; then
        continue
      fi

      local current_target
      current_target=$(pg_query "SELECT metadata->>'sprint_target' FROM $TICKET_TABLE WHERE id='$tkt_id';" 2>/dev/null | head -1)

      if [[ "$current_target" == "$sprint_name" ]]; then
        continue
      fi

      if [[ -n "$current_target" && "$current_target" != "null" && "$current_target" != "$sprint_name" ]]; then
        continue  # already handled as conflict above
      fi

      if [[ "$dry_run" == "true" ]]; then
        echo "  WOULD MIGRATE (assessed): $tkt_id → $sprint_name (seq=$seq, effort=$effort, agent=$agent)"
        ((migrated++))
        continue
      fi

      local current_meta
      current_meta=$(get_metadata "$tkt_id")

      local updated_meta
      updated_meta=$(echo "$current_meta" | $JQ \
        --arg sprint "$sprint_name" \
        --arg seq "${seq:-}" \
        --arg effort "${effort:-}" \
        --arg agent "${agent:-}" \
        '{
          sprint_target: $sprint
        } + (if $seq != "" and $seq != "null" then {sprint_seq: ($seq | tonumber)} else {} end) +
          (if $effort != "" and $effort != "null" then {sprint_effort: $effort} else {} end) +
          (if $agent != "" and $agent != "null" then {sprint_agent: $agent} else {} end) +
          .
      ' 2>/dev/null)

      write_metadata "$tkt_id" "$updated_meta"
      # Also populate the proper sprint columns (TKT-0391, TKT-0725-A6: use sprint_id FK)
      local sprint_id
      sprint_id=$(pg_query "SELECT id FROM $SPRINT_TABLE WHERE sprint_number=$sprint_num ORDER BY updated_at DESC LIMIT 1;" 2>/dev/null | head -1)
      if [[ -n "$sprint_id" && "$sprint_id" != "null" ]]; then
        pg_query "UPDATE $TICKET_TABLE SET sprint='$sprint_name', sprint_id='$sprint_id', sprint_seq=$seq, updated_at=NOW() WHERE id='$tkt_id';" > /dev/null 2>&1 || true
      else
        pg_query "UPDATE $TICKET_TABLE SET sprint='$sprint_name', sprint_seq=$seq, updated_at=NOW() WHERE id='$tkt_id';" > /dev/null 2>&1 || true
      fi
      echo "  MIGRATED (assessed): $tkt_id → $sprint_name (seq=$seq)"
      ((migrated++))

    done <<< "$items"
  }

  # Process both files
  process_sprint_file "$sprint_file" "sprint-${sprint_num}.json"
  process_assessed_file "$assessed_file"

  echo ""
  echo "=== Migration Summary ==="
  echo "  Migrated: $migrated"
  echo "  Already in PG: $already_set"
  echo "  Conflicts: $conflicts"
  echo "  Not in PG (no ticket): $not_in_pg"
  local mode_label="LIVE (writes applied)"
  if [[ "$dry_run" == "true" ]]; then
    mode_label="DRY RUN (no writes)"
  fi
  echo "  Mode: $mode_label"

  if [[ "$dry_run" == "false" && $migrated -gt 0 ]]; then
    log "✓ Migration complete - $migrated tickets migrated to $sprint_name"
    log "  Sprint JSON files ($sprint_file, $assessed_file) remain as read-only reference."
  fi
}

# ──────────────────────────────────────────────
# FUNCTION: auto-generate sprint-current.json from PG
# Called after every ceremony completion to keep the cache fresh.
# ──────────────────────────────────────────────
generate_sprint_current_json() {
  local sprint_num="${1:-}"
  [[ -z "$sprint_num" ]] && sprint_num=$(get_current_sprint_name | sed 's/[^0-9]//g')

  local sprint_json
  sprint_json=$(pg_query "SELECT row_to_json(s)::text FROM $SPRINT_TABLE s WHERE sprint_number=$sprint_num ORDER BY updated_at DESC LIMIT 1;" 2>/dev/null)

  if [[ -z "$sprint_json" || "$sprint_json" == "null" ]]; then
    log "No PG sprint row for sprint $sprint_num - cannot generate sprint-current.json"
    return 1
  fi

  # Build the cache file from PG data
  python3 -c "
import json, sys

pg = json.loads(sys.stdin.read())

# Extract fields
sprint_num = pg.get('sprint_number', 0)
sprint_name = pg.get('sprint_name', f'Sprint {sprint_num}')
status = pg.get('status', 'planning')
start = pg.get('start_date', '')
end = pg.get('end_date', '')
ceremonies = pg.get('ceremonies', {})

# Build previous sprint summary (query is caller's responsibility)
# Build next sprint summary

cache = {
    'sprint': sprint_num,
    'name': sprint_name,
    'dates': f'{start} to {end}' if start and end else 'TBD',
    'status': status,
    'ceremoniesCompleted': ceremonies,
    'auto_generated': True,
    'source': 'PG state_sprints',
    'generated_at': '$(date -u '+%Y-%m-%dT%H:%M:%S+08:00')'
}

print(json.dumps(cache, indent=2))
" <<< "$sprint_json" > "$WORKSPACE_ROOT/state/sprint-current.json"

  log "✓ sprint-current.json auto-generated from PG"
  return 0
}

# ──────────────────────────────────────────────
# SUBCOMMAND: export [--sprint <name>]
# TKT-0348 A5: Export read-only JSON summary of sprint (derived from PG)
# This is a DERIVED EXPORT — never consumed as authoritative data.
# The output is stamped with "derived": true and "source": "PG state_sprints".
# ──────────────────────────────────────────────
cmd_export() {
  local sprint_name=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --sprint)
        sprint_name="$2"
        shift 2
        ;;
      --help)
        echo "Usage: db-sprint.sh export [--sprint <name>]"
        echo "  Exports a read-only JSON summary of the sprint (derived from PG)."
        echo "  --sprint <name>  Sprint to export (default: current sprint)."
        return 0
        ;;
      *)
        die "Unknown flag: $1. Use --sprint <name>"
        ;;
    esac
  done

  [[ -z "$sprint_name" ]] && sprint_name=$(get_current_sprint_name)

  local sprint_num
  sprint_num=$(sprint_name_to_number "$sprint_name")

  log "Exporting sprint summary: $sprint_name (derived from PG)"

  # Get sprint row from PG
  local sprint_json
  sprint_json=$(pg_query "SELECT row_to_json(s)::text FROM $SPRINT_TABLE s WHERE sprint_number=$sprint_num ORDER BY updated_at DESC LIMIT 1;" 2>/dev/null)

  if [[ -z "$sprint_json" || "$sprint_json" == "null" ]]; then
    die "Sprint $sprint_name not found in PG"
  fi

  # Get ticket counts for this sprint via sprint_id FK join
  local sprint_id
  sprint_id=$(pg_query "SELECT id FROM $SPRINT_TABLE WHERE sprint_number=$sprint_num ORDER BY updated_at DESC LIMIT 1;" 2>/dev/null | head -1)

  local ticket_count=0
  local done_count=0
  local open_count=0
  local in_progress_count=0

  if [[ -n "$sprint_id" && "$sprint_id" != "null" ]]; then
    ticket_count=$(pg_query "SELECT COUNT(*) FROM $TICKET_TABLE WHERE sprint_id='$sprint_id';" 2>/dev/null | head -1)
    done_count=$(pg_query "SELECT COUNT(*) FROM $TICKET_TABLE WHERE sprint_id='$sprint_id' AND status IN ('closed','done','folded');" 2>/dev/null | head -1)
    open_count=$(pg_query "SELECT COUNT(*) FROM $TICKET_TABLE WHERE sprint_id='$sprint_id' AND status IN ('open','backlog','grooming');" 2>/dev/null | head -1)
    in_progress_count=$(pg_query "SELECT COUNT(*) FROM $TICKET_TABLE WHERE sprint_id='$sprint_id' AND status IN ('in-progress','in_progress');" 2>/dev/null | head -1)
  fi

  # Get committed items from state_sprints.items
  local items_json
  items_json=$(pg_query "SELECT items::text FROM $SPRINT_TABLE WHERE sprint_number=$sprint_num ORDER BY updated_at DESC LIMIT 1;" 2>/dev/null)

  # Build derived export JSON
  local ts
  ts=$(date -u '+%Y-%m-%dT%H:%M:%S+08:00')

  local export_json
  export_json=$(echo "$sprint_json" | $JQ     --argjson ticket_count "${ticket_count:-0}"     --argjson done_count "${done_count:-0}"     --argjson open_count "${open_count:-0}"     --argjson in_progress_count "${in_progress_count:-0}"     --arg ts "$ts"     --arg sprint_name "$sprint_name"     '{
      sprint: $sprint_name,
      sprint_number: .sprint_number,
      status: .status,
      dates: "\(.start_date // "?") to \(.end_date // "?")",
      ticket_count: $ticket_count,
      done_count: $done_count,
      open_count: $open_count,
      in_progress_count: $in_progress_count,
      completion_pct: (if $ticket_count > 0 then ($done_count * 100 / $ticket_count) else 0 end),
      ceremonies: .ceremonies,
      derived: true,
      source: "PG state_sprints",
      exported_at: $ts
    }' 2>/dev/null)

  if [[ -z "$export_json" || "$export_json" == "null" ]]; then
    die "Failed to build export JSON"
  fi

  echo "$export_json"
}

# ──────────────────────────────────────────────
# SUBCOMMAND: ceremony complete <review|planning> [--sprint <name>]
# Logs ceremony completion to PG and auto-generates sprint-current.json
# ──────────────────────────────────────────────
cmd_ceremony() {
  local action="${1:-}"
  shift 2>/dev/null || true

  if [[ "$action" != "complete" ]]; then
    die "Usage: db-sprint.sh ceremony complete <review|planning> [--sprint <name>]"
  fi

  local ceremony_type="${1:-}"
  shift 2>/dev/null || true

  if [[ "$ceremony_type" != "review" && "$ceremony_type" != "planning" ]]; then
    die "Ceremony type must be 'review' or 'planning'. Got: '$ceremony_type'"
  fi

  local sprint_name=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --sprint)
        sprint_name="$2"
        shift 2
        ;;
      *)
        die "Unknown flag: $1. Use --sprint <name>"
        ;;
    esac
  done

  [[ -z "$sprint_name" ]] && sprint_name=$(get_current_sprint_name)

  local sprint_num
  sprint_num=$(sprint_name_to_number "$sprint_name")

  # Get current ceremonies from PG
  local current_ceremonies
  current_ceremonies=$(pg_query "SELECT ceremonies::text FROM $SPRINT_TABLE WHERE sprint_number=$sprint_num ORDER BY updated_at DESC LIMIT 1;" 2>/dev/null)

  if [[ -z "$current_ceremonies" || "$current_ceremonies" == "null" || "$current_ceremonies" == "{}" ]]; then
    current_ceremonies='{}'
  fi

  # Build ceremony key: sprintReview or sprintPlanning
  local ceremony_key=""
  if [[ "$ceremony_type" == "review" ]]; then
    ceremony_key="sprint${sprint_num}Review"
  else
    ceremony_key="sprint${sprint_num}Planning"
  fi

  log "Logging $ceremony_key to PG state_sprints.ceremonies"

  local ts
  ts=$(date -u '+%Y-%m-%dT%H:%M:%S+08:00')

  # Update ceremonies JSONB in PG
  local updated_ceremonies
  updated_ceremonies=$(echo "$current_ceremonies" | $JQ --arg key "$ceremony_key" --arg ts "$ts" '. + {($key): $ts}' 2>/dev/null)

  if [[ -z "$updated_ceremonies" ]]; then
    die "Failed to build updated ceremonies JSON"
  fi

  local escaped
  escaped=$(echo "$updated_ceremonies" | sed "s/'/''/g")
  pg_query "UPDATE $SPRINT_TABLE SET ceremonies='$escaped'::jsonb, updated_at=NOW() WHERE sprint_number=$sprint_num;" > /dev/null 2>&1
  local ret=$?

  if [[ $ret -ne 0 ]]; then
    die "Failed to write ceremonies to PG"
  fi

  log "✓ $ceremony_key logged at $ts"

  # Auto-generate sprint-current.json cache
  generate_sprint_current_json "$sprint_num"

  # Best-effort: generate sprint review report for review ceremonies
  if [[ "$ceremony_type" == "review" ]]; then
    local review_script="$WORKSPACE_ROOT/agent-skills/agile/scripts/sprint-review.sh"
    if [[ -x "$review_script" ]]; then
      bash "$review_script" --sprint "$sprint_name" > /dev/null 2>&1 || log "sprint-review.sh generated report (optional)"
    else
      log "sprint-review.sh not found; skipping optional report generation"
    fi
  fi

  echo "{\"ceremony\":\"$ceremony_key\",\"sprint\":\"$sprint_name\",\"completed_at\":\"$ts\",\"status\":\"logged\",\"cache\":\"sprint-current.json auto-generated\"}"
}

# ──────────────────────────────────────────────
# SUBCOMMAND: next-ticket [--agent <name>]
# TKT-0728: Canonical next-ticket resolution for pg-sprint-backlog skill
# Priority pipeline:
#   (a) in-progress ticket in active sprint
#   (b) open+unblocked ticket in active sprint ordered by priority DESC, sprint_seq ASC
#   (c) same in next committed sprint
#   (d) backlog
# ──────────────────────────────────────────────
cmd_next_ticket() {
  local agent_filter=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --agent)
        agent_filter="$2"
        shift 2
        ;;
      --help)
        echo "Usage: db-sprint.sh next-ticket [--agent <name>]"
        echo "  Returns the next ticket to work as JSON."
        echo "  --agent <name>  Filter to tickets assigned to this agent (optional)."
        return 0
        ;;
      *)
        die "Unknown flag: $1. Use --agent <name>"
        ;;
    esac
  done

  log "Resolving next ticket (agent filter: ${agent_filter:-none})"

  # ── CRESTv2-P1 Tracker Override (TKT-0761) ──
  # Check locked_execution_order before canonical resolution.
  # When state/crestv2-p1-tracker.json has status=locked, the first eligible
  # ticket in locked_execution_order sequence is returned with reason=tracker-override.
  local TRACKER_FILE="$WORKSPACE_ROOT/state/crestv2-p1-tracker.json"
  local SELECTED_TRACKER_TICKET=""
  local TRACKER_OVERRIDE_ACTIVE="false"

  # ── Agent matching helper (inlined from deprecated next-ticket-tracker-override.sh) ──
  # For yoda: lenient — matches yoda, unassigned, null, or empty.
  # For other agents: strict match only.
  agent_matches_filter() {
    local ticket_agent="$1"
    local filter="$2"
    if [[ -z "$filter" ]]; then
      return 0
    fi
    if [[ "$filter" == "yoda" ]]; then
      if [[ -z "$ticket_agent" || "$ticket_agent" == "null" || "$ticket_agent" == "yoda" ]]; then
        return 0
      fi
      return 1
    fi
    if [[ "$ticket_agent" == "$filter" ]]; then
      return 0
    fi
    return 1
  }

  if [[ -f "$TRACKER_FILE" ]]; then
    local TRACKER_JSON
    TRACKER_JSON=$(cat "$TRACKER_FILE" 2>/dev/null)
    if echo "$TRACKER_JSON" | $JQ empty 2>/dev/null; then
      local TRACKER_STATUS
      TRACKER_STATUS=$(echo "$TRACKER_JSON" | $JQ -r '.status // ""' 2>/dev/null)
      if [[ "$TRACKER_STATUS" == "locked" ]]; then
        log "CRESTv2-P1 tracker is locked — checking locked_execution_order"

        # Pre-fetch active and next sprint names (they don't change per ticket)
        local ACTIVE_SPRINT_NAME_TR
        ACTIVE_SPRINT_NAME_TR=$(pg_query "SELECT sprint_name FROM $SPRINT_TABLE WHERE status='in_progress' AND sprint_number > 0 ORDER BY sprint_number DESC LIMIT 1;" 2>/dev/null | head -1)
        if [[ -z "$ACTIVE_SPRINT_NAME_TR" ]]; then
          ACTIVE_SPRINT_NAME_TR=$(pg_query "SELECT sprint_name FROM $SPRINT_TABLE WHERE start_date <= CURRENT_DATE AND end_date >= CURRENT_DATE AND sprint_number > 0 ORDER BY sprint_number DESC LIMIT 1;" 2>/dev/null | head -1)
        fi
        local NEXT_SPRINT_NAME_TR
        NEXT_SPRINT_NAME_TR=$(pg_query "SELECT sprint_name FROM $SPRINT_TABLE WHERE status='committed' AND start_date > CURRENT_DATE AND sprint_number > 0 ORDER BY start_date ASC LIMIT 1;" 2>/dev/null | head -1)

        # Iterate locked_execution_order in sequence
        local TRACKER_TICKETS
        TRACKER_TICKETS=$(echo "$TRACKER_JSON" | $JQ -r '.locked_execution_order[].tickets[]' 2>/dev/null)

        while IFS= read -r tkt_id; do
          [[ -z "$tkt_id" ]] && continue
          log "  Checking tracker ticket: $tkt_id"

          # Query PG for ticket status, sprint, and agent
          local ROW
          ROW=$(pg_query "SELECT id, status, sprint, metadata->>'sprint_agent' as agent FROM $TICKET_TABLE WHERE id='$tkt_id';" 2>/dev/null | head -1)
          if [[ -z "$ROW" ]]; then
            log "    Ticket $tkt_id not found in PG — skipping"
            continue
          fi

          local TKT_STATUS TKT_SPRINT TKT_AGENT
          IFS='|' read -r _ TKT_STATUS TKT_SPRINT TKT_AGENT <<< "$ROW"

          # Check status: must be open or in_progress
          if [[ "$TKT_STATUS" != "open" && "$TKT_STATUS" != "in_progress" && "$TKT_STATUS" != "in-progress" ]]; then
            log "    Ticket $tkt_id status is '$TKT_STATUS' — not eligible (skipping)"
            continue
          fi

          # Check sprint: must be in active or next committed sprint
          local IN_VALID_SPRINT=false
          if [[ -n "$TKT_SPRINT" && "$TKT_SPRINT" != "null" ]]; then
            if [[ "$TKT_SPRINT" == "$ACTIVE_SPRINT_NAME_TR" || "$TKT_SPRINT" == "$NEXT_SPRINT_NAME_TR" ]]; then
              IN_VALID_SPRINT=true
            fi
          fi
          if [[ "$IN_VALID_SPRINT" != "true" ]]; then
            log "    Ticket $tkt_id sprint is '$TKT_SPRINT' — not in active/next sprint (skipping)"
            continue
          fi

          # Check agent filter
          if ! agent_matches_filter "$TKT_AGENT" "$agent_filter"; then
            log "    Ticket $tkt_id agent is '$TKT_AGENT' — does not match filter '$agent_filter' (skipping)"
            continue
          fi

          # Eligible!
          SELECTED_TRACKER_TICKET="$tkt_id"
          TRACKER_OVERRIDE_ACTIVE="true"
          log "  Selected tracker ticket: $tkt_id (status=$TKT_STATUS, sprint=$TKT_SPRINT, agent=$TKT_AGENT)"
          break
        done <<< "$TRACKER_TICKETS"
      else
        log "CRESTv2-P1 tracker status is '$TRACKER_STATUS' (not locked) — skipping override"
      fi
    else
      log "CRESTv2-P1 tracker file contains invalid JSON — skipping override"
    fi
  else
    log "CRESTv2-P1 tracker file not found — skipping override"
  fi

  # ── Step 1: Determine current active sprint ──
  local active_sprint_id=""
  local active_sprint_name=""
  local active_sprint_status=""
  local active_sprint_start=""
  local active_sprint_end=""
  local active_sprint_is_active="false"

  # 1a. Check for in_progress sprint
  local sprint_row
  sprint_row=$(pg_query "SELECT id, sprint_name, status, start_date::text, end_date::text FROM $SPRINT_TABLE WHERE status='in_progress' AND sprint_number > 0 ORDER BY sprint_number DESC LIMIT 1;" 2>/dev/null)
  if [[ -n "$sprint_row" ]]; then
    IFS='|' read -r active_sprint_id active_sprint_name active_sprint_status active_sprint_start active_sprint_end <<< "$sprint_row"
    active_sprint_is_active="true"
    log "Active sprint (in_progress): $active_sprint_name"
  else
    # 1b. Date-window match
    sprint_row=$(pg_query "SELECT id, sprint_name, status, start_date::text, end_date::text FROM $SPRINT_TABLE WHERE start_date <= CURRENT_DATE AND end_date >= CURRENT_DATE AND sprint_number > 0 ORDER BY sprint_number DESC LIMIT 1;" 2>/dev/null)
    if [[ -n "$sprint_row" ]]; then
      IFS='|' read -r active_sprint_id active_sprint_name active_sprint_status active_sprint_start active_sprint_end <<< "$sprint_row"
      active_sprint_is_active="true"
      log "Active sprint (date window): $active_sprint_name (status=$active_sprint_status)"
    fi
  fi

  # ── Step 2: Determine next committed sprint ──
  local next_sprint_id=""
  local next_sprint_name=""
  local next_sprint_status=""
  local next_sprint_start=""
  local next_sprint_end=""

  local next_row
  next_row=$(pg_query "SELECT id, sprint_name, status, start_date::text, end_date::text FROM $SPRINT_TABLE WHERE status='committed' AND start_date > CURRENT_DATE AND sprint_number > 0 ORDER BY start_date ASC LIMIT 1;" 2>/dev/null)
  if [[ -n "$next_row" ]]; then
    IFS='|' read -r next_sprint_id next_sprint_name next_sprint_status next_sprint_start next_sprint_end <<< "$next_row"
    log "Next committed sprint: $next_sprint_name"
  fi

  # ── Helper: find best ticket in a sprint ──
  # Returns JSON with ticket info or empty
  find_ticket_in_sprint() {
    local sprint_id="$1"
    local sprint_name="$2"
    local agent="${3:-}"

    # (a) In-progress ticket
    local tkt_json
    if [[ -n "$agent" ]]; then
      tkt_json=$(pg_query "SELECT row_to_json(t)::text FROM $TICKET_TABLE t WHERE sprint_id='$sprint_id' AND status='in_progress' AND (metadata->>'sprint_agent' = '$agent' OR metadata->>'agent' = '$agent') ORDER BY COALESCE(sprint_seq, 999) ASC LIMIT 1;" 2>/dev/null)
    else
      tkt_json=$(pg_query "SELECT row_to_json(t)::text FROM $TICKET_TABLE t WHERE sprint_id='$sprint_id' AND status='in_progress' ORDER BY COALESCE(sprint_seq, 999) ASC LIMIT 1;" 2>/dev/null)
    fi
    if [[ -n "$tkt_json" && "$tkt_json" != "null" ]]; then
      echo "$tkt_json|in-progress-resume"
      return 0
    fi

    # (b) Open, unblocked tickets ordered by priority DESC, sprint_seq ASC
    # Priority order: critical > high > medium > low (mapped to numeric)
    local order_sql
    order_sql="CASE WHEN LOWER(priority) IN ('critical','p0','urgent') THEN 0 WHEN LOWER(priority) IN ('high','p1') THEN 1 WHEN LOWER(priority) IN ('medium','p2','normal') THEN 2 WHEN LOWER(priority) IN ('low','p3') THEN 3 ELSE 99 END"

    if [[ -n "$agent" ]]; then
      tkt_json=$(pg_query "SELECT row_to_json(t)::text FROM $TICKET_TABLE t WHERE sprint_id='$sprint_id' AND status='open' AND (metadata->>'sprint_agent' = '$agent' OR metadata->>'agent' = '$agent') AND (metadata->>'depends_on' IS NULL OR metadata->>'depends_on' = '[]'::text OR NOT EXISTS (SELECT 1 FROM jsonb_array_elements_text(COALESCE(t.metadata->'depends_on', '[]'::jsonb)) AS dep_id JOIN $TICKET_TABLE b ON b.id = dep_id WHERE b.status NOT IN ('closed','done','folded'))) ORDER BY $order_sql ASC, COALESCE(sprint_seq, 999) ASC LIMIT 1;" 2>/dev/null)
    else
      tkt_json=$(pg_query "SELECT row_to_json(t)::text FROM $TICKET_TABLE t WHERE sprint_id='$sprint_id' AND status='open' AND (metadata->>'depends_on' IS NULL OR metadata->>'depends_on' = '[]'::text OR NOT EXISTS (SELECT 1 FROM jsonb_array_elements_text(COALESCE(t.metadata->'depends_on', '[]'::jsonb)) AS dep_id JOIN $TICKET_TABLE b ON b.id = dep_id WHERE b.status NOT IN ('closed','done','folded'))) ORDER BY $order_sql ASC, COALESCE(sprint_seq, 999) ASC LIMIT 1;" 2>/dev/null)
    fi
    if [[ -n "$tkt_json" && "$tkt_json" != "null" ]]; then
      echo "$tkt_json|active-sprint-ready"
      return 0
    fi

    return 1
  }

  # ── Step 3: Pipeline resolution ──
  local result_ticket=""
  local result_reason=""

  # 3a. CRESTv2-P1 tracker override takes priority (TKT-0761)
  if [[ "$TRACKER_OVERRIDE_ACTIVE" == "true" && -n "$SELECTED_TRACKER_TICKET" ]]; then
    # Fetch full ticket JSON from PG for the output builder
    local TRACKER_TKT_JSON
    TRACKER_TKT_JSON=$(pg_query "SELECT row_to_json(t)::text FROM $TICKET_TABLE t WHERE id='$SELECTED_TRACKER_TICKET';" 2>/dev/null)
    if [[ -n "$TRACKER_TKT_JSON" && "$TRACKER_TKT_JSON" != "null" ]]; then
      result_ticket="$TRACKER_TKT_JSON"
      result_reason="tracker-override"
      log "Tracker override active: $SELECTED_TRACKER_TICKET (reason=tracker-override)"
    else
      log "Tracker override: could not fetch full JSON for $SELECTED_TRACKER_TICKET — falling through"
    fi
  fi

  # 3b. Try active sprint (only if no tracker override)
  if [[ "$TRACKER_OVERRIDE_ACTIVE" != "true" && -n "$active_sprint_id" ]]; then
    local active_result
    active_result=$(find_ticket_in_sprint "$active_sprint_id" "$active_sprint_name" "$agent_filter")
    if [[ -n "$active_result" ]]; then
      result_ticket=$(echo "$active_result" | cut -d'|' -f1)
      result_reason=$(echo "$active_result" | cut -d'|' -f2-)
      log "Found ticket in active sprint: reason=$result_reason"
    fi
  fi

  # 3c. If no ticket in active sprint, try next committed sprint
  if [[ -z "$result_ticket" && -n "$next_sprint_id" ]]; then
    local next_result
    next_result=$(find_ticket_in_sprint "$next_sprint_id" "$next_sprint_name" "$agent_filter")
    if [[ -n "$next_result" ]]; then
      result_ticket=$(echo "$next_result" | cut -d'|' -f1)
      result_reason=$(echo "$next_result" | cut -d'|' -f2-)
      # Override reason to next-sprint-ready
      result_reason="next-sprint-ready"
      log "Found ticket in next sprint: reason=$result_reason"
    fi
  fi

  # 3d. If no ticket in any sprint, try backlog
  if [[ -z "$result_ticket" ]]; then
    local order_sql
    order_sql="CASE WHEN LOWER(priority) IN ('critical','p0','urgent') THEN 0 WHEN LOWER(priority) IN ('high','p1') THEN 1 WHEN LOWER(priority) IN ('medium','p2','normal') THEN 2 WHEN LOWER(priority) IN ('low','p3') THEN 3 ELSE 99 END"
    local backlog_tkt
    if [[ -n "$agent_filter" ]]; then
      backlog_tkt=$(pg_query "SELECT row_to_json(t)::text FROM $TICKET_TABLE t WHERE (sprint IS NULL OR sprint = '' OR sprint = 'Unassigned') AND status='open' AND (metadata->>'sprint_agent' = '$agent_filter' OR metadata->>'agent' = '$agent_filter') ORDER BY $order_sql ASC, id ASC LIMIT 1;" 2>/dev/null)
    else
      backlog_tkt=$(pg_query "SELECT row_to_json(t)::text FROM $TICKET_TABLE t WHERE (sprint IS NULL OR sprint = '' OR sprint = 'Unassigned') AND status='open' ORDER BY $order_sql ASC, id ASC LIMIT 1;" 2>/dev/null)
    fi
    if [[ -n "$backlog_tkt" && "$backlog_tkt" != "null" ]]; then
      result_ticket="$backlog_tkt"
      result_reason="backlog"
      log "Found ticket in backlog: reason=$result_reason"
    fi
  fi

  # ── Step 4: Build output JSON ──
  local ticket_id=""
  local ticket_title=""
  local ticket_status=""
  local ticket_priority=""
  local ticket_sprint=""
  local ticket_sprint_seq=""
  local ticket_effort=""
  local ticket_agent=""

  if [[ -n "$result_ticket" && "$result_ticket" != "null" ]]; then
    ticket_id=$(echo "$result_ticket" | $JQ -r '.id // ""' 2>/dev/null)
    ticket_title=$(echo "$result_ticket" | $JQ -r '.title // ""' 2>/dev/null)
    ticket_status=$(echo "$result_ticket" | $JQ -r '.status // ""' 2>/dev/null)
    ticket_priority=$(echo "$result_ticket" | $JQ -r '.priority // ""' 2>/dev/null)
    ticket_sprint=$(echo "$result_ticket" | $JQ -r '.sprint // ""' 2>/dev/null)
    ticket_sprint_seq=$(echo "$result_ticket" | $JQ -r '.sprint_seq // ""' 2>/dev/null)
    ticket_effort=$(echo "$result_ticket" | $JQ -r '.metadata.sprint_effort // (.metadata.effort // "")' 2>/dev/null)
    ticket_agent=$(echo "$result_ticket" | $JQ -r '.metadata.sprint_agent // (.metadata.agent // "")' 2>/dev/null)
  fi

  # Compute completion for active sprint
  local active_completion="0%"
  if [[ -n "$active_sprint_id" ]]; then
    local active_total
    active_total=$(pg_query "SELECT COUNT(*) FROM $TICKET_TABLE WHERE sprint_id='$active_sprint_id';" 2>/dev/null | head -1)
    local active_done
    active_done=$(pg_query "SELECT COUNT(*) FROM $TICKET_TABLE WHERE sprint_id='$active_sprint_id' AND status IN ('closed','done','folded');" 2>/dev/null | head -1)
    if [[ "${active_total:-0}" -gt 0 ]]; then
      active_completion="$(( active_done * 100 / active_total ))%"
    fi
  fi

  # Compute completion for next sprint
  local next_completion="0%"
  if [[ -n "$next_sprint_id" ]]; then
    local next_total
    next_total=$(pg_query "SELECT COUNT(*) FROM $TICKET_TABLE WHERE sprint_id='$next_sprint_id';" 2>/dev/null | head -1)
    local next_done
    next_done=$(pg_query "SELECT COUNT(*) FROM $TICKET_TABLE WHERE sprint_id='$next_sprint_id' AND status IN ('closed','done','folded');" 2>/dev/null | head -1)
    if [[ "${next_total:-0}" -gt 0 ]]; then
      next_completion="$(( next_done * 100 / next_total ))%"
    fi
  fi

  # Build JSON output
  local OUTPUT_JSON
  OUTPUT_JSON=$($JQ -n     --arg ticket "${ticket_id:-null}"     --arg sprint "${ticket_sprint:-null}"     --arg sprint_seq "${ticket_sprint_seq:-null}"     --arg status "${ticket_status:-null}"     --arg priority "${ticket_priority:-null}"     --arg effort "${ticket_effort:-null}"     --arg agent "${ticket_agent:-null}"     --arg reason "${result_reason:-none-available}"     --arg cs_name "${active_sprint_name:-null}"     --arg cs_status "${active_sprint_status:-null}"     --arg cs_start "${active_sprint_start:-null}"     --arg cs_end "${active_sprint_end:-null}"     --arg cs_completion "${active_completion:-0%}"     --argjson cs_active ${active_sprint_is_active:-false}     --arg ns_name "${next_sprint_name:-null}"     --arg ns_status "${next_sprint_status:-null}"     --arg ns_start "${next_sprint_start:-null}"     --arg ns_end "${next_sprint_end:-null}"     --arg ns_completion "${next_completion:-0%}"     '{
      ticket: (if $ticket == "null" then null else $ticket end),
      sprint: (if $sprint == "null" then null else $sprint end),
      sprint_seq: (if $sprint_seq == "null" then null else ($sprint_seq | tonumber) end),
      status: (if $status == "null" then null else $status end),
      priority: (if $priority == "null" then null else $priority end),
      effort: (if $effort == "null" then null else $effort end),
      agent: (if $agent == "null" then null else $agent end),
      reason: $reason,
      current_sprint: {
        name: (if $cs_name == "null" then null else $cs_name end),
        status: (if $cs_status == "null" then null else $cs_status end),
        dates: (if $cs_start == "null" or $cs_end == "null" then null else "\($cs_start) to \($cs_end)" end),
        completion: $cs_completion,
        is_active: $cs_active
      },
      next_sprint: {
        name: (if $ns_name == "null" then null else $ns_name end),
        status: (if $ns_status == "null" then null else $ns_status end),
        dates: (if $ns_start == "null" or $ns_end == "null" then null else "\($ns_start) to \($ns_end)" end),
        completion: $ns_completion
      }
    }' 2>/dev/null)
  echo "$OUTPUT_JSON"
  echo "$OUTPUT_JSON" > "$WORKSPACE_ROOT/state/next-ticket.json"
}

# ──────────────────────────────────────────────
# SUBCOMMAND: activate [--dry-run]
# TKT-0728: Transition any committed sprint whose start_date <= today to in_progress
# ──────────────────────────────────────────────
cmd_activate() {
  local dry_run="false"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run)
        dry_run="true"
        shift
        ;;
      --help)
        echo "Usage: db-sprint.sh activate [--dry-run]"
        echo "  Transitions committed sprints whose start_date <= today to in_progress."
        echo "  --dry-run  Show what would change without writing."
        return 0
        ;;
      *)
        die "Unknown flag: $1. Use --dry-run"
        ;;
    esac
  done

  log "Checking for sprints to activate..."

  # Find committed sprints whose start_date <= today
  local sprints_to_activate
  sprints_to_activate=$(pg_query "SELECT sprint_number, sprint_name, start_date::text, end_date::text FROM $SPRINT_TABLE WHERE status='committed' AND start_date <= CURRENT_DATE AND sprint_number > 0 ORDER BY sprint_number ASC;" 2>/dev/null)

  if [[ -z "$sprints_to_activate" ]]; then
    echo "{"action":"activate","status":"no-sprints-to-activate","transitions":[]}"
    return 0
  fi

  local transitions_json="[]"
  local count=0

  while IFS='|' read -r snum sname sstart send; do
    [[ -z "$snum" ]] && continue
    ((count++))

    if [[ "$dry_run" == "true" ]]; then
      log "DRY RUN: Would activate $sname (start=$sstart, end=$send)"
      transitions_json=$(echo "$transitions_json" | $JQ --arg sn "$sname" --arg snum "$snum" --arg sstart "$sstart" --arg send "$send" '. + [{
        sprint_name: $sn,
        sprint_number: ($snum | tonumber),
        start_date: $sstart,
        end_date: $send,
        from_status: "committed",
        to_status: "in_progress",
        action: "would-activate"
      }]' 2>/dev/null)
    else
      log "Activating $sname (start=$sstart, end=$send)"
      pg_query "UPDATE $SPRINT_TABLE SET status='in_progress', updated_at=NOW() WHERE sprint_number=$snum AND status='committed';" > /dev/null 2>&1
      local ret=$?
      if [[ $ret -eq 0 ]]; then
        transitions_json=$(echo "$transitions_json" | $JQ --arg sn "$sname" --arg snum "$snum" --arg sstart "$sstart" --arg send "$send" '. + [{
          sprint_name: $sn,
          sprint_number: ($snum | tonumber),
          start_date: $sstart,
          end_date: $send,
          from_status: "committed",
          to_status: "in_progress",
          action: "activated"
        }]' 2>/dev/null)
        # Emit event for activation
        local actor
        actor=$(resolve_actor)
        local act_payload
        act_payload=$($JQ -n --arg name "$sname" --arg num "$snum" --arg start "$sstart" --arg end "$send" '{sprint_name: $name, sprint_number: ($num | tonumber), start_date: $start, end_date: $end}' 2>/dev/null || echo '{"sprint_name":"'"$sname"'"}')
        emit_event "$actor" "activated" "sprint" "$sname" "$act_payload" "committed" "in_progress"
      else
        log "WARNING: Failed to activate $sname"
      fi
    fi
  done <<< "$sprints_to_activate"

  local mode_label="LIVE"
  [[ "$dry_run" == "true" ]] && mode_label="DRY RUN"

  echo "$transitions_json" | $JQ --arg mode "$mode_label" --arg count "$count" '{
    action: "activate",
    status: "complete",
    mode: $mode,
    transitions_count: ($count | tonumber),
    transitions: .
  }' 2>/dev/null
}

# ──────────────────────────────────────────────
# SUBCOMMAND: complete "<Sprint N>" [--dry-run]
# Mark a sprint as completed. Only sprints with status='in_progress' can be completed.
# Logs a completion ceremony and auto-generates sprint-current.json.
# ──────────────────────────────────────────────
cmd_complete() {
  local sprint_name=""
  local dry_run="false"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run)
        dry_run="true"
        shift
        ;;
      --help)
        echo "Usage: db-sprint.sh complete \"<Sprint N>\" [--dry-run]"
        echo "  Mark an in_progress sprint as completed."
        echo "  --dry-run  Show what would change without writing."
        return 0
        ;;
      *)
        if [[ -z "$sprint_name" ]]; then
          sprint_name="$1"
          shift
        else
          die "Unknown flag: $1. Use --dry-run"
        fi
        ;;
    esac
  done

  if [[ -z "$sprint_name" ]]; then
    die "Usage: db-sprint.sh complete \"<Sprint N>\" [--dry-run]"
  fi

  local sprint_num
  sprint_num=$(sprint_name_to_number "$sprint_name")

  local current_status
  current_status=$(pg_query "SELECT status FROM $SPRINT_TABLE WHERE sprint_number=$sprint_num ORDER BY updated_at DESC LIMIT 1;" 2>/dev/null | head -1)

  if [[ -z "$current_status" || "$current_status" == "null" ]]; then
    die "Sprint $sprint_name not found in PG"
  fi

  if [[ "$current_status" != "in_progress" ]]; then
    die "Sprint $sprint_name status is '$current_status'; only 'in_progress' sprints can be completed"
  fi

  local mode_label="LIVE"
  [[ "$dry_run" == "true" ]] && mode_label="DRY RUN"
  log "Completing $sprint_name ($mode_label)"

  if [[ "$dry_run" == "true" ]]; then
    echo "{\"sprint\":\"$sprint_name\",\"sprint_number\":$sprint_num,\"from_status\":\"$current_status\",\"to_status\":\"completed\",\"action\":\"would-complete\"}"
    return 0
  fi

  pg_query "UPDATE $SPRINT_TABLE SET status='completed', updated_at=NOW() WHERE sprint_number=$sprint_num AND status='in_progress';" > /dev/null 2>&1
  local ret=$?
  if [[ $ret -ne 0 ]]; then
    die "Failed to complete sprint $sprint_name in PG"
  fi

  # Log completion ceremony
  local current_ceremonies
  current_ceremonies=$(pg_query "SELECT ceremonies::text FROM $SPRINT_TABLE WHERE sprint_number=$sprint_num ORDER BY updated_at DESC LIMIT 1;" 2>/dev/null)
  [[ -z "$current_ceremonies" || "$current_ceremonies" == "null" ]] && current_ceremonies='{}'

  local ceremony_key="sprint${sprint_num}Complete"
  local ts
  ts=$(date -u '+%Y-%m-%dT%H:%M:%S+08:00')
  local updated_ceremonies
  updated_ceremonies=$(echo "$current_ceremonies" | $JQ --arg key "$ceremony_key" --arg ts "$ts" '. + {($key): $ts}' 2>/dev/null)
  local escaped
  escaped=$(echo "$updated_ceremonies" | sed "s/'/''/g")
  pg_query "UPDATE $SPRINT_TABLE SET ceremonies='$escaped'::jsonb, updated_at=NOW() WHERE sprint_number=$sprint_num;" > /dev/null 2>&1 || true

  # Emit event
  local actor
  actor=$(resolve_actor)
  local complete_payload
  complete_payload=$($JQ -n --arg name "$sprint_name" --arg num "$sprint_num" '{sprint_name: $name, sprint_number: ($num | tonumber)}' 2>/dev/null || echo "{\"sprint_name\":\"$sprint_name\"}")
  emit_event "$actor" "completed" "sprint" "$sprint_name" "$complete_payload" "in_progress" "completed"

  # Auto-generate sprint-current.json cache
  generate_sprint_current_json "$sprint_num"

  log "✓ Sprint $sprint_name marked completed"
  echo "{\"sprint\":\"$sprint_name\",\"sprint_number\":$sprint_num,\"from_status\":\"in_progress\",\"to_status\":\"completed\",\"ceremony\":\"$ceremony_key\",\"completed_at\":\"$ts\",\"action\":\"completed\"}"
}

# ──────────────────────────────────────────────
# MAIN DISPATCH
# ──────────────────────────────────────────────

main() {
  local cmd="${1:-help}"
  shift || true

  case "$cmd" in
    current)
      cmd_current "$@"
      ;;
    commit)
      [[ -z "${1:-}" ]] && die "Usage: db-sprint.sh commit <TKT-ID> <seq> [effort] [agent] [--sprint <name>]"
      cmd_commit "$@"
      ;;
    status)
      cmd_status "$@"
      ;;
    plan)
      cmd_plan "$@"
      ;;
    create)
      [[ -z "${1:-}" ]] && die "Usage: db-sprint.sh create \"<Sprint X>\" \"<dates>\""
      cmd_create "$1" "${2:-}"
      ;;
    defer)
      [[ -z "${1:-}" ]] && die "Usage: db-sprint.sh defer <TKT-ID> --to <Sprint X> --reason \"...\""
      cmd_defer "$@"
      ;;
    migrate)
      cmd_migrate "$@"
      ;;
    next-ticket)
      cmd_next_ticket "$@"
      ;;
    activate)
      cmd_activate "$@"
      ;;
    complete)
      if [[ "$#" -eq 0 || "${1:-}" == --* ]]; then
        if [[ "${1:-}" == "--dry-run" ]]; then
          # Handle: complete --dry-run without sprint name (use current)
          sprint_name=$(get_current_sprint_name)
          set -- "$sprint_name" "$@"
        elif [[ "${1:-}" == "--help" ]]; then
          # Pass --help through to cmd_complete
          :
        else
          die "Usage: db-sprint.sh complete \"<Sprint N>\" [--dry-run]"
        fi
      fi
      cmd_complete "$@"
      ;;
    ceremony)
      cmd_ceremony "$@"
      ;;
    export)
      cmd_export "$@"
      ;;
    help|--help|-h)
      usage
      ;;
    *)
      echo "ERROR: Unknown subcommand: '$cmd'" >&2
      cat <<'USAGE_ERR'
Usage: db-sprint.sh <subcommand> [args...]

Subcommands:
  current                              - Current sprint as JSON from PG
  next-ticket [--agent <name>]        - Return next ticket to work as JSON (TKT-0728)
  activate [--dry-run]                 - Transition committed sprints whose start_date <= today to in_progress
  commit <TKT-ID> <seq> <effort> <agent> [--sprint <name>] - Commit ticket to sprint
  status [--sprint <name>]             - Sprint progress with dependency graph
  plan [--sprint <name>]               - Sprint planning view
  create "<Sprint X>" "<dates>"        - Create new sprint in PG
  defer <TKT-ID> --to <Sprint X> --reason "..." - Defer ticket
  migrate [--sprint <name>]            - Migrate sprint JSON → PG
  ceremony complete <review|planning> [--sprint <name>] - Log ceremony to PG
  complete "<Sprint N>" [--dry-run]    - Mark sprint completed (updates status, logs ceremony, regenerates cache)
  export [--sprint <name>]             - Export read-only JSON summary of sprint (derived from PG)
  help                                 - Show this usage
USAGE_ERR
      exit 1
      ;;
  esac
}

main "$@"
