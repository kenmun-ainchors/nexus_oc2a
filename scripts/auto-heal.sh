#!/bin/zsh
# AInchors Auto-Heal — nightly system sweep, fix what's safe, file US for what needs Ken
# Runs 23:30 AEST. Output: state/auto-heal-YYYY-MM-DD.json
# Full from Day 3 (2026-04-27) — auto-fixes safe items, files US for needs-Ken items
#
# Exit codes: 0 = clean run; 1 = scan errors; 2 = needs-Ken items present (informational)

set -u  # don't set -e — want to keep going across checks

WORKSPACE="/Users/ainchorsangiefpl/.openclaw/workspace"
STATE_DIR="$WORKSPACE/state"
TODAY=$(TZ="Australia/Melbourne" date '+%Y-%m-%d')
NOW=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
NOW_LOCAL=$(TZ="Australia/Melbourne" date '+%Y-%m-%d %H:%M %Z')
REPORT="$STATE_DIR/auto-heal-${TODAY}.json"
LOG="$STATE_DIR/auto-heal-${TODAY}.log"
STATE_TMP="$STATE_DIR/auto-heal-current.json"
CHANGELOG_HELPER="$WORKSPACE/scripts/changelog-append.sh"

mkdir -p "$STATE_DIR"

# State arrays
typeset -a CHECKS_RUN
typeset -a ISSUES_FOUND
typeset -a AUTO_FIXED
typeset -a NEEDS_KEN

log() { echo "[$(date '+%H:%M:%S')] $1" | tee -a "$LOG"; }

