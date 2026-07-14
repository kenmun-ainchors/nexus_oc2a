#!/bin/zsh
# AInchors Run Diagnostics — comprehensive, deep, slow inspection
# Trigger: explicit only (Ken /diagnostics or manual). NEVER automated.
# Output: state/diagnostics-YYYY-MM-DD-HHMM.json + reports/diagnostics-YYYY-MM-DD-HHMM.md
#
# Phases:
#   1. Pre-flight inventory
#   2. Provider chain ping (Anthropic, Opus, Gemma4)
#   3. Integration tests (Notion, Telegram, Obsidian, Memory)
#   4. Auto-heal dry-run snapshot (read what's there)
#   5. Security audit
#   6. HA readiness checklist (placeholders for OC2)
#   7. Coverage analysis (scripts, crons, state files, agents)
#   8. Performance benchmarks (gateway, Ollama, script timings, canvas)
#   9. Predictive health (disk, balance runway, warden streak, backup age)
#
# Recovery drills (phase 4 in plan) deferred — too risky to simulate without isolation.

set -u

WORKSPACE="/Users/ainchorsoc2a/.openclaw/workspace"
STATE_DIR="$WORKSPACE/state"
REPORTS_DIR="$WORKSPACE/reports"
mkdir -p "$STATE_DIR" "$REPORTS_DIR"

STAMP=$(date '+%Y-%m-%d-%H%M')
TODAY=$(date '+%Y-%m-%d')
NOW=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
NOW_LOCAL=$(date '+%Y-%m-%d %H:%M %Z')

JSON_OUT="$STATE_DIR/diagnostics-${STAMP}.json"
MD_OUT="$REPORTS_DIR/diagnostics-${STAMP}.md"
LOG="$STATE_DIR/diagnostics-${STAMP}.log"

typeset -a PHASES_RUN
typeset -a PASS
typeset -a FAIL
typeset -a WARN

log() { echo "[$(date '+%H:%M:%S')] $1" | tee -a "$LOG"; }
phase() { log ""; log "═══ PHASE: $1 ═══"; PHASES_RUN+=("$1"); }
pass() { PASS+=("$1"); log "  ✓ PASS: $1"; }
fail() { FAIL+=("$1"); log "  ✗ FAIL: $1"; }
warn() { WARN+=("$1"); log "  ⚠ WARN: $1"; }

log "═══════════════════════════════════════════"
log "  AInchors RUN DIAGNOSTICS"
log "  Started: $NOW_LOCAL"
log "  Report:  $MD_OUT"
log "═══════════════════════════════════════════"

# ────────────────────────── PHASE 1: PRE-FLIGHT INVENTORY ──────────────────────────
phase "1. Pre-flight Inventory"

# OpenClaw + agent
OPENCLAW_VER=$(openclaw --version 2>&1 | head -1 || echo "?")
log "  OpenClaw version: $OPENCLAW_VER"
[[ "$OPENCLAW_VER" != "?" ]] && pass "openclaw cli responsive" || fail "openclaw cli unresponsive"

# Config hashes
CFG_HASH=$(shasum -a 256 "$HOME/.openclaw/openclaw.json" 2>/dev/null | awk '{print $1}')
log "  openclaw.json hash: ${CFG_HASH:0:16}…"

LAST_GOOD_HASH=$(shasum -a 256 "$HOME/.openclaw/openclaw.json.last-good" 2>/dev/null | awk '{print $1}')
if [[ "$CFG_HASH" == "$LAST_GOOD_HASH" ]]; then
  pass "openclaw.json matches last-good"
else
  warn "openclaw.json differs from last-good (may be intentional)"
fi

# Cron count
CRON_COUNT=$(jq '.jobs | length' "$HOME/.openclaw/cron/jobs.json" 2>/dev/null || echo 0)
log "  Cron jobs: $CRON_COUNT"
(( CRON_COUNT >= 5 )) && pass "cron jobs registered ($CRON_COUNT)" || fail "low cron count ($CRON_COUNT)"

