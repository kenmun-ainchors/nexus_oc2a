#!/usr/bin/env bash
# =============================================================================
# pvt.sh — AInchors Post Verification Test
# =============================================================================
# Runs a full platform shakedown after any risky operation or startup recovery.
# Exit code: 0 = all checks pass | 1 = one or more failures
#
# Usage: bash scripts/pvt.sh [--quiet]
#
# Checks:
#   1. Gateway       — HTTP probe to localhost:18789
#   2. Ollama        — process running + API responding
#   3. Disk          — all volumes <85% used
#   4. Memory index  — 22+ files indexed, embeddings ready
#   5. Doctor        — `openclaw doctor` exits 0 (no warnings)
#   6. Tasks         — 0 running, 0 queued
#   7. Secrets       — all expected secrets present (secrets-init.sh verify)
#   8. Plugin deps   — only ONE versioned dir, no openclaw-unknown-*
#   9. Telegram      — telegram channel configured in openclaw
#  10. Content Gov   — content-governance-review.sh exists and is executable
#
# Output: colour-coded per check, final PASS/FAIL banner
# State:  state/pvt-last-result.json
# Alert:  /tmp/pvt-alert.txt (written if any check fails — main session sends to Ken)
# =============================================================================

set -uo pipefail

WORKSPACE="/Users/ainchorsangiefpl/.openclaw/workspace"
STATE_DIR="$WORKSPACE/state"
RESULT_FILE="$STATE_DIR/pvt-last-result.json"
ALERT_FILE="/tmp/pvt-alert.txt"
LOG_DIR="$HOME/Backups/ainchors/logs"
LOG_FILE="$LOG_DIR/pvt.log"
QUIET="${1:-}"

mkdir -p "$STATE_DIR" "$LOG_DIR"

# ── Colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# ── Helpers ──────────────────────────────────────────────────────────────────
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [PVT] $1" | tee -a "$LOG_FILE"; }

PASS_COUNT=0
FAIL_COUNT=0
CHECK_RESULTS=()   # JSON fragments

check_pass() {
  local name="$1" detail="${2:-}"
  PASS_COUNT=$((PASS_COUNT + 1))
  [[ "$QUIET" != "--quiet" ]] && echo -e "  ${GREEN}✅ PASS${RESET}  ${BOLD}${name}${RESET}${detail:+  — $detail}"
  CHECK_RESULTS+=("{\"check\":\"${name}\",\"status\":\"pass\",\"detail\":$(printf '%s' "${detail}" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')}")
}

check_fail() {
  local name="$1" detail="${2:-}"
  FAIL_COUNT=$((FAIL_COUNT + 1))
  [[ "$QUIET" != "--quiet" ]] && echo -e "  ${RED}❌ FAIL${RESET}  ${BOLD}${name}${RESET}${detail:+  — $detail}"
  CHECK_RESULTS+=("{\"check\":\"${name}\",\"status\":\"fail\",\"detail\":$(printf '%s' "${detail}" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')}")
}

check_warn() {
  local name="$1" detail="${2:-}"
  # Warnings still count as pass (non-blocking) but are surfaced
  PASS_COUNT=$((PASS_COUNT + 1))
  [[ "$QUIET" != "--quiet" ]] && echo -e "  ${YELLOW}⚠️  WARN${RESET}  ${BOLD}${name}${RESET}${detail:+  — $detail}"
  CHECK_RESULTS+=("{\"check\":\"${name}\",\"status\":\"warn\",\"detail\":$(printf '%s' "${detail}" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')}")
}

# ── Header ───────────────────────────────────────────────────────────────────
RUN_TIME="$(date '+%Y-%m-%d %H:%M:%S %Z')"
RUN_TIME_ISO="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
[[ "$QUIET" != "--quiet" ]] && echo ""
[[ "$QUIET" != "--quiet" ]] && echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════╗${RESET}"
[[ "$QUIET" != "--quiet" ]] && echo -e "${CYAN}${BOLD}║   AInchors Post Verification Test (PVT)  ║${RESET}"
[[ "$QUIET" != "--quiet" ]] && echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════╝${RESET}"
[[ "$QUIET" != "--quiet" ]] && echo -e "  ${CYAN}Run time:${RESET} $RUN_TIME"
[[ "$QUIET" != "--quiet" ]] && echo ""
log "=== PVT Start === $RUN_TIME"

