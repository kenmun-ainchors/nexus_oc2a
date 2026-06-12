#!/bin/bash
# db-ticket.sh — Canonical Ticket Interface (PG SSOT)
# TKT-0369-A: Structured subcommands replacing flag-based ticket.sh
# Author: Forge (Infrastructure & SRE Agent)
# Created: 2026-06-10
#
# SKILL GATE: pg-sprint-backlog skill MUST be loaded before use.
# See scripts/skill-gate.sh and infra/sandbox/seed/skills/pg-sprint-backlog/SKILL.md
source "${SCRIPT_DIR:-$(dirname "$0")}/skill-gate.sh" "pg-sprint-backlog" || exit $?
#
# Subcommands:
#   read <TKT-ID>          — Full JSON with metadata
#   create                   — Interactive guided creation (no flags!)
#   update <TKT-ID> <json>   — Validated JSON write to PG
#   groom <TKT-ID>           — Append to metadata.grooming_history[]
#   fold <TKT-ID> --into <PARENT-ID> — CHG-0456 5-gate fold SOP
#   list [filters]           — Dependency-aware queries
#   sync <TKT-ID>            — PG → Notion one-shot sync
#   validate                 — Validate all open tickets have required metadata

set -u

# --- CONSTANTS ---
WORKSPACE_ROOT="/Users/ainchorsangiefpl/.openclaw/workspace"
DB_SCRIPT="$WORKSPACE_ROOT/scripts/db.sh"
DB_READ="$WORKSPACE_ROOT/scripts/db-read.sh"
DB_WRITE="$WORKSPACE_ROOT/scripts/db-write.sh"
SYNC_SCRIPT="$WORKSPACE_ROOT/scripts/pg-to-notion-sync.sh"
JQ="/opt/homebrew/bin/jq"
TICKET_TABLE="state_tickets"
TICKET_FILE="$WORKSPACE_ROOT/state/tickets.json"

# --- UTILITIES ---
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] db-ticket: $1" >&2; }
die() { echo "ERROR: $1" >&2; exit 1; }
usage() {
  cat <<'USAGE'
Usage: db-ticket.sh <subcommand> [args...]

Subcommands:
  read <TKT-ID>                        — Return full ticket as JSON (id, title, status, priority, metadata)
  create                                 — Interactive guided ticket creation (no flags!)
  update <TKT-ID> '<json-payload>'        — Validate and write JSON to PG
  groom <TKT-ID>                         — Append grooming entry to metadata.grooming_history[]
  fold <TKT-ID> --into <PARENT-ID>       — CHG-0456 5-gate fold: extract→migrate→close→sync
  list [--status <s>] [--blocked-by <T>] [--sprint <S>] [--open] [--blocked] — Query tickets
  sync <TKT-ID>                          — One-shot PG→Notion sync for single ticket
  validate                               — Validate all open tickets have required metadata fields
  help                                   — Show this usage

Flags are NOT accepted. Unknown subcommands print this usage and exit 1.
USAGE
  exit 0
}

flag_reject() {
  local cmd="$1"
  shift
  for arg in "$@"; do
    if [[ "$arg" == --* ]]; then
      if [[ "$cmd" == "create" ]]; then
        die "ERROR: db-ticket.sh create uses interactive prompts, not flags. Just run: db-ticket.sh create"
      else
        die "ERROR: db-ticket.sh $cmd does not accept flags. Use positional arguments. See: db-ticket.sh help"
      fi
    fi
  done
}

# --- PG QUERY HELPERS ---

pg_query() {
  # Run a query, return raw PSQL output
  bash "$DB_SCRIPT" -c "$1" 2>/dev/null
}

pg_query_json() {
  # Run query expecting row_to_json output
  bash "$DB_READ" "$1"
}

ticket_exists() {
  local tkt_id="$1"
  local result
  result=$(pg_query "SELECT id FROM $TICKET_TABLE WHERE id='$tkt_id';")
  [[ -n "$result" && "$result" == *"$tkt_id"* ]]
}

get_ticket_json() {
  # Return full ticket as JSON including metadata
  # L-077 / CHG-0503: PG-only. The state/tickets.json stub (3 entries) was misleading
  # read operations into returning false data. Option B (Ken-approved 2026-06-12 08:25):
  # make read PG-only, fail loud when ticket not in PG. This applies to all read paths:
  # read, update, groom, fold, list — all use this function.
  # Note: we return empty stdout on miss instead of `return 1` to avoid set -euo pipefail
  # (sourced from skill-gate.sh) killing the script before the caller's error message.
  local tkt_id="$1"
  local result

  result=$(pg_query "SELECT row_to_json(t)::text FROM $TICKET_TABLE t WHERE id='$tkt_id' LIMIT 1;" 2>/dev/null)

  if [[ -z "$result" || "$result" == "null" ]]; then
    return 0  # empty stdout signals "not found"
  fi

  echo "$result"
}