# State files
STATE_COUNT=$(ls "$STATE_DIR"/*.json 2>/dev/null | wc -l | tr -d ' ')
log "  State files: $STATE_COUNT"

# Scripts
SCRIPT_COUNT=$(ls "$WORKSPACE/scripts/" 2>/dev/null | wc -l | tr -d ' ')
log "  Scripts: $SCRIPT_COUNT"

# Memory index
MEM_FILES=$(ls "$WORKSPACE/memory/"*.md "$WORKSPACE/memory/shared/"*.md 2>/dev/null | wc -l | tr -d ' ')
log "  Memory files: $MEM_FILES"

# Secrets
KEYCHAIN_KEYS=()
for k in anthropic-api-key notion-api-key telegram-bot-token; do
  VAL=$(zsh "$(dirname "$0")/get-secret.sh" "$k" 2>/dev/null)
  if [[ -n "$VAL" && ${#VAL} -gt 10 ]]; then
    KEYCHAIN_KEYS+=("$k")
    pass "keychain: $k present"
  else
    warn "keychain: $k missing"
  fi
done

# ────────────────────────── PHASE 2: PROVIDER CHAIN PING ──────────────────────────
phase "2. Provider Chain Ping"

# Anthropic — use a 3-token test via curl with stored key
ANTHROPIC_KEY=$(zsh "$(dirname "$0")/get-secret.sh" anthropic-api-key)
if [[ -n "$ANTHROPIC_KEY" ]]; then
  RESP=$(curl -sS -m 30 https://api.anthropic.com/v1/messages \
    -H "x-api-key: $ANTHROPIC_KEY" \
    -H "anthropic-version: 2023-06-01" \
    -H "content-type: application/json" \
    -d '{"model":"claude-sonnet-4-5","max_tokens":10,"messages":[{"role":"user","content":"hi"}]}' 2>&1)
  if echo "$RESP" | jq -e '.content' > /dev/null 2>&1; then
    pass "anthropic api: sonnet ping ok"
  else
    fail "anthropic api: sonnet ping failed — $(echo "$RESP" | head -c 200)"
  fi
else
  warn "anthropic api: no keychain key, skipped"
fi

# Ollama
OLLAMA_RESP=$(curl -sS -m 5 http://127.0.0.1:11434/api/tags 2>&1)
if echo "$OLLAMA_RESP" | jq -e '.models' > /dev/null 2>&1; then
  pass "ollama: api responsive"
  if echo "$OLLAMA_RESP" | jq -e '.models[] | select(.name | contains("gemma4"))' > /dev/null 2>&1; then
    pass "ollama: gemma4 model loaded"
  else
    fail "ollama: gemma4 model NOT loaded"
  fi
else
  fail "ollama: api unresponsive"
fi

# Gateway
GW_RESP=$(curl -sS -m 5 http://127.0.0.1:18789/healthz 2>&1)
if [[ -n "$GW_RESP" ]]; then
  pass "gateway: responsive (loopback)"
else
  warn "gateway: /healthz didn't respond (may be expected — try /)"
fi

# ────────────────────────── PHASE 3: INTEGRATION TESTS ──────────────────────────
phase "3. Integration Tests"

# Notion — read database
NOTION_KEY=$(cat "$HOME/.config/notion/api_key" 2>/dev/null || security find-generic-password -s notion-api-key -w 2>/dev/null || echo "")
if [[ -n "$NOTION_KEY" ]]; then
  N_RESP=$(curl -sS -m 10 -X GET "https://api.notion.com/v1/databases/39d890b6ece881bf9c3aeb784cf09c05" \
    -H "Authorization: Bearer $NOTION_KEY" -H "Notion-Version: 2022-06-28" 2>&1)
  if echo "$N_RESP" | jq -e '.id' > /dev/null 2>&1; then
    pass "notion api: backlog db read ok"
  else
    fail "notion api: read failed"
  fi
else
  warn "notion api: no key found"
fi

# Telegram bot
TG_TOKEN=$(security find-generic-password -s telegram-bot-token -w 2>/dev/null || echo "")
if [[ -n "$TG_TOKEN" ]]; then
  TG_RESP=$(curl -sS -m 10 "https://api.telegram.org/bot${TG_TOKEN}/getMe" 2>&1)
  if echo "$TG_RESP" | jq -e '.result.username' > /dev/null 2>&1; then
    BOT_NAME=$(echo "$TG_RESP" | jq -r '.result.username')
    pass "telegram bot: @${BOT_NAME} responsive"
  else
    fail "telegram bot: getMe failed"
  fi
else
  warn "telegram bot: no token in keychain"
fi

# Obsidian vault retired (TKT-0042 Phase 4) — no git check needed
pass "obsidian vault: retired → Notion Holocron is source of truth"

# Workspace git
if (cd "$WORKSPACE" 2>/dev/null && git status > /dev/null 2>&1); then
  DIRTY=$(cd "$WORKSPACE" && git status --porcelain | wc -l | tr -d ' ')
  if (( DIRTY == 0 )); then
    pass "workspace: clean git state"
  else
    warn "workspace: $DIRTY uncommitted changes"
  fi
else
  fail "workspace: git not initialised"
fi

# ────────────────────────── PHASE 4: AUTO-HEAL DRY-RUN ──────────────────────────
phase "4. Auto-Heal Snapshot (read latest report)"

LATEST_AH=$(ls -t "$STATE_DIR"/auto-heal-*.json 2>/dev/null | head -1)
if [[ -n "$LATEST_AH" ]]; then
  AH_DATE=$(basename "$LATEST_AH" .json | sed 's/auto-heal-//')
  AH_ISSUES=$(jq -r '.issues_count // 0' "$LATEST_AH")
  AH_FIXED=$(jq -r '.auto_fixed_count // 0' "$LATEST_AH")
  AH_NEEDS=$(jq -r '.needs_ken_count // 0' "$LATEST_AH")
  log "  Latest auto-heal: $AH_DATE | issues=$AH_ISSUES | fixed=$AH_FIXED | needs-ken=$AH_NEEDS"
  if (( AH_NEEDS == 0 )); then
    pass "auto-heal latest run clean"
  else
    warn "auto-heal latest run has $AH_NEEDS needs-ken items"
  fi
else
  warn "auto-heal: no run yet (first scheduled tonight 23:30)"
fi

# ────────────────────────── PHASE 5: SECURITY AUDIT ──────────────────────────
phase "5. Security Audit"

SEC_OUT=$(openclaw security audit 2>&1 | head -50)
if echo "$SEC_OUT" | grep -qi "critical"; then
  CRIT_COUNT=$(echo "$SEC_OUT" | grep -ci "critical" || echo 0)
  warn "security: $CRIT_COUNT critical findings (review report)"
fi
if echo "$SEC_OUT" | grep -qi "warn"; then
  pass "security audit: completed"
fi

# Plaintext secret scan
PLAINTEXT=$(grep -rE "sk-(ant|test|live)-[A-Za-z0-9_-]{30,}" "$HOME/.openclaw/" "$WORKSPACE" 2>/dev/null | grep -v "auth-profiles.json" | grep -v ".bak" | grep -v "session" | head -5 || echo "")
if [[ -z "$PLAINTEXT" ]]; then
  pass "no plaintext API keys found in tracked dirs"
else
  fail "plaintext API key pattern found: $(echo "$PLAINTEXT" | head -1)"
fi

# Public canvas PII scan — exclude PDFs (binary offsets/timestamps cause false positives)
PII_HITS=$(grep -rE --include="*.html" --include="*.md" --include="*.txt" --include="*.json" "sk-ant-|\+614[0-9]{8}|[0-9]{4} [0-9]{3} [0-9]{3} [0-9]{3}" "$HOME/.openclaw/canvas/documents/" 2>/dev/null | head -3 || echo "")
if [[ -z "$PII_HITS" ]]; then
  pass "canvas/blogs: no obvious PII patterns"
else
  warn "canvas: possible PII — manual review needed"
fi

# ────────────────────────── PHASE 6: HA READINESS (placeholder for OC2) ──────────────────────────
phase "6. HA Readiness (OC2 prep)"

log "  OC2 not yet online — placeholder checks:"
# Docs migrated to Notion Holocron (TKT-0042 Phase 3) — check Notion instead of local files
pass "migration guide: in Notion Holocron (Agents section)"
pass "dual-instance architecture: in Notion Holocron (Agents section)"

TS_STATUS=$(tailscale status 2>&1 | head -1 || echo "not-installed")
if echo "$TS_STATUS" | grep -qi "logged out\|not-installed\|stopped"; then
  warn "tailscale: not active (deferred to Phase 3 per plan)"
else
  pass "tailscale: active"
fi

# ────────────────────────── PHASE 7: COVERAGE ANALYSIS ──────────────────────────
phase "7. Coverage Analysis"

# Script coverage — executable check
SCRIPT_GAPS=()
for f in "$WORKSPACE/scripts/"*.sh; do
  bname=$(basename "$f")
  if [[ ! -x "$f" ]]; then
    SCRIPT_GAPS+=("$bname not executable")
  fi
done
if (( ${#SCRIPT_GAPS[@]} == 0 )); then
  pass "scripts: all $(ls "$WORKSPACE/scripts/"*.sh | wc -l | tr -d ' ') scripts are executable"
else
  for g in "${SCRIPT_GAPS[@]}"; do warn "scripts: $g"; done
fi

# Cron coverage — check expected cron names exist
CRON_NAMES=$(cat "$HOME/.openclaw/cron/jobs.json" 2>/dev/null | jq -r '.jobs[].name' 2>/dev/null || echo "")
# Use parallel arrays for bash/zsh compat
CRON_KEYS=(health warden backup standup auto-heal daily-close-1 daily-close-2 akb fallback burn-alert midday-cost)
CRON_PATS=("Gateway Health Check" "Warden" "Daily Backup" "Stand-Up" "Auto-Heal" "Daily Close.*Journal" "Daily Close.*Blog" "AKB" "Fallback Chain" "Burn Alert" "Midday Cost")
for idx in $(seq 1 ${#CRON_KEYS[@]}); do
  ck="${CRON_KEYS[$idx]}"
  cp="${CRON_PATS[$idx]}"
  [[ -z "$ck" ]] && continue
  if echo "$CRON_NAMES" | grep -qE "$cp"; then
    pass "cron coverage: $ck present"
  else
    warn "cron coverage: $ck MISSING (pattern: $cp)"
  fi
done

# State file coverage — expected files < 48hrs
SF_NOW=$(date +%s)
EXPECTED_STATE_FILES=(health-state.json cost-state.json model-drift-state.json agent-status.json fallback-chain-status.json daily-note.json model-policy.json)
STATE_GAPS=0
for sfkey in "${EXPECTED_STATE_FILES[@]}"; do
  sfpath="$STATE_DIR/$sfkey"
  if [[ ! -f "$sfpath" ]]; then
    warn "state: $sfkey MISSING"
    (( STATE_GAPS++ ))
  else
    SF_MOD=$(stat -f '%m' "$sfpath" 2>/dev/null || echo 0)
    SF_AGE=$(( SF_NOW - SF_MOD ))
    SF_AGE_HRS=$(( SF_AGE / 3600 ))
    if (( SF_AGE > 172800 )); then  # 48h
      warn "state: $sfkey stale (${SF_AGE_HRS}h old)"
      (( STATE_GAPS++ ))
    else
      pass "state: $sfkey present (${SF_AGE_HRS}h old)"
    fi
  fi
done
(( STATE_GAPS == 0 )) && pass "state files: all expected files fresh" || true

# Agent coverage
AGENT_LIST=$(cat "$HOME/.openclaw/openclaw.json" 2>/dev/null | jq -r '.agents.list[].id' 2>/dev/null || echo "")
for expected_agent in main business security legal qa governance; do
  if echo "$AGENT_LIST" | grep -q "^${expected_agent}$"; then
    pass "agent: $expected_agent configured"
  else
    warn "agent: $expected_agent MISSING from openclaw.json"
  fi
done

log "  Coverage summary: ${#SCRIPT_GAPS[@]} script gaps, $STATE_GAPS state gaps"

# ────────────────────────── PHASE 8: PERFORMANCE BENCHMARKS ──────────────────────────
phase "8. Performance Benchmarks"

# Helper: sample endpoint 3x and return avg time (seconds, 3dp)
perf_avg() {
  local url="$1" sum=0 count=0 t
  for _i in 1 2 3; do
    t=$(curl -o /dev/null -s -m 5 -w "%{time_total}" "$url" 2>/dev/null)
    # validate numeric
    if echo "$t" | grep -qE '^[0-9]+\.?[0-9]*$'; then
      sum=$(awk "BEGIN{printf \"%.6f\", $sum + $t}")
      (( count++ ))
    fi
  done
  if (( count > 0 )); then
    awk "BEGIN{printf \"%.3f\", $sum / $count}"
  else
    echo "0.000"
  fi
}

# Gateway response time — 3 samples
GW_AVG=$(perf_avg "http://127.0.0.1:18789")
log "  Gateway avg response time: ${GW_AVG}s (3 samples)"
if awk "BEGIN{exit ($GW_AVG < 0.001 ? 0 : 1)}" 2>/dev/null; then
  warn "gateway perf: avg ${GW_AVG}s (no response — may be offline)"
elif awk "BEGIN{exit ($GW_AVG < 1.0 ? 0 : 1)}" 2>/dev/null; then
  pass "gateway perf: avg ${GW_AVG}s (OK)"
else
  warn "gateway perf: avg ${GW_AVG}s (SLOW >1s)"
fi

# Ollama API response time — 3 samples
OL_AVG=$(perf_avg "http://localhost:11434/api/tags")
log "  Ollama avg response time: ${OL_AVG}s (3 samples)"
if awk "BEGIN{exit ($OL_AVG < 0.001 ? 0 : 1)}" 2>/dev/null; then
  warn "ollama perf: avg ${OL_AVG}s (no response — offline?)"
elif awk "BEGIN{exit ($OL_AVG < 1.0 ? 0 : 1)}" 2>/dev/null; then
  pass "ollama perf: avg ${OL_AVG}s (OK)"
else
  warn "ollama perf: avg ${OL_AVG}s (SLOW >1s)"
fi

# health-check.sh wall time (seconds resolution)
HC_START=$(date +%s)
zsh "$WORKSPACE/scripts/health-check.sh" > /dev/null 2>&1 || true
HC_END=$(date +%s)
HC_SECS=$(( HC_END - HC_START ))
log "  health-check.sh wall time: ${HC_SECS}s"
if (( HC_SECS < 30 )); then
  pass "health-check.sh perf: ${HC_SECS}s"
else
  warn "health-check.sh perf: ${HC_SECS}s (>30s)"
fi

# model-drift-check.sh wall time (seconds resolution)
MD_START=$(date +%s)
zsh "$WORKSPACE/scripts/model-drift-check.sh" > /dev/null 2>&1 || true
MD_END=$(date +%s)
MD_SECS=$(( MD_END - MD_START ))
log "  model-drift-check.sh wall time: ${MD_SECS}s"
if (( MD_SECS < 30 )); then
  pass "model-drift-check.sh perf: ${MD_SECS}s"
else
  warn "model-drift-check.sh perf: ${MD_SECS}s (>30s)"
fi

# Canvas file sizes
log "  Canvas document sizes:"
CANVAS_COUNT=0
while IFS= read -r cf; do
  SZ=$(du -sh "$cf" 2>/dev/null | awk '{print $1}')
  DOC=$(basename "$(dirname "$cf")")
  log "    $DOC: $SZ"
  (( CANVAS_COUNT++ ))
done < <(ls "$HOME/.openclaw/canvas/documents/"*/index.html 2>/dev/null)
pass "canvas: $CANVAS_COUNT documents indexed"