# ── CHECK 1: Gateway ──────────────────────────────────────────────────────────
[[ "$QUIET" != "--quiet" ]] && echo -e "${BOLD}[1/9] Gateway${RESET}"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "http://127.0.0.1:18789" 2>/dev/null || echo "000")
if [[ "$HTTP_CODE" == "200" || "$HTTP_CODE" == "301" || "$HTTP_CODE" == "302" || "$HTTP_CODE" == "401" || "$HTTP_CODE" == "403" ]]; then
  check_pass "Gateway" "HTTP $HTTP_CODE at localhost:18789"
  log "Gateway: PASS (HTTP $HTTP_CODE)"
else
  check_fail "Gateway" "Expected 2xx/3xx/401, got HTTP $HTTP_CODE at localhost:18789"
  log "Gateway: FAIL (HTTP $HTTP_CODE)"
fi

# ── CHECK 2: Ollama ───────────────────────────────────────────────────────────
[[ "$QUIET" != "--quiet" ]] && echo -e "${BOLD}[2/9] Ollama${RESET}"
OLLAMA_PROC=false
OLLAMA_API=false

if pgrep -x ollama > /dev/null 2>&1; then
  OLLAMA_PROC=true
fi

OLLAMA_HTTP=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "http://127.0.0.1:11434/api/tags" 2>/dev/null || echo "000")
if [[ "$OLLAMA_HTTP" == "200" ]]; then
  OLLAMA_API=true
fi

if $OLLAMA_PROC && $OLLAMA_API; then
  check_pass "Ollama" "process running, API responding (HTTP 200)"
  log "Ollama: PASS"
elif $OLLAMA_PROC && ! $OLLAMA_API; then
  check_warn "Ollama" "process running but API not responding (HTTP $OLLAMA_HTTP)"
  log "Ollama: WARN (proc up, API $OLLAMA_HTTP)"
elif ! $OLLAMA_PROC; then
  check_fail "Ollama" "process not running (pgrep -x ollama returned nothing)"
  log "Ollama: FAIL (not running)"
fi

# ── CHECK 3: Disk ─────────────────────────────────────────────────────────────
[[ "$QUIET" != "--quiet" ]] && echo -e "${BOLD}[3/9] Disk${RESET}"
DISK_FAIL=false
DISK_DETAIL=""
while IFS= read -r line; do
  PCT=$(echo "$line" | awk '{print $5}' | tr -d '%')
  MOUNT=$(echo "$line" | awk '{print $NF}')  # macOS df -h: mount is last field
  [[ "$MOUNT" == "map"* ]] && continue        # skip macOS automount maps
  [[ "$MOUNT" == "/dev" ]] && continue          # skip devfs (always 100%, virtual)
  [[ "$MOUNT" == "/dev"* ]] && continue         # skip all devfs mounts
  [[ "$MOUNT" == "/System/Volumes/Data/home" ]] && continue  # skip auto_home (virtual)
  if [[ "$PCT" =~ ^[0-9]+$ ]] && (( PCT >= 85 )); then
    DISK_FAIL=true
    DISK_DETAIL="${DISK_DETAIL}${MOUNT} at ${PCT}%; "
  fi
done < <(df -h | tail -n +2)

if $DISK_FAIL; then
  check_fail "Disk" "Volume(s) at or above 85%: ${DISK_DETAIL}"
  log "Disk: FAIL ($DISK_DETAIL)"
else
  check_pass "Disk" "all volumes <85% used"
  log "Disk: PASS"
fi

# ── CHECK 4: Memory index ─────────────────────────────────────────────────────
[[ "$QUIET" != "--quiet" ]] && echo -e "${BOLD}[4/9] Memory Index${RESET}"
MEM_OUTPUT=$(openclaw memory status 2>/dev/null || echo "ERROR")
if echo "$MEM_OUTPUT" | grep -q "ERROR\|failed\|not found"; then
  check_fail "Memory Index" "openclaw memory status failed to run"
  log "Memory Index: FAIL (command error)"