get_metadata() {
  # Extract metadata JSONB from ticket
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
  # Write metadata JSONB to ticket using direct PG query
  local tkt_id="$1"
  local meta_json="$2"
  
  # Validate JSON
  if ! echo "$meta_json" | $JQ empty 2>/dev/null; then
    die "Invalid JSON for metadata update"
  fi
  
  # Escape single quotes for PG
  local escaped
  escaped=$(echo "$meta_json" | sed "s/'/''/g")
  
  pg_query "UPDATE $TICKET_TABLE SET metadata='$escaped'::jsonb, updated_at=NOW() WHERE id='$tkt_id';" > /dev/null 2>&1
  local ret=$?
  
  if [[ $ret -eq 0 ]]; then
    # Trigger Notion sync in background
    bash "$SYNC_SCRIPT" > /dev/null 2>&1 &
    return 0
  else
    log "PG write failed for $tkt_id metadata update"
    return 1
  fi
}

normalize_priority() {
  local val
  val=$(echo "$1" | tr '[:upper:]' '[:lower:]')
  case "$val" in
    critical|p0|urgent) echo "critical" ;;
    high|p1) echo "high" ;;
    medium|p2|normal) echo "medium" ;;
    low|p3) echo "low" ;;
    *) echo "medium" ;;
  esac
}

normalize_status() {
  local val
  val=$(echo "$1" | tr '[:upper:]' '[:lower:]')
  case "$val" in
    open|new|todo) echo "open" ;;
    in-progress|in_progress|wip|doing) echo "in-progress" ;;
    done|resolved|closed|complete) echo "closed" ;;
    pending|blocked|waiting) echo "pending" ;;
    backlog|grooming|refining) echo "backlog" ;;
    cancelled|canceled|deferred) echo "cancelled" ;;
    monitoring|monitor) echo "monitoring" ;;
    folded) echo "folded" ;;
    *) echo "open" ;;
  esac
}

# --- SCHEMA VALIDATION ---

