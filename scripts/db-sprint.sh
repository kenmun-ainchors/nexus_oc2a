#!/bin/bash
# db-sprint.sh — Sprint Operations PG-First (TKT-0369-B)
# Author: Forge (Infrastructure & SRE Agent)
# Created: 2026-06-10
#
# SKILL GATE: pg-sprint-backlog skill MUST be loaded before use.
source "${SCRIPT_DIR:-$(dirname "$0")}/skill-gate.sh" "pg-sprint-backlog" || exit $?
#
# Subcommands:
#   current                        — Current sprint as JSON from PG
#   commit <TKT-ID> <seq> <effort> <agent> — Commit ticket to sprint in PG
#   status [--sprint Sprint7]      — Sprint progress with dependency graph
#   plan [--sprint Sprint7]        — Sprint planning view
#   create "<Sprint X>" "<dates>"  — Create a new sprint in PG
#   defer <TKT-ID> --to <Sprint X> --reason "..." — Defer ticket to another sprint
#   migrate [--sprint Sprint7]     — Migrate sprint JSON data to PG
#   ceremony complete <review|planning> [--sprint Sprint7] — Log ceremony completion to PG

set -u

# --- CONSTANTS ---
WORKSPACE_ROOT="/Users/ainchorsangiefpl/.openclaw/workspace"
DB_SCRIPT="$WORKSPACE_ROOT/scripts/db.sh"
JQ="/opt/homebrew/bin/jq"
TICKET_TABLE="state_tickets"
TICKET_SCRIPT="$WORKSPACE_ROOT/scripts/db-ticket.sh"
SPRINT_TABLE="state_sprints"
TICKET_FILE="$WORKSPACE_ROOT/state/tickets.json"

# --- UTILITIES ---
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] db-sprint: $1" >&2; }
die() { echo "ERROR: $1" >&2; exit 1; }

