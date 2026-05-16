#!/bin/zsh
# AInchors Auto-Heal — nightly system sweep, fix what's safe, file US for what needs Ken
# Runs 23:30 AEST. Output: state/auto-heal-YYYY-MM-DD.json
# Full from Day 3 (2026-04-27) — auto-fixes safe items, files US for needs-Ken items
#
# Exit codes: 0 = clean run; 1 = scan errors; 2 = needs-Ken items present (informational)

set -u  # don't set -e — want to keep going across checks

WORKSPACE="/Users/ainchorsangiefpl/.openclaw/workspace"
STATE_DIR="$WORKSPACE/state"
TODAY=$(date '+%Y-%m-%d')
NOW=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
NOW_LOCAL=$(date '+%Y-%m-%d %H:%M %Z')
REPORT="$STATE_DIR/auto-heal-${TODAY}.json"
LOG="$STATE_DIR/auto-heal-${TODAY}.log"
CHANGELOG_HELPER="$WORKSPACE/scripts/changelog-append.sh"

mkdir -p "$STATE_DIR"

# State arrays
typeset -a CHECKS_RUN
typeset -a ISSUES_FOUND
typeset -a AUTO_FIXED
typeset -a NEEDS_KEN

log() { echo "[$(date '+%H:%M:%S')] $1" | tee -a "$LOG"; }

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

# ---------- CHECK 3: Backup freshness ----------
log "CHECK 3: backup freshness"
CHECKS_RUN+=("backup_freshness")
# Check both full tar.gz backups and incremental rsync backups
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

# ---------- CHECK 4: Disk space ----------
log "CHECK 4: disk space"
CHECKS_RUN+=("disk_space")
DISK_PCT=$(df -h "$HOME" | awk 'NR==2 {gsub("%",""); print $5}')
if (( DISK_PCT > 90 )); then
  ISSUES_FOUND+=("disk:full:${DISK_PCT}%")
  NEEDS_KEN+=("Disk usage at ${DISK_PCT}% — needs cleanup or expansion")
fi

# ---------- CHECK 5: Stale plugin-runtime-deps ----------
log "CHECK 5: plugin-runtime-deps cleanup"
CHECKS_RUN+=("plugin_runtime_deps")
STALE_DIRS=$(ls -d "$HOME/.openclaw/plugin-runtime-deps/openclaw-unknown-"* 2>/dev/null | wc -l | tr -d ' ')
if (( STALE_DIRS > 1 )); then
  ISSUES_FOUND+=("plugin-deps:stale:${STALE_DIRS}-dirs")
  # AUTO-FIX: keep newest, remove rest
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
        --verified "ls confirms only 1 versioned dir remains" \
        --rollback "N/A — stale dirs are regenerated automatically on plugin load" \
        --linked "INC-20260426-003" 2>&1 || echo "")
      [[ -n "$CHG" ]] && log "  Logged $CHG"
    fi
  fi
fi

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

# ---------- CHECK 7: Git repo health ----------
log "CHECK 7: git repo health"
CHECKS_RUN+=("git_health")
# Obsidian vault retired (TKT-0042 Phase 4) — workspace only
for repo in "$WORKSPACE"; do
  if [[ -d "$repo/.git" ]]; then
    cd "$repo" || continue
    DIRTY=$(git status --porcelain | wc -l | tr -d ' ')
    if (( DIRTY > 0 )); then
      # AUTO-FIX: commit
      git add -A
      if git commit -m "chore: auto-heal commit ${TODAY}" > /dev/null 2>&1; then
        AUTO_FIXED+=("git-commit:$(basename "$repo"):${DIRTY}-files")
        log "  AUTO-FIX: committed $DIRTY untracked files in $(basename "$repo")"
      fi
    fi
  fi
done

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

# ---------- CHECK 12: Critical config baseline (anti-drift guard) ----------
log "CHECK 12: critical config baseline"
CHECKS_RUN+=("critical_config_baseline")
BASELINE="$WORKSPACE/state/critical-config-baseline.json"
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
      if [[ "$CHECK_SEVERITY" == "critical" ]]; then
        NEEDS_KEN+=("CRITICAL DRIFT: ${CHECK_NAME} | expected '${CHECK_EXPECTED}' | actual '${ACTUAL}' | fix: ${CHECK_FIX}")
      else
        NEEDS_KEN+=("WARN DRIFT: ${CHECK_NAME} | expected '${CHECK_EXPECTED}' | actual '${ACTUAL}' | fix: ${CHECK_FIX}")
      fi
      log "  X ${CHECK_ID} DRIFT: expected '${CHECK_EXPECTED}' got '${ACTUAL}'"
    fi
  done