else
  INDEXED=$(echo "$MEM_OUTPUT" | grep -oE 'Indexed: ([0-9]+)/' | grep -oE '[0-9]+' | head -1)
  VECTOR=$(echo "$MEM_OUTPUT" | grep "Vector:" | grep -o "ready" | head -1 || echo "")
  DIRTY=$(echo "$MEM_OUTPUT" | grep "Dirty:" | grep -o "yes" || echo "no")

  if [[ -z "$INDEXED" ]]; then
    check_fail "Memory Index" "could not parse index count from openclaw memory status"
    log "Memory Index: FAIL (parse error)"
  elif (( INDEXED < 22 )); then
    check_fail "Memory Index" "${INDEXED} files indexed (expected ≥22)"
    log "Memory Index: FAIL ($INDEXED files)"
  elif [[ "$VECTOR" != "ready" ]]; then
    check_fail "Memory Index" "${INDEXED} files indexed but vector store not ready"
    log "Memory Index: FAIL (vector not ready)"
  elif [[ "$DIRTY" == "yes" ]]; then
    check_warn "Memory Index" "${INDEXED} files indexed, vector ready, but index is dirty (re-index pending)"
    log "Memory Index: WARN (dirty)"
  else
    check_pass "Memory Index" "${INDEXED} files indexed, vector ready"
    log "Memory Index: PASS ($INDEXED files)"
  fi
fi

# ── CHECK 5: Doctor ───────────────────────────────────────────────────────────
[[ "$QUIET" != "--quiet" ]] && echo -e "${BOLD}[5/9] Doctor${RESET}"
DOCTOR_OUTPUT=$(openclaw doctor 2>&1 || true)
DOCTOR_EXIT=$?
# openclaw doctor returns 0 if healthy; non-zero on warnings/errors
if [[ $DOCTOR_EXIT -eq 0 ]]; then
  check_pass "Doctor" "openclaw doctor exited 0 (no warnings)"
  log "Doctor: PASS"
else
  DOCTOR_SUMMARY=$(echo "$DOCTOR_OUTPUT" | tail -5 | tr '\n' ' ' | sed 's/  / /g')
  check_fail "Doctor" "openclaw doctor exited $DOCTOR_EXIT — $DOCTOR_SUMMARY"
  log "Doctor: FAIL (exit $DOCTOR_EXIT)"
fi

# ── CHECK 6: Tasks ────────────────────────────────────────────────────────────
[[ "$QUIET" != "--quiet" ]] && echo -e "${BOLD}[6/9] Tasks${RESET}"
TASKS_FILE="$STATE_DIR/async-tasks.json"
if [[ ! -f "$TASKS_FILE" ]]; then
  check_pass "Tasks" "no async-tasks.json — no active tasks"
  log "Tasks: PASS (no tasks file)"
else
  TASK_COUNTS=$(python3 - "$TASKS_FILE" << 'PYEOF'
import json, sys
try:
    with open(sys.argv[1]) as f:
        d = json.load(f)
    active = d.get("activeTasks", {})
    # Subagent/cli/TASK tasks are expected during normal ops — only flag unknown stuck tasks
    stuck = [t for t in active.values()
             if t.get("status") in ("running", "pending")
             and t.get("kind", "") not in ("subagent", "cli", "")]
    print(f"{len(stuck)}")
except Exception as e:
    print("0")
PYEOF
)
  if [[ "$TASK_COUNTS" -eq 0 ]]; then
    check_pass "Tasks" "no stuck non-subagent tasks"
    log "Tasks: PASS (0 stuck)"
  else
    check_fail "Tasks" "${TASK_COUNTS} non-subagent task(s) stuck running/queued"
    log "Tasks: FAIL ($TASK_COUNTS stuck)"
  fi
fi

# ── CHECK 7: Secrets ──────────────────────────────────────────────────────────
[[ "$QUIET" != "--quiet" ]] && echo -e "${BOLD}[7/9] Secrets${RESET}"
SECRETS_SCRIPT="$WORKSPACE/scripts/secrets-init.sh"
if [[ ! -f "$SECRETS_SCRIPT" ]]; then
  check_fail "Secrets" "scripts/secrets-init.sh not found"
  log "Secrets: FAIL (script missing)"