usage() {
  cat <<'USAGE'
Usage: db-sprint.sh <subcommand> [args...]

Subcommands:
  current                              — Return current sprint as JSON from PG
  commit <TKT-ID> <seq> <effort> <agent> — Commit ticket to sprint (sets metadata.sprint_target)
  status [--sprint <name>]             — Sprint progress with dependency graph
  plan [--sprint <name>]               — Sprint planning view: all committed items
  create "<Sprint X>" "<dates>"        — Create a new sprint in PG
  defer <TKT-ID> --to <Sprint X> --reason "..." — Defer ticket to another sprint
  migrate [--sprint <name>]            — Migrate sprint JSON → PG metadata
  ceremony complete <review|planning> [--sprint <name>] — Log ceremony to PG + auto-gen sprint-current.json
  help                                 — Show this usage
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
  # 2. Sprint with status='active' or status='committed' (legacy states)
  # 3. Most recent sprint by number
  # 4. Most common sprint_target in open tickets
  # 5. Hard fallback: Sprint 7
  local name
  name=$(pg_query "SELECT sprint_name FROM $SPRINT_TABLE WHERE status='in_progress' OR status='active' ORDER BY sprint_number DESC LIMIT 1;" 2>/dev/null | head -1)
  if [[ -z "$name" ]]; then
    name=$(pg_query "SELECT sprint_name FROM $SPRINT_TABLE WHERE status='committed' ORDER BY sprint_number DESC LIMIT 1;" 2>/dev/null | head -1)
  fi
  if [[ -z "$name" ]]; then
    name=$(pg_query "SELECT sprint_name FROM $SPRINT_TABLE ORDER BY sprint_number DESC LIMIT 1;" 2>/dev/null | head -1)
  fi
  if [[ -z "$name" ]]; then
    name=$(pg_query "SELECT metadata->>'sprint_target' FROM $TICKET_TABLE WHERE status IN ('open','in-progress','pending','backlog','grooming') AND metadata->>'sprint_target' IS NOT NULL GROUP BY metadata->>'sprint_target' ORDER BY COUNT(*) DESC LIMIT 1;" 2>/dev/null | head -1)
  fi
  # Normalize: extract just "Sprint N" from potentially longer names like "Sprint 7 — ..."
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
  
  # Get sprint row from PG — try exact name match, then prefix match
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
  
  # Get ticket counts for this sprint
  local ticket_count
  ticket_count=$(pg_query "SELECT COUNT(*) FROM $TICKET_TABLE WHERE (sprint = '$sprint_name' OR metadata->>'sprint_target' = '$sprint_name');" 2>/dev/null | head -1)
  local done_count
  done_count=$(pg_query "SELECT COUNT(*) FROM $TICKET_TABLE WHERE (sprint = '$sprint_name' OR metadata->>'sprint_target' = '$sprint_name') AND status IN ('closed','done','folded');" 2>/dev/null | head -1)
  
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
  local tkt_id="$1"
  local seq="$2"
  local effort="$3"
  local agent="$4"
  
  if [[ -z "$tkt_id" || -z "$seq" ]]; then
    die "Usage: db-sprint.sh commit <TKT-ID> <seq> <effort> <agent>"
  fi
  
  if ! ticket_exists "$tkt_id"; then
    die "Ticket $tkt_id not found in PG"
  fi
  
  local sprint_name
  sprint_name=$(get_current_sprint_name)
  
  log "Committing $tkt_id to $sprint_name (seq=$seq, effort=$effort, agent=$agent)"
  
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
    --arg ts "$(date -u '+%Y-%m-%dT%H:%M:%S+10:00')" \
    '. + {
      sprint_target: $sprint,
      sprint_seq: ($seq | tonumber),
      sprint_effort: $effort,
      sprint_agent: $agent,
      sprint_committed_at: $ts
    }' 2>/dev/null)
  
  write_metadata "$tkt_id" "$updated_meta"
  
  # Also populate the proper sprint columns (TKT-0391)
  pg_query "UPDATE $TICKET_TABLE SET sprint='$sprint_name', sprint_seq=$seq, updated_at=NOW() WHERE id='$tkt_id';" > /dev/null 2>&1 || true
  
  # Also update state_sprints.items if sprint row exists
  local sprint_num
  sprint_num=$(sprint_name_to_number "$sprint_name")
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
  
  # Query all tickets in this sprint (column-first, JSONB fallback TKT-0391)
  local tickets
  tickets=$(pg_query "SELECT id, title, status, metadata FROM $TICKET_TABLE WHERE (sprint = '$sprint_name' OR metadata->>'sprint_target' = '$sprint_name') ORDER BY COALESCE(sprint_seq, (metadata->>'sprint_seq')::int, 999), id;" 2>/dev/null)
  
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
  ticket_json=$(pg_query "SELECT jsonb_agg(t ORDER BY seq_num, id) FROM (SELECT t.*, COALESCE(t.sprint_seq, (t.metadata->>'sprint_seq')::int, 999) AS seq_num FROM $TICKET_TABLE t WHERE (t.sprint = '$sprint_name' OR t.metadata->>'sprint_target' = '$sprint_name')) t;" 2>/dev/null)
  
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
    ($meta.sprint_seq // "---") as $seq |
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
    echo "  (No PG sprint row found — showing ticket-level data only)"
  fi
  echo ""
  
  # Query all committed tickets (column-first, JSONB fallback TKT-0391)
  local ticket_json
  ticket_json=$(pg_query "SELECT jsonb_agg(row_to_json(t) ORDER BY COALESCE(t.sprint_seq, (t.metadata->>'sprint_seq')::int, 999), t.id) FROM $TICKET_TABLE t WHERE (t.sprint = '$sprint_name' OR t.metadata->>'sprint_target' = '$sprint_name');" 2>/dev/null)
  
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
      (.metadata.sprint_seq // "?"),
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
    echo "$ticket_json" | $JQ -r '.[] | select(.metadata.deferred_from != null) | "  \(.id): from \(.metadata.deferred_from) → \(.metadata.sprint_target) — \(.metadata.deferred_reason // "no reason")"' 2>/dev/null
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
    --arg ts "$(date -u '+%Y-%m-%dT%H:%M:%S+10:00')" \
    '. + {
      sprint_target: $to,
      deferred: true,
      deferred_from: $from,
      deferred_reason: $reason,
      deferred_at: $ts
    } | del(.sprint_seq) | del(.sprint_effort)' 2>/dev/null)
  
  write_metadata "$tkt_id" "$updated_meta"
  
  # Also update the proper sprint column (TKT-0391)
  pg_query "UPDATE $TICKET_TABLE SET sprint='$target_sprint', sprint_seq=NULL, updated_at=NOW() WHERE id='$tkt_id';" > /dev/null 2>&1 || true
  
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
        echo "  CONFLICT: $tkt_id — PG says '$current_target', JSON says '$sprint_name' (status=$current_status)"
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
      # Also populate the proper sprint columns (TKT-0391)
      pg_query "UPDATE $TICKET_TABLE SET sprint='$sprint_name', sprint_seq=$seq, updated_at=NOW() WHERE id='$tkt_id';" > /dev/null 2>&1 || true
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
      # Also populate the proper sprint columns (TKT-0391)
      pg_query "UPDATE $TICKET_TABLE SET sprint='$sprint_name', sprint_seq=$seq, updated_at=NOW() WHERE id='$tkt_id';" > /dev/null 2>&1 || true
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
    log "✓ Migration complete — $migrated tickets migrated to $sprint_name"
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
    log "No PG sprint row for sprint $sprint_num — cannot generate sprint-current.json"
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
    'generated_at': '$(date -u '+%Y-%m-%dT%H:%M:%S+10:00')'
}

print(json.dumps(cache, indent=2))
" <<< "$sprint_json" > "$WORKSPACE_ROOT/state/sprint-current.json"
  
  log "✓ sprint-current.json auto-generated from PG"
  return 0
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
  ts=$(date -u '+%Y-%m-%dT%H:%M:%S+10:00')
  
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
  
  echo "{\"ceremony\":\"$ceremony_key\",\"sprint\":\"$sprint_name\",\"completed_at\":\"$ts\",\"status\":\"logged\",\"cache\":\"sprint-current.json auto-generated\"}"
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
      [[ -z "${1:-}" || -z "${2:-}" ]] && die "Usage: db-sprint.sh commit <TKT-ID> <seq> <effort> <agent>"
      cmd_commit "$1" "$2" "${3:-?}" "${4:-?}"
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
    ceremony)
      cmd_ceremony "$@"
      ;;
    help|--help|-h)
      usage
      ;;
    *)
      echo "ERROR: Unknown subcommand: '$cmd'" >&2
      cat <<'USAGE_ERR'
Usage: db-sprint.sh <subcommand> [args...]

Subcommands:
  current                              — Current sprint as JSON from PG
  commit <TKT-ID> <seq> <effort> <agent> — Commit ticket to sprint
  status [--sprint <name>]             — Sprint progress with dependency graph
  plan [--sprint <name>]               — Sprint planning view
  create "<Sprint X>" "<dates>"        — Create new sprint in PG
  defer <TKT-ID> --to <Sprint X> --reason "..." — Defer ticket
  migrate [--sprint <name>]            — Migrate sprint JSON → PG
  ceremony complete <review|planning> [--sprint <name>] — Log ceremony to PG
  help                                 — Show this usage
USAGE_ERR
      exit 1
      ;;
  esac
}

main "$@"