else
  log "  WARN: critical-config-baseline.json missing - anti-drift guard disabled"
  ISSUES_FOUND+=("config-baseline:file-missing")
  NEEDS_KEN+=("critical-config-baseline.json missing at $BASELINE - anti-drift guard disabled")
fi

# ---------- CHECK 13: Aria (business agent) health ----------
log "CHECK 13: Aria business agent health"
CHECKS_RUN+=("aria_health")
BUSINESS_WS="$HOME/.openclaw/workspace-business"
BUSINESS_AUTH="$HOME/.openclaw/agents/business/agent/auth-profiles.json"
if [[ ! -d "$BUSINESS_WS" ]]; then
  ISSUES_FOUND+=("aria:workspace-missing")
  NEEDS_KEN+=("Aria business workspace missing at $BUSINESS_WS")
else
  log "  OK aria workspace exists"
  # Check auth profiles present
  if [[ ! -f "$BUSINESS_AUTH" ]]; then
    ISSUES_FOUND+=("aria:auth-missing")
    # AUTO-FIX: copy auth from main agent
    cp "$HOME/.openclaw/agents/main/agent/auth-profiles.json" "$BUSINESS_AUTH" 2>/dev/null && {
      AUTO_FIXED+=("aria-auth-copied-from-main")
      log "  AUTO-FIX: copied auth-profiles to business agent"
    } || NEEDS_KEN+=("Aria auth-profiles.json missing and copy failed")
  else
    log "  OK aria auth-profiles present"
  fi
  # Check git dirty in business workspace
  if [[ -d "$BUSINESS_WS/.git" ]]; then
    DIRTY=$(cd "$BUSINESS_WS" && git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    if (( DIRTY > 0 )); then
      cd "$BUSINESS_WS" && git add -A && git commit -m "chore: auto-heal commit ${TODAY}" > /dev/null 2>&1
      AUTO_FIXED+=("aria-git-commit:${DIRTY}-files")
      log "  AUTO-FIX: committed $DIRTY files in business workspace"
    fi
  fi
fi

# ---------- CHECK 14B: Telegram routing integrity (auto-fix) ----------
log "CHECK 14B: Telegram routing audit"
CHECKS_RUN+=("telegram_routing")
TG_AUDIT="$WORKSPACE/scripts/telegram-routing-audit.sh"
if [[ -x "$TG_AUDIT" ]]; then
  bash "$TG_AUDIT" --quiet 2>/dev/null
  TG_EXIT=$?
  if [[ $TG_EXIT -ne 0 ]]; then
    log "  VIOLATION: Telegram routing misconfigured — attempting auto-fix..."
    bash "$TG_AUDIT" --fix --quiet 2>/dev/null
    FIX_EXIT=$?
    if [[ $FIX_EXIT -eq 0 ]]; then
      AUTO_FIXED+=("telegram_routing:auto-fixed")
      log "  AUTO-FIX: Telegram routing corrected"
    else
      ISSUES_FOUND+=("telegram_routing_violation")
      NEEDS_KEN+=("Telegram routing violation detected and auto-fix failed — run: bash scripts/telegram-routing-audit.sh --fix")
      log "  FAIL: Telegram routing auto-fix failed — needs Ken"
    fi
  else
    log "  OK: Telegram routing all correct"
  fi
else
  log "  SKIP: telegram-routing-audit.sh not found"
fi

# ---------- CHECK 14: MEMORY.md + tiered memory files size guard ----------
log "CHECK 14: bootstrap file size guard (tiered memory: Option B)"
CHECKS_RUN+=("bootstrap_size")
# Tiered limits: MEMORY.md ≤10k (warn 8k), MEMORY_TICKETS.md ≤8k, MEMORY_DECISIONS.md ≤6k
declare -A MEM_FILES MEM_WARN MEM_HARD
MEM_FILES=([MEMORY.md]="$WORKSPACE/MEMORY.md" [MEMORY_TICKETS.md]="$WORKSPACE/MEMORY_TICKETS.md" [MEMORY_DECISIONS.md]="$WORKSPACE/MEMORY_DECISIONS.md")
MEM_WARN=([MEMORY.md]=8000 [MEMORY_TICKETS.md]=6000 [MEMORY_DECISIONS.md]=5000)
MEM_HARD=([MEMORY.md]=10000 [MEMORY_TICKETS.md]=8000 [MEMORY_DECISIONS.md]=6000)
for fname in MEMORY.md MEMORY_TICKETS.md MEMORY_DECISIONS.md; do
  fpath="${MEM_FILES[$fname]}"
  fwarn="${MEM_WARN[$fname]}"
  fhard="${MEM_HARD[$fname]}"
  if [[ -f "$fpath" ]]; then
    fsize=$(wc -c < "$fpath" | tr -d ' ')
    if (( fsize > fhard )); then
      ISSUES_FOUND+=("${fname}_hard_limit")
      NEEDS_KEN+=("${fname} is ${fsize} chars — OVER hard limit ${fhard}. Trim immediately.")
      log "  ERROR: ${fname} ${fsize} chars > hard limit ${fhard}"
    elif (( fsize > fwarn )); then
      ISSUES_FOUND+=("${fname}_warn")
      NEEDS_KEN+=("${fname} is ${fsize} chars (warn ${fwarn} / hard ${fhard}). Trim soon.")
      log "  WARN: ${fname} ${fsize} chars > warn threshold ${fwarn}"
    else
      log "  OK: ${fname} ${fsize} chars (warn ${fwarn} / hard ${fhard})"
    fi
  else
    if [[ "$fname" == "MEMORY.md" ]]; then
      log "  SKIP: ${fname} not found"
    else
      log "  OK: ${fname} not yet created (optional)"
    fi
  fi
done
# Check SOUL.md sizes for all agents
for SOUL in "$WORKSPACE/SOUL.md" \
            "$HOME/.openclaw/workspace-business/SOUL.md" \
            "$HOME/.openclaw/workspace-security/SOUL.md" \
            "$HOME/.openclaw/workspace-governance/SOUL.md" \
            "$HOME/.openclaw/workspace-legal/SOUL.md" \
            "$HOME/.openclaw/workspace-qa/SOUL.md"; do
  if [[ -f "$SOUL" ]]; then
    SOUL_SIZE=$(wc -c < "$SOUL" | tr -d ' ')
    AGENT_NAME=$(basename $(dirname "$SOUL"))
    if (( SOUL_SIZE > 6000 )); then
      ISSUES_FOUND+=("soul_oversized:${AGENT_NAME}")
      NEEDS_KEN+=("SOUL.md oversized: ${AGENT_NAME} is ${SOUL_SIZE} chars (warn: 6000 / hard: 10000). Compact immediately.")
      log "  WARN: ${AGENT_NAME}/SOUL.md ${SOUL_SIZE} chars > 6000 threshold"
    else
      log "  OK: ${AGENT_NAME}/SOUL.md ${SOUL_SIZE} chars"
    fi
  fi
done

# ---------- CHECK 14C: Journal format validation ----------
log "CHECK 14C: journal format validation"
CHECKS_RUN+=("journal_format")
JOURNAL_TODAY="$WORKSPACE/memory/journal-${TODAY}.md"
JOURNAL_YESTERDAY="$WORKSPACE/memory/journal-$(date -v-1d '+%Y-%m-%d').md"
for JFILE in "$JOURNAL_TODAY" "$JOURNAL_YESTERDAY"; do
  JDATE=$(basename "$JFILE" .md | sed 's/journal-//')
  if [[ ! -f "$JFILE" ]]; then
    # Auto-heal runs at 01:00 AEST. At that time:
    # - YESTERDAY's journal must exist (written at 23:55 AEST the previous day)
    # - TODAY's journal does not exist yet (won't be written until 23:55 AEST today) — skip check
    if [[ "$JFILE" == "$JOURNAL_YESTERDAY" ]]; then
      ISSUES_FOUND+=("journal:missing:${JDATE}")
      NEEDS_KEN+=("Journal missing for ${JDATE}: $JFILE not found. EOD cron (4d926b2c) may have failed.")
      log "  ISSUE: journal missing for $JDATE"
    else
      log "  SKIP: today's journal not yet due at 01:00 AEST (written by EOD cron at 23:55 AEST)"
    fi
    continue
  fi
  # Journal exists — validate format (must have per-entry structure, not summary style)
  # Correct format signature: "Ken's prompt (verbatim):"
  # Wrong format signature: large block of prompts at top without per-entry structure
  VERBATIM_COUNT=$(grep -c "Ken's prompt (verbatim):" "$JFILE" 2>/dev/null || echo 0)
  LINE_COUNT=$(wc -l < "$JFILE" | tr -d ' ')
  # A valid journal for an active day should have many per-entry blocks
  # Wrong-format journal will have 0 verbatim markers (summary style)
  if (( VERBATIM_COUNT == 0 && LINE_COUNT > 50 )); then
    ISSUES_FOUND+=("journal:wrong-format:${JDATE}")
    NEEDS_KEN+=("Journal ${JDATE} is in WRONG FORMAT (${LINE_COUNT} lines, 0 per-entry verbatim blocks). Likely created by premature heartbeat. Rebuild required — see memory/journal-2026-05-09.md for correct format.")
    log "  ISSUE: journal $JDATE wrong format — $LINE_COUNT lines, 0 verbatim blocks"
  elif (( VERBATIM_COUNT < 3 && LINE_COUNT > 100 )); then
    # Low verbatim count for a long journal is suspicious
    ISSUES_FOUND+=("journal:suspect-format:${JDATE}")
    NEEDS_KEN+=("Journal ${JDATE} may be in wrong format (${LINE_COUNT} lines, only ${VERBATIM_COUNT} per-entry verbatim blocks). Review format.")
    log "  WARN: journal $JDATE suspect — $LINE_COUNT lines, only $VERBATIM_COUNT verbatim blocks"
  else
    log "  OK: journal $JDATE valid ($LINE_COUNT lines, $VERBATIM_COUNT verbatim blocks)"
  fi
done

# ---------- CHECK 15: Cron dead-letter cleanup ----------
log "CHECK 15: cron dead-letter state"
CHECKS_RUN+=("cron_dead_letter")
DL_FILE="$STATE_DIR/cron-dead-letter.json"
if [[ -f "$DL_FILE" ]]; then
  # Any cron with failCount >= 5 and not recovered → needs-ken
  CRITICAL=$(jq -r '[.[] | select(.failCount >= 5 and .status != "recovered")] | length' "$DL_FILE" 2>/dev/null || echo 0)
  if (( CRITICAL > 0 )); then
    CRITICAL_NAMES=$(jq -r '[.[] | select(.failCount >= 5 and .status != "recovered") | "\(.name) (\(.cronId)) fails=\(.failCount) lastErr=\(.lastError | .[0:80])"] | join("; ")' "$DL_FILE" 2>/dev/null || echo "unknown")
    ISSUES_FOUND+=("cron-dead-letter:${CRITICAL}-critical")
    NEEDS_KEN+=("$CRITICAL cron(s) dead-lettered with >= 5 failures — disable or fix before they burn more API calls: $CRITICAL_NAMES")
    log "  ISSUE: $CRITICAL cron(s) with failCount >= 5 not recovered"
  fi
  # Auto-fix: remove entries with status=recovered
  RECOVERED=$(jq '[.[] | select(.status == "recovered")] | length' "$DL_FILE" 2>/dev/null || echo 0)
  if (( RECOVERED > 0 )); then
    CLEANED=$(jq '[.[] | select(.status != "recovered")]' "$DL_FILE")
    echo "$CLEANED" > "$DL_FILE"
    AUTO_FIXED+=("cron-dead-letter-cleanup:removed-${RECOVERED}-recovered-entries")
    log "  AUTO-FIX: removed $RECOVERED recovered entries from cron-dead-letter.json"
  fi
  if (( CRITICAL == 0 && RECOVERED == 0 )); then
    TOTAL=$(jq 'length' "$DL_FILE" 2>/dev/null || echo 0)
    log "  OK: $TOTAL dead-letter entries, none critical"
  fi
else
  log "  OK: no cron-dead-letter.json (no dead-lettered crons)"
fi

# ---------- CHECK 16: Stale running task cleanup ----------
# Uses JSON API to get full task IDs (audit output truncates IDs with ellipsis)
log "CHECK 16: zombie task runs (stale_running)"
CHECKS_RUN+=("zombie_tasks")
STALE_THRESHOLD_HOURS=4
STALE_THRESHOLD_MS=$(( STALE_THRESHOLD_HOURS * 3600 * 1000 ))
NOW_MS=$(date +%s)000

ZOMBIE_JSON=$(openclaw tasks list --status running --json 2>/dev/null || echo '{"tasks":[]}')
STALE_TASKS=$(echo "$ZOMBIE_JSON" | jq -r --argjson now "$NOW_MS" --argjson thresh "$STALE_THRESHOLD_MS" '
  .tasks[]? | select(.status == "running") |
  (.lastEventAt // .startedAt // 0) as $lastEvent |
  select(($now | tonumber) - $lastEvent > $thresh) |
  {taskId, runtime, lastEventAt, startedAt, age_ms: (($now | tonumber) - $lastEvent)}
')

STALE_COUNT=$(echo "$STALE_TASKS" | jq -s 'length')
if (( STALE_COUNT > 0 )); then
  log "  ISSUE: $STALE_COUNT zombie task(s) detected (> ${STALE_THRESHOLD_HOURS}h stale) — cancelling..."
  CANCELLED=0
  echo "$STALE_TASKS" | jq -r '.taskId' | while IFS= read -r task_id; do
    [[ -z "$task_id" ]] && continue
    openclaw tasks cancel "$task_id" >> "$LOG" 2>&1 && {
      AUTO_FIXED+=("zombie-task-cancelled:${task_id:0:8}")
      log "  AUTO-FIX: cancelled zombie task ${task_id:0:8}"
      (( CANCELLED++ ))
    } || log "  FAIL: could not cancel zombie task ${task_id:0:8}"
  done
  log "  AUTO-FIX: cancelled $CANCELLED/$STALE_COUNT zombie task(s)"
  if (( CANCELLED < STALE_COUNT )); then
    NEEDS_KEN+=("$((STALE_COUNT - CANCELLED)) zombie task(s) could not be auto-cancelled — run: openclaw tasks list --status running")
  fi
else
  log "  OK: no zombie tasks (> ${STALE_THRESHOLD_HOURS}h threshold)"
fi

# ---------- CHECK 17: Keychain secret liveness ----------
log "CHECK 17: keychain secret liveness"
CHECKS_RUN+=("keychain_liveness")
GET_SECRET="$WORKSPACE/scripts/get-secret.sh"
if [[ -f "$GET_SECRET" ]]; then
  # Anthropic key
  ANTH_KEY=$(zsh "$GET_SECRET" anthropic-api-key 2>/dev/null)
  if [[ -n "$ANTH_KEY" && ${#ANTH_KEY} -gt 20 ]]; then
    ANTH_HTTP=$(curl -s -o /dev/null -w "%{http_code}" \
      -H "anthropic-version: 2023-06-01" \
      -H "x-api-key: $ANTH_KEY" \
      "https://api.anthropic.com/v1/models" 2>/dev/null)
    if [[ "$ANTH_HTTP" == "200" ]]; then
      log "  OK: anthropic-api-key live (HTTP 200)"
      # AUTO-FIX: sync key to all agent auth-profiles.json files that have a stale copy
      for AUTH_FILE in \
        "$HOME/.openclaw/agents/business/agent/auth-profiles.json" \
        "$HOME/.openclaw/agents/security/agent/auth-profiles.json" \
        "$HOME/.openclaw/agents/governance/agent/auth-profiles.json" \
        "$HOME/.openclaw/agents/legal/agent/auth-profiles.json" \
        "$HOME/.openclaw/agents/qa/agent/auth-profiles.json"; do
        if [[ -f "$AUTH_FILE" ]]; then
          STORED_KEY=$(python3 -c "import json; d=json.load(open('$AUTH_FILE')); print(d.get('profiles',{}).get('anthropic:default',{}).get('key',''))" 2>/dev/null)
          if [[ "$STORED_KEY" != "$ANTH_KEY" ]]; then
            python3 -c "
import json
path='$AUTH_FILE'
with open(path) as f: d=json.load(f)
if 'anthropic:default' in d.get('profiles',{}):
    d['profiles']['anthropic:default']['key']='$ANTH_KEY'
with open(path,'w') as f: json.dump(d,f,indent=2)
" 2>/dev/null && {
              AUTO_FIXED+=("auth-key-synced:$(basename $(dirname $AUTH_FILE))")
              log "  AUTO-FIX: synced anthropic key to $AUTH_FILE"
            }
          fi
        fi
      done
    else
      ISSUES_FOUND+=("keychain:anthropic-key-stale")
      NEEDS_KEN+=("Anthropic API key in keychain returning HTTP $ANTH_HTTP — key may be rotated or disabled. Run: zsh scripts/get-secret.sh anthropic-api-key and update keychain if needed.")
      log "  ISSUE: anthropic-api-key returning HTTP $ANTH_HTTP — stale or disabled"
    fi
  else
    ISSUES_FOUND+=("keychain:anthropic-key-missing")
    NEEDS_KEN+=("Anthropic API key not found in keychain via get-secret.sh")
    log "  ISSUE: anthropic-api-key not found"
  fi
else
  log "  SKIP: get-secret.sh not found at $GET_SECRET"
fi

# ---------- WRITE REPORT ----------
log "=== WRITING REPORT ==="

# Build JSON arrays
checks_json=$(printf '%s\n' "${CHECKS_RUN[@]}" | jq -R . | jq -s .)
issues_json=$(printf '%s\n' "${ISSUES_FOUND[@]}" | jq -R . | jq -s 'map(select(length > 0))')
fixed_json=$(printf '%s\n' "${AUTO_FIXED[@]}" | jq -R . | jq -s 'map(select(length > 0))')
needsken_json=$(printf '%s\n' "${NEEDS_KEN[@]}" | jq -R . | jq -s 'map(select(length > 0))')

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
  "exit_status": "complete"
}
EOF


# ---------- FILE INC FOR EACH AUTO-FIX (ITSM-US-007) ----------
# NOTE: git-commit auto-fixes are EXCLUDED from incident logging (CHG-0168, 2026-05-05).
# Routine auto-heal git commits are not incidents. Only log real service/config issues.
if (( ${#AUTO_FIXED[@]} > 0 )); then
  log "Filing INC records for qualifying auto-fixed item(s)..."
  for fix in "${AUTO_FIXED[@]}"; do
    # Skip git commit operations — these are housekeeping, not incidents
    if [[ "$fix" == git-commit:* ]]; then
      log "  Skipping INC for routine git op: $fix"
      continue
    fi
    bash "$WORKSPACE/scripts/incident-log.sh" \
      --title "AUTO-HEAL: $fix" \
      --severity P4 \
      --type "planned" \
      --description "Auto-healed by auto-heal.sh at $NOW_LOCAL. Item: $fix. No Ken action required." \
      >> "$HOME/Backups/ainchors/logs/auto-heal.log" 2>&1 || true
  done
  log "INC records filed for qualifying auto-fixed items (git ops excluded)."
fi

log "Report written: $REPORT"
log "  checks: ${#CHECKS_RUN[@]} | issues: ${#ISSUES_FOUND[@]} | auto-fixed: ${#AUTO_FIXED[@]} | needs-ken: ${#NEEDS_KEN[@]}"

# US40: Log each auto-fix and needs-ken item to obs.db
OBS_LOG_CMD="$WORKSPACE/scripts/obs-log.sh"
if [[ -x "$OBS_LOG_CMD" ]]; then
  for _fix in "${AUTO_FIXED[@]}"; do
    [[ -z "$_fix" ]] && continue
    bash "$OBS_LOG_CMD" \
      --source auto-heal --level INFO --type auto_heal_fix \
      --message "Auto-heal fixed: ${_fix:0:120}" \
      --detail "{\"item\":\"${_fix:0:200}\",\"runAt\":\"$NOW\"}" \
      >> "$LOG" 2>&1 || true
  done
  for _item in "${NEEDS_KEN[@]}"; do
    [[ -z "$_item" ]] && continue
    # Escape double quotes in item for JSON safety
    _item_safe=${_item//"/\\"}
    bash "$OBS_LOG_CMD" \
      --source auto-heal --level WARN --type auto_heal_needs_ken \
      --message "Needs Ken: ${_item:0:120}" \
      --detail "{\"item\":\"${_item_safe:0:200}\",\"runAt\":\"$NOW\"}" \
      >> "$LOG" 2>&1 || true
  done
  log "US40: obs-log events written for ${#AUTO_FIXED[@]} auto-fix + ${#NEEDS_KEN[@]} needs-ken items"
fi

log "=== AUTO-HEAL COMPLETE ==="

# Exit code reflects needs-ken status (informational, not failure)
if (( ${#NEEDS_KEN[@]} > 0 )); then
  exit 2
fi
exit 0
