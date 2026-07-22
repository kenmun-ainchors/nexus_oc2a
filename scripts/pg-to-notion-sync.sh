#!/bin/zsh
# pg-to-notion-sync.sh v3.0 — Permanent PG (SSOT) to Notion Backlog Sync
# TKT-0768 IMPLEMENTATION
# SSOT: PostgreSQL -> Derived View: Notion DB A
#
# Live DB A schema (queried 2026-07-14 22:05 AEST):
#   - ID (title)              | Status (select)         | Priority (select)
#   - Type (select)           | Tags (multi_select)     | Sprint (rich_text)
#   - Agent (rich_text)       | Created (date)          | Updated (date)
#   - URL (url)               | CHG Ref (rich_text)     | Notion Sync (rich_text)
#   - Title (rich_text)       | tenant_id (rich_text)

set -euo pipefail

# --- SKILL GATE: notion + pg-sprint-backlog ---
source "${SCRIPT_DIR:-$(dirname "$0")}/skill-gate.sh" "notion" || exit $?
source "${SCRIPT_DIR:-$(dirname "$0")}/skill-gate.sh" "pg-sprint-backlog" || exit $?

# --- CONFIGURATION ---
WORKSPACE_ROOT="/Users/ainchorsoc2a/.openclaw/workspace"
DB_SCRIPT="$WORKSPACE_ROOT/scripts/db.sh"
NOTION_KEY_FILE="/Users/ainchorsoc2a/.config/notion/api_key"
LOCK_FILE="/tmp/pg-notion-sync.lock"
NOTION_API="https://api.notion.com/v1"
NOTION_VERSION="2022-06-28"
DB_BACKLOG="39d890b6-ece8-81bf-9c3a-eb784cf09c05"
DB_ARCHIVE="39d890b6-ece8-81fd-8826-d250c3c2df13"

# Errors file path (atomic-write target)
ERRORS_FILE="$WORKSPACE_ROOT/state/pg-notion-sync-errors.json"

# --- UTILITIES ---
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"; }
die() { echo "CRITICAL ERROR: $1" >&2; exit 1; }

# Rate limiting: 350ms sleep to stay under 3 req/sec
rate_limit() { sleep 0.35; }

# Atomic JSON write: write to .tmp then mv (preserves on crash)
atomic_write_json() {
  local target="$1"
  local body="$2"
  local tmp="${target}.tmp.$$"
  echo "$body" > "$tmp" || { log "ERROR: failed to write $tmp"; return 1; }
  mv -f "$tmp" "$target" || { log "ERROR: failed to mv $tmp -> $target"; return 1; }
}

# Load Notion Key
[[ ! -f "$NOTION_KEY_FILE" ]] && die "Notion API key missing at $NOTION_KEY_FILE"
NOTION_KEY=$(cat "$NOTION_KEY_FILE")
[[ -z "$NOTION_KEY" ]] && die "Notion API key empty at $NOTION_KEY_FILE"

# Lock handling with staleness detection
acquire_lock() {
  if ! command -v flock >/dev/null; then return 0; fi
  exec 200>"$LOCK_FILE"
  if ! flock -n 200; then
    local lock_age=$(stat -f %m "$LOCK_FILE" 2>/dev/null || echo 0)
    local now=$(date +%s)
    if (( now - lock_age > 3600 )); then
      log "Stale lock detected (>1h). Force acquiring..."
      rm -f "$LOCK_FILE"
      exec 200>"$LOCK_FILE"
      flock -n 200 || die "Failed to acquire lock after stale cleanup"
    else
      log "Sync already running. Exiting."
      exit 0
    fi
  fi
}

# --- NOTION API HELPERS ---

