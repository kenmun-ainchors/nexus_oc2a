#!/bin/zsh
# AInchors Auto-Heal — nightly system sweep, fix what's safe, file US for what needs Ken
# Runs 23:30 AEST. Output: state/auto-heal-YYYY-MM-DD.json
# Full from Day 3 (2026-04-27) — auto-fixes safe items, files US for needs-Ken items
#
# Exit codes: 0 = clean run; 1 = scan errors; 2 = needs-Ken items present (informational)
#
# DRY-RUN CONTRACT (TKT-0529 B3.3):
# ENFORCE_DRY_RUN=true → log-only, no blocking/mutation.
# Retained auto-destructive hygiene ops (stale plugin dirs, stale locks, orphan gateways,
# PG sequence fix) run regardless because they are health/housekeeping with proven safety history.

set -euo pipefail

# Preserve legacy keep-going semantics inside individual checks using explicit || true.
# TKT-0529 A7 Bundle 1: upgraded from set -u only.

# Resolve workspace root dynamically; fall back to known path only when unset.
WORKSPACE="${WORKSPACE_ROOT:-$HOME/.openclaw/workspace}"
STATE_DIR="$WORKSPACE/state"
TODAY=$(TZ="Australia/Melbourne" date '+%Y-%m-%d')
NOW=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
NOW_LOCAL=$(TZ="Australia/Melbourne" date '+%Y-%m-%d %H:%M %Z')
REPORT="$STATE_DIR/auto-heal-${TODAY}.json"
LOG="$STATE_DIR/auto-heal-${TODAY}.log"
STATE_TMP="$STATE_DIR/auto-heal-current.json"
CHANGELOG_HELPER="$WORKSPACE/scripts/changelog-append.sh"

mkdir -p "$STATE_DIR"

# --- SELF LOCKFILE (TKT-0529 B3.2) ---
# Prevents concurrent auto-heal.sh runs (cron overlap + manual). If lockfile exists
# and the recorded PID is alive and is an auto-heal.sh process, exit 0 (single instance).
# Stale locks (dead PID or non-auto-heal PID) are removed and recreated.
LOCKFILE="$STATE_DIR/auto-heal.lock"

acquire_autoheal_lock() {
  # If lockfile does not exist → create it
  if [[ ! -f "$LOCKFILE" ]]; then
    echo "pid=$$ started=$(date -u '+%Y-%m-%dT%H:%M:%SZ')" > "$LOCKFILE" 2>/dev/null || true
    return 0
  fi
  # Lockfile exists → read PID
  local lock_pid
  lock_pid=$(grep -oE 'pid=[0-9]+' "$LOCKFILE" 2>/dev/null | head -1 | sed 's/pid=//' || true)
  if [[ -z "$lock_pid" ]]; then
    # Corrupt/empty lock — treat as stale
    # Note: log() may not be defined yet at this point; use plain echo as fallback
    if type log >/dev/null 2>&1; then
      log "  LOCK: removing corrupt auto-heal lock"
    else
      echo "[$(date '+%H:%M:%S')] LOCK: removing corrupt auto-heal lock"
    fi
    rm -f "$LOCKFILE" 2>/dev/null || true
    echo "pid=$$ started=$(date -u '+%Y-%m-%dT%H:%M:%SZ')" > "$LOCKFILE" 2>/dev/null || true
    return 0
  fi
  # Check if process is alive AND is auto-heal.sh
  if ps -p "$lock_pid" -o comm= 2>/dev/null | grep -q auto-heal; then
    if type log >/dev/null 2>&1; then
      log "auto-heal already running (PID $lock_pid)"
    else
      echo "[$(date '+%H:%M:%S')] auto-heal already running (PID $lock_pid)"
    fi
    return 1
  fi
  # PID is dead or not auto-heal → stale
  if type log >/dev/null 2>&1; then
    log "removing stale auto-heal lock (pid=$lock_pid not running)"
  else
    echo "[$(date '+%H:%M:%S')] removing stale auto-heal lock (pid=$lock_pid not running)"
  fi
  rm -f "$LOCKFILE" 2>/dev/null || true
  echo "pid=$$ started=$(date -u '+%Y-%m-%dT%H:%M:%SZ')" > "$LOCKFILE" 2>/dev/null || true
  return 0
}

release_autoheal_lock() {
  if [[ -f "$LOCKFILE" ]]; then
    # Only remove if it still matches our PID
    local lock_pid
    lock_pid=$(grep -oE 'pid=[0-9]+' "$LOCKFILE" 2>/dev/null | head -1 | sed 's/pid=//' || true)
    if [[ "$lock_pid" == "$$" ]] || [[ -z "$lock_pid" ]]; then
      rm -f "$LOCKFILE" 2>/dev/null || true
    fi
  fi
}

# --- ATOMIC WRITE HELPER (TKT-0529 A7 Bundle 2) ---
# Source the shared atomic-write lib. The base atomic_write() in the helper
# installs a transient EXIT/INT/TERM trap that ends with `trap - EXIT INT TERM`,
# which clobbers the auto-heal crash trap (set on ERR/SIGINT/SIGTERM) for
# INT/TERM. We wrap it locally with safe_atomic_write() that snapshots the
# trap table to a tmp file, invokes atomic_write(), and restores the snapshot
# so the crash trap is preserved across every state-file write.
source "${WORKSPACE}/scripts/lib/atomic-write.sh"
safe_atomic_write() {
  local target="$1"
  local _sw_trapfile
  _sw_trapfile=$(mktemp "${WORKSPACE}/.tmp.auto-heal.safeatomic.XXXXXX")
  trap > "$_sw_trapfile"
  atomic_write "$target"
  source "$_sw_trapfile"
  rm -f "$_sw_trapfile"
}

# --- ARGUMENT PARSING (TKT-0340 A1: --enforce framework) ---
ENFORCE_MODE=false
DRY_RUN=false
ALLOW_CONTEXT_SUMMARY=false

for arg in "$@"; do
  case "$arg" in
    --enforce) ENFORCE_MODE=true ;;
    --dry-run) DRY_RUN=true ;;
    # TKT-0529 B3.1: opt-in flag for context-file auto-summarization (HITL gate)
    --allow-context-summary) ALLOW_CONTEXT_SUMMARY=true ;;
  esac
done

export ENFORCE_MODE DRY_RUN

# State arrays
typeset -a CHECKS_RUN
typeset -a ISSUES_FOUND
typeset -a AUTO_FIXED
typeset -a NEEDS_KEN

log() { echo "[$(date '+%H:%M:%S')] $1" | tee -a "$LOG"; }

# --- CONTEXT SUMMARY HITL GATE (TKT-0529 B3.1) ---
# Ken decision 2026-06-18: context-file auto-summarization is gated to NEEDS_KEN
# by default. Auto-heal must NOT rewrite SOUL.md / AGENTS.md / MEMORY.md / HEARTBEAT.md
# unless explicitly approved via:
#   (a) --allow-context-summary CLI flag, OR
#   (b) state/allow-context-summary.json with { "allowed": true, "expires": "ISO" } (future or empty)
ALLOW_CONTEXT_SUMMARY_FILE="$STATE_DIR/allow-context-summary.json"

context_summary_allowed() {
  # CLI flag overrides
  if [[ "${ALLOW_CONTEXT_SUMMARY:-false}" == "true" ]]; then
    return 0
  fi
  # State-file opt-in
  if [[ ! -f "$ALLOW_CONTEXT_SUMMARY_FILE" ]]; then
    return 1
  fi
  local allowed expires_epoch now_epoch
  allowed=$(jq -r '.allowed // false' "$ALLOW_CONTEXT_SUMMARY_FILE" 2>/dev/null || echo "false")
  expires_epoch=$(jq -r '.expiresEpoch // empty' "$ALLOW_CONTEXT_SUMMARY_FILE" 2>/dev/null || true)
  if [[ "$allowed" != "true" ]]; then
    return 1
  fi
  # If expiresEpoch is set, check it
  if [[ -n "$expires_epoch" ]]; then
    now_epoch=$(date +%s)
    if (( now_epoch >= expires_epoch )); then
      return 1
    fi
  fi
  return 0
}

# TKT-0529 B3.2: Acquire self lockfile here (after log() is defined) to prevent
# concurrent runs. exit 0 if another auto-heal is in progress.
if ! acquire_autoheal_lock; then
  exit 0
fi