validate_ticket_payload() {
  # Validate a JSON payload for ticket update/create
  # Returns 0 if valid, 1 with error message if invalid
  local payload="$1"
  local errors=""
  
  # Must be valid JSON
  if ! echo "$payload" | $JQ empty 2>/dev/null; then
    echo "INVALID_JSON"
    return 1
  fi
  
  # Check for known forbidden fields
  local forbidden=$(echo "$payload" | $JQ -r '
    keys[] as $k |
    if $k == "id" then "id-is-readonly"
    elif $k == "created_at" then "created_at-is-system-managed"
    else empty end
  ' 2>/dev/null)
  
  if [[ -n "$forbidden" ]]; then
    echo "FORBIDDEN_FIELD: $forbidden"
    return 1
  fi
  
  # If metadata key present, validate its structure
  if echo "$payload" | $JQ -e 'has("metadata")' > /dev/null 2>&1; then
    local meta_errors=$(echo "$payload" | $JQ -r '
      .metadata as $m |
      [
        (if ($m.brief | type) != "string" and $m.brief != null then "metadata.brief must be string" else empty end),
        (if ($m.grooming_history | type) != "array" and $m.grooming_history != null then "metadata.grooming_history must be array" else empty end),
        (if ($m.depends_on | type) != "array" and $m.depends_on != null then "metadata.depends_on must be array" else empty end),
        (if ($m.blocks | type) != "array" and $m.blocks != null then "metadata.blocks must be array" else empty end),
        (if ($m.folded_from | type) != "array" and $m.folded_from != null then "metadata.folded_from must be array" else empty end),
        (if ($m.folded_scope | type) != "array" and $m.folded_scope != null then "metadata.folded_scope must be array" else empty end),
        (if ($m.notion_sync | type) != "object" and $m.notion_sync != null then "metadata.notion_sync must be object" else empty end),
        (if ($m.sprint | type) != "string" and $m.sprint != null then "metadata.sprint must be string" else empty end),
        (if ($m.effort | type) != "string" and $m.effort != null then "metadata.effort must be string" else empty end),
        (if ($m.agent | type) != "string" and $m.agent != null then "metadata.agent must be string" else empty end)
      ] | map(select(. != null)) | join("; ")
    ' 2>/dev/null)
    
    if [[ -n "$meta_errors" ]]; then
      echo "METADATA_TYPE_ERROR: $meta_errors"
      return 1
    fi
  fi
  
  return 0
}

# ──────────────────────────────────────────────
# SUBCOMMAND: read <TKT-ID>
# ──────────────────────────────────────────────
cmd_read() {
  local tkt_id="$1"
  flag_reject "read" "$@"
  
  local ticket
  ticket=$(get_ticket_json "$tkt_id")
  if [[ -z "$ticket" ]]; then
    die "Ticket $tkt_id not found in PG (L-077/CHG-0503: read is PG-only, no file fallback)"
  fi
  
  # Pretty-print with metadata expanded
  echo "$ticket" | $JQ '
    . as $t |
    if .metadata and (.metadata | type) == "string" then
      .metadata = (.metadata | fromjson)
    else . end
  ' 2>/dev/null || echo "$ticket"
}

# ──────────────────────────────────────────────
# SUBCOMMAND: create (INTERACTIVE — NO FLAGS)
# ──────────────────────────────────────────────
cmd_create() {
  # REJECT ALL FLAGS (Failure #5 fix)
  for arg in "$@"; do
    if [[ "$arg" == --* ]]; then
      die "ERROR: db-ticket.sh create uses interactive prompts, not flags. Just run: db-ticket.sh create"
    fi
  done
  
  echo "=== db-ticket.sh: Interactive Ticket Creation ==="
  echo ""
  
  # Prompt: TKT-ID
  while true; do
    read -r -p "Ticket ID (e.g. TKT-0400): " tkt_id
    if [[ ! "$tkt_id" =~ ^TKT-[0-9]+[A-Za-z]?(-[A-Za-z0-9]+)?$ ]]; then
      echo "  Invalid format. Must be TKT-NNNN or TKT-NNNN-X"
      continue
    fi
    if ticket_exists "$tkt_id"; then
      echo "  ERROR: $tkt_id already exists. Use 'db-ticket.sh update' to modify."
      exit 1
    fi
    break
  done
  
  # Prompt: Title
  while true; do
    read -r -p "Title: " title
    if [[ -z "$title" ]]; then
      echo "  Title cannot be empty."
      continue
    fi
    break
  done
  
  # Prompt: Brief (1-2 sentence scope summary)
  echo "Brief (1-2 sentence scope summary — what this ticket delivers):"
  read -r -p "> " brief
  
  # Prompt: Priority
  while true; do
    read -r -p "Priority [critical/high/medium/low] (default: medium): " priority
    priority="${priority:-medium}"
    priority=$(normalize_priority "$priority")
    break
  done
  
  # Prompt: Type
  while true; do
    read -r -p "Type [task/bug/build/epic/story/chg] (default: task): " ticket_type
    ticket_type="${ticket_type:-task}"
    case "$ticket_type" in
      task|bug|build|epic|story|chg|feature|infra) break ;;
      *) echo "  Valid types: task, bug, build, epic, story, chg, feature, infra" ;;
    esac
  done
  
  # Prompt: Efforts
  read -r -p "Effort [XS/S/M/L/XL] (default: M): " effort
  effort="${effort:-M}"
  
  # Prompt: Agent
  read -r -p "Assigned Agent (e.g. Forge, Yoda, Aria): " agent
  
  # Prompt: AC Count
  read -r -p "Number of Acceptance Criteria (default: 1): " ac_count
  ac_count="${ac_count:-1}"
  
  # Prompt: Dependencies
  echo "Dependencies (comma-separated TKT-IDs, or leave empty):"
  read -r -p "> " deps_input
  local deps_json="[]"
  if [[ -n "$deps_input" ]]; then
    deps_json=$(echo "$deps_input" | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | grep -E '^TKT-[0-9]' | $JQ -R . | $JQ -s .)
  fi
  
  # Prompt: Sprint
  read -r -p "Sprint (e.g. Sprint7, or leave empty): " sprint
  
  # Build timestamp
  local ts
  ts=$(date -u '+%Y-%m-%dT%H:%M:%S+10:00')
  
  # Build metadata JSONB
  local metadata
  metadata=$($JQ -n \
    --arg brief "$brief" \
    --arg effort "$effort" \
    --arg agent "$agent" \
    --arg ac_count "$ac_count" \
    --arg sprint "$sprint" \
    --argjson deps "$deps_json" \
    --arg created_ts "$ts" \
    '{
      brief: $brief,
      effort: $effort,
      agent: $agent,
      ac_count: ($ac_count | tonumber),
      sprint: (if $sprint == "" then null else $sprint end),
      depends_on: $deps,
      blocks: [],
      grooming_history: [{
        date: $created_ts,
        decisions: "Ticket created via db-ticket.sh interactive create",
        ac_count: ($ac_count | tonumber),
        ken_approved: false
      }],
      folded_from: [],
      folded_scope: [],
      notion_sync: { last_synced: null, status: "pending" }
    }')
  
  # Build the PG insert payload
  local payload
  payload=$($JQ -n \
    --arg id "$tkt_id" \
    --arg title "$title" \
    --arg status "open" \
    --arg priority "$priority" \
    --arg type "$ticket_type" \
    --arg created_at "$ts" \
    --argjson metadata "$metadata" \
    '{
      id: $id,
      title: $title,
      status: $status,
      priority: $priority,
      type: $type,
      created_at: $created_at,
      metadata: $metadata
    }')
  
  echo ""
  echo "=== Review ==="
  echo "$payload" | $JQ '{id, title, status, priority, type, created_at, metadata: {brief, effort, agent, ac_count, sprint, depends_on}}'
  echo ""
  read -r -p "Create ticket? [y/N]: " confirm
  
  local confirm_lower
  confirm_lower=$(echo "$confirm" | tr '[:upper:]' '[:lower:]')
  if [[ "$confirm_lower" != "y" && "$confirm_lower" != "yes" ]]; then
    log "Creation cancelled."
    exit 0
  fi
  
  # PG write with SAFE MODE (no overwrite)
  local write_result
  DBWRITE_SAFE_MODE=1 bash "$DB_WRITE" "$TICKET_TABLE" \
    "{\"id\":\"$tkt_id\",\"title\":\"$title\",\"status\":\"open\",\"priority\":\"$priority\",\"type\":\"$ticket_type\",\"created_at\":\"$ts\",\"metadata\":$metadata}" \
    "$tkt_id" > /dev/null 2>&1
  local ret=$?
  
  if [[ $ret -eq 3 ]]; then
    die "COLLISION: $tkt_id was created between check and write. Use db-ticket.sh update instead."
  elif [[ $ret -eq 0 ]]; then
    log "Ticket $tkt_id created successfully."
    
    # Populate sprint column if sprint was provided
    if [[ -n "$sprint" ]]; then
      bash "$DB_SCRIPT" -c "UPDATE state_tickets SET sprint = '$(echo "$sprint" | sed "s/'/''/g")', updated_at = NOW() WHERE id = '$tkt_id';" > /dev/null 2>&1 || true
    fi
    
    # Also update tickets.json for backward compat
    if [[ -f "$TICKET_FILE" ]]; then
      local tmp_json
      tmp_json=$(mktemp)
      $JQ --argjson new "$(echo "$payload" | $JQ '{id, title, status, priority, type, created_at}' 2>/dev/null)" \
        '. + [$new]' "$TICKET_FILE" > "$tmp_json" 2>/dev/null && mv "$tmp_json" "$TICKET_FILE"
    fi
    
    # TKT-0406: Defer Notion sync to first groom (no sparse pages)
    # Sync is triggered by db-ticket.sh groom or update instead
    log "Ticket created in PG. Notion sync deferred to first groom."
  else
    # Check if write actually succeeded despite non-zero
    if ticket_exists "$tkt_id"; then
      log "Ticket $tkt_id created (verified post-write)."
    else
      die "Failed to create ticket $tkt_id"
    fi
  fi
}