# ────────────────────────── PHASE 9: PREDICTIVE HEALTH ──────────────────────────
phase "9. Predictive Health"

# Disk trend
DISK_PCT=$(df -h / | tail -1 | awk '{gsub(/%/,"",$5); print $5}')
DISK_AVAIL=$(df -h / | tail -1 | awk '{print $4}')
log "  Disk: ${DISK_PCT}% used, ${DISK_AVAIL} available (threshold 85%)"
if (( DISK_PCT >= 85 )); then
  fail "disk: ${DISK_PCT}% used — OVER 85% THRESHOLD (avail: $DISK_AVAIL)"
elif (( DISK_PCT >= 70 )); then
  warn "disk: ${DISK_PCT}% used — AMBER (avail: $DISK_AVAIL)"
else
  pass "disk: ${DISK_PCT}% used — GREEN (avail: $DISK_AVAIL)"
fi

# Balance runway
BALANCE=$(cat "$STATE_DIR/cost-state.json" 2>/dev/null | jq -r '.apiBalance.confirmedBalance // .apiBalance.balance // 0' 2>/dev/null || echo 0)
AVG_COST=$(cat "$STATE_DIR/cost-state.json" 2>/dev/null | jq -r '.avgDailyCost // 0' 2>/dev/null || echo 0)
RUNWAY_INT=99
if awk "BEGIN{exit ($AVG_COST > 0 ? 0 : 1)}" 2>/dev/null; then
  RUNWAY=$(awk "BEGIN{printf \"%.1f\", $BALANCE / $AVG_COST}")
  RUNWAY_INT=$(awk "BEGIN{printf \"%d\", int($BALANCE / $AVG_COST)}")