# Notion API call with 429 retry. Args: METHOD PATH JSON_BODY
# Echoes body to stdout; returns curl exit code.
notion_call() {
  local method="$1"
  local path="$2"
  local body="${3:-}"
  local attempt=0
  local max_attempts=4
  local resp=""
  while (( attempt < max_attempts )); do
    ((attempt++))
    if [[ -n "$body" ]]; then
      resp=$(curl -s -w "\n%{http_code}" -X "$method" "$NOTION_API$path" \
        -H "Authorization: Bearer $NOTION_KEY" -H "Notion-Version: $NOTION_VERSION" \
        -H "Content-Type: application/json" --data "$body")
    else
      resp=$(curl -s -w "\n%{http_code}" -X "$method" "$NOTION_API$path" \
        -H "Authorization: Bearer $NOTION_KEY" -H "Notion-Version: $NOTION_VERSION" \
        -H "Content-Type: application/json")
    fi
    local http_code=$(echo "$resp" | tail -1)
    local resp_body=$(echo "$resp" | sed '$d')
    if [[ "$http_code" == "429" ]]; then
      local wait=$(echo "$resp_body" | jq -r '."retry-after" // 1' 2>/dev/null || echo "1")
      log "Rate-limited (429). Sleeping ${wait}s (attempt $attempt/$max_attempts)"
      sleep "$wait"
      continue
    fi
    echo "$resp_body"
    [[ "$http_code" =~ ^2 ]] && return 0 || return 1
  done
  echo "$resp_body"
  return 1
}

# --- MAPPINGS (PG state values -> Notion select enums) ---

# Status: Notion enum is open|closed|in_progress|backlog
map_status() {
  case "$1" in
    open) echo "open" ;;
    backlog) echo "backlog" ;;
    closed|cancelled|done|folded) echo "closed" ;;
    pending|deferred|parked|monitoring|Grooming|"") echo "open" ;;
    in-progress|in_progress) echo "in_progress" ;;
    *) echo "" ;;
  esac
}

# Priority: Notion enum is critical|high|medium|low
map_priority() {
  case "$1" in
    critical|high|medium|low) echo "$1" ;;
    Critical|High) echo "high" ;;
    P0|p0) echo "critical" ;;
    P1|p1) echo "high" ;;
    P2|p2) echo "medium" ;;
    P3|p3) echo "low" ;;
    *) echo "" ;;
  esac
}

# Type: Notion enum is task|bug|feature|enhancement|incident
map_type() {
  case "$1" in
    task|bug|feature|enhancement|incident) echo "$1" ;;
    epic|Epic) echo "feature" ;;
    build|chg|change|policy) echo "task" ;;
    story|defect|improvement|refactor|review) echo "enhancement" ;;
    audit|assessment) echo "task" ;;
    infra) echo "task" ;;
    backlog) echo "task" ;;
    tkt|Tkt|TKT) echo "task" ;;
    *) echo "" ;;
  esac
}