# ──────────────────────────────────────────────
# SUBCOMMAND: update <TKT-ID> <json-payload>
# ──────────────────────────────────────────────
cmd_update() {
  local tkt_id="$1"
  local json_payload="$2"
  
  # Reject flags after tkt_id
  flag_reject "update" "$@"
  
  if [[ -z "$tkt_id" || -z "$json_payload" ]]; then
    die "Usage: db-ticket.sh update <TKT-ID> '<json-payload>'"
  fi
  
  # Validate ticket exists
  if ! ticket_exists "$tkt_id"; then
    die "Ticket $tkt_id not found"
  fi
  
  # Validate payload against schema
  local val_result
  val_result=$(validate_ticket_payload "$json_payload" 2>&1)
  if [[ $? -ne 0 ]]; then
    die "Schema validation failed: $val_result"
  fi

  # CREST DONE GATE: if closing a parent ticket, verify CREST trail is complete
  local new_status
  new_status=$(echo "$json_payload" | $JQ -r '.status // empty' 2>/dev/null)
  if [[ "$new_status" == "closed" ]] || [[ "$new_status" == "done" ]]; then
    # Check if this ticket has sub-tickets (is a parent in CREST)
    local sub_count
    sub_count=$(pg_query "SELECT COUNT(*) FROM state_tickets WHERE id LIKE '${tkt_id}-%';" 2>/dev/null | head -1 || echo "0")
    if [[ "$sub_count" -gt 0 ]]; then
      log "CREST DONE GATE: $tkt_id has $sub_count sub-tickets — verifying CREST trail..."
      local gate_script="$SCRIPT_DIR/crest-done-gate.sh"
      if [[ -x "$gate_script" ]]; then
        local gate_result
        gate_result=$("$gate_script" "$tkt_id" 2>&1)
        local gate_exit=$?
        if [[ $gate_exit -ne 0 ]]; then
          die "CREST DONE GATE FAILED: $gate_result"
        fi
        log "CREST DONE GATE PASSED: $gate_result"
      else
        log "WARNING: crest-done-gate.sh not found — gate skipped (install it for CREST enforcement)"
      fi
    fi
  fi
  
  # Write to PG — handle metadata specially (db-write has issues with nested JSONB)
  local has_metadata
  has_metadata=$(echo "$json_payload" | $JQ 'has("metadata")' 2>/dev/null)
  
  if [[ "$has_metadata" == "true" ]]; then
    # Use direct PG update for metadata to avoid db-write.sh shell escaping issues
    local meta_part
    meta_part=$(echo "$json_payload" | $JQ -c '.metadata' 2>/dev/null)
    if [[ -n "$meta_part" ]]; then
      write_metadata "$tkt_id" "$meta_part"
      
      # Sync sprint/sprint_seq/epic columns from metadata
      local sprint_val sprint_seq_val epic_val
      sprint_val=$(echo "$meta_part" | $JQ -r '.sprint // empty' 2>/dev/null)
      sprint_seq_val=$(echo "$meta_part" | $JQ -r '.sprint_seq // empty' 2>/dev/null)
      epic_val=$(echo "$meta_part" | $JQ -r '.epic // empty' 2>/dev/null)
      
      local col_updates=""
      [[ -n "$sprint_val" && "$sprint_val" != "null" ]] && col_updates+="sprint='$(echo "$sprint_val" | sed "s/'/''/g")', "
      [[ -n "$sprint_seq_val" && "$sprint_seq_val" != "null" ]] && col_updates+="sprint_seq=$sprint_seq_val, "
      [[ -n "$epic_val" && "$epic_val" != "null" ]] && col_updates+="epic='$(echo "$epic_val" | sed "s/'/''/g")', "
      
      if [[ -n "$col_updates" ]]; then
        col_updates+="updated_at=NOW()"
        bash "$DB_SCRIPT" -c "UPDATE state_tickets SET $col_updates WHERE id='$tkt_id';" > /dev/null 2>&1 || true
      fi
    fi
    
    # Handle non-metadata fields separately
    local non_meta
    non_meta=$(echo "$json_payload" | $JQ 'del(.metadata)' 2>/dev/null)
    if [[ -n "$non_meta" && "$non_meta" != "null" && "$non_meta" != "{}" ]]; then
      local write_result
      write_result=$($DB_WRITE "$TICKET_TABLE" "$non_meta" "$tkt_id" 2>&1)
    fi
    
    log "Ticket $tkt_id updated."
    
    # TKT-0406: Trigger single-ticket Notion sync in background
    bash "$0" sync "$tkt_id" > /dev/null 2>&1 &
    
    # Update tickets.json fallback
    if [[ -f "$TICKET_FILE" ]]; then
      local tmp_json
      tmp_json=$(mktemp)
      $JQ --arg id "$tkt_id" --argjson patch "$json_payload" \
        'map(if .id == $id then . + $patch else . end)' "$TICKET_FILE" > "$tmp_json" 2>/dev/null && mv "$tmp_json" "$TICKET_FILE"
    fi
  else
    local write_result
    write_result=$($DB_WRITE "$TICKET_TABLE" "$json_payload" "$tkt_id" 2>&1)
    if echo "$write_result" | grep -q "degraded"; then
      log "WARNING: PG write degraded ($write_result). Ticket may only exist in file fallback."
    else
      log "Ticket $tkt_id updated."
      
      # TKT-0406: Trigger single-ticket Notion sync in background
      bash "$0" sync "$tkt_id" > /dev/null 2>&1 &
      
      # Update tickets.json fallback
      if [[ -f "$TICKET_FILE" ]]; then
        local tmp_json
        tmp_json=$(mktemp)
        $JQ --arg id "$tkt_id" --argjson patch "$json_payload" \
          'map(if .id == $id then . + $patch else . end)' "$TICKET_FILE" > "$tmp_json" 2>/dev/null && mv "$tmp_json" "$TICKET_FILE"
      fi
    fi
  fi
}