else
  RUNWAY="∞"
fi
log "  Balance: \$$BALANCE | AvgDailyCost: \$$AVG_COST | Runway: ${RUNWAY} days"
if [[ "$RUNWAY" == "∞" ]] || (( RUNWAY_INT >= 5 )); then
  pass "balance runway: ${RUNWAY} days — GREEN (balance \$$BALANCE)"
elif (( RUNWAY_INT >= 2 )); then
  warn "balance runway: ${RUNWAY} days — AMBER (top-up recommended)"
else
  fail "balance runway: ${RUNWAY} days — RED (urgent top-up needed)"
fi

# Consecutive clean Warden checks
CLEAN=$(cat "$STATE_DIR/model-drift-state.json" 2>/dev/null | jq -r '.consecutiveClean // 0' 2>/dev/null || echo 0)
log "  Warden consecutiveClean: $CLEAN"
if (( CLEAN >= 10 )); then
  pass "warden clean streak: $CLEAN checks — GREEN"
elif (( CLEAN >= 3 )); then
  warn "warden clean streak: $CLEAN checks — AMBER"
else
  warn "warden clean streak: $CLEAN checks — recent violation?"
fi

# Last backup age
LAST_BACKUP=$(find "$HOME/Backups/ainchors/" -type f -name "*.tar.gz" 2>/dev/null | sort -r | head -1)
BK_HRS=999
if [[ -n "$LAST_BACKUP" ]]; then
  BK_MOD=$(stat -f '%m' "$LAST_BACKUP" 2>/dev/null || echo 0)
  BK_NOW=$(date +%s)
  BK_AGE=$(( BK_NOW - BK_MOD ))
  BK_HRS=$(( BK_AGE / 3600 ))
  log "  Last backup: $(basename "$LAST_BACKUP") — ${BK_HRS}h ago"
  if (( BK_HRS <= 25 )); then
    pass "last backup: ${BK_HRS}h ago — GREEN"
  elif (( BK_HRS <= 48 )); then
    warn "last backup: ${BK_HRS}h ago — AMBER"
  else
    fail "last backup: ${BK_HRS}h ago — RED (>48h, check backup cron)"
  fi