# Normalize a PG date string ("2026-07-14 18:47:14.110546+10" or ISO) to Notion "YYYY-MM-DD"
normalize_date() {
  local raw="$1"
  [[ -z "$raw" || "$raw" == "null" ]] && { echo ""; return; }
  # Try date -j -f first (BSD/macOS)
  local normalized
  normalized=$(date -j -f "%Y-%m-%d %H:%M:%S%z" "$raw" "+%Y-%m-%d" 2>/dev/null) || \
  normalized=$(date -j -f "%Y-%m-%dT%H:%M:%S%z" "$raw" "+%Y-%m-%d" 2>/dev/null) || \
  normalized=$(echo "$raw" | grep -oE '^[0-9]{4}-[0-9]{2}-[0-9]{2}' | head -1) || \
  normalized=""
  # Validate format
  if [[ "$normalized" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    echo "$normalized"
  else
    echo ""
  fi
}

# --- SCHEMA-DRIFT GUARD ---
# Fetches live DB schema, validates required properties exist with correct types.
# Returns 0 if OK, non-zero if drift detected (prints drift details).
REQUIRED_PROPS=(
  "ID:title"
  "Title:rich_text"
  "Status:select"
  "Priority:select"
  "Type:select"
  "Tags:multi_select"
  "Sprint:rich_text"
  "Agent:rich_text"
  "Created:date"
  "Updated:date"
  "URL:url"
  "CHG Ref:rich_text"
  "Notion Sync:rich_text"
  "tenant_id:rich_text"
)

schema_check() {
  log "Schema-drift guard: fetching live DB A schema..."
  local schema_json
  schema_json=$(notion_call "GET" "/databases/$DB_BACKLOG" "") || {
    log "SCHEMA-DRIFT: failed to fetch DB A schema (network/auth error)"
    return 2
  }
  local obj_status=$(echo "$schema_json" | jq -r '.object // ""')
  if [[ "$obj_status" != "database" ]]; then
    log "SCHEMA-DRIFT: response is not a database object: $schema_json"
    return 2
  fi
  
  local drifts=()
  local prop
  for spec in "${REQUIRED_PROPS[@]}"; do
    local pname="${spec%%:*}"
    local ptype="${spec##*:}"
    local actual_type=$(echo "$schema_json" | jq -r --arg n "$pname" '.properties[$n].type // "MISSING"')
    if [[ "$actual_type" != "$ptype" ]]; then
      drifts+=("$pname expected=$ptype actual=$actual_type")
    fi
  done
  
  if (( ${#drifts[@]} > 0 )); then
    log "SCHEMA-DRIFT DETECTED:"
    for d in "${drifts[@]}"; do
      log "  - $d"
    done
    return 1
  fi
  
  log "Schema-drift guard: PASS (all ${#REQUIRED_PROPS[@]} required properties present)"
  return 0
}

# --- PAYLOAD BUILDER ---
# Echoes a Notion properties JSON object (without "parent" — caller adds for create).
build_payload() {
  # Args: tkt_id, title, status_pg, priority_pg, type_pg,
  #       sprint, agent, created_iso, updated_iso, url, chg_ref,
  #       notion_sync_text, tenant_id, tags_csv
  local tkt_id="$1" title="$2" status_pg="$3" priority_pg="$4" type_pg="$5"
  local sprint="$6" agent="$7" created_iso="$8" updated_iso="$9"
  local url="${10}" chg_ref="${11}" notion_sync_text="${12}"
  local tenant_id="${13}" tags_csv="${14}"

  # Map to Notion enums
  local n_status=$(map_status "$status_pg")
  local n_priority=$(map_priority "$priority_pg")
  local n_type=$(map_type "$type_pg")
  local n_created=$(normalize_date "$created_iso")
  local n_updated=$(normalize_date "$updated_iso")
  
  # Build tags array (multi_select) — Notion requires [{name: "tag"}] objects, not bare strings
  local tags_json="[]"
  if [[ -n "$tags_csv" ]]; then
    tags_json=$(echo "$tags_csv" | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | grep -v '^$' | jq -R '{name: .}' | jq -s '.')
  fi

  # Build property block piece-by-piece so we can set each to null when empty
  # (Notion requires explicit null, not empty string or absent for select/date/url)
  local props
  props=$(jq -n \
    --arg id "$tkt_id" \
    --arg title "$title" \
    --arg status "$n_status" \
    --arg pri "$n_priority" \
    --arg typ "$n_type" \
    --argjson tags "$tags_json" \
    --arg sprint "$sprint" \
    --arg agent "$agent" \
    --arg created "$n_created" \
    --arg updated "$n_updated" \
    --arg url "$url" \
    --arg chg_ref "$chg_ref" \
    --arg nsync "$notion_sync_text" \
    --arg tenant "$tenant_id" \
    '
    {
      "ID":            {title: [{text: {content: $id}}]},
      "Title":         {rich_text: [{text: {content: $title}}]},
      "Tags":          {multi_select: $tags},
      "Sprint":        {rich_text: [{text: {content: $sprint}}]},
      "Agent":         {rich_text: [{text: {content: $agent}}]},
      "CHG Ref":       {rich_text: [{text: {content: $chg_ref}}]},
      "Notion Sync":   {rich_text: [{text: {content: $nsync}}]},
      "tenant_id":     {rich_text: [{text: {content: $tenant}}]},
      "Status":        (if $status == "" then {select: null} else {select: {name: $status}} end),
      "Priority":      (if $pri    == "" then {select: null} else {select: {name: $pri}}    end),
      "Type":          (if $typ    == "" then {select: null} else {select: {name: $typ}}    end),
      "Created":       (if $created == "" then {date: null}    else {date: {start: $created}} end),
      "Updated":       (if $updated == "" then {date: null}    else {date: {start: $updated}} end),
      "URL":           (if $url    == "" or $url == "null" then {url: null} else {url: $url} end)
    }')
  echo "$props"
}

# --- CORE SYNC LOGIC ---

# Append an error record to the errors file (atomic).
record_error() {
  local tkt_id="$1"
  local err="$2"
  local ts=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
  local current="[]"
  [[ -f "$ERRORS_FILE" ]] && current=$(cat "$ERRORS_FILE" 2>/dev/null) || current="[]"
  [[ -z "$current" ]] && current="[]"
  local updated
  updated=$(echo "$current" | jq --arg t "$tkt_id" --arg e "$err" --arg ts "$ts" \
    '. + [{ticket:$t, error:$e, timestamp:$ts}]')
  atomic_write_json "$ERRORS_FILE" "$updated" || \
    log "WARNING: failed to record error for $tkt_id"
}

# Clear errors file (used at start of --batch run; subsequent errors get appended)
reset_errors() {
  atomic_write_json "$ERRORS_FILE" "[]" || log "WARNING: failed to reset errors file"
}

sync_ticket() {
  local tkt_id="$1"
  local dry_run="${2:-false}"
  
  # 1. Read PG Data — query columns individually to avoid JSONB null-byte corruption
  #    row_to_json on JSONB metadata can embed U+0000 which breaks jq
  local title t_status priority sprint t_type notionid created_at updated_at url_val
  local tenant_id2 chg_ref notion_sync_text meta_raw agent tags_csv

  title=$($DB_SCRIPT -c "SELECT title FROM state_tickets WHERE id='$tkt_id';" 2>/dev/null | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  [[ -z "$title" ]] && { log "TKT-ID $tkt_id not found in PG. Skipping."; return 1; }
  
  t_status=$($DB_SCRIPT -c "SELECT status FROM state_tickets WHERE id='$tkt_id';" 2>/dev/null | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  priority=$($DB_SCRIPT -c "SELECT priority FROM state_tickets WHERE id='$tkt_id';" 2>/dev/null | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  sprint=$($DB_SCRIPT -c "SELECT COALESCE(sprint,'') FROM state_tickets WHERE id='$tkt_id';" 2>/dev/null | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  t_type=$($DB_SCRIPT -c "SELECT type FROM state_tickets WHERE id='$tkt_id';" 2>/dev/null | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  notionid=$($DB_SCRIPT -c "SELECT COALESCE(notionpageid,'') FROM state_tickets WHERE id='$tkt_id';" 2>/dev/null | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  created_at=$($DB_SCRIPT -c "SELECT created_at::text FROM state_tickets WHERE id='$tkt_id';" 2>/dev/null | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  updated_at=$($DB_SCRIPT -c "SELECT updated_at::text FROM state_tickets WHERE id='$tkt_id';" 2>/dev/null | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  url_val=$($DB_SCRIPT -c "SELECT COALESCE(url,'') FROM state_tickets WHERE id='$tkt_id';" 2>/dev/null | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  tenant_id2=$($DB_SCRIPT -c "SELECT COALESCE(tenant_id2,'') FROM state_tickets WHERE id='$tkt_id';" 2>/dev/null | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  tags_csv=$($DB_SCRIPT -c "SELECT COALESCE(string_agg(tag, ','), '') FROM (SELECT unnest(tags) AS tag FROM state_tickets WHERE id='$tkt_id') t WHERE tag IS NOT NULL AND tag <> '';" 2>/dev/null | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  meta_raw=$($DB_SCRIPT -c "SELECT metadata::text FROM state_tickets WHERE id='$tkt_id';" 2>/dev/null | tr -d '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  
  # Fallback for missing created_at
  [[ -z "$created_at" || "$created_at" == "null" ]] && created_at="$updated_at"
  [[ -z "$created_at" ]] && created_at="2026-04-25"  # Platform Day 1
  
  # Parse metadata
  local meta="{}"
  [[ -n "$meta_raw" ]] && meta=$(echo "$meta_raw" | jq -c '.' 2>/dev/null || echo "{}")
  
  agent=$(echo "$meta" | jq -r '.agent // ""' 2>/dev/null)
  [[ "$agent" == "null" ]] && agent=""
  chg_ref=$(echo "$meta" | jq -r '.chg_ref // .resolution // ""' 2>/dev/null)
  [[ "$chg_ref" == "null" ]] && chg_ref=""
  # Notion rich_text content limit: 2000 chars
  if [[ ${#chg_ref} -gt 2000 ]]; then
    chg_ref="${chg_ref:0:1997}..."
    log "WARN: chg_ref truncated to 2000 chars for $tkt_id"
  fi
  notion_sync_text=$(echo "$meta" | jq -r '.notion_sync.last_synced // ""' 2>/dev/null)
  [[ "$notion_sync_text" == "null" ]] && notion_sync_text=""
  
  # Build payload (14 props matching live DB A schema)
  local payload
  payload=$(jq -n --argjson props "$(build_payload "$tkt_id" "$title" "$t_status" "$priority" "$t_type" "$sprint" "$agent" "$created_at" "$updated_at" "$url_val" "$chg_ref" "$notion_sync_text" "$tenant_id2" "$tags_csv")" \
    '{properties: $props}')
  
  # Validate payload before hitting API
  local prop_count=$(echo "$payload" | jq '.properties | keys | length')
  if [[ "$prop_count" -ne 14 ]]; then
    log "INTERNAL ERROR: payload for $tkt_id has $prop_count properties, expected 14"
    record_error "$tkt_id" "payload property count=$prop_count (expected 14)"
    return 1
  fi
  
  if [[ "$dry_run" == "true" ]]; then
    log "[DRY-RUN] Payload for $tkt_id:"
    echo "$payload" | jq '.'
    return 0
  fi
  
  # 2. Resolve Notion page (link or create)
  local live_notionid=""
  if [[ -n "$notionid" ]]; then
    # Verify stored notionpageid still exists (post-OC1 migration: many 404)
    rate_limit
    local verify=$(notion_call "GET" "/pages/$notionid" "")
    local verify_obj=$(echo "$verify" | jq -r '.object // ""')
    if [[ "$verify_obj" == "page" ]]; then
      live_notionid="$notionid"
    else
      log "Stale notionpageid for $tkt_id ($notionid returned $verify_obj). Will create new."
      # Clear stale id in PG
      $DB_SCRIPT -c "UPDATE state_tickets SET notionpageid = NULL, updated_at = NOW() WHERE id = '$tkt_id';" > /dev/null 2>&1
    fi
  fi
  
  if [[ -z "$live_notionid" ]]; then
    # Search by ID (title field) to avoid duplicates
    rate_limit
    local search_body
    search_body=$(jq -n --arg t "$tkt_id" '{"filter": {"property": "ID", "title": {"equals": $t}}, "page_size": 1}')
    local search_resp
    search_resp=$(notion_call "POST" "/databases/$DB_BACKLOG/query" "$search_body")
    local found_id
    found_id=$(echo "$search_resp" | jq -r '.results[0].id // ""')
    if [[ -n "$found_id" ]]; then
      log "Linking existing Notion page $found_id to $tkt_id"
      $DB_SCRIPT -c "UPDATE state_tickets SET notionpageid = '$found_id', updated_at = NOW() WHERE id = '$tkt_id';" > /dev/null 2>&1
      live_notionid="$found_id"
    else
      # Create new page
      local create_payload
      create_payload=$(echo "$payload" | jq --arg db "$DB_BACKLOG" '.parent = {database_id: $db}')
      rate_limit
      local create_resp
      create_resp=$(notion_call "POST" "/pages" "$create_payload")
      local new_pid
      new_pid=$(echo "$create_resp" | jq -r '.id // ""')
      if [[ -z "$new_pid" ]]; then
        log "Failed to create Notion page for $tkt_id: $create_resp"
        record_error "$tkt_id" "create failed: $(echo "$create_resp" | jq -c '.message // .' 2>/dev/null | head -c 200)"
        return 1
      fi
      log "Created Notion page $new_pid for $tkt_id"
      $DB_SCRIPT -c "UPDATE state_tickets SET notionpageid = '$new_pid', updated_at = NOW() WHERE id = '$tkt_id';" > /dev/null 2>&1
      live_notionid="$new_pid"
    fi
  fi
  
  # 3. Update Notion page
  rate_limit
  local upd_resp
  upd_resp=$(notion_call "PATCH" "/pages/$live_notionid" "$payload")
  local upd_id
  upd_id=$(echo "$upd_resp" | jq -r '.id // ""')
  if [[ -z "$upd_id" ]]; then
    log "Failed to update Notion page $live_notionid for $tkt_id: $upd_resp"
    record_error "$tkt_id" "update failed: $(echo "$upd_resp" | jq -c '.message // .' 2>/dev/null | head -c 200)"
    return 1
  fi
  
  # 4. Mark PG as synced
  local ts_now=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
  $DB_SCRIPT -c "UPDATE state_tickets SET metadata = jsonb_set(metadata, '{notion_sync}', '{\"status\":\"synced\",\"last_synced\":\"$ts_now\"}'), updated_at = NOW() WHERE id = '$tkt_id';" > /dev/null 2>&1
  log "Successfully synced $tkt_id -> $live_notionid"
  return 0
}

# --- MODES ---

# Paginate through a Notion database query and return total result count
_notion_db_count() {
  local db_id="$1"
  local total=0
  local next_cursor=""
  local has_more="true"
  while [[ "$has_more" == "true" ]]; do
    local body
    if [[ -n "$next_cursor" ]]; then
      body=$(jq -n --arg c "$next_cursor" '{page_size:100, start_cursor:$c}')
    else
      body='{"page_size":100}'
    fi
    rate_limit
    local resp
    resp=$(notion_call "POST" "/databases/$db_id/query" "$body")
    local page_count
    page_count=$(echo "$resp" | jq '.results | length' 2>/dev/null || echo 0)
    total=$((total + page_count))
    next_cursor=$(echo "$resp" | jq -r '.next_cursor // ""')
    has_more=$(echo "$resp" | jq -r '.has_more // false')
  done
  echo "$total"
}

do_audit() {
  log "Running Integrity Audit..."
  
  # 1. Count Check (paginated — TKT-0406 audit previously capped at 100 pages)
  local pg_count
  pg_count=$($DB_SCRIPT -c "SELECT count(*) FROM state_tickets;" | tr -d '[:space:]')
  local n_pages
  n_pages=$(_notion_db_count "$DB_BACKLOG")
  local mismatch=$((pg_count - n_pages))
  [[ "$mismatch" -lt 0 ]] && mismatch=$((mismatch * -1))
  local overall="pass"
  local message="PG and Notion counts within tolerance"
  if [[ "$mismatch" -gt 5 ]]; then
    overall="fail"
    message="Mismatch detected: PG=$pg_count, Notion=$n_pages, delta=$mismatch"
  fi
  
  jq -n \
    --arg overall "$overall" \
    --argjson pg_count "$pg_count" \
    --argjson notion_count "$n_pages" \
    --argjson mismatch "$mismatch" \
    --arg message "$message" \
    '{overall:$overall, pg_count:$pg_count, notion_count:$notion_count, mismatch:$mismatch, message:$message}'
}

do_batch() {
  local reset_err="${1:-true}"
  local force_all="${2:-false}"  # When true, sync every ticket (one-time full backfill)
  log "Running Batch Reconciliation (force_all=$force_all)..."
  if [[ "$reset_err" == "true" ]]; then
    reset_errors
  fi
  
  # Tee progress to a log file for forensic record
  local batch_log="/tmp/pg-notion-batch-$(date +%Y%m%d-%H%M%S).log"
  exec > >(tee -a "$batch_log") 2>&1
  log "Batch progress log: $batch_log"
  
  # Find target tickets
  local tickets
  if [[ "$force_all" == "true" ]]; then
    # Process every ticket; sync_ticket() is idempotent (creates if missing, updates if exists,
    # auto-detects 404 stale notionpageid and recreates).
    tickets=$($DB_SCRIPT -c "SELECT id FROM state_tickets ORDER BY updated_at;" 2>/dev/null | { grep "^TKT-" || true; })
    log "force_all=true: processing all tickets (one-time full backfill)"
  else
    # Normal: only tickets that PG metadata says are NOT synced
    tickets=$($DB_SCRIPT -c "SELECT id FROM state_tickets WHERE (metadata->'notion_sync'->>'status' IS NULL OR metadata->'notion_sync'->>'status' != 'synced') ORDER BY updated_at;" 2>/dev/null | { grep "^TKT-" || true; })
  fi
  
  if [[ -z "$tickets" ]]; then
    log "All tickets synced. Nothing to do."
    return 0
  fi
  
  local total=$(echo "$tickets" | wc -l | tr -d '[:space:]')
  log "Found $total target ticket(s). Starting backfill..."
  
  local i=0
  local failed=0
  while IFS= read -r t; do
    [[ -z "$t" ]] && continue
    ((i++))
    if ! sync_ticket "$t" "false"; then
      ((failed++))
    fi
    # Progress heartbeat every 25 tickets
    if (( i % 25 == 0 )); then
      log "Progress: $i / $total processed ($failed failed so far)"
    fi
  done <<< "$tickets"
  
  log "Batch complete: $i processed, $failed failed"
  return 0
}

do_sprint() {
  local sprint_name="$1"
  log "Syncing all tickets in sprint: $sprint_name"
  local tickets
  tickets=$($DB_SCRIPT -c "SELECT id FROM state_tickets WHERE sprint = '$sprint_name';" | grep "^TKT-")
  while IFS= read -r t; do
    [[ -n "$t" ]] && sync_ticket "$t" "false" || true
  done <<< "$tickets"
}

# --- STATUS MAPPING TEST ---
do_test_status() {
  local failures=0
  local total=0

  # Status mapping tests: input:expected
  for pair in \
    "open:open" \
    "in_progress:in_progress" \
    "in-progress:in_progress" \
    "done:closed" \
    "closed:closed" \
    "backlog:backlog" \
    "cancelled:closed" \
    "pending:open" \
    "monitoring:open" \
    "folded:closed" \
    "garbage_value:" \
    ":open"; do
    ((total++))
    input="${pair%%:*}"
    expected="${pair#*:}"
    result=$(map_status "$input")
    if [[ "$result" != "$expected" ]]; then
      echo "FAIL: map_status('$input') = '$result' (expected '$expected')"
      ((failures++))
    else
      echo "PASS: map_status('$input') = '$result'"
    fi
  done

  # Priority mapping
  for pair in \
    "critical:critical" \
    "high:high" \
    "medium:medium" \
    "low:low" \
    "P0:critical" \
    "p1:high" \
    "P2:medium" \
    "garbage:"; do
    ((total++))
    input="${pair%%:*}"
    expected="${pair#*:}"
    result=$(map_priority "$input")
    if [[ "$result" != "$expected" ]]; then
      echo "FAIL: map_priority('$input') = '$result' (expected '$expected')"
      ((failures++))
    else
      echo "PASS: map_priority('$input') = '$result'"
    fi
  done

  # Type mapping
  for pair in \
    "task:task" \
    "bug:bug" \
    "feature:feature" \
    "epic:feature" \
    "build:task" \
    "audit:task" \
    "garbage:"; do
    ((total++))
    input="${pair%%:*}"
    expected="${pair#*:}"
    result=$(map_type "$input")
    if [[ "$result" != "$expected" ]]; then
      echo "FAIL: map_type('$input') = '$result' (expected '$expected')"
      ((failures++))
    else
      echo "PASS: map_type('$input') = '$result'"
    fi
  done

  echo ""
  echo "=== Mapping Test Results ==="
  echo "Total: $total, Passed: $((total - failures)), Failed: $failures"
  return $failures
}

# --- MAIN ---

if [[ $# -eq 0 ]]; then
  echo "Usage: $0 [--batch | --batch-all | --single <TKT-ID> | --audit | --dry-run | --sprint <name> | --test-status | --schema-check]"
  exit 1
fi

acquire_lock

# Run schema-drift guard on every invocation
schema_check || {
  log "FATAL: Notion DB A schema mismatch. Refusing to proceed."
  log "       Inspect live schema, update REQUIRED_PROPS, or run --schema-check for details."
  exit 2
}

DRY_RUN="false"
if [[ "$1" == "--dry-run" ]]; then DRY_RUN="true"; shift; fi

case "$1" in
  --batch) do_batch ;;
  --batch-no-reset) do_batch "false" ;;
  --batch-all) do_batch "true" "true" ;;  # One-time full backfill: process every ticket
  --single) sync_ticket "$2" "$DRY_RUN" ;;
  --audit) do_audit ;;
  --sprint) do_sprint "$2" ;;
  --test-status) do_test_status ;;
  --schema-check) schema_check ;;
  *) echo "Invalid option: $1"; exit 1 ;;
esac