# ──────────────────────────────────────────────
# SUBCOMMAND: groom <TKT-ID>
# ──────────────────────────────────────────────
cmd_groom() {
  local tkt_id="$1"
  flag_reject "groom" "$@"
  
  if [[ -z "$tkt_id" ]]; then
    die "Usage: db-ticket.sh groom <TKT-ID>"
  fi
  
  if ! ticket_exists "$tkt_id"; then
    die "Ticket $tkt_id not found"
  fi
  
  local ts
  ts=$(date -u '+%Y-%m-%dT%H:%M:%S+10:00')
  
  echo "=== Grooming: $tkt_id ==="
  
  # Show current brief/title
  local current_meta
  current_meta=$(get_metadata "$tkt_id")
  local current_title
  current_title=$(pg_query "SELECT title FROM $TICKET_TABLE WHERE id='$tkt_id';" | head -1)
  
  echo "Current title: $current_title"
  echo "Current brief: $(echo "$current_meta" | $JQ -r '.brief // "NONE"' 2>/dev/null)"
  echo ""
  
  # Prompt: decisions
  echo "Grooming decisions (what was decided, changed, or clarified):"
  read -r -p "> " decisions
  
  # Prompt: AC count
  read -r -p "AC count (current or updated): " ac_count
  ac_count="${ac_count:-0}"
  
  # Prompt: Ken approved?
  read -r -p "Ken approved? [y/N]: " ken_app
  local ken_approved="false"
  local ken_lower
  ken_lower=$(echo "$ken_app" | tr '[:upper:]' '[:lower:]')
  [[ "$ken_lower" == "y" || "$ken_lower" == "yes" ]] && ken_approved="true"
  
  # Build grooming entry
  local entry
  entry=$($JQ -n \
    --arg date "$ts" \
    --arg decisions "$decisions" \
    --arg ac_count "$ac_count" \
    --argjson ken_approved "$ken_approved" \
    '{date: $date, decisions: $decisions, ac_count: ($ac_count | tonumber), ken_approved: $ken_approved}')
  
  # Append to grooming_history
  local updated_meta
  updated_meta=$(echo "$current_meta" | $JQ --argjson entry "$entry" '
    .grooming_history = (.grooming_history // []) + [$entry] |
    .notion_sync.status = "pending"
  ' 2>/dev/null)
  
  if [[ -z "$updated_meta" ]]; then
    die "Failed to build updated metadata"
  fi
  
  write_metadata "$tkt_id" "$updated_meta"
  log "Grooming entry appended to $tkt_id"
  
  # TKT-0406: First groom triggers initial Notion sync (deferred from create)
  bash "$0" sync "$tkt_id" > /dev/null 2>&1 &
}

# ──────────────────────────────────────────────
# SUBCOMMAND: fold <TKT-ID> --into <PARENT-ID>
# CHG-0456 5-gate fold SOP
# ──────────────────────────────────────────────
cmd_fold() {
  local child_id="$1"
  local parent_id=""
  
  # Parse --into flag (this is the ONLY accepted flag in fold)
  shift
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --into)
        parent_id="$2"
        shift 2
        ;;
      --*)
        die "ERROR: db-ticket.sh fold only accepts --into <PARENT-ID>. Unknown flag: $1"
        ;;
      *)
        shift
        ;;
    esac
  done
  
  if [[ -z "$child_id" || -z "$parent_id" ]]; then
    die "Usage: db-ticket.sh fold <TKT-ID> --into <PARENT-ID>"
  fi
  
  if [[ "$child_id" == "$parent_id" ]]; then
    die "Cannot fold a ticket into itself"
  fi
  
  # Gate 0: Validate both tickets exist
  if ! ticket_exists "$child_id"; then
    die "Child ticket $child_id not found"
  fi
  if ! ticket_exists "$parent_id"; then
    die "Parent ticket $parent_id not found"
  fi
  
  local ts
  ts=$(date -u '+%Y-%m-%dT%H:%M:%S+10:00')
  
  log "=== CHG-0456 Fold SOP: $child_id → $parent_id ==="
  
  # ── GATE 1: EXTRACT ────────────────────────
  log "GATE 1/5: EXTRACT child metadata..."
  
  local child_meta
  child_meta=$(get_metadata "$child_id")
  local child_title
  child_title=$(pg_query "SELECT title FROM $TICKET_TABLE WHERE id='$child_id';" | head -1)
  local child_status
  child_status=$(pg_query "SELECT status FROM $TICKET_TABLE WHERE id='$child_id';" | head -1)
  
  if [[ "$child_status" == "folded" ]]; then
    die "Child ticket $child_id is already folded"
  fi
  
  local child_brief
  child_brief=$(echo "$child_meta" | $JQ -r '.brief // ""')
  local child_effort
  child_effort=$(echo "$child_meta" | $JQ -r '.effort // "M"')
  local child_ac_count
  child_ac_count=$(echo "$child_meta" | $JQ -r '.ac_count // 0')
  
  log "  Child: $child_title"
  log "  Brief: $child_brief"
  log "  Status: $child_status"
  
  # ── GATE 2: MIGRATE ────────────────────────
  log "GATE 2/5: MIGRATE scope to parent..."
  
  local parent_meta
  parent_meta=$(get_metadata "$parent_id")
  
  # Build fold scope entry
  local scope_entry
  scope_entry=$($JQ -n \
    --arg tkt_id "$child_id" \
    --arg title "$child_title" \
    --arg brief "$child_brief" \
    --arg ac_count "$child_ac_count" \
    --arg effort "$child_effort" \
    --arg folded_at "$ts" \
    '{
      tkt_id: $tkt_id,
      title: $title,
      brief: $brief,
      ac_count: ($ac_count | tonumber),
      effort: $effort,
      folded_at: $folded_at
    }')
  
  # Update parent metadata
  local updated_parent_meta
  updated_parent_meta=$(echo "$parent_meta" | $JQ \
    --argjson entry "$scope_entry" \
    --arg child_id "$child_id" \
    --arg ts "$ts" \
    '
    .folded_scope = (.folded_scope // []) + [$entry] |
    .folded_from = (.folded_from // []) + [$child_id] |
    .depends_on = (.depends_on // []) |
    .depends_on |= map(select(. != $child_id)) |
    .notion_sync.status = "pending"
    ' 2>/dev/null)
  
  log "  Writing updated parent metadata..."
  write_metadata "$parent_id" "$updated_parent_meta"
  
  # Also update parent's updated_at
  pg_query "UPDATE $TICKET_TABLE SET updated_at=NOW() WHERE id='$parent_id';" > /dev/null 2>&1
  
  # ── GATE 3: UPDATE child to folded ─────────
  log "GATE 3/5: UPDATE child status → folded..."
  
  local child_updated_meta
  child_updated_meta=$(echo "$child_meta" | $JQ \
    --arg folded_at "$ts" \
    --arg parent_id "$parent_id" \
    '
    .folded_into = $parent_id |
    .folded_at = $folded_at |
    .notion_sync.status = "pending"
    ' 2>/dev/null)
  
  write_metadata "$child_id" "$child_updated_meta"
  
  # ── GATE 4: CLOSE child ────────────────────
  log "GATE 4/5: CLOSE child ticket..."
  
  pg_query "UPDATE $TICKET_TABLE SET status='folded', updated_at=NOW() WHERE id='$child_id';" > /dev/null 2>&1
  
  # Update tickets.json fallback
  if [[ -f "$TICKET_FILE" ]]; then
    local tmp_json
    tmp_json=$(mktemp)
    $JQ --arg id "$child_id" 'map(if .id == $id then .status = "folded" else . end)' "$TICKET_FILE" > "$tmp_json" 2>/dev/null && mv "$tmp_json" "$TICKET_FILE"
  fi
  
  # ── GATE 5: SYNC ───────────────────────────
  log "GATE 5/5: SYNC both to Notion..."
  bash "$SYNC_SCRIPT" > /dev/null 2>&1 &
  
  log "✓ Fold complete: $child_id → $parent_id"
  echo "{\"status\":\"folded\",\"child\":\"$child_id\",\"parent\":\"$parent_id\",\"folded_at\":\"$ts\"}"
}

# ──────────────────────────────────────────────
# SUBCOMMAND: list [filters]
# ──────────────────────────────────────────────
cmd_list() {
  local filter_status=""
  local filter_blocked_by=""
  local filter_sprint=""
  local filter_blocked="false"
  local filter_open="false"
  
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --status)
        filter_status="$2"
        shift 2
        ;;
      --blocked-by)
        filter_blocked_by="$2"
        shift 2
        ;;
      --sprint)
        filter_sprint="$2"
        shift 2
        ;;
      --open)
        filter_open="true"
        shift
        ;;
      --blocked)
        filter_blocked="true"
        shift
        ;;
      --help)
        echo "Usage: db-ticket.sh list [--status <s>] [--blocked-by <TKT>] [--sprint <S>] [--open] [--blocked]"
        return 0
        ;;
      *)
        die "Unknown filter: $1. Use --status, --blocked-by, --sprint, --open, --blocked"
        ;;
    esac
  done
  
  # Build WHERE clauses
  local where_clauses=()
  
  if [[ -n "$filter_status" ]]; then
    local n_status
    n_status=$(normalize_status "$filter_status")
    where_clauses+=("status='$n_status'")
  fi
  
  if [[ "$filter_open" == "true" ]]; then
    where_clauses+=("status IN ('open','in-progress','pending','backlog','grooming','monitoring')")
  fi
  
  if [[ -n "$filter_sprint" ]]; then
    where_clauses+=("sprint='$filter_sprint'")
  fi
  
  # Build the base query — include sprint for display
  local sql="SELECT id, title, status, priority, sprint, metadata FROM $TICKET_TABLE"
  if [[ ${#where_clauses[@]} -gt 0 ]]; then
    local where_str
    where_str=$(printf " AND %s" "${where_clauses[@]}")
    sql="$sql WHERE ${where_str:5}"
  fi
  sql="$sql ORDER BY id ASC;"
  
  if [[ "$filter_blocked" == "true" ]]; then
    # Blocked: has depends_on but none of the blockers are closed/done
    sql="SELECT id, title, status, priority, sprint, metadata FROM $TICKET_TABLE t
WHERE t.metadata->'depends_on' IS NOT NULL
  AND t.metadata->'depends_on' != '[]'::jsonb
  AND NOT EXISTS (
    SELECT 1 FROM jsonb_array_elements_text(t.metadata->'depends_on') AS dep_id
    JOIN $TICKET_TABLE b ON b.id = dep_id
    WHERE b.status IN ('closed','done','resolved','folded')
  )
ORDER BY t.id ASC;"
  fi
  
  if [[ -n "$filter_blocked_by" ]]; then
    # Tickets blocked BY a specific ticket
    sql="SELECT id, title, status, priority, sprint FROM $TICKET_TABLE
WHERE metadata->'depends_on' ? '$filter_blocked_by'
ORDER BY id ASC;"
  fi
  
  # Execute
  local results
  results=$(pg_query "$sql" 2>/dev/null)
  
  if [[ -z "$results" ]]; then
    echo "No tickets found."
    return 0
  fi
  
  # Pretty-print as table — show sprint column
  printf "%-14s %-50s %-12s %-8s %-10s\n" "ID" "TITLE" "STATUS" "PRIORITY" "SPRINT"
  printf "%-14s %-50s %-12s %-8s %-10s\n" "──────" "──────────────────────────────────────────────────" "────────" "────" "────────"
  
  while IFS='|' read -r id title tstatus tpriority tsprint meta_rest; do
    [[ -z "$id" ]] && continue
    # Truncate title to 48 chars
    local short_title="${title:0:48}"
    printf "%-14s %-50s %-12s %-8s %-10s\n" "$id" "$short_title" "$tstatus" "$tpriority" "${tsprint:-}"
  done <<< "$results"
}

# ──────────────────────────────────────────────
# SUBCOMMAND: sync <TKT-ID>
# ──────────────────────────────────────────────
cmd_sync() {
  local tkt_id="$1"
  flag_reject "sync" "$@"
  
  if [[ -z "$tkt_id" ]]; then
    die "Usage: db-ticket.sh sync <TKT-ID>"
  fi
  
  if ! ticket_exists "$tkt_id"; then
    die "Ticket $tkt_id not found"
  fi
  
  log "Syncing $tkt_id to Notion..."
  
  # Update notion_sync status to syncing
  local current_meta
  current_meta=$(get_metadata "$tkt_id")
  local ts
  ts=$(date -u '+%Y-%m-%dT%H:%M:%S+10:00')
  
  local updated_meta
  updated_meta=$(echo "$current_meta" | $JQ --arg ts "$ts" '
    .notion_sync = {last_synced: $ts, status: "syncing"}
  ' 2>/dev/null)
  
  write_metadata "$tkt_id" "$updated_meta"
  
  # Run full sync
  bash "$SYNC_SCRIPT"
  local ret=$?
  
  # Update sync status after sync
  current_meta=$(get_metadata "$tkt_id")
  ts=$(date -u '+%Y-%m-%dT%H:%M:%S+10:00')
  
  if [[ $ret -eq 0 ]]; then
    updated_meta=$(echo "$current_meta" | $JQ --arg ts "$ts" '
      .notion_sync = {last_synced: $ts, status: "synced"}
    ' 2>/dev/null)
    log "Sync complete."
  else
    updated_meta=$(echo "$current_meta" | $JQ --arg ts "$ts" '
      .notion_sync = {last_synced: $ts, status: "failed"}
    ' 2>/dev/null)
    log "Sync failed."
  fi
  
  write_metadata "$tkt_id" "$updated_meta"
}

# ──────────────────────────────────────────────
# SUBCOMMAND: validate
# ──────────────────────────────────────────────
cmd_validate() {
  flag_reject "validate" "$@"
  
  log "Validating all open tickets have required metadata fields..."
  
  local open_tickets
  open_tickets=$(pg_query "SELECT id, title, status FROM $TICKET_TABLE WHERE status IN ('open','in-progress','pending','backlog','grooming','monitoring') ORDER BY id;" 2>/dev/null)
  
  if [[ -z "$open_tickets" ]]; then
    echo "No open tickets found."
    return 0
  fi
  
  local total=0
  local pass=0
  local fail=0
  local failures=()
  
  while IFS='|' read -r id title tstatus; do
    [[ -z "$id" ]] && continue
    ((total++))
    
    local meta
    meta=$(get_metadata "$id")
    local issues=""
    
    # Check required fields
    local brief
    brief=$(echo "$meta" | $JQ -r '.brief // ""' 2>/dev/null)
    if [[ -z "$brief" || "$brief" == "null" ]]; then
      issues="$issues missing_brief"
    fi
    
    local grooming
    grooming=$(echo "$meta" | $JQ -r '.grooming_history // []' 2>/dev/null)
    if [[ "$grooming" == "[]" || "$grooming" == "null" ]]; then
      issues="$issues missing_grooming_history"
    fi
    
    local notion
    notion=$(echo "$meta" | $JQ -r '.notion_sync // null' 2>/dev/null)
    if [[ "$notion" == "null" ]]; then
      issues="$issues missing_notion_sync"
    fi
    
    if [[ -n "$issues" ]]; then
      ((fail++))
      failures+=("$id: $issues")
      echo "  FAIL $id ($tstatus):$issues"
    else
      ((pass++))
    fi
  done <<< "$open_tickets"
  
  echo ""
  echo "=== Validation Results ==="
  echo "Total open tickets: $total"
  echo "Passed: $pass"
  echo "Failed: $fail"
  
  if [[ $fail -gt 0 ]]; then
    echo ""
    echo "Failed tickets:"
    for f in "${failures[@]}"; do
      echo "  $f"
    done
    return 1
  fi
  
  echo "✓ All open tickets have required metadata."
}

# ──────────────────────────────────────────────
# MAIN DISPATCH
# ──────────────────────────────────────────────

main() {
  local cmd="${1:-help}"
  shift || true
  
  case "$cmd" in
    read)
      [[ -z "${1:-}" ]] && die "Usage: db-ticket.sh read <TKT-ID>"
      # Reject flags in remaining args
      for a in "${@:2}"; do [[ "$a" == --* ]] && die "ERROR: db-ticket.sh read does not accept flags. Use positional arguments. See: db-ticket.sh help"; done
      cmd_read "$@"
      ;;
    create)
      cmd_create "$@"
      ;;
    update)
      [[ -z "${1:-}" || -z "${2:-}" ]] && die "Usage: db-ticket.sh update <TKT-ID> '<json-payload>'"
      # Reject any trailing flags (catches --force, etc.)
      for a in "${@:3}"; do
        [[ "$a" == --* ]] && die "ERROR: db-ticket.sh update does not accept flags after payload. Unknown: $a"
      done
      cmd_update "$1" "$2"
      ;;
    groom)
      [[ -z "${1:-}" ]] && die "Usage: db-ticket.sh groom <TKT-ID>"
      # Reject flags in remaining args
      for a in "${@:2}"; do [[ "$a" == --* ]] && die "ERROR: db-ticket.sh groom does not accept flags. Use: db-ticket.sh groom <TKT-ID>"; done
      cmd_groom "$1"
      ;;
    fold)
      [[ -z "${1:-}" ]] && die "Usage: db-ticket.sh fold <TKT-ID> --into <PARENT-ID>"
      cmd_fold "$@"
      ;;
    list)
      cmd_list "$@"
      ;;
    sync)
      [[ -z "${1:-}" ]] && die "Usage: db-ticket.sh sync <TKT-ID>"
      for a in "${@:2}"; do [[ "$a" == --* ]] && die "ERROR: db-ticket.sh sync does not accept flags. Use: db-ticket.sh sync <TKT-ID>"; done
      cmd_sync "$1"
      ;;
    validate)
      cmd_validate "$@"
      ;;
    help|--help|-h)
      usage
      ;;
    *)
      # Unknown subcommand — print usage and exit 1
      echo "ERROR: Unknown subcommand: '$cmd'" >&2
      cat <<'USAGE_ERR'
Usage: db-ticket.sh <subcommand> [args...]

Subcommands:
  read <TKT-ID>                        — Return full ticket as JSON
  create                                 — Interactive guided ticket creation (no flags!)
  update <TKT-ID> '<json-payload>'        — Validate and write JSON to PG
  groom <TKT-ID>                         — Append grooming entry to metadata
  fold <TKT-ID> --into <PARENT-ID>       — CHG-0456 5-gate fold SOP
  list [--status <s>] [--blocked-by <T>] [--sprint <S>] [--open] [--blocked]
  sync <TKT-ID>                          — One-shot PG→Notion sync
  validate                               — Validate all open tickets
  help                                   — Show this usage

Flags are NOT accepted. Unknown subcommands print this usage and exit 1.
USAGE_ERR
      exit 1
      ;;
  esac
}

main "$@"