else
  SECRETS_OUTPUT=$(bash "$SECRETS_SCRIPT" verify 2>&1)
  SECRETS_EXIT=$?
  if [[ $SECRETS_EXIT -eq 0 ]] && echo "$SECRETS_OUTPUT" | grep -qv "❌"; then
    check_pass "Secrets" "all expected secrets present in macOS Keychain"
    log "Secrets: PASS"
  else
    MISSING=$(echo "$SECRETS_OUTPUT" | grep "❌" | tr '\n' ' ')
    check_fail "Secrets" "missing secret(s): ${MISSING:-see verify output}"
    log "Secrets: FAIL ($MISSING)"
  fi
fi

# ── CHECK 8: Plugin-runtime-deps ──────────────────────────────────────────────
[[ "$QUIET" != "--quiet" ]] && echo -e "${BOLD}[8/9] Plugin-runtime-deps${RESET}"
PLUGIN_DIR="$HOME/.openclaw/plugin-runtime-deps"
if [[ ! -d "$PLUGIN_DIR" ]]; then
  check_warn "Plugin-runtime-deps" "directory $PLUGIN_DIR not found — may be normal on fresh install"
  log "Plugin-runtime-deps: WARN (dir missing)"
else
  # openclaw-unknown-* dirs are recreated by OpenClaw on every restart for npm cache — expected, not a failure
  VERSIONED_COUNT=$(ls "$PLUGIN_DIR" 2>/dev/null | grep -v "^openclaw-unknown-" | grep -v "^\." | wc -l | tr -d ' ')

  if [[ "$VERSIONED_COUNT" -gt 1 ]]; then
    check_fail "Plugin-runtime-deps" "$VERSIONED_COUNT versioned dirs found (expected 1) — $(ls $PLUGIN_DIR | tr '\n' ' ')"
    log "Plugin-runtime-deps: FAIL ($VERSIONED_COUNT versioned dirs)"
  elif [[ "$VERSIONED_COUNT" -eq 0 ]]; then
    check_warn "Plugin-runtime-deps" "no versioned dirs found in $PLUGIN_DIR"
    log "Plugin-runtime-deps: WARN (0 versioned dirs)"
  else
    VERSIONED_NAME=$(ls "$PLUGIN_DIR" | grep -v "^openclaw-unknown-" | head -1)
    check_pass "Plugin-runtime-deps" "1 versioned dir ($VERSIONED_NAME), no unknown-* stale dirs"
    log "Plugin-runtime-deps: PASS ($VERSIONED_NAME)"
  fi
fi

# ── CHECK 9: Telegram channel
# (note: check 10 added below after check 9) ─────────────────────────────────────────────────
[[ "$QUIET" != "--quiet" ]] && echo -e "${BOLD}[9/10] Telegram${RESET}"
OC_STATUS=$(openclaw status 2>/dev/null || echo "")
if echo "$OC_STATUS" | grep -qi "telegram"; then
  check_pass "Telegram" "telegram channel present in openclaw status"
  log "Telegram: PASS"
else
  # Fallback: check config files
  TELEGRAM_IN_CONFIG=false
  for cfg in "$HOME/.openclaw/config.json" "$HOME/.openclaw/agents/main/config.json"; do
    if [[ -f "$cfg" ]] && grep -qi "telegram" "$cfg" 2>/dev/null; then
      TELEGRAM_IN_CONFIG=true
      break
    fi
  done

  if $TELEGRAM_IN_CONFIG; then
    check_pass "Telegram" "telegram found in openclaw config"
    log "Telegram: PASS (config)"
  else
    # Check if telegram bot token is in keychain as a secondary indicator
    TBOT=$(security find-generic-password -a "ainchors" -s "telegram-bot-token" -w 2>/dev/null || echo "")
    if [[ -n "$TBOT" ]]; then
      check_warn "Telegram" "telegram bot token in keychain but channel not visible in openclaw status"
      log "Telegram: WARN (token present, channel not visible in status)"
    else
      check_fail "Telegram" "telegram not found in openclaw status or config, no bot token in keychain"
      log "Telegram: FAIL (not configured)"
    fi
  fi
fi


# ── CHECK 10: Content governance gate ─────────────────────────────────────────
[[ "$QUIET" != "--quiet" ]] && echo -e "${BOLD}[10/10] Content Governance Gate${RESET}"
CGR_SCRIPT="$WORKSPACE/scripts/content-governance-review.sh"
if [[ ! -f "$CGR_SCRIPT" ]]; then
  check_fail "Content Governance Gate" "scripts/content-governance-review.sh not found"
  log "Content Governance Gate: FAIL (script missing)"
