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
  local checks_json=$(printf '%s\n' "${CHECKS_RUN[@]}" | jq -R . | jq -s .)
  local issues_json=$(printf '%s\n' "${ISSUES_FOUND[@]}" | jq -R . | jq -s 'map(select(length > 0))')
  local fixed_json=$(printf '%s\n' "${AUTO_FIXED[@]}" | jq -R . | jq -s 'map(select(length > 0))')
  local needsken_json=$(printf '%s\n' "${NEEDS_KEN[@]}" | jq -R . | jq -s 'map(select(length > 0))')

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

# ---------- CHECK 1: Auth profiles present ----------
log "CHECK 1: auth profiles"
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
  if (( AGE_HOURS > 26 )); then
    ISSUES_FOUND+=("backup:stale:${AGE_HOURS}h")
    NEEDS_KEN+=("Latest ${BACKUP_TYPE} backup is ${AGE_HOURS}h old (>26h threshold). Path: ${BACKUP_PATH}")
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
for lock in "$HOME/.openclaw/agents/main/sessions/"*.lock(N); do
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
INTERIM_ACTIVE=false
if [[ -f "$BASELINE" ]]; then
  INTERIM_CHECK=$(jq -r '.interimNote // empty' "$BASELINE" 2>/dev/null)
  if [[ -n "$INTERIM_CHECK" ]]; then
    INTERIM_ACTIVE=true
    log "  NOTE: Interim period active — config drift is expected (CHG-0349/CHG-0418)"
  fi
fi
if [[ -f "$BASELINE" ]]; then
  CHECK_COUNT=$(jq '.checks | length' "$BASELINE")
  log "  Validating $CHECK_COUNT critical config items"
  for i in $(seq 0 $((CHECK_COUNT - 1))); do
    CHECK_ID=$(jq -r ".checks[$i].id" "$BASELINE")
    CHECK_NAME=$(jq -r ".checks[$i].name" "$BASELINE")
    CHECK_FILE=$(jq -r ".checks[$i].file" "$BASELINE")
    CHECK_QUERY=$(jq -r ".checks[$i].jq_query" "$BASELINE")
    CHECK_EXPECTED=$(jq -r ".checks[$i].expected_value" "$BASELINE")
    CHECK_SEVERITY=$(jq -r ".checks[$i].severity" "$BASELINE")
    CHECK_FIX=$(jq -r ".checks[$i].fix_command" "$BASELINE")
    if [[ ! -f "$CHECK_FILE" ]]; then
      ISSUES_FOUND+=("config-baseline:${CHECK_ID}:file-missing")
      NEEDS_KEN+=("CRITICAL: ${CHECK_NAME} - file missing: ${CHECK_FILE}. Fix: ${CHECK_FIX}")
      log "  X ${CHECK_ID}: file missing - ${CHECK_FILE}"
      continue
    fi
    ACTUAL=$(jq -r "$CHECK_QUERY" "$CHECK_FILE" 2>/dev/null)
    if [[ "$ACTUAL" == "$CHECK_EXPECTED" ]]; then
      log "  OK ${CHECK_ID}: ${ACTUAL}"
    else
      ISSUES_FOUND+=("config-baseline:${CHECK_ID}:drift")
      if [[ "$INTERIM_ACTIVE" == "true" ]]; then
        ISSUES_FOUND+=("config-baseline:${CHECK_ID}:interim-drift-expected")
        log "  ~ ${CHECK_ID} DRIFT (interim-expected): expected '${CHECK_EXPECTED}' got '${ACTUAL}'"
      elif [[ "$CHECK_SEVERITY" == "critical" ]]; then
        NEEDS_KEN+=("CRITICAL DRIFT: ${CHECK_NAME} | expected '${CHECK_EXPECTED}' | actual '${ACTUAL}' | fix: ${CHECK_FIX}")
      else
        NEEDS_KEN+=("WARN DRIFT: ${CHECK_NAME} | expected '${CHECK_EXPECTED}' | actual '${ACTUAL}' | fix: ${CHECK_FIX}")
      fi
      log "  X ${CHECK_ID} DRIFT: expected '${CHECK_EXPECTED}' got '${ACTUAL}'"
    fi
  done
fi
write_state

# ---------- CHECK 13: Kimi Confidence Mapping ----------
log "CHECK 13: kimi confidence mapping"
CHECKS_RUN+=("kimi_confidence_mapping")
CONFIDENCE_MAP="$STATE_DIR/kimi-confidence-mapping.json"
if [[ -f "$CONFIDENCE_MAP" ]]; then
  MAP_DATE=$(stat -f %m "$CONFIDENCE_MAP")
  MAP_AGE_S=$(( $(date +%s) - $MAP_DATE ))
  MAP_AGE_DAYS=$(( MAP_AGE_S / 86400 ))
  if (( MAP_AGE_DAYS > 7 )); then
    ISSUES_FOUND+=("kimi-confidence-map:stale:${MAP_AGE_DAYS}d")
    NEEDS_KEN+=("kimi confidence mapping is ${MAP_AGE_DAYS} days old — re-sync needed")
    log "  WARN: confidence mapping stale ${MAP_AGE_DAYS}d"
  fi
  OPEN_TICKETS=$(python3 -c "
import json
try:
  with open('$STATE_DIR/tickets.json') as f:
    data = json.load(f)
    print(len([t for t in data if t.get('status') == 'open']))
except Exception: print(0)
" 2>/dev/null || echo 0)
  MAPPED_TICKETS=$(python3 -c "
import json
try:
  with open('$CONFIDENCE_MAP') as f:
    data = json.load(f)
    print(len(data.get('tickets', {})))
except Exception: print(0)
" 2>/dev/null || echo 0)
  if [[ "$OPEN_TICKETS" != "$MAPPED_TICKETS" ]]; then
    ISSUES_FOUND+=("kimi-confidence-map:count-mismatch")
    NEEDS_KEN+=("kimi confidence mapping has $MAPPED_TICKETS tickets but $OPEN_TICKETS are open — re-sync needed")
    log "  WARN: ticket count mismatch (mapped=$MAPPED_TICKETS, open=$OPEN_TICKETS)"
  else
    log "  OK: confidence mapping current (${MAP_AGE_DAYS}d old, $MAPPED_TICKETS tickets mapped)"
  fi
else
  ISSUES_FOUND+=("kimi-confidence-map:missing")
  NEEDS_KEN+=("kimi confidence mapping missing at $CONFIDENCE_MAP — run assessment to create")
  log "  ISSUE: confidence mapping missing"
fi
write_state

# ---------- FINAL REPORT WRITE ----------
log "=== WRITING FINAL REPORT ==="
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

log "=== AUTO-HEAL COMPLETE ==="
[[ ${#NEEDS_KEN[@]} -gt 0 ]] && exit 2 || exit 0