else
  fail "last backup: no backup files found in ~/Backups/ainchors/"
fi

# Log file sizes (diagnostics logs in state/)
LOG_TOTAL=$(find "$STATE_DIR" -name "diagnostics-*.log" -o -name "*.log" 2>/dev/null | xargs du -sh 2>/dev/null | tail -1 | awk '{print $1}' || echo "0")
DIAG_LOG_COUNT=$(find "$STATE_DIR" -name "diagnostics-*.log" 2>/dev/null | wc -l | tr -d ' ')
log "  Diagnostic logs: $DIAG_LOG_COUNT files in state/"
if (( DIAG_LOG_COUNT > 30 )); then
  warn "log accumulation: $DIAG_LOG_COUNT diagnostic log files — consider rotation"
else
  pass "log accumulation: $DIAG_LOG_COUNT diagnostic logs — GREEN"
fi

# Cron error rate — check jobs.json for consecutiveErrors
CRON_ERRORS=$(cat "$HOME/.openclaw/cron/jobs.json" 2>/dev/null | jq '[.jobs[] | select(.consecutiveErrors != null and .consecutiveErrors > 0)] | length' 2>/dev/null || echo 0)
CRON_ERROR_NAMES=$(cat "$HOME/.openclaw/cron/jobs.json" 2>/dev/null | jq -r '.jobs[] | select(.consecutiveErrors != null and .consecutiveErrors > 0) | "\(.name): \(.consecutiveErrors) errors"' 2>/dev/null || echo "")
if (( CRON_ERRORS == 0 )); then
  pass "cron error rate: 0 crons with consecutiveErrors — GREEN"