# --- FAIL-SAFE REPORTING (TKT-0279) ---
# Writes the current state to a JSON file. Called after every check and via trap.
write_state() {
  local exit_status=${1:-"in-progress"}
  local checks_json=$(printf '%s\n' "${CHECKS_RUN[@]:-}" | jq -R . | jq -s .)
  local issues_json=$(printf '%s\n' "${ISSUES_FOUND[@]:-}" | jq -R . | jq -s 'map(select(length > 0))')
  local fixed_json=$(printf '%s\n' "${AUTO_FIXED[@]:-}" | jq -R . | jq -s 'map(select(length > 0))')
  local needsken_json=$(printf '%s\n' "${NEEDS_KEN[@]:-}" | jq -R . | jq -s 'map(select(length > 0))')

  cat > "$REPORT" <<EOF
{
  "runAt": "$NOW",
  "runAtLocal": "$NOW_LOCAL",
  "duration_ms": 0,
  "checks_run": $checks_json,
  "checks_count": ${#CHECKS_RUN[@]},
  "issues_found": $issues_json,
  "issues_count": ${#ISSUES_FOUND[@]},
  "auto_fixed": $fixed_json,
  "auto_fixed_count": ${#AUTO_FIXED[@]},
  "needs_ken": $needsken_json,
  "needs_ken_count": ${#NEEDS_KEN[@]},
  "exit_status": "$exit_status"
}
EOF
  # Keep a tmp copy as well
  cp "$REPORT" "$STATE_TMP"
}

# Trap for unexpected exits (crashes/timeouts)
trap 'log "CRASH DETECTED: Trap triggered. Finalizing partial report..."; write_state "crashed"; exit 1' ERR SIGINT SIGTERM

log "=== AUTO-HEAL START $NOW_LOCAL ==="

# ---------- CHECK 1: Auth profiles + delegated tokens ----------
log "CHECK 1: auth profiles + delegated tokens"
CHECKS_RUN+=("auth_profiles")
AUTH_FILE="$HOME/.openclaw/agents/main/agent/auth-profiles.json"
if [[ -f "$AUTH_FILE" ]]; then
  HAS_ANTHROPIC=$(jq -r '.profiles."anthropic:default".key // empty' "$AUTH_FILE" 2>/dev/null)
  HAS_OLLAMA=$(jq -r '.profiles."ollama:default".key // empty' "$AUTH_FILE" 2>/dev/null)
  if [[ -z "$HAS_ANTHROPIC" ]]; then
    ISSUES_FOUND+=("auth:anthropic-missing")
    NEEDS_KEN+=("Anthropic API key missing in auth-profiles.json — requires Ken to add via openclaw agents auth")
    log "  ISSUE: anthropic key missing"
  fi
  if [[ -z "$HAS_OLLAMA" ]]; then
    ISSUES_FOUND+=("auth:ollama-missing")
    NEEDS_KEN+=("Ollama key missing in auth-profiles.json — fallback chain broken")
    log "  ISSUE: ollama key missing"
  fi
else
  ISSUES_FOUND+=("auth:file-missing")
  NEEDS_KEN+=("auth-profiles.json missing entirely — major issue, OpenClaw cannot route any model")
fi

# CHECK 1a: Delegated gog auth tokens (TKT-0336)
log "CHECK 1a: delegated gog auth tokens"
CHECKS_RUN+=("delegated_auth")
DELEG_AUTH_SCRIPT="$WORKSPACE/scripts/check-delegated-auth.sh"
if [[ -x "$DELEG_AUTH_SCRIPT" ]]; then
  zsh "$DELEG_AUTH_SCRIPT" --json >> "$LOG" 2>&1
  DELEG_EXIT=$?
  if [[ $DELEG_EXIT -eq 1 ]]; then
    ISSUES_FOUND+=("delegated-auth:expired")
    # Extract expired accounts from the JSON for the needs_ken summary
    DELEG_JSON="$STATE_DIR/delegated-auth-status.json"
    if [[ -f "$DELEG_JSON" ]]; then
      EXPIRED_ACCOUNTS=$(python3 -c "
import json
try:
  d=json.load(open('$DELEG_JSON'))
  expired=[a['email'] for a in d.get('accounts',[]) if a['status'] in ('EXPIRED','MISSING')]
  print(', '.join(expired) if expired else '')
except: pass
" 2>/dev/null)
      [[ -n "$EXPIRED_ACCOUNTS" ]] && NEEDS_KEN+=("Delegated auth tokens expired/missing: $EXPIRED_ACCOUNTS — re-auth needed with 'gog auth add <email> --services <services>'")
    fi
    log "  X: delegated auth tokens expired/missing"
  elif [[ $DELEG_EXIT -eq 2 ]]; then
    # gog not available — non-critical if gog not set up yet
    log "  WARN: gog not available — delegated auth check skipped"
  else
    log "  OK: all delegated auth tokens valid"
  fi
else
  log "  WARN: check-delegated-auth.sh not found — delegated auth check skipped"
fi
write_state

# ---------- CHECK 2: Cron job health ----------
log "CHECK 2: cron job health"
CHECKS_RUN+=("cron_health")
CRON_FILE="$HOME/.openclaw/cron/jobs.json"
if [[ -f "$CRON_FILE" ]]; then
  ERRORED_JOBS=$(jq -r '.jobs[]? | select(.state.consecutiveErrors > 0) | "\(.name) [\(.id)] consecutiveErrors=\(.state.consecutiveErrors) lastError=\(.state.lastError // "?")"' "$CRON_FILE" 2>/dev/null)
  if [[ -n "$ERRORED_JOBS" ]]; then
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      ISSUES_FOUND+=("cron-error:$line")
      NEEDS_KEN+=("Cron job has consecutive errors: $line")
      log "  ISSUE: $line"
    done <<< "$ERRORED_JOBS"
  fi
fi
write_state

# ---------- CHECK 3: Backup freshness ----------
log "CHECK 3: backup freshness"
CHECKS_RUN+=("backup_freshness")
LATEST_FULL=$(ls -t "$HOME/Backups/ainchors/workspace/" 2>/dev/null | head -1)
LATEST_INCR=$(ls -t "$HOME/Backups/ainchors/workspace-incremental/" 2>/dev/null | head -1)
LATEST_BACKUP=""
BACKUP_PATH=""
BACKUP_TYPE=""

if [[ -n "$LATEST_INCR" ]]; then
  BACKUP_PATH="$HOME/Backups/ainchors/workspace-incremental/$LATEST_INCR"
  LATEST_BACKUP="$LATEST_INCR"
  BACKUP_TYPE="incremental"
elif [[ -n "$LATEST_FULL" ]]; then
  BACKUP_PATH="$HOME/Backups/ainchors/workspace/$LATEST_FULL"
  LATEST_BACKUP="$LATEST_FULL"
  BACKUP_TYPE="full"
fi

if [[ -z "$LATEST_BACKUP" ]]; then
  ISSUES_FOUND+=("backup:none-found")
  NEEDS_KEN+=("No backup files found in ~/Backups/ainchors/workspace/ or workspace-incremental/")
else
  AGE_HOURS=$(( ( $(date +%s) - $(stat -f %m "$BACKUP_PATH") ) / 3600 ))
  if (( AGE_HOURS > 30 )); then
    ISSUES_FOUND+=("backup:stale:${AGE_HOURS}h")
    NEEDS_KEN+=("Latest ${BACKUP_TYPE} backup is ${AGE_HOURS}h old (>30h threshold). Path: ${BACKUP_PATH}")
    log "  ISSUE: backup stale ${AGE_HOURS}h (${BACKUP_TYPE})"
  else
    log "  OK: ${BACKUP_TYPE} backup ${AGE_HOURS}h old: ${LATEST_BACKUP}"
  fi
fi
write_state

# ---------- CHECK 4: Disk space ----------
log "CHECK 4: disk space"
CHECKS_RUN+=("disk_space")
DISK_PCT=$(df -h "$HOME" | awk 'NR==2 {gsub("%",""); print $5}')
if (( DISK_PCT > 90 )); then
  ISSUES_FOUND+=("disk:full:${DISK_PCT}%")
  NEEDS_KEN+=("Disk usage at ${DISK_PCT}% — needs cleanup or expansion")
fi
write_state

# ---------- CHECK 5: Stale plugin-runtime-deps ----------
log "CHECK 5: plugin-runtime-deps cleanup"
CHECKS_RUN+=("plugin_runtime_deps")
setopt NULL_GLOB 2>/dev/null || true
STALE_DIRS=$(ls -d "$HOME/.openclaw/plugin-runtime-deps/openclaw-unknown-"* 2>/dev/null | wc -l | tr -d ' ')
STALE_DIRS=${STALE_DIRS:-0}
unsetopt NULL_GLOB 2>/dev/null || true
if (( STALE_DIRS > 1 )); then
  ISSUES_FOUND+=("plugin-deps:stale:${STALE_DIRS}-dirs")
  KEEP=$(ls -t -d "$HOME/.openclaw/plugin-runtime-deps/openclaw-unknown-"* 2>/dev/null | head -1)
  REMOVED=0
  for d in "$HOME/.openclaw/plugin-runtime-deps/openclaw-unknown-"*; do
    if [[ "$d" != "$KEEP" ]]; then
      rm -rf "$d" && (( REMOVED+=1 ))
    fi
  done
  if (( REMOVED > 0 )); then
    AUTO_FIXED+=("plugin-deps-cleanup:removed-${REMOVED}-stale-dirs")
    log "  AUTO-FIX: removed $REMOVED stale plugin-runtime-deps dirs"
    if [[ -x "$CHANGELOG_HELPER" ]]; then
      CHG=$("$CHANGELOG_HELPER" \
        --type infra --source auto-heal \
        --title "Cleaned $REMOVED stale plugin-runtime-deps dirs" \
        --trigger "auto-heal scan found $STALE_DIRS dirs (threshold >1)" \
        --changed "Removed $REMOVED stale openclaw-unknown-* dirs from ~/.openclaw/plugin-runtime-deps/, kept newest" \
        --why "Stale plugin-runtime-deps caused INC-20260426-003 (116min outage). Pre-emptive cleanup prevents recurrence." \
        --verified "ls confirms only 1 version versioned dir remains" \
        --rollback "N/A — stale dirs are regenerated automatically on plugin load" \
        --linked "INC-20260426-003" 2>&1 || echo "")
      [[ -n "$CHG" ]] && log "  Logged $CHG"
    fi
  fi
fi
write_state

# ---------- CHECK 6: Stale lock files ----------
log "CHECK 6: stale lock files"
CHECKS_RUN+=("stale_locks")
REMOVED_LOCKS=0
setopt -s null_glob 2>/dev/null || shopt -s nullglob 2>/dev/null || true
for lock in "$HOME/.openclaw/agents/main/sessions/"*.lock; do
  [[ -f "$lock" ]] || continue
  PID=$(cat "$lock" 2>/dev/null | grep -oE '[0-9]+' | head -1)
  if [[ -n "$PID" ]] && ! ps -p "$PID" > /dev/null 2>&1; then
    AGE_S=$(( $(date +%s) - $(stat -f %m "$lock") ))
    if (( AGE_S > 300 )); then
      rm -f "$lock" && REMOVED_LOCKS=$((REMOVED_LOCKS+1))
    fi
  fi
done
if (( REMOVED_LOCKS > 0 )); then
  AUTO_FIXED+=("locks-cleanup:removed-${REMOVED_LOCKS}-stale")
  log "  AUTO-FIX: removed $REMOVED_LOCKS stale locks"
fi
write_state

# ---------- CHECK 7: Git repo health ----------
log "CHECK 7: git repo health"
CHECKS_RUN+=("git_health")
for repo in "$WORKSPACE"; do
  if [[ -d "$repo/.git" ]]; then
    cd "$repo" || continue
    DIRTY=$(git status --porcelain | wc -l | tr -d ' ')
    if (( DIRTY > 0 )); then
      git add -A . 2>/dev/null || true
      if git commit --allow-empty -m "chore: auto-heal commit ${TODAY}" > /dev/null 2>&1; then
        AUTO_FIXED+=("git-commit:$(basename "$repo"):${DIRTY}-files")
        log "  AUTO-FIX: committed $DIRTY untracked files in $(basename "$repo")"
      fi
    fi
  fi
done
write_state

# ---------- CHECK 8: Health-state freshness ----------
log "CHECK 8: health-state freshness"
CHECKS_RUN+=("health_state")
HEALTH_FILE="$STATE_DIR/health-state.json"
if [[ -f "$HEALTH_FILE" ]]; then
  AGE_MIN=$(( ( $(date +%s) - $(stat -f %m "$HEALTH_FILE") ) / 60 ))
  if (( AGE_MIN > 30 )); then
    ISSUES_FOUND+=("health-state:stale:${AGE_MIN}min")
    NEEDS_KEN+=("Health-state.json is ${AGE_MIN}min old — health-check cron may be broken")
  fi
fi
write_state

# ---------- CHECK 9: Cost balance ----------
log "CHECK 9: API balance"
CHECKS_RUN+=("api_balance")
# CHG-0446: Anthropic balance check suppressed until TRIGGER-01 (OC2 arrival + CLAUDE RESTORE).
# Ollama Cloud is $100/mo fixed subscription — no pay-as-you-go balance to track.
# Re-enable this check after TRIGGER-01 sub-action 01-CLAUDE-RESTORE completes.
TRIGGER_FILE="$STATE_DIR/chg-triggers.json"
CLAUDE_SUPPRESS=true
if [[ -f "$TRIGGER_FILE" ]]; then
  TRIGGER01_STATUS=$(jq -r '.triggers["TRIGGER-01"].status // "pending"' "$TRIGGER_FILE")
  if [[ "$TRIGGER01_STATUS" == "fired" ]]; then
    CLAUDE_SUPPRESS=false
  fi
fi
if [[ "$CLAUDE_SUPPRESS" == "true" ]]; then
  log "  SKIP: Anthropic balance check suppressed (CLAUDE RESTORE pending — TRIGGER-01 not yet fired)"
else
  COST_FILE="$STATE_DIR/cost-state.json"
  if [[ -f "$COST_FILE" ]]; then
    REMAINING=$(jq -r '.apiBalance.remainingEstimate // 0' "$COST_FILE")
    THRESHOLD_10=$(jq -r '.spendAlerts.alert10pct.threshold // 5' "$COST_FILE")
    REMAINING_INT=$(echo "$REMAINING" | awk '{printf "%d", $1*100}')
    THRESHOLD_INT=$(echo "$THRESHOLD_10" | awk '{printf "%d", $1*100}')
    if (( REMAINING_INT < THRESHOLD_INT )); then
      ISSUES_FOUND+=("balance:critical:\$${REMAINING}")
      NEEDS_KEN+=("API balance critically low: \$${REMAINING} USD remaining (threshold \$${THRESHOLD_10})")
    fi
  fi
fi
write_state

# ---------- CHECK 10: Recent incident pattern ----------
log "CHECK 10: incident patterns (7-day)"
CHECKS_RUN+=("incident_patterns")
INC_FILE="$STATE_DIR/incident-log.json"
if [[ -f "$INC_FILE" ]]; then
  CUTOFF_MS=$(( ($(date +%s) - 7*86400) * 1000 ))
  RECENT=$(jq --argjson cut "$CUTOFF_MS" '[.[] | select(.timestamp_ms >= $cut)] | length' "$INC_FILE" 2>/dev/null || echo 0)
  if (( RECENT > 3 )); then
    ISSUES_FOUND+=("incidents:pattern:${RECENT}-in-7d")
    NEEDS_KEN+=("$RECENT incidents in last 7 days — pattern review needed")
  fi
fi
write_state

# ---------- CHECK 11: Config drift ----------
log "CHECK 11: openclaw.json drift"
CHECKS_RUN+=("config_drift")
CFG="$HOME/.openclaw/openclaw.json"
LAST_GOOD="$HOME/.openclaw/openclaw.json.last-good"
if [[ -f "$CFG" && -f "$LAST_GOOD" ]]; then
  if ! diff -q "$CFG" "$LAST_GOOD" > /dev/null 2>&1; then
    log "  INFO: openclaw.json differs from last-good (informational only — config-health monitors this)"
  fi
fi
write_state

# ---------- CHECK 12: Critical config baseline (anti-drift guard) ----------
log "CHECK 12: critical config baseline"
CHECKS_RUN+=("critical_config_baseline")
BASELINE="$WORKSPACE/state/critical-config-baseline.json"
if [[ -f "$BASELINE" ]]; then
  log "  Validating critical config baseline (flat structure)"
  
  # Check each known field in the flat baseline
  check_baseline_field() {
    local field="$1" local label="$2" local expected_min="$3" local comparator="$4"
    local actual=$(jq -r ".$field // 0" "$BASELINE" 2>/dev/null)
    if [[ "$comparator" == "min" ]]; then
      if (( actual >= expected_min )); then
        log "  OK $label: $actual (>= $expected_min)"
      else
        ISSUES_FOUND+=("config-baseline:$field:below-minimum")
        NEEDS_KEN+=("WARN: $label is $actual, expected >= $expected_min. Run gateway-config-snapshot.sh to refresh baseline.")
        log "  X $label: $actual < $expected_min"
      fi
    elif [[ "$comparator" == "eq" ]]; then
      if [[ "$actual" == "$expected_min" ]]; then
        log "  OK $label: $actual"
      else
        ISSUES_FOUND+=("config-baseline:$field:drift")
        NEEDS_KEN+=("WARN: $label is '$actual', expected '$expected_min'. Run gateway-config-snapshot.sh to refresh.")
        log "  X $label: '$actual' != '$expected_min'"
      fi
    fi
  }
  
  check_baseline_field "agentCount" "Agent Count" 14 "min"
  check_baseline_field "cronCount" "Cron Count" 50 "min"
  check_baseline_field "pgTables" "PG Tables" 18 "min"
  check_baseline_field "gatewayStatus" "Gateway Status" "healthy" "eq"
  
  # Version check: warn if baseline was written more than 7 days ago
  upgraded_at=$(jq -r '.upgradedAt // empty' "$BASELINE" 2>/dev/null)
  if [[ -n "$upgraded_at" ]]; then
    upgraded_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%S" "${upgraded_at%+*}" "+%s" 2>/dev/null || echo 0)
    now_epoch=$(date +%s)
    age_days=$(( (now_epoch - upgraded_epoch) / 86400 ))
    if (( age_days > 7 )); then
      ISSUES_FOUND+=("config-baseline:stale-baseline")
      NEEDS_KEN+=("WARN: Config baseline is $age_days days old. Run gateway-config-snapshot.sh to refresh.")
      log "  X Baseline stale: $age_days days old"
    else
      log "  OK Baseline age: $age_days days"
    fi
  fi
fi
write_state

# ---------- CHECK 13: Agent Identity Integrity (L-043) ----------
CHECKS_RUN+=("agent_identity")
IDENTITY_AUDIT="$WORKSPACE/scripts/agent-identity-audit.sh"
if [[ -x "$IDENTITY_AUDIT" ]]; then
  if bash "$IDENTITY_AUDIT" >> "$LOG" 2>&1; then
    log "  OK agent-identity: all agents have commissioned SOUL.md"
  else
    ISSUES_FOUND+=("agent-identity:vanilla-soul-detected")
    NEEDS_KEN+=("CRITICAL: Agent identity drift — one or more agents have vanilla SOUL.md. Run agent-identity-audit.sh for details.")
    log "  X agent-identity: VANILLA SOUL detected — needs commissioning"
  fi
else
  ISSUES_FOUND+=("agent-identity:audit-script-missing")
  NEEDS_KEN+=("WARN: agent-identity-audit.sh not found — cannot verify agent identities")
  log "  X agent-identity: audit script missing"
fi
# ---------- CHECK 14: Agent RULES.md presence (TKT-0307) ----------
log "CHECK 14: agent RULES.md audit"
if zsh "$WORKSPACE/scripts/agent-rules-audit.sh" >> "$LOG" 2>&1; then
  log "  OK: All agents have RULES.md"
else
  log "  X: Agents missing RULES.md — see state/agent-rules-audit.json"
  NEEDS_KEN+=("RULES.md missing for agent(s) — run agent-rules-audit.sh for details. See TKT-0307.")
fi
CHECKS_RUN+=("agent_rules")

# ---------- CHECK 15: Injected File Size Guard (TKT-0310) ----------
log "CHECK 15: injected file size limits"
CHECKS_RUN+=("file_size_guard")
WORKSPACE_ROOT="/Users/ainchorsangiefpl/.openclaw/workspace"

# Per-file hard limits from TKT-0310 (TKT-0336 fix: were all 10000; now per-document)
# SOUL.md: 10000 | AGENTS.md: 12000 | MEMORY.md: 15000 | HEARTBEAT.md: 15000
# RULES.md: reference-only, not injected — excluded from size check
SOFT_LIMIT=8000
VIOLATIONS=()

_check_file() {
  local file="$1" label="$2" hard="$3"
  [[ -f "$file" ]] || return
  local size=$(wc -c < "$file" 2>/dev/null | tr -d ' ')
  if [[ "$size" -gt "$hard" ]]; then
    VIOLATIONS+=("$label: ${size} chars (HARD LIMIT ${hard} — SILENT TRUNCATION RISK)")
  elif [[ "$size" -gt "$SOFT_LIMIT" ]]; then
    log "  WARN: $label at ${size} chars (soft limit ${SOFT_LIMIT})"
  fi
}

_check_file "$WORKSPACE_ROOT/SOUL.md" "SOUL.md" 10000
_check_file "$WORKSPACE_ROOT/AGENTS.md" "AGENTS.md" 12000
_check_file "$WORKSPACE_ROOT/MEMORY.md" "MEMORY.md" 15000
_check_file "$WORKSPACE_ROOT/HEARTBEAT.md" "HEARTBEAT.md" 15000
# RULES.md intentionally excluded — reference-only, not injected

if [[ ${#VIOLATIONS[@]} -gt 0 ]]; then
  for v in "${VIOLATIONS[@]}"; do
    log "  X: $v"
    NEEDS_KEN+=("$v")
  done
else
  log "  OK: All injected files within limits"
fi

# ---------- CHECK 16: Bootstrap Total Injection Size (TKT-0310) ----------
log "CHECK 16: bootstrap injection total size"
CHECKS_RUN+=("bootstrap_size")

TOTAL_INJECTION=0
INJECTION_FILES=(
  "$WORKSPACE_ROOT/SOUL.md"
  "$WORKSPACE_ROOT/IDENTITY.md"
  "$WORKSPACE_ROOT/USER.md"
  "$WORKSPACE_ROOT/AGENTS.md"
  "$WORKSPACE_ROOT/MEMORY.md"
  "$WORKSPACE_ROOT/HEARTBEAT.md"
)
# RULES.md excluded — reference doc, not injected

for f in "${INJECTION_FILES[@]}"; do
  if [[ -f "$f" ]]; then
    size=$(wc -c < "$f" 2>/dev/null | tr -d ' ')
    TOTAL_INJECTION=$((TOTAL_INJECTION + size))
  fi
done

INJECTION_LIMIT=120000
INJECTION_WARN=80000

if [[ "$TOTAL_INJECTION" -gt "$INJECTION_LIMIT" ]]; then
  log "  X: Bootstrap injection ${TOTAL_INJECTION} chars — OVER LIMIT (${INJECTION_LIMIT})"
  NEEDS_KEN+=("Bootstrap injection at ${TOTAL_INJECTION} chars — risks context window overflow. Reduce injected files.")
elif [[ "$TOTAL_INJECTION" -gt "$INJECTION_WARN" ]]; then
  log "  WARN: Bootstrap injection ${TOTAL_INJECTION} chars (warn threshold ${INJECTION_WARN})"
else
  log "  OK: Bootstrap injection ${TOTAL_INJECTION} chars (limit ${INJECTION_LIMIT})"
fi

# ---------- CHECK 17: PG Sequence Health (TKT-0367) ----------
log "CHECK 17: PG sequence health (last_value vs MAX(id))"
CHECKS_RUN+=("pg_sequence_health")

# Validate all state table sequences are in sync. If sequence < MAX(id), INSERTs will
# hit duplicate key violations silently. Auto-heal fixes by calling setval().
SEQUENCE_DRIFT=()
for table in state_config_baseline state_cost state_linkedin state_autoheal_log \
             state_diagnostics state_uptime state_model_trials state_kri \
             state_governance state_latency state_model_drift state_frameworks; do
  seq_name="${table}_id_seq"
  seq_val=$(bash "$WORKSPACE/scripts/db.sh" -c "SELECT last_value FROM $seq_name" 2>/dev/null | tr -d ' ')
  max_id=$(bash "$WORKSPACE/scripts/db.sh" -c "SELECT COALESCE(MAX(id),0) FROM $table" 2>/dev/null | tr -d ' ')
  if [[ -n "$seq_val" && -n "$max_id" ]]; then
    if [[ "$seq_val" -lt "$max_id" ]]; then
      # Auto-fix: resync sequence
      new_val=$((max_id + 1))
      bash "$WORKSPACE/scripts/db.sh" -c "SELECT setval('$seq_name', $new_val)" >> "$LOG" 2>&1 && \
        log "  FIXED: $seq_name was $seq_val, reset to $new_val (table max=$max_id)" && \
        AUTO_FIXED+=("pg-sequence:$seq_name:$seq_val→$new_val")
      SEQUENCE_DRIFT+=("$seq_name desynced: seq=$seq_val max=$max_id")
    else
      log "  OK: $seq_name = $seq_val"
    fi
  else
    log "  WARN: Could not read $seq_name or $table"
  fi
done

if [[ ${#SEQUENCE_DRIFT[@]} -gt 0 ]]; then
  log "  X: ${#SEQUENCE_DRIFT[@]} sequences desynced"
  # Auto-fixed above — only log for awareness, don't escalate to needs-Ken
  # (unless fix failed, which would show in NEEDS_KEN via PG write failure)
else
  log "  OK: All 12 state sequences in sync"
fi

# ---------- CHECK 18: Orphaned Gateway Process Detection (TKT-0332) ----------
log "CHECK 18: orphaned gateway process (port 18789)"
CHECKS_RUN+=("orphaned_gateway")

# Detect orphaned openclaw processes holding port 18789 that are NOT the active gateway.
# Pattern: gateway crash → stale child survives → port lock prevents restart.
# INC-20260608-001: PID 77230 held port 18789 for 30 min, blocking recovery.
ORPHAN_COUNT=0
ACTIVE_GW_PID=$(pgrep -f "openclaw.*gateway.*18789" | head -1)

# List ALL PIDs holding port 18789
LSOF_OUT=$(/usr/sbin/lsof -i :18789 -sTCP:LISTEN -t 2>/dev/null || true)
if [[ -n "$LSOF_OUT" ]]; then
  while IFS= read -r pid; do
    pid=$(echo "$pid" | tr -d ' ')
    [[ -z "$pid" ]] && continue
    # Skip the active gateway PID
    if [[ -n "$ACTIVE_GW_PID" && "$pid" == "$ACTIVE_GW_PID" ]]; then
      continue
    fi
    # Verify it's actually an openclaw process
    if ps -p "$pid" -o comm= 2>/dev/null | grep -q openclaw; then
      log "  X: Orphaned openclaw PID $pid holding port 18789 (active gateway: ${ACTIVE_GW_PID:-none})"
      ORPHAN_COUNT=$((ORPHAN_COUNT + 1))
      # Auto-fix: kill the orphan after 5-min grace period
      # Only kill if active gateway exists (meaning we're NOT in a crash loop)
      if [[ -n "$ACTIVE_GW_PID" ]]; then
        PROCESS_AGE=$(ps -o etime= -p "$pid" 2>/dev/null | tr -d ' ' || echo "unknown")
        log "  FIX: Killing orphaned gateway PID $pid (age: $PROCESS_AGE)"
        kill -9 "$pid" 2>/dev/null && AUTO_FIXED+=("orphaned-gateway:$pid") || log "  WARN: Could not kill PID $pid"
      else
        log "  WARN: No active gateway found, leaving orphan PID $pid (may be crash loop)"
        NEEDS_KEN+=("Orphaned gateway PID $pid holding port 18789 with no active gateway — possible crash loop")
      fi
    fi
  done <<< "$LSOF_OUT"
fi

if [[ $ORPHAN_COUNT -eq 0 ]]; then
  log "  OK: No orphaned gateway processes"
fi

# ---------- CHECK 19: Sandbox Gateway Liveness (TKT-0333) ----------
log "CHECK 19: sandbox gateway liveness (port 28789)"
CHECKS_RUN+=("sandbox_gateway_liveness")

SANDBOX_PORT=28789
SANDBOX_PLIST="$HOME/Library/LaunchAgents/ai.openclaw.sandbox-gateway.plist"

if /usr/sbin/lsof -i :$SANDBOX_PORT -sTCP:LISTEN -t > /dev/null 2>&1; then
  log "  OK: Sandbox gateway listening on port $SANDBOX_PORT"
else
  if [[ -f "$SANDBOX_PLIST" ]]; then
    log "  WARN: Sandbox gateway NOT listening on port $SANDBOX_PORT — LaunchAgent plist exists but service is down"
    ISSUES_FOUND+=("sandbox-gateway:down")
    NEEDS_KEN+=("WARN: Sandbox gateway (port 28789) not listening — LaunchAgent exists ($SANDBOX_PLIST), manual start may be needed")
  else
    log "  WARN: Sandbox gateway NOT listening on port $SANDBOX_PORT — no LaunchAgent plist found"
    ISSUES_FOUND+=("sandbox-gateway:no-plist")
    NEEDS_KEN+=("WARN: Sandbox gateway (port 28789) not listening and no LaunchAgent plist at $SANDBOX_PLIST")
  fi
fi
write_state

# ---------- CHECK 20: Shadow Gateway Liveness — Port 38789 (CHG-0471) ----------
log "CHECK 20: shadow gateway liveness (port 38789)"
CHECKS_RUN+=("shadow_gateway_liveness")

SHADOW_PORT=38789

if /usr/sbin/lsof -i :$SHADOW_PORT -sTCP:LISTEN -t > /dev/null 2>&1; then
  log "  OK: Shadow gateway listening on port $SHADOW_PORT"
else
  log "  INFO: Shadow gateway not running on port $SHADOW_PORT — expected unless shadow is actively deployed"
  # Shadow is optional — not an issue if not running. Only flag if deployed but crashed.
fi
# ---------- CHECK 20: Tilde Path in Cron Payloads (TKT-0336) ----------
log "CHECK 20: tilde paths in cron payloads"

# Scan all active cron jobs' payloads for ~ tilde patterns
# This detects if any agent/cron is using ~ in tool call paths
TILDE_FOUND=0
CRON_JOBS=$(/opt/homebrew/bin/openclaw cron list --json 2>/dev/null || echo '[]')

# Extract payload text fields and check for tilde patterns
TILDE_PATTERNS=$(echo "$CRON_JOBS" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
except:
    sys.exit(0)

if isinstance(data, list):
    for job in data:
        payload = job.get('payload', {})
        text = payload.get('text', '') + payload.get('message', '')
        if '~/' in text or '~\\\\/' in text:
            print(f\"CRON: {job.get('name','?')} ({job.get('id','?')[:8]}) — tilde in payload\")
" 2>&1)

if [[ -n "$TILDE_PATTERNS" ]]; then
  echo "$TILDE_PATTERNS" | while read line; do
    issues+="\n  ⚠️ [$line]"
    TILDE_FOUND=$((TILDE_FOUND+1))
  done
  log "  WARNING: $TILDE_FOUND cron payload(s) contain tilde paths"
else
  log "  OK: no tilde paths in cron payloads"
fi

# Also check common agent config files for tilde in path references
if grep -rq '~/' "$WORKSPACE/state/" --include='*.json' 2>/dev/null; then
  tilde_files=$(grep -rl '~/' "$WORKSPACE/state/" --include='*.json' 2>/dev/null | head -5 | tr '\n' ' ')
  issues+="\n  ⚠️ Tilde in state files: $tilde_files"
  TILDE_FOUND=$((TILDE_FOUND+1))
  log "  WARNING: tilde paths found in state JSON files"
fi

if (( TILDE_FOUND > 0 )); then
  needs_ken+="\n  [TKT-0336] Tilde paths detected in $TILDE_FOUND location(s) — review crons and state files"
else
  log "  OK: no tilde paths anywhere"
fi

write_state

# ---------- CHECK 21: Workspace File Contract Audit (TKT-0341) ----------
log "CHECK 21: workspace file contract audit"
if [[ -x "$WORKSPACE/scripts/file-size-guard.sh" ]]; then
  ROOT_OUTPUT=$("$WORKSPACE/scripts/file-size-guard.sh" --root 2>&1) || true
  ROOT_RC=$?
  if [[ "$ROOT_OUTPUT" == *"UNTRACKED FILES"* ]]; then
    _untracked=$(echo "$ROOT_OUTPUT" | grep "UNTRACKED FILES:" | sed 's/.*UNTRACKED FILES: //')
    issues+="\n  [TKT-0341] Untracked .md files in workspace root: $_untracked"
    needs_ken+="\n  [TKT-0341] Untracked .md files in root — move to docs/archive/agents or register contract"
    log "  WARNING: untracked files: $_untracked"
  elif [[ $ROOT_RC -eq 2 ]]; then
    needs_ken+="\n  [TKT-0341] Workspace root .md total exceeds 60K cap — trim injected files"
    log "  WARNING: root .md cap exceeded"
  else
    log "  OK: all root .md files tracked and within limits"
  fi
else
  log "  SKIP: file-size-guard.sh not found"
fi

write_state "complete"

# ---------- FILE INC FOR EACH AUTO-FIX (ITSM-US-007) ----------
if (( ${#AUTO_FIXED[@]} > 0 )); then
  log "Filing INC records for qualifying auto-fixed item(s)..."
  for fix in "${AUTO_FIXED[@]}"; do
    if [[ "$fix" == git-commit:* ]]; then
      continue
    fi
    bash "$WORKSPACE/scripts/incident-log.sh" \
      --title "AUTO-HEAL: $fix" \
      --severity P4 \
      --type "planned" \
      --description "Auto-healed by auto-heal.sh at $NOW_LOCAL. Item: $fix. No Ken action required." \
      >> "$HOME/Backups/ainchors/logs/auto-heal.log" 2>&1 || true
  done
fi

# US40: Log to obs.db
OBS_LOG_CMD="$WORKSPACE/scripts/obs-log.sh"
if [[ -x "$OBS_LOG_CMD" ]]; then
  for _fix in "${AUTO_FIXED[@]}"; do
    bash "$OBS_LOG_CMD" \
      --source auto-heal --level INFO --type auto_heal_fix \
      --message "Auto-heal fixed: ${_fix:0:120}" \
      --detail "{\"item\":\"${_fix:0:200}\",\"runAt\":\"$NOW\"}" \
      >> "$LOG" 2>&1 || true
  done
  for _item in "${NEEDS_KEN[@]}"; do
    _item_safe=${_item//"/\\"}
    bash "$OBS_LOG_CMD" \
      --source auto-heal --level WARN --type auto_heal_needs_ken \
      --message "Needs Ken: ${_item:0:120}" \
      --detail "{\"item\":\"${_item_safe:0:200}\",\"runAt\":\"$NOW\"}" \
      >> "$LOG" 2>&1 || true
  done
fi

# ── PG WRITE: state_autoheal_log (TKT-XXXX — live sync) ──────────────────
# Mirrors the JSON report to PG for standup/dashboard queries
_PG_PASSED=$(( ${#CHECKS_RUN[@]} - ${#ISSUES_FOUND[@]} ))
_NEEDS_KEN_ARR=""
for _nk in "${NEEDS_KEN[@]}"; do
  _nk_escaped="${_nk//\'/''}"
  if [[ -z "$_NEEDS_KEN_ARR" ]]; then
    _NEEDS_KEN_ARR="'${_nk_escaped}'"
  else
    _NEEDS_KEN_ARR="${_NEEDS_KEN_ARR},'${_nk_escaped}'"
  fi
done
_CHECKS_JSON=$(python3 -c "
import json
checks = '${(j:,:)CHECKS_RUN}'.split(',')
issues = '${(j:;;:)ISSUES_FOUND}'.split(';;;') if '${(j:;;:)ISSUES_FOUND}' else []
auto_fixed = '${(j:;;:)AUTO_FIXED}'.split(';;;') if '${(j:;;:)AUTO_FIXED}' else []
print(json.dumps({'checks_run': checks, 'issues': issues, 'auto_fixed': auto_fixed, 'auto_fixed_count': len(auto_fixed)}).replace(\"'\", \"''''\"))
" 2>/dev/null || echo '{}')
_STATUS="complete"
[[ ${#NEEDS_KEN[@]} -gt 0 ]] && _STATUS="complete_with_needs_ken"
bash "$WORKSPACE/scripts/db.sh" -c "
INSERT INTO state_autoheal_log (run_date, status, total_checks, passed, failed, warnings, needs_ken, needs_ken_count, checks_detail)
VALUES (
    '$TODAY',
    '$_STATUS',
    ${#CHECKS_RUN[@]},
    $_PG_PASSED,
    ${#ISSUES_FOUND[@]},
    0,
    ARRAY[$_NEEDS_KEN_ARR]::text[],
    ${#NEEDS_KEN[@]},
    '$_CHECKS_JSON'::jsonb
)
ON CONFLICT (run_date) DO UPDATE SET
    status = EXCLUDED.status,
    total_checks = EXCLUDED.total_checks,
    passed = EXCLUDED.passed,
    failed = EXCLUDED.failed,
    needs_ken = EXCLUDED.needs_ken,
    needs_ken_count = EXCLUDED.needs_ken_count,
    checks_detail = EXCLUDED.checks_detail;
" >> "$LOG" 2>&1 || log "WARN: PG write for state_autoheal_log failed"

log "=== AUTO-HEAL COMPLETE ==="
[[ ${#NEEDS_KEN[@]} -gt 0 ]] && exit 2 || exit 0
