#!/bin/zsh
# run-ci-cycle-a.sh — CI Cycle A: Batch Shadow Checks
# Runs every 6h as Forge Cycle A. Checks system health, cron health, gateway,
# disk usage, cost state staleness, and previous cycle metrics.
# Exit: 0 = all pass | 1 = any check fails

set -u
WORKSPACE="$HOME/.openclaw/workspace"
STATE_DIR="$WORKSPACE/state"
LOG="$HOME/Backups/ainchors/logs/ci-cycle-a.log"
mkdir -p "$(dirname "$LOG")"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG"
}

PASSED=0
FAILED=0
CHECKS=0
FAIL_DESCRIPTIONS=()

check() {
  local name="$1"
  local result="$2"
  CHECKS=$(( CHECKS + 1 ))
  if [ "$result" = "pass" ]; then
    PASSED=$(( PASSED + 1 ))
    log "✅ [${CHECKS}] $name — PASS"
  else
    FAILED=$(( FAILED + 1 ))
    FAIL_DESCRIPTIONS+=("$name: $3")
    log "❌ [${CHECKS}] $name — FAIL — $3"
  fi
}

# ─── Check 1: Gateway reachable ──────────────────────────────────────────────
GW_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://127.0.0.1:18789/health 2>/dev/null || echo "000")
if [ "$GW_STATUS" = "200" ]; then
  check "Gateway health" "pass" ""
else
  check "Gateway health" "fail" "HTTP $GW_STATUS (expected 200)"
fi

# ─── Check 2: Cron health (reuse existing cron-health-check.sh) ──────────────
if [ -x "$WORKSPACE/scripts/cron-health-check.sh" ]; then
  zsh "$WORKSPACE/scripts/cron-health-check.sh" > /dev/null 2>&1
  CH_EXIT=$?
  if [ $CH_EXIT -eq 0 ]; then
    check "Cron health" "pass" ""
  else
    check "Cron health" "fail" "Cron failures detected (exit $CH_EXIT)"
  fi
else
  check "Cron health" "fail" "cron-health-check.sh not found"
fi

# ─── Check 3: Disk usage ─────────────────────────────────────────────────────
DISK_PCT=$(df -h / | tail -1 | awk '{print $5}' | sed 's/%//')
if [ "$DISK_PCT" -lt 85 ]; then
  check "Disk usage" "pass" ""
else
  check "Disk usage" "fail" "Disk at ${DISK_PCT}% (threshold 85%)"
fi

# ─── Check 4: Cost state freshness ───────────────────────────────────────────
if [ -f "$STATE_DIR/cost-state.json" ]; then
  COST_AGE=$(( $(date +%s) - $(stat -f %m "$STATE_DIR/cost-state.json" 2>/dev/null || echo 0) ))
  COST_AGE_HRS=$(( COST_AGE / 3600 ))
  if [ "$COST_AGE_HRS" -lt 26 ]; then
    check "Cost state freshness" "pass" ""
  else
    check "Cost state freshness" "fail" "cost-state.json last updated ${COST_AGE_HRS}h ago (threshold 26h)"
  fi
else
  check "Cost state freshness" "fail" "cost-state.json missing"
fi

# ─── Check 5: Ollama models reachable (local) ────────────────────────────────
OLLAMA_OK=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://127.0.0.1:11434/api/tags 2>/dev/null || echo "000")
if [ "$OLLAMA_OK" = "200" ]; then
  check "Ollama local" "pass" ""
else
  check "Ollama local" "fail" "HTTP $OLLAMA_OK (expected 200)"
fi

# ─── Check 6: Previous CI Cycle A state exists and is recent ─────────────────
if [ -f "$STATE_DIR/ci-agent-state.json" ]; then
  CI_STATE_AGE=$(( $(date +%s) - $(stat -f %m "$STATE_DIR/ci-agent-state.json" 2>/dev/null || echo 0) ))
  CI_STATE_HRS=$(( CI_STATE_AGE / 3600 ))
  if [ "$CI_STATE_HRS" -lt 168 ]; then  # 7 days
    check "CI state freshness" "pass" ""
  else
    check "CI state freshness" "fail" "ci-agent-state.json last updated ${CI_STATE_HRS}h ago (threshold 168h)"
  fi
else
  check "CI state freshness" "fail" "ci-agent-state.json missing"
fi

# ─── Check 7: Backup health ──────────────────────────────────────────────────
if [ -x "$WORKSPACE/scripts/backup-health-check.sh" ]; then
  zsh "$WORKSPACE/scripts/backup-health-check.sh" > /dev/null 2>&1
  BK_EXIT=$?
  if [ $BK_EXIT -eq 0 ]; then
    check "Backup health" "pass" ""
  else
    check "Backup health" "fail" "Backup failure detected (exit $BK_EXIT)"
  fi
else
  check "Backup health" "skip" "backup-health-check.sh not found — skipping"
  CHECKS=$(( CHECKS - 1 ))
fi

# ─── Check 8: Workspace integrity (critical dirs exist) ──────────────────────
MISSING_DIRS=""
for d in "scripts" "state" "memory" "memory/agents"; do
  [ ! -d "$WORKSPACE/$d" ] && MISSING_DIRS="$MISSING_DIRS $d"
done
if [ -z "$MISSING_DIRS" ]; then
  check "Workspace integrity" "pass" ""
else
  check "Workspace integrity" "fail" "Missing dirs:$MISSING_DIRS"
fi

# ─── Summary ──────────────────────────────────────────────────────────────────
echo ""
if [ "$FAILED" -eq 0 ]; then
  echo "CI CYCLE A: PASS (${PASSED}/${CHECKS} checks)"
  exit 0
else
  FAIL_STR=$(IFS="; "; echo "${FAIL_DESCRIPTIONS[*]}")
  echo "CI CYCLE A: FAIL — ${FAIL_STR}"
  exit 1
fi