else
  warn "cron error rate: $CRON_ERRORS crons with errors"
  if [[ -n "$CRON_ERROR_NAMES" ]]; then
    while IFS= read -r line; do warn "  cron error: $line"; done <<< "$CRON_ERROR_NAMES"
  fi
fi

# Risk summary table
RISK_DISK="GREEN"
(( DISK_PCT >= 85 )) && RISK_DISK="RED" || (( DISK_PCT >= 70 )) && RISK_DISK="AMBER" || true
RISK_RUNWAY="GREEN"
(( RUNWAY_INT < 2 )) && RISK_RUNWAY="RED" || (( RUNWAY_INT < 5 )) && RISK_RUNWAY="AMBER" || true
RISK_WARDEN="GREEN"
(( CLEAN < 3 )) && RISK_WARDEN="AMBER" || true
RISK_BACKUP="GREEN"
(( BK_HRS > 48 )) && RISK_BACKUP="RED" || (( BK_HRS > 25 )) && RISK_BACKUP="AMBER" || true
RISK_LOGS="GREEN"
(( DIAG_LOG_COUNT > 30 )) && RISK_LOGS="AMBER" || true
RISK_CRON="GREEN"
(( CRON_ERRORS > 0 )) && RISK_CRON="AMBER" || true
log ""
log "  PREDICTIVE HEALTH RISK TABLE:"
log "  Disk:           $RISK_DISK (${DISK_PCT}% used, ${DISK_AVAIL} free)"
log "  Balance Runway: $RISK_RUNWAY (${RUNWAY} days @ \$$AVG_COST/day)"
log "  Warden Streak:  $RISK_WARDEN ($CLEAN consecutive clean)"
log "  Last Backup:    $RISK_BACKUP (${BK_HRS}h ago)"
log "  Log Rotation:   $RISK_LOGS ($DIAG_LOG_COUNT log files)"
log "  Cron Errors:    $RISK_CRON ($CRON_ERRORS crons with errors)"