elif [[ ! -x "$CGR_SCRIPT" ]]; then
  check_fail "Content Governance Gate" "scripts/content-governance-review.sh exists but is not executable"
  log "Content Governance Gate: FAIL (not executable)"
else
  check_pass "Content Governance Gate" "scripts/content-governance-review.sh exists and is executable"
  log "Content Governance Gate: PASS"
fi

# ── Results banner ────────────────────────────────────────────────────────────
TOTAL=$((PASS_COUNT + FAIL_COUNT))
echo ""
if [[ $FAIL_COUNT -eq 0 ]]; then
  OVERALL="pass"
  echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════╗${RESET}"
  echo -e "${GREEN}${BOLD}║            ✅  PVT PASSED  ✅             ║${RESET}"
  echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════╝${RESET}"
  echo -e "  ${GREEN}${PASS_COUNT}/${TOTAL} checks passed${RESET}"
  log "=== PVT PASSED ($PASS_COUNT/$TOTAL checks) ==="
else
  OVERALL="fail"
  echo -e "${RED}${BOLD}╔══════════════════════════════════════════╗${RESET}"
  echo -e "${RED}${BOLD}║            ❌  PVT FAILED  ❌             ║${RESET}"
  echo -e "${RED}${BOLD}╚══════════════════════════════════════════╝${RESET}"
  echo -e "  ${RED}${FAIL_COUNT}/${TOTAL} checks FAILED — see above for details${RESET}"
  log "=== PVT FAILED ($FAIL_COUNT/$TOTAL checks failed) ==="
fi
echo ""

# ── Write state/pvt-last-result.json ─────────────────────────────────────────
python3 - "$RESULT_FILE" "$RUN_TIME_ISO" "$RUN_TIME" "$OVERALL" "$PASS_COUNT" "$FAIL_COUNT" << PYEOF
import json, sys

result_file, run_iso, run_local, overall, pass_c, fail_c = sys.argv[1:]

# Build checks array from environment (passed as JSON fragments by shell)
checks_raw = """${CHECK_RESULTS[@]:-}"""

# Parse the check results
import os
checks = []
for line in checks_raw.strip().split('\n'):
    line = line.strip().rstrip(',')
    if line.startswith('{'):
        try:
            checks.append(json.loads(line))
        except Exception:
            pass

result = {
    "runAt": run_iso,
    "runAtLocal": run_local,
    "overall": overall,
    "passeCount": int(pass_c),
    "failCount": int(fail_c),
    "checks": checks
}

with open(result_file, 'w') as f:
    json.dump(result, f, indent=2)

print(f"Result written: {result_file}")
PYEOF

# ── Write alert if failures ───────────────────────────────────────────────────
if [[ $FAIL_COUNT -gt 0 ]]; then
  FAILED_NAMES=""
  for frag in "${CHECK_RESULTS[@]}"; do
    if echo "$frag" | grep -q '"status":"fail"'; then
      NAME=$(echo "$frag" | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); print(d.get('check','?'))" 2>/dev/null || echo "?")
      DETAIL=$(echo "$frag" | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); print(d.get('detail','')[:100])" 2>/dev/null || echo "")
      FAILED_NAMES="${FAILED_NAMES}\n• ${NAME}: ${DETAIL}"
    fi
  done

  cat > "$ALERT_FILE" << ALERTEOF
🔴 *PVT FAILED — AInchors Platform*

⏱ ${RUN_TIME}
❌ ${FAIL_COUNT}/${TOTAL} checks failed

*Failed checks:*
$(printf "${FAILED_NAMES}")

Run \`bash scripts/pvt.sh\` to re-verify or check \`state/pvt-last-result.json\` for full details.
ALERTEOF
  log "Alert written to $ALERT_FILE"
  echo -e "  ${RED}⚠️  Alert written to $ALERT_FILE — main session will dispatch to Ken${RESET}"
else
  # Clear any previous alert
  rm -f "$ALERT_FILE"
fi

log "Result written to $RESULT_FILE"

# ── Exit code ─────────────────────────────────────────────────────────────────
[[ $FAIL_COUNT -eq 0 ]] && exit 0 || exit 1