# --- FAIL-SAFE REPORTING (TKT-0279) ---
# Writes the current state to a JSON file. Called after every check and via trap.
write_state() {
  local exit_status=${1:-"in-progress"}
  local checks_json=$(printf '%s\n' "${CHECKS_RUN[@]:-}" | jq -R . | jq -s .)
  local issues_json=$(printf '%s\n' "${ISSUES_FOUND[@]:-}" | jq -R . | jq -s 'map(select(length > 0))')
  local fixed_json=$(printf '%s\n' "${AUTO_FIXED[@]:-}" | jq -R . | jq -s 'map(select(length > 0))')
  local needsken_json=$(printf '%s\n' "${NEEDS_KEN[@]:-}" | jq -R . | jq -s 'map(select(length > 0))')

  safe_atomic_write "$REPORT" <<EOF
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
# TKT-0529 B3.2: also releases the self lockfile on EXIT so a normal completion cleans up.
trap 'release_autoheal_lock' EXIT
trap 'log "CRASH DETECTED: Trap triggered. Finalizing partial report..."; write_state "crashed"; release_autoheal_lock; exit 1' ERR SIGINT SIGTERM

# --- DRY-RUN SAFETY: 24h grace period before real enforcement (TKT-0340 A1) ---
# Must be AFTER log() is defined but BEFORE any CHECKs run
ENFORCE_DRY_RUN=false
if [[ "$ENFORCE_MODE" == "true" ]]; then
  GRACE_FILE="$STATE_DIR/enforce-dry-run-until.json"
  NOW_EPOCH=$(date +%s)

  if [[ -f "$GRACE_FILE" ]]; then
    GRACE_EXPIRES=$(jq -r '.enforceAfterEpoch // 0' "$GRACE_FILE" 2>/dev/null || echo 0)
    if (( NOW_EPOCH >= GRACE_EXPIRES )); then
      log "ENFORCE: Dry-run grace period EXPIRED. Real enforcement ACTIVE."
      ENFORCE_DRY_RUN=false
    else
      REMAINING=$(( (GRACE_EXPIRES - NOW_EPOCH) / 3600 ))
      log "ENFORCE: Dry-run grace period active (~${REMAINING}h remaining). Will LOG only, no blocking."
      ENFORCE_DRY_RUN=true
    fi
  else
    # First --enforce invocation: seed the 24h grace period
    GRACE_EXPIRES=$((NOW_EPOCH + 86400))
    GRACE_EXPIRES_ISO=$(python3 -c "import datetime; print(datetime.datetime.utcfromtimestamp($GRACE_EXPIRES).strftime('%Y-%m-%dT%H:%M:%SZ'))" 2>/dev/null || echo "unknown")
    mkdir -p "$STATE_DIR"
    safe_atomic_write "$GRACE_FILE" <<EOGRACE
{
  "seededAt": "$NOW",
  "enforceAfterEpoch": $GRACE_EXPIRES,
  "enforceAfterISO": "$GRACE_EXPIRES_ISO",
  "note": "Enforcement blocked until this timestamp. Delete this file to bypass grace period."
}
EOGRACE
    log "ENFORCE: First --enforce invocation. Seeded 24h dry-run grace period (expires $GRACE_EXPIRES_ISO)."
    ENFORCE_DRY_RUN=true
  fi
fi

# --dry-run flag overrides: force dry-run regardless
if [[ "$DRY_RUN" == "true" ]]; then
  ENFORCE_DRY_RUN=true
  log "DRY-RUN: --dry-run flag set. Enforcement is simulated only (no blocking)."
fi

# --- ENFORCE MODE ANNOUNCEMENT ---
if [[ "$ENFORCE_MODE" == "true" ]]; then
  if [[ "$ENFORCE_DRY_RUN" == "true" ]]; then
    log "ENFORCE MODE: ON (dry-run — logging only, no blocking)"
  else
    log "ENFORCE MODE: ON (live — will actively block/reject violations)"
  fi
fi

log "=== AUTO-HEAL START $NOW_LOCAL ==="

# ---------- CHECK 1: Auth profiles + delegated tokens ----------
log "CHECK 1: auth profiles + delegated tokens"
CHECKS_RUN+=("auth_profiles")
AUTH_FILE="$HOME/.openclaw/agents/main/agent/auth-profiles.json"
# CHG-0857: Removed Anthropic dependency. Only verify Ollama auth profile exists.
if [[ -f "$AUTH_FILE" ]]; then
  HAS_OLLAMA=$(jq -r '.profiles."ollama:default".key // empty' "$AUTH_FILE" 2>/dev/null)
  if [[ -z "$HAS_OLLAMA" ]]; then
    ISSUES_FOUND+=("auth:ollama-missing")
    NEEDS_KEN+=("Ollama key missing in auth-profiles.json — fallback chain broken")
    log "  ISSUE: ollama key missing"
  fi
else
  # CHG-0857: Check all agents (main, business, security, legal, qa) for auth-profiles.json
  AUTH_CHECK_FAILED=false
  for agent_dir in "$HOME/.openclaw/agents/main/agent" "$HOME/.openclaw/agents/business/agent" "$HOME/.openclaw/agents/security/agent" "$HOME/.openclaw/agents/legal/agent" "$HOME/.openclaw/agents/qa/agent"; do
    if [[ ! -f "$agent_dir/auth-profiles.json" ]]; then
      AUTH_CHECK_FAILED=true
      ISSUES_FOUND+=("auth:file-missing:$(basename $(dirname $agent_dir))")
      log "  ISSUE: $(basename $(dirname $agent_dir)) auth-profiles.json missing"
    fi
  done
  if [[ "$AUTH_CHECK_FAILED" == "true" ]]; then
    NEEDS_KEN+=("auth-profiles.json missing for one or more agents — CHG-0857 requires recreation")
  fi
fi

# CHECK 1a: Delegated gog auth tokens (TKT-0336)
log "CHECK 1a: delegated gog auth tokens"
CHECKS_RUN+=("delegated_auth")
DELEG_AUTH_SCRIPT="$WORKSPACE/scripts/check-delegated-auth.sh"
if [[ -x "$DELEG_AUTH_SCRIPT" ]]; then
  # TKT-0340 A1: Pass --enforce when ENFORCE_MODE is true
  DELEG_ARGS="--json"
  if [[ "$ENFORCE_MODE" == "true" ]]; then
    if [[ "$ENFORCE_DRY_RUN" == "true" ]]; then
      DELEG_ARGS="$DELEG_ARGS --enforce --dry-run"
    else
      DELEG_ARGS="$DELEG_ARGS --enforce"
    fi
  fi
  zsh "$DELEG_AUTH_SCRIPT" $=DELEG_ARGS >> "$LOG" 2>&1
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
  NEEDS_KEN+=("No backup files found in ${HOME}/Backups/ainchors/workspace/ or workspace-incremental/")
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
STALE_DIRS=$(ls -d "$HOME/.openclaw/plugin-runtime-deps/openclaw-unknown-"* 2>/dev/null | wc -l | tr -d ' ' || echo 0)
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
        --changed "Removed $REMOVED stale openclaw-unknown-* dirs from \${HOME}/.openclaw/plugin-runtime-deps/, kept newest" \
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

# ---------- CHECK 9: Ollama weekly request budget ----------
# CHG-0500 + cost-state billing-model change 2026-06-15: tracking moved from
# `apiBalance.remainingEstimate` (USD credit, decommissioned) to `turnsLimit`
# (Ollama Cloud weekly request cap, 30,000/week flat count). Thresholds live
# in `spendAlerts.tier1-4` (50/70/85/95% of weekly limit). auto-heal flags at
# tier3 (85%, CRITICAL → NEEDS_KEN); tier2 (70%, ALERT) is surfaced via the
# heartbeat instead of NEEDS_KEN.
log "CHECK 9: Ollama weekly request budget"
CHECKS_RUN+=("request_budget")
COST_FILE="$STATE_DIR/cost-state.json"
if [[ -f "$COST_FILE" ]]; then
  CURRENT_PCT=$(jq -r '.turnsLimit.currentPct // 0' "$COST_FILE")
  REQUESTS_REMAINING=$(jq -r '.turnsLimit.requestsRemaining // 0' "$COST_FILE")
  TIER2_PCT=$(jq -r '.spendAlerts.tier2.thresholdPct // 70' "$COST_FILE")
  TIER3_PCT=$(jq -r '.spendAlerts.tier3.thresholdPct // 85' "$COST_FILE")
  CURRENT_PCT_INT=$(echo "$CURRENT_PCT" | awk '{printf "%d", $1*100}')
  TIER2_INT=$(echo "$TIER2_PCT" | awk '{printf "%d", $1*100}')
  TIER3_INT=$(echo "$TIER3_PCT" | awk '{printf "%d", $1*100}')
  if (( CURRENT_PCT_INT >= TIER3_INT )); then
    ISSUES_FOUND+=("request-budget:critical:${CURRENT_PCT}pct")
    NEEDS_KEN+=("Ollama weekly request budget CRITICAL: ${CURRENT_PCT}% used (${REQUESTS_REMAINING} requests remaining, tier3 threshold ${TIER3_PCT}%)")
  elif (( CURRENT_PCT_INT >= TIER2_INT )); then
    ISSUES_FOUND+=("request-budget:warn:${CURRENT_PCT}pct")
    log "  WARN: Ollama weekly request budget at ${CURRENT_PCT}% (${REQUESTS_REMAINING} remaining) — tier2 threshold ${TIER2_PCT}% reached; heartbeat will surface"
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
  SCHEMA_VER=$(jq -r '.schemaVersion // 0' "$BASELINE" 2>/dev/null)
  log "  Baseline schema v${SCHEMA_VER}"

  # ── Schema v2 (CHG-0613): config hash + structured fields ──
  if [[ "$SCHEMA_VER" == "2" ]]; then
    # Config hash drift (primary check)
    CURRENT_HASH=$(shasum -a 256 "$HOME/.openclaw/openclaw.json" 2>/dev/null | cut -d' ' -f1 || echo "unknown")
    STORED_HASH=$(jq -r '.configHash // "unknown"' "$BASELINE" 2>/dev/null)
    if [[ "$CURRENT_HASH" != "$STORED_HASH" ]]; then
      ISSUES_FOUND+=("config-baseline:hash-drift")
      NEEDS_KEN+=("WARN: Gateway config hash changed — possible unlogged config mutation. Run gateway-config-snapshot.sh to refresh and review diff.")
      log "  X Config hash drift: $STORED_HASH → $CURRENT_HASH"
    else
      log "  OK Config hash matches"
    fi

    # Key field checks
    check_baseline_field() {
      local field="$1" local label="$2" local expected_min="$3" local comparator="$4"
      local actual=$(jq -r ".$field // \"0\"" "$BASELINE" 2>/dev/null)
      if [[ "$comparator" == "min" ]]; then
        if (( actual >= expected_min )); then
          log "  OK $label: $actual (>= $expected_min)"
        else
          ISSUES_FOUND+=("config-baseline:$field:below-minimum")
          NEEDS_KEN+=("WARN: $label is $actual, expected >= $expected_min. Run gateway-config-snapshot.sh to refresh.")
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
    check_baseline_field "pgTables" "PG Tables" 18 "min"
    check_baseline_field "gatewayStatus" "Gateway Status" "live" "eq"

    # Sandbox mode guard (TKT-0532)
    SANDBOX_MODE=$(jq -r '.sandboxMode // "unknown"' "$BASELINE" 2>/dev/null)
    if [[ "$SANDBOX_MODE" != "off" ]]; then
      ISSUES_FOUND+=("config-baseline:sandbox-mode-on")
      NEEDS_KEN+=("WARN: Sandbox mode is '$SANDBOX_MODE' — subagents may lack exec capability. Expected 'off' per TKT-0532 resolution.")
      log "  X Sandbox mode: $SANDBOX_MODE (expected off)"
    else
      log "  OK Sandbox mode: off"
    fi

    # NODE_OPTIONS guard (L-102)
    NODE_OPTS=$(jq -r '.nodeOptions // "not-set"' "$BASELINE" 2>/dev/null)
    if [[ "$NODE_OPTS" != *"max-old-space-size=6144"* ]]; then
      ISSUES_FOUND+=("config-baseline:node-options-missing")
      NEEDS_KEN+=("WARN: NODE_OPTIONS missing --max-old-space-size=6144 (L-102). Current: $NODE_OPTS")
      log "  X NODE_OPTIONS: $NODE_OPTS"
    else
      log "  OK NODE_OPTIONS: $NODE_OPTS"
    fi

    # Yoda tools.deny guard (CHG-0608 — should be empty after revert)
    YODA_DENY=$(jq -r '.yodaToolsDeny | join(",") // "none"' "$BASELINE" 2>/dev/null)
    if [[ "$YODA_DENY" != "" && "$YODA_DENY" != "none" && "$YODA_DENY" != "[]" ]]; then
      ISSUES_FOUND+=("config-baseline:yoda-tools-deny-active")
      NEEDS_KEN+=("WARN: Yoda tools.deny is active: $YODA_DENY. CHG-0608 was reverted — this should be empty.")
      log "  X Yoda tools.deny: $YODA_DENY"
    else
      log "  OK Yoda tools.deny: none"
    fi

    # Age check: warn if snapshot > 7 days old
    last_snapshot=$(jq -r '.lastSnapshot // empty' "$BASELINE" 2>/dev/null)
    if [[ -n "$last_snapshot" ]]; then
      snap_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$last_snapshot" "+%s" 2>/dev/null || echo 0)
      now_epoch=$(date +%s)
      age_days=$(( (now_epoch - snap_epoch) / 86400 ))
      if (( age_days > 7 )); then
        ISSUES_FOUND+=("config-baseline:stale-baseline")
        NEEDS_KEN+=("WARN: Config baseline is $age_days days old. Run gateway-config-snapshot.sh to refresh.")
        log "  X Baseline stale: $age_days days old"
      else
        log "  OK Baseline age: $age_days days"
      fi
    fi

    # ── PG baseline verification (TKT-0343) ──
    PG_ROW=$(bash "$WORKSPACE/scripts/db-raw.sh" -c "SELECT data::text FROM state_config_baseline WHERE tenant_id='ainchors'" 2>/dev/null)
    if [[ -z "$PG_ROW" ]]; then
      ISSUES_FOUND+=("config-baseline:pg-row-missing")
      NEEDS_KEN+=("WARN: state_config_baseline PG row missing. Run gateway-config-snapshot.sh to backfill.")
      log "  X PG baseline row missing"
    else
      PG_EQ=$(python3 -c "
import json, sys
pg = json.loads('''$PG_ROW''')
fl = json.load(open('$BASELINE'))
print('yes' if json.dumps(pg, sort_keys=True) == json.dumps(fl, sort_keys=True) else 'no')
" 2>/dev/null)
      if [[ "$PG_EQ" == "yes" ]]; then
        log "  OK PG baseline matches JSON file"
      else
        ISSUES_FOUND+=("config-baseline:pg-json-mismatch")
        NEEDS_KEN+=("WARN: state_config_baseline PG row differs from state/critical-config-baseline.json. Run gateway-config-snapshot.sh to reconcile.")
        log "  X PG baseline JSON mismatch"
      fi

      PG_UPDATED=$(bash "$WORKSPACE/scripts/db-raw.sh" -c "SELECT updated_at::text FROM state_config_baseline WHERE tenant_id='ainchors'" 2>/dev/null)
      if [[ -n "$PG_UPDATED" && -n "$last_snapshot" ]]; then
        pg_epoch=$(date -j -f "%Y-%m-%d %H:%M:%S.%N%z" "$PG_UPDATED" "+%s" 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%S.%N%z" "$PG_UPDATED" "+%s" 2>/dev/null || echo 0)
        snap_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$last_snapshot" "+%s" 2>/dev/null || echo 0)
        if (( pg_epoch > 0 && snap_epoch > 0 )); then
          pg_age_days=$(( (snap_epoch - pg_epoch) / 86400 ))
          if (( pg_age_days > 7 )); then
            ISSUES_FOUND+=("config-baseline:pg-stale")
            NEEDS_KEN+=("WARN: state_config_baseline PG row is stale (updated_at=$PG_UPDATED). Run gateway-config-snapshot.sh to refresh.")
            log "  X PG baseline stale: $pg_age_days days behind JSON"
          fi
        fi
      fi
    fi
  fi

  # ── Schema v1 (legacy flat structure) ──
  else
    log "  Validating legacy baseline (flat structure)"
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
  # TKT-0340 A1: Pass --enforce when ENFORCE_MODE is true
  AUDIT_ARGS=""
  if [[ "$ENFORCE_MODE" == "true" ]]; then
    if [[ "$ENFORCE_DRY_RUN" == "true" ]]; then
      AUDIT_ARGS="--enforce --dry-run"
    else
      AUDIT_ARGS="--enforce"
    fi
  fi
  if bash "$IDENTITY_AUDIT" $=AUDIT_ARGS >> "$LOG" 2>&1; then
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
# TKT-0340 A1: Pass --enforce when ENFORCE_MODE is true
RULES_ARGS=""
if [[ "$ENFORCE_MODE" == "true" ]]; then
  if [[ "$ENFORCE_DRY_RUN" == "true" ]]; then
    RULES_ARGS="--enforce --dry-run"
  else
    RULES_ARGS="--enforce"
  fi
fi
if zsh "$WORKSPACE/scripts/agent-rules-audit.sh" $=RULES_ARGS >> "$LOG" 2>&1; then
  log "  OK: All agents have RULES.md"
else
  log "  X: Agents missing RULES.md — see state/agent-rules-audit.json"
  NEEDS_KEN+=("RULES.md missing for agent(s) — run agent-rules-audit.sh for details. See TKT-0307.")
fi
CHECKS_RUN+=("agent_rules")

# ---------- CHECK 15: Injected File Size Guard (TKT-0310) ----------
log "CHECK 15: injected file size limits"
CHECKS_RUN+=("file_size_guard")
# Use the script-level $WORKSPACE; avoid shadowing WORKSPACE_ROOT.
WORKSPACE_ROOT_INTERNAL="${WORKSPACE}"

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

_check_file "$WORKSPACE/SOUL.md" "SOUL.md" 10000
_check_file "$WORKSPACE/AGENTS.md" "AGENTS.md" 12000
_check_file "$WORKSPACE/MEMORY.md" "MEMORY.md" 15000
_check_file "$WORKSPACE/HEARTBEAT.md" "HEARTBEAT.md" 15000
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
  "$WORKSPACE/SOUL.md"
  "$WORKSPACE/IDENTITY.md"
  "$WORKSPACE/USER.md"
  "$WORKSPACE/AGENTS.md"
  "$WORKSPACE/MEMORY.md"
  "$WORKSPACE/HEARTBEAT.md"
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
  seq_val=$(bash "$WORKSPACE/scripts/db-raw.sh" -c "SELECT last_value FROM $seq_name" 2>/dev/null | tr -d ' ' || true)
  max_id=$(bash "$WORKSPACE/scripts/db-raw.sh" -c "SELECT COALESCE(MAX(id),0) FROM $table" 2>/dev/null | tr -d ' ' || true)
  if [[ -n "$seq_val" && -n "$max_id" ]]; then
    if [[ "$seq_val" -lt "$max_id" ]]; then
      # Auto-fix: resync sequence
      new_val=$((max_id + 1))
      bash "$WORKSPACE/scripts/db-raw.sh" -c "SELECT setval('$seq_name', $new_val)" >> "$LOG" 2>&1 && \
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
ACTIVE_GW_PID=$(pgrep -f "openclaw.*gateway.*18789" | head -1 || true)

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
# Sandbox (port 28789) is ON-DEMAND — only spin up when required for Forge/build/infra work.
# Not expected to be running continuously. Log status but do NOT flag as issue.
log "CHECK 19: sandbox gateway liveness (port 28789)"
CHECKS_RUN+=("sandbox_gateway_liveness")

SANDBOX_PORT=28789

if /usr/sbin/lsof -i :$SANDBOX_PORT -sTCP:LISTEN -t > /dev/null 2>&1; then
  log "  OK: Sandbox gateway listening on port $SANDBOX_PORT"
else
  log "  INFO: Sandbox gateway not running on port $SANDBOX_PORT — expected (on-demand, not always-on)"
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
# ---------- CHECK 20: Tilde Path Enforcement (TKT-0336, TKT-0340 A2) ----------
log "CHECK 20: tilde path enforcement via safe-path.sh"
CHECKS_RUN+=("tilde_path_enforcement")

SAFE_PATH_SCRIPT="$WORKSPACE/scripts/safe-path.sh"
if [[ ! -x "$SAFE_PATH_SCRIPT" ]]; then
  ISSUES_FOUND+=("tilde-path:safe-path-script-missing")
  NEEDS_KEN+=("CRITICAL: safe-path.sh not found or not executable — cannot enforce tilde path policy")
  log "  X: safe-path.sh missing — tilde enforcement disabled"
  write_state
else
  # Scan all active cron jobs' payloads for ~ tilde patterns
  TILDE_FOUND=0
  TILDE_BLOCKED=0
  TILDE_DRY_RUN_BLOCKED=0
  CRON_JOBS=$(/Users/ainchorsoc2a/local/bin/openclaw cron list --json 2>/dev/null || echo '[]')

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
        if '~/' in text or '~\\\\\\\\/' in text:
            print(f\"CRON:{job.get('name','?')}:{job.get('id','?')[:8]}:tilde_in_payload\")
" 2>&1)

  if [[ -n "$TILDE_PATTERNS" ]]; then
    echo "$TILDE_PATTERNS" | while IFS=: read -r source name id detail; do
      [[ -z "$source" ]] && continue
      TILDE_FOUND=$((TILDE_FOUND+1))
      ISSUES_FOUND+=("tilde-path:cron:${name}:${id}")

      # Extract the specific tilde paths from the payload for enforcement
      tilde_paths=$(echo "$CRON_JOBS" | python3 -c "
import json, sys, re
try:
    data = json.load(sys.stdin)
    for job in data:
        if job.get('id','')[:8] == '${id}':
            payload = job.get('payload', {})
            text = payload.get('text', '') + payload.get('message', '')
            for match in re.finditer(r'~/\\S+', text):
                print(match.group(0))
except: pass
" 2>/dev/null)

      # ENFORCE: Call safe-path.sh --enforce for each detected tilde path
      if [[ "$ENFORCE_MODE" == "true" ]]; then
        while IFS= read -r tp; do
          [[ -z "$tp" ]] && continue
          if [[ "$ENFORCE_DRY_RUN" == "true" ]]; then
            ENFORCE_OUT=$(zsh "$SAFE_PATH_SCRIPT" --enforce --dry-run "$tp" 2>&1) || true
            log "  ENFORCE(dry-run): $ENFORCE_OUT"
            TILDE_DRY_RUN_BLOCKED=$((TILDE_DRY_RUN_BLOCKED+1))
          else
            ENFORCE_OUT=$(zsh "$SAFE_PATH_SCRIPT" --enforce "$tp" 2>&1) || true
            ENFORCE_RC=$?
            if [[ $ENFORCE_RC -ne 0 ]]; then
              log "  ENFORCE: BLOCKED tilde path: $tp"
              TILDE_BLOCKED=$((TILDE_BLOCKED+1))
            fi
          fi
        done <<< "$tilde_paths"
      else
        log "  WARNING: cron '${name}' (${id}) has tilde path in payload (ENFORCE_MODE off — scan only)"
      fi
    done
  fi

  # Also check state JSON files for tilde path references (L-092 fix: exclude self-detect)
  # Skip: detector's own output (auto-heal-*.json), task-queue.json (contains task descriptions
  # with ~/ examples), and any state file under 200 bytes (config defaults, no real paths)
  # Detector fix L-134: filter to only files that have actual tilde-path usage
  # (~/something) not just any ~ character (which catches ~May, ~240, ~3-4 etc.)
  TILDE_STATE_FILES=$(grep -rlE '~(/[A-Za-z0-9._-]+|/[A-Za-z0-9._/-]+)' "$WORKSPACE/state/" --include='*.json' 2>/dev/null \
    | grep -vE '/(auto-heal-.*\.json|task-queue\.json|sandbox-boundary-audit\.json|cron-list-snapshot\.json)$' \
    | xargs -I {} sh -c 'test $(stat -f%z "{}" 2>/dev/null || echo 0) -gt 200 && echo "{}"' 2>/dev/null \
    | head -5 || true)
  if [[ -n "$TILDE_STATE_FILES" ]]; then
    tilde_files="$TILDE_STATE_FILES"
    while IFS= read -r tf; do
      [[ -z "$tf" ]] && continue
      TILDE_FOUND=$((TILDE_FOUND+1))
      ISSUES_FOUND+=("tilde-path:state-file:$(basename "$tf")")

      # Extract tilde paths from each file. Use a tighter pattern that matches
      # actual tilde-path usage (~/path or ~user/path) and not approximations
      # like ~May 19, ~240 lines, ~3-4 hours, ~2h. Detector fix L-134: require
      # the tilde to be followed by / (or be exactly ~/ or ~$ at end of line).
      tilde_paths_in_file=$(grep -oE '~(/[A-Za-z0-9._-]+|/[A-Za-z0-9._/-]+)' "$tf" 2>/dev/null | head -5)

      if [[ "$ENFORCE_MODE" == "true" ]]; then
        while IFS= read -r tp; do
          [[ -z "$tp" ]] && continue
          if [[ "$ENFORCE_DRY_RUN" == "true" ]]; then
            ENFORCE_OUT=$(zsh "$SAFE_PATH_SCRIPT" --enforce --dry-run "$tp" 2>&1) || true
            log "  ENFORCE(dry-run): $ENFORCE_OUT (in $(basename "$tf"))"
            TILDE_DRY_RUN_BLOCKED=$((TILDE_DRY_RUN_BLOCKED+1))
          else
            ENFORCE_OUT=$(zsh "$SAFE_PATH_SCRIPT" --enforce "$tp" 2>&1) || true
            ENFORCE_RC=$?
            if [[ $ENFORCE_RC -ne 0 ]]; then
              log "  ENFORCE: BLOCKED tilde path '$tp' in $(basename "$tf")"
              TILDE_BLOCKED=$((TILDE_BLOCKED+1))
            fi
          fi
        done <<< "$tilde_paths_in_file"
      else
        log "  WARNING: tilde path in state file: $(basename "$tf") (ENFORCE_MODE off — scan only)"
      fi
    done <<< "$tilde_files"
  fi

  # Summary
  if (( TILDE_FOUND > 0 )); then
    if [[ "$ENFORCE_MODE" == "true" ]]; then
      if [[ "$ENFORCE_DRY_RUN" == "true" ]]; then
        log "  X: $TILDE_FOUND tilde path violations detected — ${TILDE_DRY_RUN_BLOCKED} WOULD be blocked (dry-run)"
        NEEDS_KEN+=("TKT-0336/TKT-0340: $TILDE_FOUND tilde path violations found. ENFORCE dry-run: ${TILDE_DRY_RUN_BLOCKED} would be blocked. Run without --dry-run to enforce.")
      else
        log "  X: $TILDE_FOUND tilde path violations — $TILDE_BLOCKED blocked by safe-path.sh --enforce"
        AUTO_FIXED+=("tilde-path-enforcement:blocked-${TILDE_BLOCKED}")
        if (( TILDE_BLOCKED < TILDE_FOUND )); then
          NEEDS_KEN+=("TKT-0336/TKT-0340: $TILDE_FOUND tilde violations found, only $TILDE_BLOCKED blocked. $(($TILDE_FOUND - $TILDE_BLOCKED)) items could not be enforced — manual review needed.")
        fi
      fi
    else
      log "  X: $TILDE_FOUND tilde path violations detected (ENFORCE_MODE off — not blocking)"
      NEEDS_KEN+=("TKT-0336: $TILDE_FOUND tilde path violations detected in cron payloads or state files. Run with --enforce to block.")
    fi
  else
    log "  OK: no tilde paths detected in cron payloads or state files"
  fi
fi

write_state

# ---------- CHECK 21: Workspace File Contract / File Size Guard Audit (TKT-0341, TKT-0340 A3) ----------
log "CHECK 21: workspace file contract + size guard audit"
CHECKS_RUN+=("file_contract_size_guard")
if [[ -x "$WORKSPACE/scripts/file-size-guard.sh" ]]; then
  # TKT-0340 A3: Pass --enforce when ENFORCE_MODE is true
  GUARD_ARGS="--root"
  if [[ "$ENFORCE_MODE" == "true" ]]; then
    if [[ "$ENFORCE_DRY_RUN" == "true" ]]; then
      GUARD_ARGS="$GUARD_ARGS --enforce --dry-run"
    else
      GUARD_ARGS="$GUARD_ARGS --enforce"
    fi
  fi
  
  # Capture full output for logging (always run, even with || true)
  ROOT_OUTPUT=$("$WORKSPACE/scripts/file-size-guard.sh" $=GUARD_ARGS 2>&1) || true
  ROOT_RC=$?
  
  # Log the full guard output to the auto-heal log
  echo "$ROOT_OUTPUT" >> "$LOG"
  
  if [[ "$ENFORCE_MODE" == "true" && "$ENFORCE_DRY_RUN" == "true" ]]; then
    # Dry-run enforcement: file-size-guard.sh exits 0, we check output for violations
    if [[ "$ROOT_OUTPUT" == *"DRY-RUN: Would BLOCK"* ]]; then
      log "  ENFORCE(dry-run): WOULD block oversized root .md files — logging only"
      ISSUES_FOUND+=("file-size-guard:would-block")
      AUTO_FIXED+=("file-size-guard:dry-run-blocked")
    fi
    if [[ "$ROOT_OUTPUT" == *"UNTRACKED FILES"* ]]; then
      _untracked=$(echo "$ROOT_OUTPUT" | grep "UNTRACKED FILES:" | sed 's/.*UNTRACKED FILES: //')
      log "  ENFORCE(dry-run): Untracked .md files detected: $_untracked"
      ISSUES_FOUND+=("file-size-guard:untracked-files")
      NEEDS_KEN+=("TKT-0341: Untracked .md files in workspace root: $_untracked — move to docs/archive/ or register contract")
    else
      log "  ENFORCE(dry-run): No violations logged"
    fi
  elif [[ "$ENFORCE_MODE" == "true" ]]; then
    # Real enforcement: file-size-guard.sh exits non-zero on violations (blocking)
    if [[ $ROOT_RC -eq 2 ]]; then
      log "  ENFORCE: Oversized root .md files BLOCKED (exit code 2)"
      ISSUES_FOUND+=("file-size-guard:blocked")
      AUTO_FIXED+=("file-size-guard:enforce-blocked")
    elif [[ $ROOT_RC -eq 1 ]]; then
      log "  ENFORCE: File size warnings (exit code 1)"
    fi
    if [[ "$ROOT_OUTPUT" == *"UNTRACKED FILES"* ]]; then
      _untracked=$(echo "$ROOT_OUTPUT" | grep "UNTRACKED FILES:" | sed 's/.*UNTRACKED FILES: //')
      log "  ENFORCE: Untracked .md files detected: $_untracked"
      ISSUES_FOUND+=("file-size-guard:untracked-files")
      NEEDS_KEN+=("TKT-0341: Untracked .md files in workspace root: $_untracked — move to docs/archive/ or register contract")
    fi
  else
    # Passive/check-only mode
    if [[ "$ROOT_OUTPUT" == *"UNTRACKED FILES"* ]]; then
      _untracked=$(echo "$ROOT_OUTPUT" | grep "UNTRACKED FILES:" | sed 's/.*UNTRACKED FILES: //')
      log "  WARNING: untracked files: $_untracked"
      ISSUES_FOUND+=("file-size-guard:untracked-files")
      NEEDS_KEN+=("TKT-0341: Untracked .md files in workspace root: $_untracked — move to docs/archive/ or register contract")
    elif [[ $ROOT_RC -eq 2 ]]; then
      log "  WARNING: root .md cap exceeded"
      ISSUES_FOUND+=("file-size-guard:cap-exceeded")
      NEEDS_KEN+=("TKT-0341: Workspace root .md total exceeds 60K cap — trim injected files")
    else
      log "  OK: all root .md files tracked and within limits"
    fi
  fi
else
  log "  SKIP: file-size-guard.sh not found"
fi

write_state "complete"


# ---------- CHECK 22: Cron Timeout Baseline Audit (TKT-0339 / TKT-0340 A4) ----------
# Scaler is FLAG/RECOMMEND ONLY (per Ken decision TKT-0339).
# Enforcement means the ALERT is escalated — timeouts are NEVER auto-applied.
# ENFORCE_MODE=true + drift deviations → blocking alert (state/cron-drift-alert.json + exit non-zero).
# ENFORCE_DRY_RUN=true → log drift but don't escalate/block.
log "CHECK 22: cron timeout baseline audit"
CHECKS_RUN+=("cron_timeout_baseline")

declare -a CRON_DRIFT_ITEMS=()
CHECK22_EXIT=0

BASELINE_FILE="$STATE_DIR/cron-timeout-baseline.json"
if [[ -f "$BASELINE_FILE" ]]; then
  TIMEOUT_ALERTS=$(python3 - "$BASELINE_FILE" << 'PYEOF'
import json, sys
with open(sys.argv[1]) as f:
    b = json.load(f)
# FIX A6 (L-098): use actionableRecommended when present (scaler vA6+),
# else fall back to timeoutsRecommended for back-compat with v1.0.0.
summary = b.get('summary', {})
scaler_version = summary.get('scalerVersion', 'pre-A6')
if 'actionableRecommended' in summary:
    actionable = summary['actionableRecommended']
else:
    actionable = summary.get('timeoutsRecommended', 0)
alerts = []
actionable_alerts = []
# FIX A6: only emit per-cron alert strings for ACTIONABLE (agentTurn) recs
for r in b['crons']:
    rec = r.get('recommendation', '')
    payload_kind = r.get('payloadKind', '?')
    cid = r['cronId']
    if rec == 'SET':
        line = 'SET:' + cid + ':' + str(r['computedTimeoutSec']) + 's:' + r['name'][:40]
    elif rec == 'INCREASE':
        line = 'INCREASE:' + cid + ':' + str(r['currentTimeoutSec']) + 's->' + str(r['computedTimeoutSec']) + 's:' + r['name'][:40]
    elif rec == 'DECREASE':
        line = 'DECREASE:' + cid + ':' + str(r['currentTimeoutSec']) + 's->' + str(r['computedTimeoutSec']) + 's:' + r['name'][:40]
    else:
        continue
    alerts.append(line)
    if payload_kind == 'agentTurn':
        actionable_alerts.append(line + '|PK=' + payload_kind)
print('SCALER_VERSION:' + scaler_version)
print('TOTAL_RECOMMENDATIONS:' + str(len(alerts)))
print('ACTIONABLE_RECOMMENDATIONS:' + str(len(actionable_alerts)))
for a in actionable_alerts:
    print(a)
PYEOF
)

  REC_COUNT=$(echo "$TIMEOUT_ALERTS" | grep 'TOTAL_RECOMMENDATIONS:' | cut -d: -f2)
  ACT_COUNT=$(echo "$TIMEOUT_ALERTS" | grep 'ACTIONABLE_RECOMMENDATIONS:' | cut -d: -f2)
  SCALER_V=$(echo "$TIMEOUT_ALERTS" | grep 'SCALER_VERSION:' | cut -d: -f2)
  SET_COUNT=$(echo "$TIMEOUT_ALERTS" | grep -c '^SET:' || true)
  INC_COUNT=$(echo "$TIMEOUT_ALERTS" | grep -c '^INCREASE:' || true)
  DEC_COUNT=$(echo "$TIMEOUT_ALERTS" | grep -c '^DECREASE:' || true)

  # FIX A6: alert-count uses actionable (agentTurn only) — the SCALER FLAG ONLY
  # alert was firing on 48 systemEvent jobs that don't consume timeoutSeconds.
  # Actionable count is what Ken actually needs to see / what auto-apply handles.
  EFFECTIVE_REC_COUNT="${ACT_COUNT:-$REC_COUNT}"

  if [[ -n "$EFFECTIVE_REC_COUNT" && "$EFFECTIVE_REC_COUNT" -gt 0 ]]; then
    ISSUES_FOUND+=("cron-timeout:${EFFECTIVE_REC_COUNT}-actionable")

    # --- Build drift detail items (for alert JSON and logging) ---
    # FIX A6: actionable (agentTurn) items only — systemEvent already filtered by scaler
    while IFS= read -r line; do
      [[ "$line" == SET:* || "$line" == INCREASE:* || "$line" == DECREASE:* ]] && CRON_DRIFT_ITEMS+=("$line")
    done <<< "$TIMEOUT_ALERTS"

    # --- Scaler: FLAG/RECOMMEND ONLY (never auto-apply timeouts unless stable) ---
    # FIX A6 (L-098): Effective count is now actionable (agentTurn) only.
    # systemEvent jobs no longer pollute the alert.
    CRON_FLAG_MSG="TKT-0339: ${EFFECTIVE_REC_COUNT} actionable cron timeout recommendation(s) (agentTurn only, scaler v${SCALER_V:-pre-A6} — SCALER FLAG ONLY"
    if [[ "$SET_COUNT" -gt 0 ]]; then
      CRON_FLAG_MSG="${CRON_FLAG_MSG}: ${SET_COUNT} SET"
    fi
    if [[ "$INC_COUNT" -gt 0 ]]; then
      CRON_FLAG_MSG="${CRON_FLAG_MSG}, ${INC_COUNT} INCREASE"
    fi
    if [[ "$DEC_COUNT" -gt 0 ]]; then
      CRON_FLAG_MSG="${CRON_FLAG_MSG}, ${DEC_COUNT} DECREASE"
    fi
    CRON_FLAG_MSG="${CRON_FLAG_MSG}). Manual review before any timeout changes. Baseline: ${BASELINE_FILE}"
    NEEDS_KEN+=("$CRON_FLAG_MSG")

    # --- Enforcement: alert escalation (TKT-0340 A4) ---
    if [[ "$ENFORCE_MODE" == "true" ]]; then
      if [[ "$ENFORCE_DRY_RUN" == "true" ]]; then
        log "  ENFORCE(dry-run): WOULD escalate drift alert for ${EFFECTIVE_REC_COUNT} actionable cron timeout deviations (agentTurn only) — not blocking"
        log "  ENFORCE(dry-run): drift items: ${SET_COUNT} SET, ${INC_COUNT} INCREASE, ${DEC_COUNT} DECREASE"
      else
        # Real enforcement: write blocking alert JSON, mark CHECK22 non-zero exit
        log "  ENFORCE: Cron timeout drift detected — escalating as BLOCKING alert"
        CRON_DRIFT_ALERT="$STATE_DIR/cron-drift-alert.json"
        # FIX A6: pass effective (actionable) count + scaler version
        printf '%s\n' "${CRON_DRIFT_ITEMS[@]:-}" | python3 - "$CRON_DRIFT_ALERT" "$NOW" "$NOW_LOCAL" "$EFFECTIVE_REC_COUNT" "$SET_COUNT" "$INC_COUNT" "$DEC_COUNT" "$SCALER_V" <<'PYEOF'
import json, sys, datetime
alert_file = sys.argv[1]
now = sys.argv[2]
now_local = sys.argv[3]
eff_count = int(sys.argv[4])
set_count = int(sys.argv[5])
inc_count = int(sys.argv[6])
dec_count = int(sys.argv[7])
scaler_v = sys.argv[8]
drift_items = [l.strip() for l in sys.stdin if l.strip()]

alert = {
    "alertId": "cron-drift-" + datetime.datetime.utcnow().strftime("%Y%m%dT%H%M%SZ"),
    "severity": "BLOCKING",
    "source": "CHECK22-cron-timeout-baseline",
    "ticket": "TKT-0340-A4",
    "runAt": now,
    "runAtLocal": now_local,
    "enforceMode": True,
    "scalerVersion": scaler_v,  # FIX A6
    "summary": f"{eff_count} actionable (agentTurn) cron timeout drift deviations detected",
    "breakdown": {"SET": set_count, "INCREASE": inc_count, "DECREASE": dec_count},
    "driftItems": drift_items,
    "resolution": "SCALER FLAG ONLY — manual review required before any timeout changes. TKT-0503-A6: agentTurn-only; systemEvent jobs excluded (don't consume timeoutSeconds).",
    "action": "Review baseline recommendations and apply timeout changes via manual process (NOT auto-applied)."
}
with open(alert_file, 'w') as f:
    json.dump(alert, f, indent=2)
PYEOF
        NEEDS_KEN+=("TKT-0340-A4: BLOCKING — ${EFFECTIVE_REC_COUNT} actionable cron timeout drift deviations (${SET_COUNT} SET, ${INC_COUNT} INCREASE, ${DEC_COUNT} DECREASE). Alert written to ${CRON_DRIFT_ALERT}. Manual review required.")
        CHECK22_EXIT=1
        log "  ENFORCE: Drift alert written to $CRON_DRIFT_ALERT (CHECK 22 will exit non-zero)"
      fi
    fi

    log "  X: $EFFECTIVE_REC_COUNT actionable cron timeout recommendations (scaler v${SCALER_V:-pre-A6}, $SET_COUNT SET, $INC_COUNT INCREASE, $DEC_COUNT DECREASE)"

    # ── A6 LEDGER + DRY-RUN SURFACE (TKT-0503-A6 / L-098) ──────────────────
    # auto-heal.sh ONLY updates the ledger and surfaces eligible items in
    # NEEDS_KEN. Live apply is the responsibility of:
    #   scripts/cron-timeout-apply.sh --cron <id> --yes
    #   scripts/cron-timeout-apply.sh --all --yes
    # This separation (CHG-0534, L-099) makes gateway config mutation an
    # explicit, one-shot, Ken-triggered action — never implicit on auto-heal.
    # TKT-0529 B3.3: ledger write is tracking-only (firstSeen/lastSeen/daysCount).
    # No destructive impact. Retained in dry-run to keep eligibility calculation
    # accurate across runs (otherwise apply-pending detection would be wrong).
    APPLIED_LEDGER="$STATE_DIR/cron-timeout-applied.json"
    APPLY_TMP=$(mktemp -t cron-timeout-ledger)
    python3 - "$BASELINE_FILE" "$APPLIED_LEDGER" "$NOW" > "$APPLY_TMP" <<'PYEOF'
import json, sys, os, datetime
baseline_file = sys.argv[1]
ledger_file = sys.argv[2]
now = sys.argv[3]

with open(baseline_file) as f:
    b = json.load(f)

ledger = {}
if os.path.exists(ledger_file):
    try:
        with open(ledger_file) as f:
            ledger = json.load(f)
    except Exception:
        ledger = {}

today = now[:10]
eligible_for_apply = []

for r in b.get('crons', []):
    cid = r.get('cronId', '')
    if r.get('payloadKind') != 'agentTurn':
        continue
    if r.get('recommendation') != 'DECREASE':
        continue
    cur = r.get('currentTimeoutSec')
    new = r.get('computedTimeoutSec')
    if cur is None or new is None or new >= cur:
        continue
    entry = ledger.get(cid, {'firstSeen': today, 'lastSeen': None, 'daysCount': 0, 'recommendation': 'DECREASE', 'currentTo': cur, 'computedTo': new, 'appliedAt': None, 'appliedTo': None})
    is_first_observation_today = (entry.get('lastSeen') != today)
    if is_first_observation_today:
        last_date = entry.get('lastSeen', '')
        if last_date:
            try:
                last_dt = datetime.datetime.strptime(last_date, '%Y-%m-%d').date()
                today_dt = datetime.datetime.strptime(today, '%Y-%m-%d').date()
                if (today_dt - last_dt).days == 1:
                    entry['daysCount'] = entry.get('daysCount', 0) + 1
                else:
                    entry['firstSeen'] = today
                    entry['daysCount'] = 1
            except Exception:
                entry['firstSeen'] = today
                entry['daysCount'] = 1
        else:
            entry['daysCount'] = entry.get('daysCount', 0) + 1
        entry['lastSeen'] = today
    entry['recommendation'] = 'DECREASE'
    entry['currentTo'] = cur
    entry['computedTo'] = new
    ledger[cid] = entry
    # Eligible if 7d+ stable, not yet applied at computed value
    if entry['daysCount'] >= 7 and (not entry.get('appliedAt') or entry.get('appliedTo') != new):
        eligible_for_apply.append({'cronId': cid, 'name': r.get('name','')[:40], 'from': cur, 'to': new, 'days': entry['daysCount']})

# Reconciliation: prune ledger entries whose cron is no longer in the
# baseline (scaler re-ran, recompute cleared the recommendation). The cron
# is now considered 'in sync' — no need to surface an apply prompt.
cid_set = {r.get('cronId', '') for r in b.get('crons', [])}
stale_cids = [cid for cid in list(ledger.keys()) if cid not in cid_set]
for cid in stale_cids:
    del ledger[cid]

# Write ledger
with open(ledger_file, 'w') as f:
    json.dump(ledger, f, indent=2, ensure_ascii=False)

result = {'eligibleCount': len(eligible_for_apply), 'eligible': eligible_for_apply, 'ledgerFile': ledger_file}
print(json.dumps(result, indent=2))
PYEOF
    APPLY_RESULT=$(cat "$APPLY_TMP")
    APPLY_ELIG_N=$(echo "$APPLY_RESULT" | python3 -c "import json, sys; print(json.loads(sys.stdin.read())['eligibleCount'])")
    rm -f "$APPLY_TMP"
    log "  A6 ledger updated: $APPLY_ELIG_N item(s) eligible for apply (7d+ stable, not yet applied)."
    if [[ "$APPLY_ELIG_N" -gt 0 ]]; then
      # Surface eligible items in NEEDS_KEN with the one-shot command
      # Throttle: only emit once per day via cron-timeout-apply-pending.json mtime
      APPLY_FLAG_JSON="$STATE_DIR/cron-timeout-apply-pending.json"
      SHOULD_EMIT=0
      if [[ ! -f "$APPLY_FLAG_JSON" ]]; then
        SHOULD_EMIT=1
      elif [[ $(find "$APPLY_FLAG_JSON" -mmin +720 2>/dev/null) ]]; then
        # File exists but is older than 12h (720 min) — re-emit
        SHOULD_EMIT=1
      fi
      if [[ $SHOULD_EMIT -eq 1 ]]; then
        # TKT-0529 B3.3: dry-run hardening — signal/flag file is informational
        # only, but still gated to log-only in dry-run to keep the contract tight.
        if [[ "${ENFORCE_DRY_RUN:-false}" == "true" ]]; then
          log "  DRY-RUN: would write $APPLY_FLAG_JSON (apply-pending signal)"
        else
          echo "$APPLY_RESULT" | python3 -c "import json, sys; r=json.loads(sys.stdin.read()); r['notedAt']='$NOW'; r['applyCommand']='bash scripts/cron-timeout-apply.sh --all --yes'; r['applyCommandOne']='bash scripts/cron-timeout-apply.sh --cron <8-char-id> --yes'; print(json.dumps(r, indent=2))" > "$APPLY_FLAG_JSON"
        fi
        NEEDS_KEN+=("CHECK 22 A6: $APPLY_ELIG_N stable DECREASE on agentTurn eligible (7d+). Review $APPLY_FLAG_JSON. To apply all: bash scripts/cron-timeout-apply.sh --all --yes  (or one-by-one with --cron <id> --yes).")
      fi
    fi
  else
    # No drift — clear any stale alert
    CRON_DRIFT_ALERT="$STATE_DIR/cron-drift-alert.json"
    [[ -f "$CRON_DRIFT_ALERT" ]] && rm -f "$CRON_DRIFT_ALERT" && log "  OK: Cleared stale cron-drift-alert.json"
    log "  OK: All cron timeouts within recommended range"
  fi
else
  log "  SKIP: cron-timeout-baseline.json not found — run cron-timeout-scaler.sh first"
fi

write_state


# ---------- CHECK 23: Context Injection Budget Audit (TKT-0340 A5) ----------
# Daily audit of bootstrap injection levels against model context window.
# Runs context-budget.sh --check to scan current injection budget status.
# ENFORCE_MODE=true: if any injection exceeds 80% warn threshold, escalate as blocking alert.
# ENFORCE_DRY_RUN=true: log warnings but don't block.
log "CHECK 23: context injection budget audit"
CHECKS_RUN+=("context_budget")

# Context budget thresholds (match context-budget.sh defaults)
CB_WARN_PCT=80
CB_BLOCK_PCT=95

CONTEXT_BUDGET_SCRIPT="$WORKSPACE/scripts/context-budget.sh"
CONTEXT_SUMMARIZE="$WORKSPACE/scripts/context-summarize.sh"
if [[ -x "$CONTEXT_BUDGET_SCRIPT" ]]; then
  # Run context-budget.sh --check to get injection budget status
  BUDGET_OUTPUT=$(zsh "$CONTEXT_BUDGET_SCRIPT" --check 2>&1) || true
  BUDGET_RC=${PIPESTATUS[0]:-$?}
  echo "$BUDGET_OUTPUT" >> "$LOG"

  # Also capture JSON output for detailed reporting
  BUDGET_JSON=$(zsh "$CONTEXT_BUDGET_SCRIPT" --json 2>/dev/null || echo '{}')

  # Extract key metrics from JSON
  BUDGET_STATUS=$(echo "$BUDGET_JSON" | jq -r '.status // "UNKNOWN"' 2>/dev/null)
  BUDGET_TOKENS=$(echo "$BUDGET_JSON" | jq -r '.totalTokens // 0' 2>/dev/null)
  BUDGET_PCT=$(echo "$BUDGET_JSON" | jq -r '.usagePercent // 0' 2>/dev/null)
  BUDGET_WINDOW=$(echo "$BUDGET_JSON" | jq -r '.window // 0' 2>/dev/null)
  BUDGET_WARN=$(echo "$BUDGET_JSON" | jq -r '.warnThreshold // 0' 2>/dev/null)
  BUDGET_BLOCK=$(echo "$BUDGET_JSON" | jq -r '.blockThreshold // 0' 2>/dev/null)

  case "$BUDGET_STATUS" in
    OK)
      log "  OK: context injection budget ${BUDGET_TOKENS} tokens (${BUDGET_PCT}% of ${BUDGET_WINDOW} window)"
      log "  OK: warn threshold ${BUDGET_WARN} tokens (80%), block threshold ${BUDGET_BLOCK} tokens (95%)"
      # Clear any stale budget alert
      BUDGET_ALERT="$STATE_DIR/context-budget-alert.json"
      [[ -f "$BUDGET_ALERT" ]] && rm -f "$BUDGET_ALERT" && log "  OK: Cleared stale context-budget-alert.json"
      ;;
    WARN)
      log "  WARN: context injection budget ${BUDGET_TOKENS} tokens — ${BUDGET_PCT}% of ${BUDGET_WINDOW} window (warn threshold: ${BUDGET_WARN} / ${CB_WARN_PCT}%)"
      ISSUES_FOUND+=("context-budget:warn-${BUDGET_PCT}pct")

      # ENFORCE escalation (TKT-0340 A5/A7): >80% warn threshold triggers enforcement
      if [[ "$ENFORCE_MODE" == "true" ]]; then
        if [[ "$ENFORCE_DRY_RUN" == "true" ]]; then
          log "  ENFORCE(dry-run): WOULD escalate context budget warning (${BUDGET_PCT}% > ${CB_WARN_PCT}%) — not blocking"
          log "  ENFORCE(dry-run): recommendation: auto-summarize oversized injected files via context-summarize.sh"
          # TKT-0529 B3.1: Dry-run — log what *would* be summarized. Always log even if
          # the gate would block summarization, so Ken can see the candidate files.
          if [[ -x "$CONTEXT_SUMMARIZE" ]]; then
            DRY_FILES=$(echo "$BUDGET_JSON" | jq -r '.files[]? | select(.pctOfBudget // 0 > 20) | .path' 2>/dev/null | tr '\n' ' ' || true)
            if [[ -z "$DRY_FILES" ]]; then
              for f in ${WORKSPACE}/SOUL.md ${WORKSPACE}/AGENTS.md ${WORKSPACE}/MEMORY.md ${WORKSPACE}/HEARTBEAT.md; do
                [[ -f "$f" ]] && DRY_FILES="$DRY_FILES $f"
              done
            fi
            log "  SUMMARIZE(dry-run): WOULD summarize $DRY_FILES"
          fi
        else
          # TKT-0529 B3.1: HITL gate for context-summarize.sh invocation.
          # By default, summarization is gated to NEEDS_KEN. Only proceed if
          # context_summary_allowed() returns true (CLI flag or state-file opt-in).
          if [[ -x "$CONTEXT_SUMMARIZE" ]] && context_summary_allowed; then
            log "  SUMMARIZE: Auto-summarizing oversized context files via context-summarize.sh..."
            # Identify oversized files from budget JSON
            FILES_JSON=$(echo "$BUDGET_JSON" | jq -r '.files // []' 2>/dev/null)
            if [[ "$FILES_JSON" != "[]" ]] && [[ -n "$FILES_JSON" ]]; then
              echo "$BUDGET_JSON" | jq -r '.files[] | "\(.path) \(.estimatedTokens)"' 2>/dev/null | while read -r FPATH FTOKENS; do
                if [[ -f "$FPATH" ]] && [[ "$FTOKENS" -gt 0 ]]; then
                  FILE_BUDGET=$(echo "$BUDGET_JSON" | jq -r --arg fp "$FPATH" '.files[] | select(.path==$fp) | .pctOfBudget // 0' 2>/dev/null)
                  if [[ "$FILE_BUDGET" -gt 20 ]]; then
                    log "  SUMMARIZE: Summarizing $FPATH (${FTOKENS} tokens, ${FILE_BUDGET}% of budget)..."
                    cp "$FPATH" "${FPATH}.pre-summary.bak"
                    if cat "$FPATH" | "$CONTEXT_SUMMARIZE" --enforce > "${FPATH}.tmp" 2>/dev/null; then
                      mv "${FPATH}.tmp" "$FPATH"
                      BUDGET_REDUCTION=$((BUDGET_REDUCTION + FTOKENS / 2))
                      log "  SUMMARIZE: $FPATH summarized — original preserved as ${FPATH}.pre-summary.bak"
                    else
                      log "  SUMMARIZE: FAILED to summarize $FPATH — restoring original"
                      mv "${FPATH}.pre-summary.bak" "$FPATH" 2>/dev/null
                    fi
                  fi
                fi
              done
            else
              log "  SUMMARIZE: No per-file budget data available — summarizing all injected files"
              for f in ${WORKSPACE}/SOUL.md ${WORKSPACE}/AGENTS.md ${WORKSPACE}/MEMORY.md ${WORKSPACE}/HEARTBEAT.md; do
                if [[ -f "$f" ]]; then
                  cp "$f" "${f}.pre-summary.bak"
                  cat "$f" | "$CONTEXT_SUMMARIZE" --enforce > "${f}.tmp" 2>/dev/null && mv "${f}.tmp" "$f"
                  log "  SUMMARIZE: $f summarized"
                fi
              done
            fi
            # Re-check budget after summarization
            BUDGET_POST=$(zsh "$CONTEXT_BUDGET_SCRIPT" --json 2>/dev/null | jq -r '.totalTokens // 0' 2>/dev/null)
            log "  SUMMARIZE: Budget re-check: ${BUDGET_POST} tokens (was ${BUDGET_TOKENS}) — reduction: $((BUDGET_TOKENS - BUDGET_POST)) tokens"
          elif [[ -x "$CONTEXT_SUMMARIZE" ]]; then
            # TKT-0529 B3.1: Gate blocked summarization. Log, NEEDS_KEN, and continue
            # with alert/escalation as before.
            log "  SUMMARIZE: SKIPPED — context summarization gated to NEEDS_KEN. Create state/allow-context-summary.json or pass --allow-context-summary to enable."
            NEEDS_KEN+=("Context injection budget at ${BUDGET_PCT}% — auto-summarization is gated. Approve via state/allow-context-summary.json or --allow-context-summary.")
            BUDGET_POST="$BUDGET_TOKENS"
          else
            BUDGET_POST="$BUDGET_TOKENS"
          fi
          # If still over threshold after summarization, escalate
          BUDGET_POST_NUM=${BUDGET_POST:-0}
          BUDGET_WARN_NUM=${BUDGET_WARN:-999999}
          if [[ "$BUDGET_POST_NUM" -gt "$BUDGET_WARN_NUM" ]]; then
            # Real enforcement: escalate as blocking alert
            log "  ENFORCE: Context injection budget at ${BUDGET_PCT}% — ESCALATING as BLOCKING alert (summarization insufficient)"
          BUDGET_ALERT="$STATE_DIR/context-budget-alert.json"
          safe_atomic_write "$BUDGET_ALERT" <<BOJ
{
  "alertId": "context-budget-$(date -u +%Y%m%dT%H%M%SZ)",
  "severity": "BLOCKING",
  "source": "CHECK23-context-budget-audit",
  "ticket": "TKT-0340-A5",
  "runAt": "$NOW",
  "runAtLocal": "$NOW_LOCAL",
  "enforceMode": true,
  "summary": "Context injection budget at ${BUDGET_PCT}% (${BUDGET_TOKENS} / ${BUDGET_WINDOW} tokens) — exceeds ${CB_WARN_PCT}% warn threshold",
  "metrics": {
    "totalTokens": $BUDGET_TOKENS,
    "window": $BUDGET_WINDOW,
    "usagePercent": $BUDGET_PCT,
    "warnThreshold": $BUDGET_WARN,
    "warnThresholdPct": $CB_WARN_PCT,
    "blockThreshold": $BUDGET_BLOCK,
    "blockThresholdPct": $CB_BLOCK_PCT,
    "status": "WARN"
  },
  "resolution": "Reduce bootstrap injection tokens by trimming injected files (SOUL.md, AGENTS.md, MEMORY.md, HEARTBEAT.md). Target: bring total below ${CB_WARN_PCT}% of ${BUDGET_WINDOW} window.",
  "action": "Manual review of injected file sizes required. Consider archiving stale content."
}
BOJ
          NEEDS_KEN+=("TKT-0340-A5: BLOCKING — Context injection budget at ${BUDGET_PCT}% (${BUDGET_TOKENS}/${BUDGET_WINDOW} tokens) exceeds ${CB_WARN_PCT}% warn threshold. Alert written to ${BUDGET_ALERT}. Trim injected files.")
          log "  ENFORCE: Budget alert written to $BUDGET_ALERT"
          else
            log "  SUMMARIZE: Budget now below warn threshold — summarization resolved the alert"
            # Clear any stale budget alert
            [[ -f "$BUDGET_ALERT" ]] && rm -f "$BUDGET_ALERT"
          fi
          log "  ENFORCE: Budget alert written to $BUDGET_ALERT"
        fi
      else
        NEEDS_KEN+=("TKT-0340-A5: Context injection budget at ${BUDGET_PCT}% (${BUDGET_TOKENS}/${BUDGET_WINDOW} tokens) — warn threshold ${CB_WARN_PCT}% exceeded. Review injected file sizes.")
      fi
      ;;
    CRITICAL)
      log "  X: context injection budget ${BUDGET_TOKENS} tokens — ${BUDGET_PCT}% of ${BUDGET_WINDOW} window (BLOCK threshold: ${BUDGET_BLOCK} / ${CB_BLOCK_PCT}%)"
      ISSUES_FOUND+=("context-budget:critical-${BUDGET_PCT}pct")

      # CRITICAL (>95%) always escalates regardless of enforce mode
      if [[ "$ENFORCE_MODE" == "true" ]]; then
        if [[ "$ENFORCE_DRY_RUN" == "true" ]]; then
          log "  ENFORCE(dry-run): WOULD escalate context budget CRITICAL (${BUDGET_PCT}% > ${CB_BLOCK_PCT}%) — not blocking"
          log "  ENFORCE(dry-run): URGENT: bootstrap injection approaching context window limit"
        else
          log "  ENFORCE: Context injection budget CRITICAL at ${BUDGET_PCT}% — ESCALATING as BLOCKING alert"
          BUDGET_ALERT="$STATE_DIR/context-budget-alert.json"
          safe_atomic_write "$BUDGET_ALERT" <<BOJ
{
  "alertId": "context-budget-$(date -u +%Y%m%dT%H%M%SZ)",
  "severity": "CRITICAL",
  "source": "CHECK23-context-budget-audit",
  "ticket": "TKT-0340-A5",
  "runAt": "$NOW",
  "runAtLocal": "$NOW_LOCAL",
  "enforceMode": true,
  "summary": "Context injection budget at ${BUDGET_PCT}% (${BUDGET_TOKENS} / ${BUDGET_WINDOW} tokens) — EXCEEDS ${CB_BLOCK_PCT}% block threshold. RISK OF SILENT TRUNCATION.",
  "metrics": {
    "totalTokens": $BUDGET_TOKENS,
    "window": $BUDGET_WINDOW,
    "usagePercent": $BUDGET_PCT,
    "warnThreshold": $BUDGET_WARN,
    "warnThresholdPct": $CB_WARN_PCT,
    "blockThreshold": $BUDGET_BLOCK,
    "blockThresholdPct": $CB_BLOCK_PCT,
    "status": "CRITICAL"
  },
  "resolution": "IMMEDIATE: Reduce bootstrap injection tokens. Files exceeding context window cause silent truncation. Trim injected files (SOUL.md, AGENTS.md, MEMORY.md, HEARTBEAT.md) to bring total below ${CB_WARN_PCT}%.",
  "action": "URGENT manual review required. Consider: (1) archiving stale content from injected files, (2) removing deprecated sections, (3) splitting MEMORY.md into short-term/summary."
}
BOJ
          NEEDS_KEN+=("TKT-0340-A5: CRITICAL — Context injection budget at ${BUDGET_PCT}% (${BUDGET_TOKENS}/${BUDGET_WINDOW} tokens) EXCEEDS ${CB_BLOCK_PCT}% block threshold. RISK OF SILENT TRUNCATION. Alert written to ${BUDGET_ALERT}. Immediate action required.")
          log "  ENFORCE: CRITICAL budget alert written to $BUDGET_ALERT"
        fi
      else
        NEEDS_KEN+=("TKT-0340-A5: CRITICAL — Context injection budget at ${BUDGET_PCT}% (${BUDGET_TOKENS}/${BUDGET_WINDOW} tokens) EXCEEDS ${CB_BLOCK_PCT}% block threshold. Immediate review required.")
      fi
      ;;
    *)
      log "  WARN: context-budget.sh returned unknown status: $BUDGET_STATUS"
      log "  Output: $BUDGET_OUTPUT"
      ;;
  esac
else
  log "  SKIP: context-budget.sh not found at $CONTEXT_BUDGET_SCRIPT — context budget audit skipped"
fi

write_state

# ---------- CHECK 24: Long-ID Stub Detection (L-085) ----------
# Detects PG tickets with long-ID format (TKT-NNNN: <text>) that may be
# L-077 stub-victim duplicates of the short-ID (TKT-NNNN) ticket.
# Age threshold: 7 days. NON-DESTRUCTIVE — writes findings to state/long-id-stubs.json,
# does NOT auto-close. Surface for Ken review via auto-heal report.
log "CHECK 24: L-085 long-ID stub detection"
CHECKS_RUN+=("long_id_stub_check")

LONG_ID_STUB_SCRIPT="$WORKSPACE/scripts/long-id-stub-check.sh"
LONG_ID_STUB_FILE="$STATE_DIR/long-id-stubs.json"
if [[ -x "$LONG_ID_STUB_SCRIPT" ]]; then
  bash "$LONG_ID_STUB_SCRIPT" >> "$LOG" 2>&1 || true
  if [[ -f "$LONG_ID_STUB_FILE" ]]; then
    STUB_COUNT=$(python3 -c "import json; d=json.load(open('$LONG_ID_STUB_FILE')); print(d.get('count') or 0)" 2>/dev/null || echo 0)
    if [[ "$STUB_COUNT" -gt 0 ]]; then
      log "CHECK 24: Found $STUB_COUNT long-ID stub(s) — see $LONG_ID_STUB_FILE"
      # Non-destructive: add to NEEDS_KEN so Ken sees it in the auto-heal report
      NEEDS_KEN+=("L-085: $STUB_COUNT long-ID stub(s) found — review state/long-id-stubs.json")
    fi
  fi
fi

# ---------- CHECK 25: CREST Tool-Call Rejection Recovery (L-089) ----------
# Detects L-089 stall pattern: an agent emitted an explanatory block after a
# rejected tool call without retrying in the same turn. Scans recent session
# transcripts (last 7 days) for the pattern. NON-DESTRUCTIVE — writes findings
# to state/crest-rejection-stalls.json. Alerts Ken via NEEDS_KEN if >0 stalls
# detected in last 24h.
log "CHECK 25: CREST tool-call rejection recovery (L-089)"
CHECKS_RUN+=("crest_rejection_stall_check")
CHECKS_RUN+=("cloud_cron_escalation")
CHECKS_RUN+=("ollama_quota_canary")

L089_FINDINGS="$STATE_DIR/crest-rejection-stalls.json"
L089_THRESHOLD_HOURS=24

python3 <<PYEOF
import json, os, re, glob, datetime
from pathlib import Path

ws = "$WORKSPACE"
threshold_hours = $L089_THRESHOLD_HOURS
findings_path = "$L089_FINDINGS"
now = datetime.datetime.now(datetime.timezone.utc)
cutoff_ms = int((now - datetime.timedelta(hours=threshold_hours)).timestamp() * 1000)

# Scan last 7 days of session JSONL files
sessions_root = Path(ws) / "agents"
pattern_paths = list(sessions_root.glob("*/sessions/*.jsonl"))
pattern_paths = [p for p in pattern_paths if (now - datetime.datetime.fromtimestamp(p.stat().st_mtime, tz=datetime.timezone.utc)).days <= 7]

stall_findings = []
schema_err_markers = [
    r"invalid cron\.update params",
    r"unexpected property",
    r"missing required",
    r"schema validation failed",
    r"TypeError: .* is not",
    r"KeyError:",
    r"AttributeError:",
    r"ValueError:.*expected",
    r"OutboundDeliveryError",
]

for p in pattern_paths:
    try:
        lines = p.read_text(errors="ignore").splitlines()
    except Exception:
        continue
    for i, line in enumerate(lines):
        try:
            rec = json.loads(line)
        except Exception:
            continue
        ts = rec.get("__openclaw", {}).get("recordTimestampMs") or rec.get("timestamp")
        if not ts or ts < cutoff_ms:
            continue
        # Look at tool result messages with error status
        content = rec.get("content")
        if isinstance(content, list):
            for c in content:
                text = c.get("text", "") if isinstance(c, dict) else ""
                for marker in schema_err_markers:
                    if re.search(marker, text):
                        # Check the next 1-5 messages: did the same session retry the tool call?
                        next_assistant = []
                        for j in range(i+1, min(i+6, len(lines))):
                            try:
                                r2 = json.loads(lines[j])
                            except Exception:
                                continue
                            if r2.get("role") == "assistant":
                                next_assistant.append(r2)
                                if len(next_assistant) >= 2:
                                    break
                        # Stall = the rejected result was followed by an assistant message
                        # that does NOT contain a tool_use block within the next 2 assistant turns
                        has_retry = False
                        for na in next_assistant:
                            nac = na.get("content", [])
                            if isinstance(nac, list):
                                for nc in nac:
                                    if isinstance(nc, dict) and nc.get("type") == "tool_use":
                                        has_retry = True
                                        break
                            if has_retry:
                                break
                        if next_assistant and not has_retry:
                            stall_findings.append({
                                "session": p.parent.parent.name + "/" + p.stem,
                                "sessionFile": str(p),
                                "timestamp": ts,
                                "marker": marker,
                                "excerpt": text[:200],
                                "agentName": rec.get("__openclaw", {}).get("agentId", "unknown"),
                            })
                        break

result = {
    "check": "crest_rejection_stall_check",
    "ran_at": now.isoformat(),
    "threshold_hours": threshold_hours,
    "stalls_found": len(stall_findings),
    "findings": stall_findings[:20],  # cap to 20 most recent
    "verdict": "PASS" if len(stall_findings) == 0 else f"NEEDS_REVIEW: {len(stall_findings)} stall pattern(s) in last {threshold_hours}h"
}
Path(findings_path).write_text(json.dumps(result, indent=2))
print(f"CHECK 25: {result['verdict']}")
if stall_findings:
    for f in stall_findings[:5]:
        print(f"  - {f['session']} @ {f['timestamp']}: {f['excerpt'][:100]}")
PYEOF

if [[ -f "$L089_FINDINGS" ]]; then
  L089_COUNT=$(python3 -c "import json; d=json.load(open('$L089_FINDINGS')); print(d.get('stalls_found') or 0)" 2>/dev/null || echo 0)
  if [[ "$L089_COUNT" -gt 0 ]]; then
    log "CHECK 25: Found $L089_COUNT CREST rejection-stall pattern(s) in last ${L089_THRESHOLD_HOURS}h — see $L089_FINDINGS"
    NEEDS_KEN+=("L-089: $L089_COUNT CREST tool-call rejection-stall pattern(s) detected. Review state/crest-rejection-stalls.json. CREST v1.2 §8.4 enforcement: agent emitted commentary after rejection without retrying.")
  fi
fi

# ---------- 
# ---------- CHECK 25b: Gateway Env-Wrapper Inert Detection (L-102) ----------
# TKT-0505-A5: structural detection of L-102 (env-wrapper inert for CLI-launched gateways).
# Without this check, the only way to know the wrapper is inert is manual ps eww inspection.
# Detects: gateway process parented to a shell/CLI (PPID != 1 on darwin) AND env vars
# set by the wrapper (e.g. NODE_OPTIONS=--max-old-space-size=6144) differ from what
# the wrapper expects. Non-destructive: writes state/gateway-launch-state.json + NEEDS_KEN.
log "CHECK 25b: gateway env-wrapper inert detect (L-102)"
CHECKS_RUN+=("gateway_env_wrapper_inert")
GATEWAY_LAUNCH_STATE="$WORKSPACE/state/gateway-launch-state.json"
PROD_PORT="${OPENCLAW_GATEWAY_PORT:-18789}"

if [[ "$(uname -s)" == "Darwin" ]]; then
  _GW_PID=$(lsof -nP -iTCP:${PROD_PORT} -sTCP:LISTEN 2>/dev/null | grep -v COMMAND | head -1 | awk '{print $2}')
  if [[ -n "$_GW_PID" ]]; then
    _GW_PPID=$(ps -o ppid= -p "$_GW_PID" 2>/dev/null | tr -d ' ')
    _GW_PARENT_NAME=""
    if [[ -n "$_GW_PPID" && "$_GW_PPID" != "1" ]]; then
      _GW_PARENT_NAME=$(ps -o command= -p "$_GW_PPID" 2>/dev/null | awk '{print $1}')
    fi
    # Extract full NODE_OPTIONS value (may contain spaces, e.g. " --max-old-space-size=6144")
    # Use python to parse ps eww reliably (handles multi-space env values)
    _GW_NODE_OPTS=$(ps eww -p "$_GW_PID" 2>/dev/null | tr '\0' '\n' | python3 -c "
import sys, re
text = sys.stdin.read()
# ps eww separates args+env with spaces, but env values can have spaces too
# Look for NODE_OPTIONS= followed by any chars until next known env var pattern
m = re.search(r'NODE_OPTIONS=([^A-Z]*?)(?:[A-Z_][A-Z_0-9]*=|\Z)', text)
if m:
    print(m.group(1).strip())
" 2>/dev/null)
    _GW_HAS_NODE_OPTS="no"
    if echo "$_GW_NODE_OPTS" | grep -q "max-old-space-size"; then
      _GW_HAS_NODE_OPTS="yes"
    fi
    _WRAPPER_PARENTED="no"
    if [[ "$_GW_PPID" == "1" ]]; then
      _WRAPPER_PARENTED="yes"
    fi
    _GW_NOW_ISO=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    python3 << PYEOF_INNER
import json, os
p = '$GATEWAY_LAUNCH_STATE'
d = {}
if os.path.exists(p):
    try: d = json.load(open(p))
    except: d = {}
d['lastChecked'] = '$_GW_NOW_ISO'
d['prodPID'] = int('$_GW_PID')
d['prodPPID'] = int('$_GW_PPID') if '$_GW_PPID' else None
d['prodParentName'] = '$_GW_PARENT_NAME'
d['wrapperParentedToLaunchd'] = '$_WRAPPER_PARENTED' == 'yes'
d['envWrapperExpected'] = 'NODE_OPTIONS contains --max-old-space-size=6144'
d['envWrapperActual'] = '$_GW_NODE_OPTS'
d['envWrapperApplied'] = '$_GW_HAS_NODE_OPTS' == 'yes'
d['launchdMatch'] = ('$_WRAPPER_PARENTED' == 'yes') and ('$_GW_HAS_NODE_OPTS' == 'yes')
d['alertIfMismatch'] = not (('$_WRAPPER_PARENTED' == 'yes') and ('$_GW_HAS_NODE_OPTS' == 'yes'))
with open(p, 'w') as f: json.dump(d, f, indent=2)
PYEOF_INNER
    if [[ "$_WRAPPER_PARENTED" != "yes" || "$_GW_HAS_NODE_OPTS" != "yes" ]]; then
      REASON_PARENT=""
      if [[ "$_WRAPPER_PARENTED" != "yes" ]]; then
        REASON_PARENT="gateway PPID=$_GW_PPID (parent: $_GW_PARENT_NAME) - NOT parented to launchd. Env-wrapper changes are INERT for CLI-launched gateways (L-102). "
      fi
      REASON_ENV=""
      if [[ "$_GW_HAS_NODE_OPTS" != "yes" ]]; then
        REASON_ENV="env-wrapper expects NODE_OPTIONS=--max-old-space-size=6144 but process env shows: ${_GW_NODE_OPTS:-empty}. "
      fi
      log "CHECK 25b: gateway env-wrapper MISMATCH - ${REASON_PARENT}${REASON_ENV}action: launchctl bootout + bootstrap (NOT openclaw gateway CLI). See state/gateway-launch-state.json."

      # --- CHG-0821 Phase 2: auto-remediation block ---
      EXPECTED_NODE_OPTIONS='--max-old-space-size=6144'
      GW_ENV_FILE="$HOME/.openclaw/service-env/ai.openclaw.gateway.env"
      GW_PLIST="/Users/ainchorsoc2a/Library/LaunchAgents/ai.openclaw.gateway.plist"
      _REMEDIATION_OK="no"
      _ENV_CHANGED="no"

      if [[ -f "$GW_ENV_FILE" ]]; then
        _ENV_CONTENT=$(cat "$GW_ENV_FILE")
        if ! echo "$_ENV_CONTENT" | grep -q "NODE_OPTIONS.*${EXPECTED_NODE_OPTIONS}"; then
          log "CHECK 25b: remediating env file — adding/updating NODE_OPTIONS=${EXPECTED_NODE_OPTIONS}"
          # Strip any existing NODE_OPTIONS export line, then append the correct one
          _ENV_CONTENT=$(echo "$_ENV_CONTENT" | grep -v '^export NODE_OPTIONS=')
          if [[ -n "$_ENV_CONTENT" ]]; then
            _ENV_CONTENT="${_ENV_CONTENT}
"
          fi
          _ENV_CONTENT="${_ENV_CONTENT}export NODE_OPTIONS='${EXPECTED_NODE_OPTIONS}'"
          printf '%s\n' "$_ENV_CONTENT" > "$GW_ENV_FILE"
          log "CHECK 25b: env file updated at $GW_ENV_FILE"
          _ENV_CHANGED="yes"
        else
          log "CHECK 25b: env file already has correct NODE_OPTIONS — no rewrite needed"
        fi

        if [[ "$_ENV_CHANGED" == "yes" ]]; then
          # --- Attempt graceful gateway restart ---
          log "CHECK 25b: attempting graceful gateway restart via launchctl..."
          launchctl bootout gui/501/ai.openclaw.gateway 2>/dev/null || true
          sleep 2
          launchctl bootstrap gui/501 "$GW_PLIST"
          sleep 3

          # --- Re-read gateway PID and NODE_OPTIONS ---
          _GW_PID_NEW=$(lsof -nP -iTCP:${PROD_PORT} -sTCP:LISTEN 2>/dev/null | grep -v COMMAND | head -1 | awk '{print $2}')
          if [[ -n "$_GW_PID_NEW" ]]; then
            _GW_NODE_OPTS_NEW=$(ps eww -p "$_GW_PID_NEW" 2>/dev/null | tr '\0' '\n' | python3 -c "
import sys, re
text = sys.stdin.read()
m = re.search(r'NODE_OPTIONS=([^A-Z]*?)(?:[A-Z_][A-Z_0-9]*=|\Z)', text)
if m:
    print(m.group(1).strip())
" 2>/dev/null)
            if echo "$_GW_NODE_OPTS_NEW" | grep -q "max-old-space-size"; then
              log "CHECK 25b: auto-remediation succeeded — gateway PID $_GW_PID_NEW has NODE_OPTIONS with max-old-space-size"
              _REMEDIATION_OK="yes"
            else
              log "CHECK 25b: auto-remediation failed — restart completed but gateway PID $_GW_PID_NEW still missing NODE_OPTIONS=--max-old-space-size"
            fi
          else
            log "CHECK 25b: auto-remediation failed — no gateway process listening on port $PROD_PORT after restart"
          fi
        else
          log "CHECK 25b: env file already correct — skipping gateway restart"
          # No env change and we are inside mismatch branch for other reasons (e.g. PPID); keep _REMEDIATION_OK="no" so NEEDS_KEN fires
        fi
      else
        log "CHECK 25b: auto-remediation failed — env file $GW_ENV_FILE does not exist"
      fi

      if [[ "$_REMEDIATION_OK" != "yes" ]]; then
        NEEDS_KEN+=("L-102: Gateway (PID $_GW_PID) env-wrapper INERT. ${REASON_PARENT}${REASON_ENV}Fix: ensure gateway is launchd-spawned. State: state/gateway-launch-state.json. (TKT-0505-A5.)")
      fi
    fi
  fi
fi

# ---------- CHECK 26: db-ticket.sh Shell-Compatibility Failure (L-090) ----------
# Detects L-090 silence-failure pattern: db-ticket.sh create invoked under
# zsh with the read -p coprocess bug, or other failed db-ticket.sh invocations.
# Scans last 7d of session JSONL for: "no coprocess" markers, TKT-XXXX JSON
# payloads passed via stdin (heredoc), or direct db-write.sh bypass calls
# (indicating the script was bypassed). NON-DESTRUCTIVE — writes findings to
# state/db-ticket-shell-failures.json. Alerts Ken via NEEDS_KEN if >0 in last 24h.
log "CHECK 26: db-ticket.sh shell-compat failure (L-090)"
CHECKS_RUN+=("db_ticket_shell_compat_check")

L090_FINDINGS="$STATE_DIR/db-ticket-shell-failures.json"
L090_THRESHOLD_HOURS=24

python3 <<PYEOF
import json, os, re, glob, datetime
from pathlib import Path

ws = "$WORKSPACE"
threshold_hours = $L090_THRESHOLD_HOURS
findings_path = "$L090_FINDINGS"
now = datetime.datetime.now(datetime.timezone.utc)
cutoff_ms = int((now - datetime.timedelta(hours=threshold_hours)).timestamp() * 1000)

sessions_root = Path(ws) / "agents"
pattern_paths = list(sessions_root.glob("*/sessions/*.jsonl"))
pattern_paths = [p for p in pattern_paths if (now - datetime.datetime.fromtimestamp(p.stat().st_mtime, tz=datetime.timezone.utc)).days <= 7]

l090_findings = []
markers = [
    (r"cmd_create:read:\d+: -p: no coprocess", "zsh_read_p_coprocess_bug"),
    (r"FORBIDDEN_FIELD: id-is-readonly", "create_from_json_validator_reject"),
    (r"db-ticket\.sh.*uses interactive prompts, not flags", "flag_rejected_on_create"),
    (r"db-write\.sh.*direct path.*zsh", "agent_db_write_bypass"),
    (r"PG write degraded.*tkt_id.*TKT-", "pg_write_degraded_on_create"),
    (r"gateway-restore\.sh.*Proceed.*-p: no coprocess", "gateway_restore_zsh_coprocess_bug"),
    (r"read -r -p.*no coprocess", "generic_read_p_zsh_coprocess"),
    (r"zsh.*read -p.*coprocess", "zsh_read_p_generic"),
]

for p in pattern_paths:
    try:
        lines = p.read_text(errors="ignore").splitlines()
    except Exception:
        continue
    for line in lines:
        try:
            rec = json.loads(line)
        except Exception:
            continue
        ts = rec.get("__openclaw", {}).get("recordTimestampMs") or rec.get("timestamp")
        if not ts or ts < cutoff_ms:
            continue
        content = rec.get("content")
        if isinstance(content, list):
            for c in content:
                text = c.get("text", "") if isinstance(c, dict) else ""
                for marker_pattern, marker_label in markers:
                    if re.search(marker_pattern, text):
                        l090_findings.append({
                            "session": p.parent.parent.name + "/" + p.stem,
                            "sessionFile": str(p),
                            "timestamp": ts,
                            "marker": marker_label,
                            "pattern": marker_pattern,
                            "excerpt": text[:200],
                            "agentName": rec.get("__openclaw", {}).get("agentId", "unknown"),
                        })
                        break
                else:
                    continue
                break

result = {
    "check": "db_ticket_shell_compat_check",
    "ran_at": now.isoformat(),
    "threshold_hours": threshold_hours,
    "failures_found": len(l090_findings),
    "findings": l090_findings[:20],
    "verdict": "PASS" if len(l090_findings) == 0 else f"NEEDS_REVIEW: {len(l090_findings)} db-ticket.sh shell-compat failure(s) in last {threshold_hours}h"
}
Path(findings_path).write_text(json.dumps(result, indent=2))
print(f"CHECK 26: {result['verdict']}")
if l090_findings:
    for f in l090_findings[:5]:
        print(f"  - {f['session']} @ {f['timestamp']}: {f['marker']} :: {f['excerpt'][:100]}")
PYEOF

if [[ -f "$L090_FINDINGS" ]]; then
  L090_COUNT=$(python3 -c "import json; d=json.load(open('$L090_FINDINGS')); print(d.get('failures_found') or 0)" 2>/dev/null || echo 0)
  if [[ "$L090_COUNT" -gt 0 ]]; then
    log "CHECK 26: Found $L090_COUNT db-ticket.sh shell-compat failure(s) in last ${L090_THRESHOLD_HOURS}h — see $L090_FINDINGS"
    NEEDS_KEN+=("L-090: $L090_COUNT db-ticket.sh shell-compat failure(s) detected. Review state/db-ticket-shell-failures.json. CHG-0524 fix: use create-from-json for non-interactive creation. Auto-reexec to bash is in place for legacy create path.")
  fi
fi

# ---------- CHECK 27: crest-done-gate.sh Syntax Validation (L-091) ----------
# Pairs with scripts/hooks/pre-commit-bash-n.sh (L-129) for defense-in-depth (catches at write time, CHECK 27 catches in nightly audit).
# Detects L-091-style pre-existing syntax errors in CREST infrastructure scripts.
# L-091: crest-done-gate.sh had a stray double-quote on line 22 since 2026-06-11,
# silently broken for 2 days because nothing actually exercised the full gate path.
# This check runs `bash -n` against critical CREST scripts and alerts if any fail.
# NON-DESTRUCTIVE — does not execute the scripts, only parses them. Threshold: 1.
log "CHECK 27: CREST infrastructure script syntax validation (L-091)"
CHECKS_RUN+=("crest_script_syntax_check")

CREST_SCRIPTS=(
  "$WORKSPACE/scripts/crest-done-gate.sh"
  "$WORKSPACE/scripts/crest-transition-check.sh"
  "$WORKSPACE/scripts/aria-crest-check.sh"
  "$WORKSPACE/scripts/dispatch-validate.sh"
  "$WORKSPACE/scripts/atom-validate.sh"
)

CREST_SYNTAX_FAILS=0
CREST_SYNTAX_REPORT="$STATE_DIR/crest-script-syntax.json"

for script_path in "${CREST_SCRIPTS[@]}"; do
  if [[ ! -f "$script_path" ]]; then
    continue  # Script doesn't exist — skip silently (not all paths may be present)
  fi
  script_name=$(basename "$script_path")
  if ! bash -n "$script_path" 2>/dev/null; then
    log "CHECK 27: SYNTAX ERROR in $script_name — see $CREST_SYNTAX_REPORT"
    CREST_SYNTAX_FAILS=$((CREST_SYNTAX_FAILS + 1))
  fi
done

# Defense-in-depth: ensure pre-commit hook is installed (L-129)
if [[ ! -L "$WORKSPACE/.git/hooks/pre-commit" ]] && [[ ! -f "$WORKSPACE/.git/hooks/pre-commit" ]]; then
  log "  WARN: pre-commit hook not installed, running installer (L-129)"
  bash "$WORKSPACE/scripts/install-pre-commit-hooks.sh" 2>&1 | while read -r line; do log "    $line"; done
fi
python3 <<PYEOF
import json
from pathlib import Path
result = {
    "check": "crest_script_syntax_check",
    "ran_at": "$(date -u '+%Y-%m-%dT%H:%M:%S+00:00')",
    "scripts_checked": ${#CREST_SCRIPTS[@]},
    "syntax_failures": $CREST_SYNTAX_FAILS,
    "verdict": "PASS" if $CREST_SYNTAX_FAILS == 0 else f"FAIL: $CREST_SYNTAX_FAILS CREST script(s) have syntax errors"
}
Path("$CREST_SYNTAX_REPORT").write_text(json.dumps(result, indent=2))
print(f"CHECK 27: {result['verdict']}")
PYEOF

if [[ $CREST_SYNTAX_FAILS -gt 0 ]]; then
  NEEDS_KEN+=("L-091: $CREST_SYNTAX_FAILS CREST infrastructure script(s) have syntax errors. Run: bash -n <script>. See state/crest-script-syntax.json")
fi

# ---------- CHECK 28f: Orphaned TQP Queue Writes — JSON-only entries (L-095) ----------
# L-095: TQP reads PG state_task_queue, NOT state/task-queue.json. Atoms queued to
# JSON only are silent failures — TQP cron 'a89d00ef' runs every 5 min, finds nothing,
# logs 'TQP: No queued or dispatched tasks. Exiting.' — no error, no alert.
# Existing task-watchdog.sh handles PG->JSON divergence; this check handles JSON->PG.
log "CHECK 28f: TQP queue write-path consistency (L-095)"
CHECKS_RUN+=("tqp_queue_consistency_check")

TQP_ORPHAN_REPORT="$STATE_DIR/tqp-orphan-writes.json"

python3 <<PYEOF
import json, os, subprocess
from pathlib import Path

json_path = Path("$STATE_DIR/../task-queue.json")
pg_out = subprocess.run(
    ["bash", "$WORKSPACE/scripts/db-raw.sh", "-c",
     "SELECT id FROM state_task_queue WHERE status IN ('queued','dispatched','running')"],
    capture_output=True, text=True
)

orphans = []
if json_path.exists():
    try:
        d = json.load(open(json_path))
        json_ids = set()
        for a in d.get('queue', []):
            aid = a.get('atom_id', '')
            status = a.get('status', '')
            if aid and status == 'queued':
                json_ids.add(aid)
        pg_ids = set()
        for line in (pg_out.stdout or '').strip().split('\n'):
            line = line.strip()
            if line and not line.startswith('---') and not line.startswith('id') and not line.startswith('('):
                pg_ids.add(line)
        missing_in_pg = sorted(json_ids - pg_ids)
        orphans = missing_in_pg
    except Exception as e:
        pass

result = {
    "check": "tqp_queue_consistency_check",
    "ran_at": "$(date -u '+%Y-%m-%dT%H:%M:%S+00:00')",
    "json_queued_count": len(json_ids) if 'json_ids' in dir() else 0,
    "pg_active_count": len(pg_ids) if 'pg_ids' in dir() else 0,
    "orphans_json_not_in_pg": orphans,
    "orphan_count": len(orphans),
    "verdict": "PASS" if len(orphans) == 0 else f"FAIL: {len(orphans)} JSON-queued atom(s) have no PG counterpart — TQP cannot see them (L-095)"
}
Path("$TQP_ORPHAN_REPORT").write_text(json.dumps(result, indent=2))
print(f"CHECK 28f: {result['verdict']}")
PYEOF

ORPHAN_COUNT=$(python3 -c "import json; d=json.load(open('$TQP_ORPHAN_REPORT')); print(d.get('orphan_count') or 0)" 2>/dev/null || echo 0)
if [[ "$ORPHAN_COUNT" -gt 0 ]]; then
  log "CHECK 28f: Found $ORPHAN_COUNT orphan JSON-queued atom(s) — see $TQP_ORPHAN_REPORT"
  NEEDS_KEN+=("L-095: $ORPHAN_COUNT atom(s) queued to state/task-queue.json only (not PG). TQP cannot see them. Re-queue to PG state_task_queue. See state/tqp-orphan-writes.json")
fi

# ---------- CHECK 28g: TQP Claimed-But-Not-Executing Detection (L-096) ----------
# L-096: TQP claims atoms (status='dispatched', claimedby='agent:tqp') but the only
# existing executor (flash-dispatcher.sh) handles CREST sub-tickets only. Plain TQP
# atoms fall through — claim succeeds, no execution, timeout fires, re-queue.
# This check detects rows claimed > 5 min ago with no state_payload update.
log "CHECK 28g: TQP claimed-but-not-executing detection (L-096)"
CHECKS_RUN+=("tqp_claim_execution_check")

TQP_STUCK_REPORT="$STATE_DIR/tqp-stuck-claims.json"

python3 <<PYEOF
import json, subprocess
from pathlib import Path
from datetime import datetime, timezone, timedelta

# Threshold: 5 min — any claim older than this without state_payload update is suspicious
STUCK_THRESHOLD_MIN = 5
now = datetime.now(timezone.utc).astimezone()
cutoff = (now - timedelta(minutes=STUCK_THRESHOLD_MIN)).isoformat(timespec='seconds')

r = subprocess.run(
    ["bash", "$WORKSPACE/scripts/db-raw.sh", "-c",
     f"SELECT id, title, claimedby, claimedat, claimtimeout, state_payload FROM state_task_queue WHERE status='dispatched' AND claimedby='agent:tqp' AND claimedat < '{cutoff}'"],
    capture_output=True, text=True
)

stuck = []
for line in (r.stdout or '').strip().split('\n'):
    line = line.strip()
    if not line or line.startswith('id') or line.startswith('---') or line.startswith('('):
        continue
    parts = line.split('|', 5)
    if len(parts) < 6: continue
    aid, title, claimedby, claimedat, claimtimeout, payload = parts
    # state_payload is empty (NULL) means no execution
    if not payload or payload in ('null', '', '{}'):
        stuck.append({
            "id": aid, "title": title, "claimedat": claimedat,
            "claimtimeout": claimtimeout, "minutes_claimed": round((now - datetime.fromisoformat(claimedat.replace('Z', '+00:00') if claimedat.endswith('Z') else claimedat)).total_seconds() / 60, 1)
        })

result = {
    "check": "tqp_claim_execution_check",
    "ran_at": now.isoformat(timespec='seconds'),
    "stuck_threshold_min": STUCK_THRESHOLD_MIN,
    "stuck_count": len(stuck),
    "stuck_atoms": stuck,
    "verdict": "PASS" if len(stuck) == 0 else f"WARN: {len(stuck)} atom(s) claimed > 5 min ago with no execution. TQP claims but no executor (L-096). Signal live since 2026-06-13 — see state/tqp-stuck-claims.json."
}
Path("$TQP_STUCK_REPORT").write_text(json.dumps(result, indent=2))
print(f"CHECK 28g: {result['verdict']}")
PYEOF

STUCK_COUNT=$(python3 -c "import json; d=json.load(open('$TQP_STUCK_REPORT')); print(d.get('stuck_count') or 0)" 2>/dev/null || echo 0)
if [[ "$STUCK_COUNT" -gt 0 ]]; then
  log "CHECK 28g: WARN: $STUCK_COUNT atom(s) claimed but not executing — see $TQP_STUCK_REPORT"
  NEEDS_KEN+=("L-096 WARN: $STUCK_COUNT TQP atom(s) claimed by agent:tqp with no execution. Signal live since 2026-06-13. Full bridge TKT-0504-A1..A5 in Sprint 9. See state/tqp-stuck-claims.json")
fi

# ---------- CHECK 28h: CREST Executor Routing Audit (L-107) ----------
# TKT-0506: weekly audit of recent TKT atoms for executor:model drift.
# Detects: Yoda (or other strong-tier agent) doing Execute work directly with
# strong-tier model, when it should have dispatched to a specialist with
# flash model. Reads state/crest-execute-gate-log.json for the last 7d of
# gate decisions and reports violations. Structural enforcement for
# CREST v1.2 §6 ("Yoda never does specialist Execute work directly").
log "CHECK 28h: CREST executor routing audit (L-107)"
CHECKS_RUN+=("crest_executor_routing_audit")
CREST_GATE_LOG="$WORKSPACE/state/crest-execute-gate-log.json"

if [[ -f "$CREST_GATE_LOG" ]]; then
  CREST_VIOLATIONS=$(python3 - <<PYEOF_INNER
import json, datetime
from pathlib import Path
p = Path("$CREST_GATE_LOG")
try: d = json.load(open(p))
except: d = {}
hist = d.get("history", [])
now = datetime.datetime.now(datetime.timezone.utc)
violations = []
strong_tier_keywords = ["kimi-k2.7-code", "kimi-k2.6", "deepseek-v4-pro", "gemma4:31b-cloud", "minimax-m3", "anthropic/claude"]
for entry in hist[-200:]:
    if entry.get("decision") == "block":
        continue
    ts = entry.get("ts", "")
    if not ts: continue
    try: et = datetime.datetime.fromisoformat(ts.replace("Z", "+00:00"))
    except: continue
    age_days = (now - et).days
    if age_days > 7: continue
    operator = entry.get("operator", "")
    model = entry.get("model", "")
    phase = entry.get("phase", "")
    if "yoda" in operator.lower() and any(k in model for k in strong_tier_keywords):
        violations.append({
            "ts": ts, "operator": operator, "model": model, "phase": phase,
            "atom": entry.get("atomDesc", "")[:80]
        })
print(len(violations))
for v in violations[:5]:
    print(f"  {v['ts']}: {v['operator']} on {v['phase']} ({v['model']}) — {v['atom']}")
PYEOF_INNER
  )
  CREST_VIOLATION_COUNT=$(echo "$CREST_VIOLATIONS" | head -1)
  if [[ "${CREST_VIOLATION_COUNT:-0}" -gt 0 ]]; then
    log "CHECK 28h: $CREST_VIOLATION_COUNT CREST routing violation(s) in last 7d"
    NEEDS_KEN+=("L-107: $CREST_VIOLATION_COUNT Yoda direct Execute work detected in last 7d (CREST v1.2 §6 violation). Yoda using strong-tier model on cheap-tier phase. See state/crest-execute-gate-log.json. TKT-0506.")
  else
    log "CHECK 28h: PASS (no CREST routing violations in last 7d)"
  fi
else
  log "CHECK 28h: SKIP (no crest-execute-gate-log.json yet)"
fi

# ---------- CHECK 28i: Model Policy Drift (TKT-0540 A9) ----------
# Runs scripts/check-model-policy-drift.sh to detect divergence between
# state/model-policy.json (CREST v1.3 PG SSOT), runtime agent models, and consumer tests.
log "CHECK 28i: model-policy drift (TKT-0540)"
CHECKS_RUN+=("model_policy_drift")
DRIFT_SCRIPT="$WORKSPACE/scripts/check-model-policy-drift.sh"
if [[ -x "$DRIFT_SCRIPT" ]]; then
  DRIFT_OUT=$(bash "$DRIFT_SCRIPT" 2>/dev/null) || true
  DRIFT_STATUS=$(echo "$DRIFT_OUT" | $JQ -r '.status // "error"' 2>/dev/null || true)
  if [[ "$DRIFT_STATUS" == "drift" ]]; then
    DRIFT_ALERTS=$(echo "$DRIFT_OUT" | $JQ -r '.alerts | join("; ")' 2>/dev/null || true)
    log "CHECK 28i: DRIFT detected — $DRIFT_ALERTS"
    NEEDS_KEN+=("TKT-0540 CHECK 28i: model-policy drift detected — $DRIFT_ALERTS. See state/model-policy-drift-alert.json.")
  else
    log "CHECK 28i: PASS (no drift)"
  fi
else
  log "CHECK 28i: SKIP (check-model-policy-drift.sh not found)"
fi

# ---------- CHECK 29: Cloud-Cron Escalation (L-116) ----------
# Detects cron failures on ollama/* modelled jobs and escalates via
# sovereign-alert immediately, bypassing the 30-min heartbeat cycle.
# Idempotent: 6h rate limit via state/check29-last-fire.json.
# CHG-0591 (2026-06-15): PRIMARY source is live openclaw cron list --json.
# FALLBACK: state/cron-health-alert.json (only if live source fails).
# Also: if last fire was for the SAME crons AND they're now healthy (cons=0),
# DON'T fire even after cooldown expires (cooldown is "don't spam", not "must fire").
log "CHECK 29: cloud-cron escalation (L-116)"
CHECKS_RUN+=("cloud_cron_escalation")
CHECKS_RUN+=("ollama_quota_canary")

CRON_ALERT="${STATE_DIR}/cron-health-alert.json"
CHECK29_LAST_FIRE="${STATE_DIR}/check29-last-fire.json"
CHECK29_COOLDOWN_S=21600  # 6h

CLOUD_ESCALATED=0
CLOUD_ESCALATED_LIST=""

# ── Live cron state (primary source) ──
CRON_LIVE_JSON=$(cd "$WORKSPACE" && openclaw cron list --json 2>/dev/null || echo "")
CRON_SOURCE="live"

if [[ -z "$CRON_LIVE_JSON" ]]; then
  # Fallback: stale heartbeat file
  if [[ -f "$CRON_ALERT" ]]; then
    CRON_LIVE_JSON=$(python3 -c "
import json, datetime, os, sys
d = json.load(open('$CRON_ALERT'))
gen_at = d.get('generatedAt', 'unknown')
try:
    gen_dt = datetime.datetime.fromisoformat(gen_at)
    age = (datetime.datetime.now(datetime.timezone.utc) - gen_dt).total_seconds()
    age_h = int(age / 3600)
    print(f'WARN — using stale fallback data, age {age_h}h (generated {gen_at})', file=sys.stderr)
except:
    print('WARN — using stale fallback data, age unknown', file=sys.stderr)
# Emit a synthetic live-like structure from the alert file
failures = d.get('failures', [])
jobs = []
for f in failures:
    jobs.append({
        'id': f.get('cronId', f.get('fullCronId', '')),
        'name': f.get('name', ''),
        'enabled': True,
        'payload': {'kind': 'agentTurn', 'model': ''},
        'state': {
            'consecutiveErrors': f.get('consecutiveErrors', 0),
            'lastError': f.get('lastError', ''),
        }
    })
print(json.dumps({'jobs': jobs}))
" 2>/dev/null || echo '{"jobs":[]}')
    CRON_SOURCE="stale-fallback"
    log "CHECK 29: WARN — openclaw cron list failed, using stale $CRON_ALERT fallback"
  else
    log "CHECK 29: SKIP (openclaw cron list failed and no $CRON_ALERT fallback)"
    CRON_LIVE_JSON='{"jobs":[]}'
    CRON_SOURCE="none"
  fi
fi

if [[ "$CRON_SOURCE" == "none" ]]; then
  : # already logged skip above
else
  # ── Same skip prefixes as cron-health-check.sh ──
  # CHG-0411: Crons where error is expected
  # CHG-0458: Gateway-restart transient errors
  SHOULD_FIRE=true
  if [[ -f "$CHECK29_LAST_FIRE" ]]; then
    LAST_FIRE_TS=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1])).get('ts',''))" "$CHECK29_LAST_FIRE" 2>/dev/null || echo "")
    if [[ -n "$LAST_FIRE_TS" ]]; then
      LAST_FIRE_EPOCH=$(date -j -f "%Y-%m-%dT%H:%M:%S" "$LAST_FIRE_TS" "+%s" 2>/dev/null || echo 0)
      NOW_EPOCH=$(date "+%s")
      ELAPSED=$(( NOW_EPOCH - LAST_FIRE_EPOCH ))
      if (( ELAPSED < CHECK29_COOLDOWN_S )); then
        SHOULD_FIRE=false
      fi
    fi
  fi

  if [[ "$SHOULD_FIRE" == "true" ]]; then
    # ── Filter live cron state through python3 (same logic as cron-health-check.sh lines 45-50) ──
    while IFS=$'\t' read -r CRON_ID CRON_NAME CRON_ERRS CRON_MODEL; do
      [[ -z "$CRON_ID" ]] && continue
      (( CRON_ERRS >= 3 )) || continue
      [[ "$CRON_MODEL" == ollama/* ]] || continue
      CLOUD_ESCALATED=$(( CLOUD_ESCALATED + 1 ))
      CLOUD_ESCALATED_LIST="${CLOUD_ESCALATED_LIST}  • ${CRON_NAME} (${CRON_ERRS} errs, ${CRON_MODEL})\n"
    done < <(python3 -c "
import json, sys

cron_raw = '''$CRON_LIVE_JSON'''
cron_data = json.loads(cron_raw) if cron_raw.strip() else {'jobs': []}

# Same skip prefixes as cron-health-check.sh (CHG-0411)
EXPECTED_ERROR_CRONS = [
    '20f59555',  # Nightly Gateway Restart
]

# Gateway-restart transient error patterns (CHG-0458)
GATEWAY_RESTART_PATTERNS = [
    'interrupted by gateway restart',
    'job interrupted by gateway restart',
]

total_checked = 0
total_at_risk = 0

for job in cron_data.get('jobs', []):
    jid = job.get('id', '')
    if not jid:
        continue

    # Only enabled crons
    if not job.get('enabled', True):
        continue

    # Skip EXPECTED_ERROR_CRONS prefixes
    if any(jid.startswith(prefix) for prefix in EXPECTED_ERROR_CRONS):
        continue

    # Skip gateway-restart transient errors
    last_error = job.get('state', {}).get('lastError', '')
    if any(pattern in last_error for pattern in GATEWAY_RESTART_PATTERNS):
        continue

    payload = job.get('payload', {})
    kind = payload.get('kind', '')
    model = payload.get('model', '')

    # Only agentTurn crons with ollama/* model
    if kind != 'agentTurn':
        continue
    if not model.startswith('ollama/'):
        continue

    total_checked += 1
    cons = job.get('state', {}).get('consecutiveErrors', 0)
    name = job.get('name', '(unnamed)')[:60]

    if cons >= 3:
        total_at_risk += 1

    # Always emit — the bash while loop filters cons>=3 and ollama/*
    print(f'{jid}\t{name}\t{cons}\t{model}')

# Log summary to stderr for the bash log line
print(f'live state — {total_checked} ollama/* agentTurn crons checked, {total_at_risk} at cons>=3', file=sys.stderr)
" 2>&1)

    # ── CHG-0591: If last fire was for the SAME crons AND they're now healthy, don't re-fire ──
    if (( CLOUD_ESCALATED == 0 )) && [[ -f "$CHECK29_LAST_FIRE" ]]; then
      # Check if all ollama/* agentTurn crons are now healthy (cons=0)
      LAST_FIRE_CRONS_HEALTHY=$(python3 -c "
import json

cron_raw = '''$CRON_LIVE_JSON'''
cron_data = json.loads(cron_raw) if cron_raw.strip() else {'jobs': []}

all_healthy = True
for job in cron_data.get('jobs', []):
    payload = job.get('payload', {})
    if payload.get('kind') != 'agentTurn':
        continue
    model = payload.get('model', '')
    if not model.startswith('ollama/'):
        continue
    if job.get('state', {}).get('consecutiveErrors', 0) > 0:
        all_healthy = False
        break

print('true' if all_healthy else 'false')
" 2>/dev/null || echo "false")

      if [[ "$LAST_FIRE_CRONS_HEALTHY" == "true" ]]; then
        log "CHECK 29: SKIP (cooldown expired but previously-fired crons now healthy — cons=0 across all ollama/* agentTurn jobs)"
        SHOULD_FIRE=false
      fi
    fi

    if [[ "$SHOULD_FIRE" == "true" ]]; then
      if (( CLOUD_ESCALATED > 0 )); then
        MSG="🚨 Cloud-cron cluster failure — ${CLOUD_ESCALATED} ollama/* job(s) at >=3 consecutive errors (likely Ollama Cloud weekly cap or auth outage):\n${CLOUD_ESCALATED_LIST}Check: openclaw cron list | state/cron-health-alert.json"
        bash "${WORKSPACE}/scripts/sovereign-alert.sh" --source CLOUD-CRON --message "$MSG" || log "CHECK 29: WARN — sovereign-alert.sh returned non-zero (Telegram send failed)"
        python3 -c "
import json, datetime
json.dump({'ts': datetime.datetime.now().strftime('%Y-%m-%dT%H:%M:%S'), 'count': $CLOUD_ESCALATED, 'crons': '''$CLOUD_ESCALATED_LIST'''}, open('$CHECK29_LAST_FIRE','w'), indent=2)
"
        log "CHECK 29: ESCALATED ${CLOUD_ESCALATED} cloud cron failure(s) via sovereign-alert"
      else
        log "CHECK 29: PASS (no ollama/* crons at >=3 consecutive errors)"
      fi
    fi
  else
    log "CHECK 29: SKIP (cooldown active, last fire <6h ago)"
  fi
fi

# ---------- CHECK 30: Ollama Quota Canary (L-118) ----------
# Detects first cron to flip to lastErrorReason=rate_limit (the 24-72h pre-cliff
# canary) and escalates via sovereign-alert with concrete shed recommendations.
# Pairs with CHECK 29 (reactive 3+ errs) for full outage prevention.
# Idempotent: 12h cooldown via state/check30-last-fire.json.
log "CHECK 30: ollama quota canary (L-118)"
CHECKS_RUN+=("ollama_quota_canary")

CRON_LIST_JSON="$WORKSPACE/state/cron-list-snapshot.json"
CHECK30_LAST_FIRE="$WORKSPACE/state/check30-last-fire.json"
CHECK30_COOLDOWN_S=43200  # 12h

# Force fresh fetch every run — rate_limit flags can be cleared between runs
# (e.g. Yoda resets stale errors). A 30-min cached snapshot would re-alert on
# already-fixed crons. CHG-0606.
openclaw cron list --json > "$CRON_LIST_JSON" 2>/dev/null || {
  log "CHECK 30: SKIP (openclaw cron list failed)"
  return 0 2>/dev/null || exit 0
}

C30_RATE_LIMITED=$(python3 -c "
import json
d = json.load(open('$CRON_LIST_JSON'))
rl = [j for j in d.get('jobs', []) if j.get('state', {}).get('lastErrorReason') == 'rate_limit']
rl_sorted = sorted(rl, key=lambda x: x.get('state', {}).get('consecutiveErrors', 0), reverse=True)
for j in rl_sorted[:15]:
    s = j.get('state', {})
    print(f\"{j.get('id','')[:8]}\t{j.get('name','')}\t{s.get('consecutiveErrors',0)}\")
" 2>/dev/null)

# Robust count: count non-empty lines only (avoid '0\n0' syntax error when grep returns multiple zeros)
C30_COUNT=$(echo "$C30_RATE_LIMITED" | grep -c "^[0-9a-f]" 2>/dev/null || true)
C30_COUNT=${C30_COUNT:-0}
C30_COUNT=$(echo "$C30_COUNT" | head -1 | tr -d -c '0-9')
C30_COUNT=${C30_COUNT:-0}

if [[ "${C30_COUNT}" -eq 0 ]]; then
  log "CHECK 30: PASS (no ollama/* crons currently rate-limited)"
else
  # Cooldown check (12h)
  SHOULD_FIRE=true
  if [[ -f "$CHECK30_LAST_FIRE" ]]; then
    LAST_FIRE_TS=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1])).get('ts',''))" "$CHECK30_LAST_FIRE" 2>/dev/null || echo "")
    if [[ -n "$LAST_FIRE_TS" ]]; then
      LAST_FIRE_EPOCH=$(date -j -f "%Y-%m-%dT%H:%M:%S" "$LAST_FIRE_TS" "+%s" 2>/dev/null || echo 0)
      NOW_EPOCH=$(date "+%s")
      ELAPSED=$(( NOW_EPOCH - LAST_FIRE_EPOCH ))
      if (( ELAPSED < CHECK30_COOLDOWN_S )); then
        SHOULD_FIRE=false
        log "CHECK 30: SKIP (cooldown active, last fire ${ELAPSED}s ago, <${CHECK30_COOLDOWN_S}s)"
      fi
    fi
  fi

  if [[ "$SHOULD_FIRE" == "true" ]]; then
    # Build shed recommendation: low-priority crons to disable if total failures climb
    # Priority tiers: governance/daily-brief = shed first; TQP/auto-heal = critical, keep
    SHED_CANDIDATES="AInchors Midday Cost Tracker, AInchors Daily Burn Alert, Daily Memory Hygiene, SOUL.md Weekly Size Audit, AInchors Weekly Asset Review, Aria Weekly Business ROI Summary, AInchors Weekly Compliance Report, Shield/Lex/Sage nightly sweeps, Aria Daily Summary (business), AInchors Daily Close (Blog)"

    MSG="🚨 Ollama quota canary — ${C30_COUNT} cron(s) flipped to lastErrorReason=rate_limit. This is the 24-72h pre-cliff signal (pattern: hits Sun/Mon, recovers Tue).\n\nCurrently rate-limited (top 15 by consecutive errors):\n$(echo "$C30_RATE_LIMITED" | awk -F'\t' '{printf "  • %s (%s errs)\n", $2, $3}')\n\nRecommended shed order (if total climbs >25):\n  ${SHED_CANDIDATES}\n\nCheck: openclaw cron list --json | jq '.jobs[] | select(.state.lastErrorReason==\"rate_limit\") | {name, consecutiveErrors}'\nDaily cap: \$100 USD Ollama Cloud. Fixed subscription, weekly usage cap on account beautiful_faraday_411."

    # CHG-0799 + CHG-0886 + TKT-0780: cron-failure business-impact alert routes
    # to BOTH Ken + Angie via cross-agent-alert.sh (default dual recipients).
    bash "${WORKSPACE}/scripts/cross-agent-alert.sh" --source QUOTA-CANARY --message "$MSG" || log "CHECK 30: WARN — cross-agent-alert.sh returned non-zero"

    python3 -c "
import json, datetime
ts = datetime.datetime.now().strftime('%Y-%m-%dT%H:%M:%S')
crons = []
for line in '''$C30_RATE_LIMITED'''.strip().split(chr(10)):
    if line:
        parts = line.split(chr(9))
        crons.append({'id': parts[0], 'name': parts[1], 'consecutiveErrors': int(parts[2])})
json.dump({'ts': ts, 'count': $C30_COUNT, 'crons': crons}, open('$CHECK30_LAST_FIRE','w'), indent=2)
"

    log "CHECK 30: ESCALATED ${C30_COUNT} rate-limited cron(s) via sovereign-alert (canary fired)"
  fi
fi
# ---------- CHECK 31: Per-cron Ollama quota tracking (L-128, Rec #1) ----------
# Pairs with CHECK 30 (aggregate) for full predictive power: per-cron attribution
# + cliff risk score. Computes estimated weekly token usage per cron, identifies
# top consumers, flags critical/warning crons. Used by multi-vendor auto-suggest
# and shed recommendations. 6h cooldown.
log "CHECK 31: per-cron ollama quota tracking (L-128)"
CHECKS_RUN+=("per_cron_ollama_quota")

QUOTA_TRACK_OUT="$WORKSPACE/state/cron-ollama-usage.json"
CHECK31_LAST_FIRE="$WORKSPACE/state/check31-last-fire.json"
CHECK31_COOLDOWN_S=21600  # 6h

# Cooldown check
SHOULD_FIRE_31=true
if [[ -f "$CHECK31_LAST_FIRE" ]]; then
  LAST_FIRE_TS_31=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1])).get('ts',''))" "$CHECK31_LAST_FIRE" 2>/dev/null || echo "")
  if [[ -n "$LAST_FIRE_TS_31" ]]; then
    LAST_FIRE_EPOCH_31=$(date -j -f "%Y-%m-%dT%H:%M:%S" "$LAST_FIRE_TS_31" "+%s" 2>/dev/null || echo 0)
    NOW_EPOCH_31=$(date "+%s")
    if (( NOW_EPOCH_31 - LAST_FIRE_EPOCH_31 < CHECK31_COOLDOWN_S )); then
      SHOULD_FIRE_31=false
    fi
  fi
fi

if [[ "$SHOULD_FIRE_31" != "true" ]]; then
  log "CHECK 31: SKIP (cooldown active, last fire <6h ago)"
  :  # script continues (matches CHECK 30 SKIP pattern)
else
  if [[ -x "$WORKSPACE/scripts/ollama-quota-track.sh" ]]; then
    TRACK_OUT=$(bash "$WORKSPACE/scripts/ollama-quota-track.sh" 2>&1 || true)
    TRACK_EXIT=$?
    if [[ $TRACK_EXIT -eq 0 ]]; then
      # Parse summary
      TRACK_STATS=$(echo "$TRACK_OUT" | grep -E "^(TRACKED|RATE_LIMITED|WARNING|CRITICAL|TOP_CONSUMER):" || echo "")
      if [[ -n "$TRACK_STATS" ]]; then
        log "CHECK 31: $TRACK_STATS"
      fi
      
      # If state file exists, get critical count
      if [[ -f "$QUOTA_TRACK_OUT" ]]; then
        C31_CRITICAL=$(python3 -c "import json; d=json.load(open('$QUOTA_TRACK_OUT')); print(d.get('summary', {}).get('critical') or 0)" 2>/dev/null || echo 0)
        C31_WARNING=$(python3 -c "import json; d=json.load(open('$QUOTA_TRACK_OUT')); print(d.get('summary', {}).get('warning') or 0)" 2>/dev/null || echo 0)
        C31_RATE_LIMITED=$(python3 -c "import json; d=json.load(open('$QUOTA_TRACK_OUT')); print(d.get('summary', {}).get('rate_limited') or 0)" 2>/dev/null || echo 0)
        
        if [[ "$C31_CRITICAL" -gt 0 ]]; then
          log "CHECK 31: ALERT — ${C31_CRITICAL} cron(s) at critical cliff risk (>=0.7)"
          NEEDS_KEN+=("Per-cron quota: ${C31_CRITICAL} cron(s) at critical cliff risk — review state/cron-ollama-usage.json top_consumers")
        elif [[ "$C31_WARNING" -gt 0 ]]; then
          log "CHECK 31: WARN — ${C31_WARNING} cron(s) at warning cliff risk (>=0.4)"
        else
          log "CHECK 31: PASS (no per-cron cliff risk detected)"
        fi
      fi
      
      # Update last fire
      python3 -c "
import json, datetime
ts = datetime.datetime.now().strftime('%Y-%m-%dT%H:%M:%S')
json.dump({'ts': ts, 'critical': $C31_CRITICAL, 'warning': $C31_WARNING, 'rate_limited': $C31_RATE_LIMITED}, open('$CHECK31_LAST_FIRE', 'w'), indent=2)
" 2>/dev/null
    else
      log "CHECK 31: WARN — ollama-quota-track.sh exited non-zero: $TRACK_OUT"
    fi
  else
    log "CHECK 31: SKIP (ollama-quota-track.sh not found at $WORKSPACE/scripts/)"
  fi
fi

# ---------- CHECK 32: Per-cron migration advisor (L-130, P2 #2) ----------
# Pairs with CHECK 31 (L-128, per-cron quota) and L-119 (multi-vendor primary).
# Uses state/cron-migration-suggestions.json to identify crons that should be
# considered for multi-vendor migration. Tier 1 = migrate now, Tier 2 = monitor.
# 6h cooldown.
log "CHECK 32: per-cron migration advisor (L-130)"
CHECKS_RUN+=("per_cron_migration_advisor")

MIGRATION_OUT="$WORKSPACE/state/cron-migration-suggestions.json"
CHECK32_LAST_FIRE="$WORKSPACE/state/check32-last-fire.json"
CHECK32_COOLDOWN_S=21600  # 6h

# Cooldown check
SHOULD_FIRE_32=true
if [[ -f "$CHECK32_LAST_FIRE" ]]; then
  LAST_FIRE_TS_32=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1])).get('ts',''))" "$CHECK32_LAST_FIRE" 2>/dev/null || echo "")
  if [[ -n "$LAST_FIRE_TS_32" ]]; then
    LAST_FIRE_EPOCH_32=$(date -j -f "%Y-%m-%dT%H:%M:%S" "$LAST_FIRE_TS_32" "+%s" 2>/dev/null || echo 0)
    NOW_EPOCH_32=$(date "+%s")
    if (( NOW_EPOCH_32 - LAST_FIRE_EPOCH_32 < CHECK32_COOLDOWN_S )); then
      SHOULD_FIRE_32=false
    fi
  fi
fi

if [[ "$SHOULD_FIRE_32" != "true" ]]; then
  log "CHECK 32: SKIP (cooldown active, last fire <6h ago)"
  :  # script continues
else
  if [[ -x "$WORKSPACE/scripts/cron-migration-advisor.sh" ]]; then
    MIGRATION_OUTPUT=$(bash "$WORKSPACE/scripts/cron-migration-advisor.sh" 2>&1 || true)
    MIGRATION_EXIT=$?
    C32_TIER1=0
    if [[ $MIGRATION_EXIT -eq 0 ]]; then
      MIGRATION_STATS=$(echo "$MIGRATION_OUTPUT" | grep -E "^(EVALUATED|TIER_1|TIER_2|TIER_3|TOP_CANDIDATE):" || echo "")
      if [[ -n "$MIGRATION_STATS" ]]; then
        log "CHECK 32: $MIGRATION_STATS"
      fi
      
      if [[ -f "$MIGRATION_OUT" ]]; then
        C32_TIER1=$(python3 -c "import json; d=json.load(open('$MIGRATION_OUT')); print(d.get('summary', {}).get('tier_1_migrate_now') or 0)" 2>/dev/null || echo 0)
        
        if [[ "$C32_TIER1" -ge 5 ]]; then
          log "CHECK 32: ALERT — ${C32_TIER1} cron(s) at tier 1 (migrate now). Top 3: see state/cron-migration-suggestions.json"
          NEEDS_KEN+=("Migration advisor: ${C32_TIER1} cron(s) recommended for multi-vendor migration — review tier 1 candidates")
        else
          log "CHECK 32: PASS (${C32_TIER1} tier 1 candidate(s) — under threshold of 5)"
        fi
      fi
      
      # Update last fire
      python3 -c "
import json, datetime
ts = datetime.datetime.now().strftime('%Y-%m-%dT%H:%M:%S')
json.dump({'ts': ts, 'tier1': $C32_TIER1}, open('$CHECK32_LAST_FIRE', 'w'), indent=2)
" 2>/dev/null
    else
      log "CHECK 32: WARN — cron-migration-advisor.sh exited non-zero: $MIGRATION_OUTPUT"
    fi
  else
    log "CHECK 32: SKIP (cron-migration-advisor.sh not found)"
  fi
fi


# ---------- CHECK 33: Null-safe JSON access static check (L-132, P2 #4) ----------
# Defense-in-depth against L-126 bug class: catches .get(KEY, N) patterns that
# flow into bash arithmetic. Sibling of CHECK 27 (L-091, script syntax) and
# CHECK 32 (L-130, migration advisor). 24h cooldown — static analysis, not state.
log "CHECK 33: null-safe JSON access static check (L-132)"
CHECKS_RUN+=("null_safe_json_access")

NULL_OUT="$WORKSPACE/state/null-safe-json-findings.json"
NULL_FINDINGS=0
NULL_HIGH=0
if [[ -x "$WORKSPACE/scripts/check-null-safe-json.sh" ]]; then
  # `|| true` masks the exit code from `set -uo pipefail` + ERR trap (zsh behavior).
  # The checker's own exit code is irrelevant — we read stdout and parse it.
  NULL_OUT_RAW=$(bash "$WORKSPACE/scripts/check-null-safe-json.sh" 2>&1 || true)
  # Parse findings + high count via python (avoids head/awk SIGPIPE with pipefail).
  # Python prints all 3 values space-separated on one line, then IFS=' ' read splits them.
  # Parse findings via python (avoids head/awk SIGPIPE with pipefail).
  # Use temp var + || true to guard procsub pipeline from ERR trap.
  NULL_PARSED=$(echo "$NULL_OUT_RAW" | python3 -c "
import sys, re
out = sys.stdin.read()
findings = re.search(r'^NULL_SAFE_FINDINGS:\s*(\d+)', out, re.M)
high = re.search(r'^HIGH:\s*(\d+)', out, re.M)
medium = re.search(r'^MEDIUM:\s*(\d+)', out, re.M)
print(findings.group(1) if findings else 0, high.group(1) if high else 0, medium.group(1) if medium else 0)
" || true)
  IFS=" " read -r NULL_FINDINGS NULL_HIGH NULL_MEDIUM <<< "$NULL_PARSED"
  NULL_FINDINGS=${NULL_FINDINGS:-0}
  NULL_HIGH=${NULL_HIGH:-0}
  
  if [[ "$NULL_FINDINGS" -gt 0 ]]; then
    log "CHECK 33: WARN — $NULL_FINDINGS null-unsafe .get() pattern(s) in scripts/, $NULL_HIGH high-severity (L-126 bug class)"
    # Only NEEDS_KEN for high-severity (those that flow into arithmetic)
    if [[ "$NULL_HIGH" -gt 0 ]]; then
      NEEDS_KEN+=("Null-safe JSON: $NULL_HIGH high-severity .get() pattern(s) flowing into bash arithmetic — review state/null-safe-json-findings.json")
    fi
  else
    log "CHECK 33: PASS (0 null-unsafe .get() patterns in scripts/)"
  fi
else
  log "CHECK 33: SKIP (check-null-safe-json.sh not found)"
fi

# ---------- CHECK 34: Cooldown-gating static check (L-137, anti-regression for L-136) ----------
# Defense-in-depth against the L-136 bug class: catches SHOULD_FIRE[_NN]=false
# patterns that are NOT followed by an if-block gating the side-effect call.
# Without this check, L-136-style bugs ship silently — the script runs without
# error and does the wrong thing (10 alerts in 45 min instead of 1 per 12h).
# Sibling of CHECK 27 (L-091, syntax), CHECK 33 (L-132, null-safety), and
# CHECK 34 (L-137, cooldown-gating). 24h cooldown — static analysis.
log "CHECK 34: cooldown-gating static check (L-137, anti-regression for L-136)"
CHECKS_RUN+=("cooldown_gating_static_check")

GATE_OUT="$WORKSPACE/state/cooldown-gate-findings.json"
GATE_FINDINGS=0
GATE_HIGH=0
if [[ -x "$WORKSPACE/scripts/check-cooldown-gate.sh" ]]; then
  # `|| true` masks the exit code from `set -uo pipefail` + ERR trap (zsh behavior).
  # The checker's own exit code is irrelevant — we read stdout and parse it.
  GATE_OUT_RAW=$(bash "$WORKSPACE/scripts/check-cooldown-gate.sh" 2>&1 || true)
  # Parse findings + high count via python (avoids head/awk SIGPIPE with pipefail).
  # Python prints all 3 values space-separated on one line, then IFS=' ' read splits them.
  # Parse findings via python (avoids head/awk SIGPIPE with pipefail).
  # Use temp var + || true to guard procsub pipeline from ERR trap.
  GATE_PARSED=$(echo "$GATE_OUT_RAW" | python3 -c "
import sys, re
out = sys.stdin.read()
findings = re.search(r'^COOLDOWN_GATE_FINDINGS:\s*(\d+)', out, re.M)
high = re.search(r'^HIGH:\s*(\d+)', out, re.M)
medium = re.search(r'^MEDIUM:\s*(\d+)', out, re.M)
print(findings.group(1) if findings else 0, high.group(1) if high else 0, medium.group(1) if medium else 0)
" || true)
  IFS=" " read -r GATE_FINDINGS GATE_HIGH GATE_MEDIUM <<< "$GATE_PARSED"
  GATE_FINDINGS=${GATE_FINDINGS:-0}
  GATE_HIGH=${GATE_HIGH:-0}
  
  if [[ "$GATE_FINDINGS" -gt 0 ]]; then
    log "CHECK 34: WARN — $GATE_FINDINGS cooldown-gating pattern(s) in scripts/, $GATE_HIGH high-severity (L-136 bug class)"
    # Only NEEDS_KEN for high-severity (SHOULD_FIRE=false + ungated side-effect)
    if [[ "$GATE_HIGH" -gt 0 ]]; then
      NEEDS_KEN+=("Cooldown-gating: $GATE_HIGH high-severity SHOULD_FIRE=false with ungated side-effect call (L-136 bug class) — review state/cooldown-gate-findings.json")
    fi
  else
    log "CHECK 34: PASS (0 cooldown-gating anti-patterns in scripts/)"
  fi
else
  log "CHECK 34: SKIP (check-cooldown-gate.sh not found)"
fi
# ---------- CHECK 35: Pipefail+trap static check (L-138, anti-regression for L-126/131/132/137) ----------
# Defense-in-depth against the L-138 bug class: catches `set -o pipefail` + `trap ... ERR`
# + ungated `$(...)` checker invocations, `awk | head` SIGPIPE patterns, `tr '\n' ' '` in
# process substitution, and `read -r ... < <(cmd)` with multi-line pipelines.
# L-126, L-131, L-132, L-137 all hit this. Anti-regression checker.
# Sibling of CHECK 27 (L-091, syntax), CHECK 33 (L-132, null-safety), and
# CHECK 34 (L-137, cooldown-gating). 24h cooldown — static analysis.
log "CHECK 35: pipefail+trap static check (L-138, anti-regression for L-126/131/132/137)"
CHECKS_RUN+=("pipefail_trap_static_check")

PIPE_OUT="$WORKSPACE/state/pipefail-trap-findings.json"
PIPE_FINDINGS=0
PIPE_HIGH=0
if [[ -x "$WORKSPACE/scripts/check-pipefail-trap.sh" ]]; then
  # `|| true` masks the exit code from `set -uo pipefail` + ERR trap (zsh behavior).
  # The checker's own exit code is irrelevant — we read stdout and parse it.
  PIPE_OUT_RAW=$(bash "$WORKSPACE/scripts/check-pipefail-trap.sh" 2>&1 || true)
  # Parse findings + high count via python (avoids head/awk SIGPIPE with pipefail).
  # Python prints all 3 values space-separated on one line, then IFS=' ' read splits them.
  # Parse findings via python (avoids head/awk SIGPIPE with pipefail).
  # Use temp var + || true to guard procsub pipeline from ERR trap.
  PIPE_PARSED=$(echo "$PIPE_OUT_RAW" | python3 -c "
import sys, re
out = sys.stdin.read()
findings = re.search(r'^PIPEFAIL_TRAP_FINDINGS:\s*(\d+)', out, re.M)
high = re.search(r'^HIGH:\s*(\d+)', out, re.M)
medium = re.search(r'^MEDIUM:\s*(\d+)', out, re.M)
print(findings.group(1) if findings else 0, high.group(1) if high else 0, medium.group(1) if medium else 0)
" || true)
  IFS=" " read -r PIPE_FINDINGS PIPE_HIGH PIPE_MEDIUM <<< "$PIPE_PARSED"
  PIPE_FINDINGS=${PIPE_FINDINGS:-0}
  PIPE_HIGH=${PIPE_HIGH:-0}
  
  if [[ "$PIPE_FINDINGS" -gt 0 ]]; then
    log "CHECK 35: WARN — $PIPE_FINDINGS pipefail+trap anti-pattern(s) in scripts/, $PIPE_HIGH high-severity (L-138 bug class)"
    # Only NEEDS_KEN for high-severity (those that crash under pipefail+ERR trap)
    if [[ "$PIPE_HIGH" -gt 0 ]]; then
      NEEDS_KEN+=("Pipefail+trap: $PIPE_HIGH high-severity anti-pattern(s) (L-138 bug class) — review state/pipefail-trap-findings.json")
    fi
  else
    log "CHECK 35: PASS (0 pipefail+trap anti-patterns in scripts/)"
  fi
else
  log "CHECK 35: SKIP (check-pipefail-trap.sh not found)"
fi

# ---------- CHECK 36: Cron Timeout Audit (<120s on :cloud agentTurn) — TKT-0526 ----------
# Detects agentTurn crons with :cloud models whose timeoutSeconds < 120 (the L-087
# root-cause minimum). Suggested timeout tiers: 120s default, 300s for sweeps/audits,
# 600–831s for blog/summary/complex-gen. Writes findings to state/auto-heal-cron-timeout-audit.json.
# This check is a sub-agent dispatch from TKT-0526; it stays DRY-RUN until Ken
# reviews the baseline and authorises flip-to-live.
log "CHECK 36: cron timeout audit (<120s on :cloud agentTurn crons) — TKT-0526"
CHECKS_RUN+=("cron_timeout_audit")

# ── Live flag — stays false until Ken flips after baseline review ──
# CHG-0583 (2026-06-15): Ken approved flip-to-live (Atom 6 of TKT-0526).
# Now live: future offenders surface in NEEDS_KEN with full Notion routing via auto-heal report.
CRON_TIMEOUT_AUDIT_LIVE=true

AUDIT_OUTFILE="${WORKSPACE}/state/auto-heal-cron-timeout-audit.json"

# Run the audit logic inline (no separate function — matches CHECK 29/30 pattern)
cron_timeout_audit_logic() {
  local live_flag="${1:-false}"
  local outfile="${2:-$AUDIT_OUTFILE}"
  local workspace="${3:-$WORKSPACE}"

  # Snapshot cron state
  local cron_json
  cron_json=$(cd "$workspace" && openclaw cron list --json 2>/dev/null || echo '{"jobs":[]}')

  # Use python3 for clean filtering — same EXPECTED_ERROR_CRONS as cron-health-check.sh (the source)
  # Gateway-restart pattern matches any cron whose lastError contains "interrupted by gateway restart"
  python3 - "$cron_json" "$outfile" "$live_flag" "$NOW" << 'PYEOF'
import json, sys, os, datetime

cron_json_raw = sys.argv[1]
outfile = sys.argv[2]
live_flag = sys.argv[3] == 'true'
now = sys.argv[4]

cron_data = json.loads(cron_json_raw) if cron_json_raw.strip() else {'jobs': []}

# Same skip prefixes as cron-health-check.sh
EXPECTED_ERROR_CRONS = [
    '20f59555',  # Nightly Gateway Restart
]

# Gateway-restart transient error patterns (CHG-0458)
GATEWAY_RESTART_PATTERNS = [
    'interrupted by gateway restart',
    'job interrupted by gateway restart',
]

offenders = []

for job in cron_data.get('jobs', []):
    jid = job.get('id', '')
    if not jid:
        continue
    
    # Only enabled crons
    enabled = job.get('enabled', True)
    if not enabled:
        continue
    
    # Skip EXPECTED_ERROR_CRONS prefixes
    if any(jid.startswith(prefix) for prefix in EXPECTED_ERROR_CRONS):
        continue
    
    # Skip gateway-restart transient errors
    last_error = job.get('state', {}).get('lastError', '')
    if any(pattern in last_error for pattern in GATEWAY_RESTART_PATTERNS):
        continue
    
    payload = job.get('payload', {})
    
    # Only agentTurn crons — systemEvent have no model/timeoutSeconds
    kind = payload.get('kind', '')
    if kind != 'agentTurn':
        continue
    
    model = payload.get('model', '')
    # Only :cloud models
    if not model.endswith(':cloud'):
        continue
    
    timeout = payload.get('timeoutSeconds', 0)
    if timeout is None:
        timeout = 0
    
    # Offender: timeout < 120
    if timeout < 120:
        name = job.get('name', '(unnamed)')[:80]
        # Tiered suggested timeout
        suggested = 120  # default
        name_lower = name.lower()
        if any(kw in name_lower for kw in ('sweep', 'audit')):
            suggested = 300
        elif any(kw in name_lower for kw in ('blog', 'summary')):
            suggested = 600
        
        offenders.append({
            'cronId': jid,
            'name': name,
            'currentTimeout': timeout,
            'model': model,
            'suggestedTimeout': suggested,
        })

# Baseline detection: file doesn't exist yet → first run
baseline = not os.path.exists(outfile)

result = {
    'checkedAt': now,
    'offenders': offenders,
    'offenderCount': len(offenders),
    'live': live_flag,
    'baseline': baseline,
}

os.makedirs(os.path.dirname(outfile), exist_ok=True)
with open(outfile, 'w') as f:
    json.dump(result, f, indent=2)

if offenders:
    print(f"OFFENDERS:{len(offenders)}")
    for o in offenders:
        print(f"  {o['cronId'][:8]} {o['name'][:50]} current={o['currentTimeout']}s model={o['model']} suggested={o['suggestedTimeout']}s")
else:
    print("OFFENDERS:0")

print(f"BASELINE:{'true' if baseline else 'false'}")
print(f"LIVE:{'true' if live_flag else 'false'}")
PYEOF
}

# Execute the logic
cron_timeout_audit_logic "$CRON_TIMEOUT_AUDIT_LIVE" "$AUDIT_OUTFILE" "$WORKSPACE"

# Wire the JSON into cron-write.sh (atomic write pattern)
if [[ -f "$AUDIT_OUTFILE" ]]; then
  # Verify JSON is well-formed
  if python3 -c "import json; json.load(open('$AUDIT_OUTFILE')); print('OK')" 2>/dev/null; then
    # Pipe through cron-write.sh for atomicity
    cat "$AUDIT_OUTFILE" | bash ${WORKSPACE}/scripts/cron-write.sh ${WORKSPACE}/state/auto-heal-cron-timeout-audit.json 2>/dev/null || true
    log "CHECK 36: Audit complete — $(python3 -c "import json; d=json.load(open('$AUDIT_OUTFILE')); print(f'{d[\"offenderCount\"]} offender(s), baseline={d[\"baseline\"]}, live={d[\"live\"]}')" 2>/dev/null || echo 'parse-failed')"

    # Surface offenders in NEEDS_KEN for the auto-heal report
    OFFENDER_COUNT=$(python3 -c "import json; d=json.load(open('$AUDIT_OUTFILE')); print(d.get('offenderCount') or 0)" 2>/dev/null || echo 0)
    if [[ "$OFFENDER_COUNT" -gt 0 ]]; then
      OFFENDER_SUMMARY=$(python3 -c "
import json
d = json.load(open('$AUDIT_OUTFILE'))
for o in d.get('offenders', []):
    print(f'{o[\"cronId\"][:8]} {o[\"name\"][:50]} current={o[\"currentTimeout\"]}s model={o[\"model\"]} suggested={o[\"suggestedTimeout\"]}s')
" 2>/dev/null)
      NEEDS_KEN+=("TKT-0526: $OFFENDER_COUNT cron(s) with :cloud model have timeoutSeconds < 120. See $AUDIT_OUTFILE. $(echo $OFFENDER_SUMMARY | tr '\n' ' ')")
    else
      log "CHECK 36: PASS — no :cloud agentTurn crons with timeoutSeconds < 120"
    fi
  else
    log "CHECK 36: ERROR — $AUDIT_OUTFILE is not valid JSON"
    ISSUES_FOUND+=("cron-timeout-audit:json-invalid")
  fi
else
  log "CHECK 36: WARN — audit file not written"
fi


# ---------- CHECK 37: Sandbox Boundary Audit (TKT-0332, INC-20260608-001) ----------
# TKT-0332 AC3: Verifies sandbox→prod config-write side-effect prevention.
# Re-reads sandbox state and attempts a guarded dry-run write through sandbox-guard.sh.
# If OPENCLAW_SANDBOX=1 is set and the write succeeds → CRITICAL NEEDS_KEN.
# This mirrors CHECK 19/20 pattern for sandbox gateway liveness.
# No cooldown — runs every auto-heal cycle. The dry-run write is harmless;
# it only succeeds if a real boundary breach exists.
log "CHECK 37: sandbox boundary audit (TKT-0332, INC-20260608-001)"
CHECKS_RUN+=("sandbox_boundary_audit")

AUDIT_JSON="$WORKSPACE/state/sandbox-boundary-audit.json"
GUARD_SCRIPT="$WORKSPACE/scripts/sandbox-guard.sh"
BOUNDARY_TESTFILE="${HOME}/.openclaw/test-boundary-write"

# Step 1: Verify audit JSON exists and is current (<7d old)
if [[ -f "$AUDIT_JSON" ]]; then
  AUDIT_AGE=$(python3 -c "
import json, os, time
try:
  d = json.load(open('$AUDIT_JSON'))
  checked = d.get('checkedAt', '')
  if checked:
    from datetime import datetime, timezone, timedelta
    dt = datetime.fromisoformat(checked)
    age_hours = (datetime.now(timezone.utc) - dt).total_seconds() / 3600
    print(int(age_hours))
  else:
    print(-1)
except:
  print(-1)
" 2>/dev/null || echo -1)
  if [[ "$AUDIT_AGE" -gt 168 ]]; then  # 7 days
    log "  CHECK 37: WARN — audit JSON is ${AUDIT_AGE}h old (stale >7d). Needs re-run."
    NEEDS_KEN+=("TKT-0332: sandbox boundary audit stale (${AUDIT_AGE}h), needs re-run")
  else
    GAP_COUNT=$(python3 -c "import json; d=json.load(open('$AUDIT_JSON')); print(d['summary']['gap'])" 2>/dev/null || echo -1)
    log "  CHECK 37: Audit JSON OK — ${AUDIT_AGE}h old, ${GAP_COUNT} gap(s)"
  fi
else
  log "  CHECK 37: WARN — audit JSON not found at $AUDIT_JSON"
  NEEDS_KEN+=("TKT-0332: sandbox boundary audit JSON missing — run A1 audit")
fi

# Step 2: Dry-run boundary write test through sandbox-guard.sh
# This tests: if OPENCLAW_SANDBOX=1 set and sandbox-guard.sh is bypassed,
# can any script write to prod paths?
if [[ -x "$GUARD_SCRIPT" ]]; then
  # Clean up any leftover test file first
  rm -f "$BOUNDARY_TESTFILE" 2>/dev/null
  
  # L-138: mask non-zero exit with `|| true` (zsh ERR trap fires on $() with non-zero even under set -u)
  DRYRUN_OUT=$(OPENCLAW_SANDBOX=1 bash -c "
    source "$GUARD_SCRIPT"
    echo 'TKT-0332-boundary-test' >> "$BOUNDARY_TESTFILE"
    echo 'WRITE_SUCCEEDED'
  " 2>&1 || true)
  DRYRUN_EXIT=$?
  
  # Check if the test file was created (should NOT exist if guard worked)
  if [[ -f "$BOUNDARY_TESTFILE" ]]; then
    log "  CHECK 37: CRITICAL — Sandbox boundary BREACHED! Write to $BOUNDARY_TESTFILE succeeded."
    NEEDS_KEN+=("CRITICAL TKT-0332: sandbox→prod boundary BREACH — OPENCLAW_SANDBOX=1 write to prod path succeeded. Investigate immediately.")
    # Clean up
    rm -f "$BOUNDARY_TESTFILE" 2>/dev/null
  elif [[ "$DRYRUN_EXIT" -eq 70 ]]; then
    log "  CHECK 37: PASS — sandbox-guard.sh blocked sandbox→prod write (exit 70 as expected)"
  else
    log "  CHECK 37: PASS — no boundary write occurred (exit=$DRYRUN_EXIT, test file absent)"
  fi
else
  log "  CHECK 37: WARN — sandbox-guard.sh not found at $GUARD_SCRIPT"
  ISSUES_FOUND+=("sandbox-boundary-audit:guard-missing")
fi


# ---------- CHECK 38: Ollama Usage Scraper (TKT-0533) ----------
# Scrapes ollama.com/settings via browser automation for real request counts.
# Updates cost-state.json with live data from Ollama's own dashboard.
# Requires: browser running + signed into ollama.com.
# Window: Monday 10:00 AEST → next Monday 10:00 AEST.
log "CHECK 38: ollama usage scraper (TKT-0533)"
CHECKS_RUN+=("ollama_usage_scraper")

SCRAPER_SCRIPT="$WORKSPACE/scripts/ollama-usage-scraper.py"
if [[ -x "$SCRAPER_SCRIPT" ]]; then
  SCRAPER_OUT=$(python3 "$SCRAPER_SCRIPT" 2>&1) || true
  SCRAPER_EXIT=$?
  if [[ $SCRAPER_EXIT -eq 0 ]]; then
    log "  CHECK 38: OK — $(echo "$SCRAPER_OUT" | head -1)"
    # Extract pct for threshold alerting (against Ollama's actual weekly limit)
    SCRAPER_PCT=$(echo "$SCRAPER_OUT" | grep -oE 'weekly=[0-9]+/[0-9]+ \([0-9.]+\)' | grep -oE '[0-9.]+(?=\))' | head -1 || echo "0")
    if (( $(echo "$SCRAPER_PCT > 70" | bc -l 2>/dev/null || echo 0) )); then
      NEEDS_KEN+=("URGENT TKT-0533: Ollama weekly usage at ${SCRAPER_PCT}% of limit. Projected exhaustion imminent.")
    fi
  elif [[ $SCRAPER_EXIT -eq 1 ]]; then
    log "  CHECK 38: WARN — not signed into ollama.com. Skipping scrape."
    ISSUES_FOUND+=("ollama-usage-scraper:not-signed-in")
  elif [[ $SCRAPER_EXIT -eq 2 ]]; then
    log "  CHECK 38: WARN — browser not running. Skipping scrape."
    ISSUES_FOUND+=("ollama-usage-scraper:browser-not-running")
  else
    log "  CHECK 38: ERROR — scraper failed (exit=$SCRAPER_EXIT): $(echo "$SCRAPER_OUT" | head -1)"
    ISSUES_FOUND+=("ollama-usage-scraper:error")
  fi
else
  log "  CHECK 38: WARN — ollama-usage-scraper.py not found or not executable"
  ISSUES_FOUND+=("ollama-usage-scraper:missing")
fi


# ---------- CHECK 28d: Auto-archive untracked root .md files (TKT-0341) ----------
# TKT-0341 contract: all .md in workspace root must be on the 8-allowlist
# (SOUL/AGENTS/MEMORY/HEARTBEAT/USER/IDENTITY/TOOLS/RULES). This check auto-archives
# new untracked .md files to state/daily-briefs/ and registers an AKB stub. Kills
# 4 recurring NEEDS_KEN events.
log "CHECK 28d: auto-archive untracked root .md files (TKT-0341)"
CHECKS_RUN+=("auto_archive_untracked_md")

# 8-allowlist per TKT-0341 contract
ROOT_ALLOWLIST_REGEX='^(SOUL|AGENTS|MEMORY|HEARTBEAT|USER|IDENTITY|TOOLS|RULES)\.md$'

UNTRACKED_COUNT=0
for md_file in "$WORKSPACE"/*.md; do
  [[ ! -f "$md_file" ]] && continue
  base=$(basename "$md_file")
  if [[ ! "$base" =~ $ROOT_ALLOWLIST_REGEX ]]; then
    # Confirm it's not git-tracked either
    if ! git -C "$WORKSPACE" ls-files --error-unmatch "$md_file" >/dev/null 2>&1; then
      UNTRACKED_COUNT=$((UNTRACKED_COUNT + 1))
      # Don't auto-archive if dry-run
      if [[ "${ENFORCE_DRY_RUN:-false}" == "true" ]]; then
        log "  DRY-RUN: would archive $base → state/daily-briefs/"
        AUTO_FIXED+=("auto-archive-md:dry-run:$base")
        continue
      fi
      # Auto-archive: move to state/daily-briefs/YYYY-MM-DD-{base}
      archive_name="$(date '+%Y-%m-%d')-${base}"
      mkdir -p "$STATE_DIR/daily-briefs"
      mv "$md_file" "$STATE_DIR/daily-briefs/$archive_name"
      log "  AUTO-ARCHIVED: $base → state/daily-briefs/$archive_name"
      AUTO_FIXED+=("auto-archive-md:$base")
      # Register AKB stub (TKT-0529 B3.7: atomic write — durable state file)
      safe_atomic_write "$STATE_DIR/daily-briefs/${archive_name}.akb-stub.json" <<AKBEOF
{
  "type": "akb-stub",
  "source_file": "$base",
  "archived_to": "state/daily-briefs/$archive_name",
  "archived_at": "$(date -u '+%Y-%m-%dT%H:%M:%SZ')",
  "reason": "TKT-0341 contract violation — auto-archived by auto-heal CHECK 28d",
  "needs_review": true,
  "review_action": "Decide: keep as daily-brief, promote to docs/, or delete"
}
AKBEOF
    fi
  fi
done

if [[ $UNTRACKED_COUNT -gt 0 ]]; then
  log "CHECK 28d: Auto-archived $UNTRACKED_COUNT untracked .md file(s) to state/daily-briefs/"
  NEEDS_KEN+=("CHECK 28d: $UNTRACKED_COUNT untracked root .md file(s) auto-archived to state/daily-briefs/. Review .akb-stub.json to decide keep/promote/delete.")
else
  log "CHECK 28d: OK — no untracked .md in root"
fi

# ---------- CHECK 28e: Auto-refresh critical-config-baseline.json if stale ----------
# Kills 4 recurring 'config baseline 8 days old' NEEDS_KEN events.
# If baseline mtime > 7 days, regenerate by re-snapshotting current config.
log "CHECK 28e: auto-refresh critical-config-baseline.json if stale (7d)"
CHECKS_RUN+=("config_baseline_auto_refresh")

# TKT-0529 B3.3: baseline refresh is housekeeping — backup is taken first
# (.bak-YYYYMMDD-HHMMSS), only lastUpdated + pgTables fields are touched, and
# the change is non-destructive (revertable from backup). Retained in dry-run.

BASELINE_FILE="$WORKSPACE/state/critical-config-baseline.json"
BASELINE_STALE_DAYS=7
BASELINE_REFRESHED=0

if [[ -f "$BASELINE_FILE" ]]; then
  BASELINE_AGE_DAYS=$(python3 -c "
import os, time
mt = os.path.getmtime('$BASELINE_FILE')
print(round((time.time() - mt) / 86400, 1))
")
  if (( $(echo "$BASELINE_AGE_DAYS > $BASELINE_STALE_DAYS" | bc -l 2>/dev/null || echo 0) )); then
    log "  Baseline is $BASELINE_AGE_DAYS days old (threshold: $BASELINE_STALE_DAYS) — refreshing"
    # Backup current baseline
    cp "$BASELINE_FILE" "${BASELINE_FILE}.bak-$(date '+%Y%m%d-%H%M%S')"
    # Write Python to temp file (TKT-0408 pattern — avoids bash-vs-Python escape hell)
    # TKT-0529 B3.7: this cat > writes a TRANSIENT temp file (deleted via EXIT trap),
    # not a durable state file. Not a candidate for safe_atomic_write.
    REFRESH_SCRIPT=$(mktemp -t baseline_refresh_XXXXXX.py) || { log "  ERROR: mktemp failed"; }
    trap "rm -f $REFRESH_SCRIPT 2>/dev/null" EXIT
    cat > "$REFRESH_SCRIPT" <<'PYEOF'
import json, os, subprocess, tempfile
from datetime import datetime, timezone
p = os.environ['BASELINE_FILE']
workspace = os.environ['WORKSPACE']
d = json.load(open(p))
now = datetime.now(timezone.utc).astimezone().isoformat(timespec='seconds')
d['lastUpdated'] = now
try:
    out = subprocess.run(['bash', f'{workspace}/scripts/db-raw.sh', '-c',
                          "SELECT count(*) FROM information_schema.tables WHERE table_schema='public'"],
                         capture_output=True, text=True)
    if out.returncode == 0 and out.stdout.strip():
        d['pgTables'] = int(out.stdout.strip())
except Exception: pass
d['lastApprovalContext'] = f'Auto-refreshed by auto-heal CHECK 28e (was {d.get("lastUpdated","?")})'
# TKT-0529 B3.7: atomic write — temp + fsync + os.replace, same pattern as atomic_write()
tmp_fd, tmp_path = tempfile.mkstemp(dir=os.path.dirname(p), suffix='.tmp')
with os.fdopen(tmp_fd, 'w') as f:
    json.dump(d, f, indent=2)
    f.flush()
    os.fsync(f.fileno())
os.replace(tmp_path, p)
print('OK: baseline refreshed')
PYEOF
    BASELINE_FILE="$BASELINE_FILE" WORKSPACE="$WORKSPACE" python3 "$REFRESH_SCRIPT"
    BASELINE_REFRESHED=1
    AUTO_FIXED+=("config-baseline-refresh:auto-28e")
  else
    log "  Baseline is $BASELINE_AGE_DAYS days old — fresh"
  fi
else
  log "  WARNING: critical-config-baseline.json missing — creating skeleton"
  # TKT-0529 B3.7: atomic write — durable state file
  safe_atomic_write "$BASELINE_FILE" <<BASELINEEOF
{
  "openclawVersion": "2026.5.27",
  "upgradedAt": "$(date -u '+%Y-%m-%dT%H:%M:%SZ')",
  "upgradedFrom": "auto-created",
  "agentCount": 14,
  "cronCount": 0,
  "pgTables": 0,
  "gatewayStatus": "unknown",
  "lastUpdated": "$(date -u '+%Y-%m-%dT%H:%M:%SZ')",
  "lastApprovalContext": "Auto-created by CHECK 28e — was missing"
}
BASELINEEOF
  BASELINE_REFRESHED=1
  AUTO_FIXED+=("config-baseline-create:auto-28e")
fi

if [[ $BASELINE_REFRESHED -gt 0 ]]; then
  log "CHECK 28e: baseline refreshed"
  NEEDS_KEN+=("CHECK 28e: critical-config-baseline.json was stale, auto-refreshed by auto-heal CHECK 28e")
fi

# ---------- CHECK 28c: Sandbox gateway 24h auto-unload (L-094) ----------
# Detects ai.openclaw.sandbox-gateway.plist loaded but port 28789 not listening.
# Tracks deadSince in state/sandbox-gateway-state.json. Alerts at 1h, auto-unloads at 24h.
# Kills 46 recurring 'sandbox gateway not listening' alerts.
log "CHECK 28c: sandbox gateway 24h auto-unload (L-094)"
CHECKS_RUN+=("sandbox_gateway_auto_unload")

SANDBOX_STATE="$WORKSPACE/state/sandbox-gateway-state.json"
SANDBOX_PLIST="${HOME}/Library/LaunchAgents/ai.openclaw.sandbox-gateway.plist"

# Detect: LaunchAgent loaded AND nothing on port 28789
SANDBOX_LOADED=0
SANDBOX_LISTENING=0
if launchctl print-disabled gui/$(id -u) 2>/dev/null | grep -q "ai.openclaw.sandbox-gateway => disabled"; then
  SANDBOX_LOADED=0
else
  # Check if it's in the loaded list
  if launchctl list 2>/dev/null | grep -q "ai.openclaw.sandbox-gateway"; then
    SANDBOX_LOADED=1
  fi
fi
if lsof -nP -iTCP:28789 -sTCP:LISTEN 2>/dev/null | grep -q LISTEN; then
  SANDBOX_LISTENING=1
fi

NOW_ISO=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

if [[ $SANDBOX_LOADED -eq 1 && $SANDBOX_LISTENING -eq 0 ]]; then
  # Dead: track or update deadSince
  if [[ -f "$SANDBOX_STATE" ]]; then
    DEAD_SINCE=$(python3 -c "import json; print(json.load(open('$SANDBOX_STATE')).get('deadSince') or '')" 2>/dev/null)
  else
    DEAD_SINCE=""
  fi
  if [[ -z "$DEAD_SINCE" ]]; then
    DEAD_SINCE="$NOW_ISO"
    # TKT-0529 B3.7: atomic write — durable state file
    safe_atomic_write "$SANDBOX_STATE" <<SANDEOF
{
  "plist": "$SANDBOX_PLIST",
  "port": 28789,
  "loaded": true,
  "listening": false,
  "deadSince": "$DEAD_SINCE",
  "alerted": false,
  "unloaded": false
}
SANDEOF
  fi
  DEAD_HOURS=$(python3 -c "
from datetime import datetime, timezone
ds = '$DEAD_SINCE'
if ds.endswith('Z'): ds = ds.replace('Z', '+00:00')
dead = datetime.fromisoformat(ds)
now = datetime.now(timezone.utc)
print(round((now - dead).total_seconds() / 3600, 1))
")
  if (( $(echo "$DEAD_HOURS > 24" | bc -l 2>/dev/null || echo 0) )); then
    # Auto-unload
    log "  Sandbox gateway dead for ${DEAD_HOURS}h — auto-unloading LaunchAgent"
    UID_NUM=$(id -u)
    if launchctl bootout gui/$UID_NUM/ai.openclaw.sandbox-gateway 2>/dev/null || launchctl unload "$SANDBOX_PLIST" 2>/dev/null; then
      python3 -c "
import json
p = '$SANDBOX_STATE'
d = json.load(open(p))
d['unloaded'] = True
d['unloadedAt'] = '$NOW_ISO'
d['unloadedBy'] = 'auto-heal CHECK 28c'
json.dump(d, open(p, 'w'), indent=2)
"
      AUTO_FIXED+=("sandbox-gateway-auto-unload:28c")
      log "  AUTO-UNLOADED: ai.openclaw.sandbox-gateway (dead ${DEAD_HOURS}h)"
    else
      log "  ERROR: launchctl bootout failed for sandbox-gateway"
      NEEDS_KEN+=("CHECK 28c: Sandbox gateway dead ${DEAD_HOURS}h, auto-unload FAILED. Manual: launchctl bootout gui/\$(id -u)/ai.openclaw.sandbox-gateway")
    fi
  elif (( $(echo "$DEAD_HOURS > 1" | bc -l 2>/dev/null || echo 0) )); then
    # Alert: dead > 1h, leave alone for now
    log "  Sandbox gateway dead for ${DEAD_HOURS}h — alert only (auto-unload at 24h)"
    NEEDS_KEN+=("CHECK 28c: Sandbox gateway LaunchAgent loaded but port 28789 not listening (dead ${DEAD_HOURS}h). Auto-unload at 24h. Manual: launchctl bootout gui/\$(id -u)/ai.openclaw.sandbox-gateway")
  else
    log "  Sandbox gateway dead for ${DEAD_HOURS}h — within 1h grace period"
  fi
else
  # Healthy: clear state if exists
  if [[ -f "$SANDBOX_STATE" ]]; then
    rm -f "$SANDBOX_STATE"
    log "  Sandbox gateway healthy — cleared deadSince state"
  else
    log "  Sandbox gateway OK (not loaded or port listening)"
  fi
fi

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
CHECKS_RUN_JSON="$(printf '%s\n' "${CHECKS_RUN[@]}" | python3 -c "import json,sys; print(json.dumps([l for l in sys.stdin.read().splitlines() if l]))")" \
ISSUES_FOUND_JSON="$(printf '%s\n' "${ISSUES_FOUND[@]}" | python3 -c "import json,sys; print(json.dumps([l for l in sys.stdin.read().splitlines() if l]))")" \
AUTO_FIXED_JSON="$(printf '%s\n' "${AUTO_FIXED[@]}" | python3 -c "import json,sys; print(json.dumps([l for l in sys.stdin.read().splitlines() if l]))")" \
_CHECKS_JSON=$(python3 -c "
import json
checks = json.loads(os.environ.get('CHECKS_RUN_JSON', '[]'))
issues = json.loads(os.environ.get('ISSUES_FOUND_JSON', '[]'))
auto_fixed = json.loads(os.environ.get('AUTO_FIXED_JSON', '[]'))
print(json.dumps({'checks_run': checks, 'issues': issues, 'auto_fixed': auto_fixed, 'auto_fixed_count': len(auto_fixed)}))
" 2>/dev/null || echo '{}')
_STATUS="complete"
[[ ${#NEEDS_KEN[@]} -gt 0 ]] && _STATUS="complete_with_needs_ken"
bash "$WORKSPACE/scripts/db-raw.sh" -c "
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

# Final state write — ensures report reflects completed run (L-127 followup)
if (( ${#NEEDS_KEN[@]} > 0 )); then
  write_state "complete_with_needs_ken"
else
  write_state "complete"
fi