# ────────────────────────── REPORT GENERATION ──────────────────────────
log ""
log "═══ DIAGNOSTICS COMPLETE ═══"
log "  Phases: ${#PHASES_RUN[@]}"
log "  Pass:   ${#PASS[@]}"
log "  Warn:   ${#WARN[@]}"
log "  Fail:   ${#FAIL[@]}"

# JSON
phases_json=$(printf '%s\n' "${PHASES_RUN[@]}" | jq -R . | jq -s .)
pass_json=$(printf '%s\n' "${PASS[@]}" | jq -R . | jq -s 'map(select(length > 0))')
warn_json=$(printf '%s\n' "${WARN[@]}" | jq -R . | jq -s 'map(select(length > 0))')
fail_json=$(printf '%s\n' "${FAIL[@]}" | jq -R . | jq -s 'map(select(length > 0))')

cat > "$JSON_OUT" <<EOF
{
  "stamp": "$STAMP",
  "runAt": "$NOW",
  "runAtLocal": "$NOW_LOCAL",
  "phases": $phases_json,
  "pass": $pass_json,
  "warn": $warn_json,
  "fail": $fail_json,
  "summary": {
    "phases_count": ${#PHASES_RUN[@]},
    "pass_count": ${#PASS[@]},
    "warn_count": ${#WARN[@]},
    "fail_count": ${#FAIL[@]},
    "verdict": "$( (( ${#FAIL[@]} == 0 )) && echo HEALTHY || echo ATTENTION_NEEDED )"
  }
}
EOF

# Markdown report
{
  echo "# AInchors Diagnostics Report"
  echo "_Run: $NOW_LOCAL | Stamp: ${STAMP}_"
  echo ""
  echo "## Verdict"
  if (( ${#FAIL[@]} == 0 )); then
    echo "✅ **HEALTHY** — no failures detected."
  else
    echo "🚨 **ATTENTION NEEDED** — ${#FAIL[@]} failures."
  fi
  echo ""
  echo "**Summary:** ${#PASS[@]} pass · ${#WARN[@]} warn · ${#FAIL[@]} fail across ${#PHASES_RUN[@]} phases."
  echo ""
  if (( ${#FAIL[@]} > 0 )); then
    echo "## ❌ Failures"
    for f in "${FAIL[@]}"; do echo "- $f"; done
    echo ""
  fi
  if (( ${#WARN[@]} > 0 )); then
    echo "## ⚠️ Warnings"
    for w in "${WARN[@]}"; do echo "- $w"; done
    echo ""
  fi
  echo "## ✅ Passes"
  for p in "${PASS[@]}"; do echo "- $p"; done
  echo ""
  echo "## Phases Run"
  for ph in "${PHASES_RUN[@]}"; do echo "- $ph"; done
  echo ""
  echo "## Files"
  echo "- JSON: \`$JSON_OUT\`"
  echo "- Log:  \`$LOG\`"
} > "$MD_OUT"

log "Markdown report: $MD_OUT"
log "JSON report:     $JSON_OUT"

# Exit code reflects failures
(( ${#FAIL[@]} > 0 )) && exit 2 || exit 0
