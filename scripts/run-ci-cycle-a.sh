#!/usr/bin/env bash
# run-ci-cycle-a.sh — CI Cycle A (Batch Shadow, every 6h)
# Runs a suite of non-disruptive checks on the AInchors workspace.
# Exit: 0 = all pass | 1 = any fail
# Output: single "CI CYCLE A: PASS|FAIL" line with detail

set -euo pipefail

WORKSPACE="$HOME/.openclaw/workspace"
STATE_DIR="$WORKSPACE/state"
PASSED=0
FAILED=0
FAIL_REASONS=()

echo "=== CI Cycle A — $(date -u '+%Y-%m-%d %H:%M UTC') ==="

# --------------------------------------------------
# Check 1: Workspace integrity — key meta files exist
# --------------------------------------------------
echo -n "[1/8] Workspace meta files present ... "
MISSING=()
for f in "IDENTITY.md" "AGENTS.md" "RULES.md" "HEARTBEAT.md" "docs/YODA_RUNBOOK.md"; do
  [[ -f "$WORKSPACE/$f" ]] || MISSING+=("$f")
done
if [[ ${#MISSING[@]} -eq 0 ]]; then
  echo "PASS"
  ((PASSED++))
else
  echo "FAIL — missing: ${MISSING[*]}"
  ((FAILED++))
  FAIL_REASONS+=("Missing meta files: ${MISSING[*]}")
fi

# --------------------------------------------------
# Check 2: State directory exists and is writable
# --------------------------------------------------
echo -n "[2/8] State directory writable ... "
if [[ -d "$STATE_DIR" && -w "$STATE_DIR" ]]; then
  echo "PASS"
  ((PASSED++))
else
  echo "FAIL"
  ((FAILED++))
  FAIL_REASONS+=("State directory missing or not writable")
fi

# --------------------------------------------------
# Check 3: Gateway health
# --------------------------------------------------
echo -n "[3/8] Gateway health ... "
GATEWAY_UP=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:18789/health 2>/dev/null || echo "000")
if [[ "$GATEWAY_UP" == "200" ]]; then
  echo "PASS (HTTP 200)"
  ((PASSED++))
else
  echo "FAIL (HTTP $GATEWAY_UP)"
  ((FAILED++))
  FAIL_REASONS+=("Gateway unreachable (HTTP $GATEWAY_UP)")
fi

# --------------------------------------------------
# Check 4: Fallback chain validation
# --------------------------------------------------
echo -n "[4/8] Fallback chain ... "
FC_OUTPUT=$(zsh "$WORKSPACE/scripts/validate-fallback-chain.sh" 2>&1 || true)
if echo "$FC_OUTPUT" | grep -qE "all.*(links OK|ok)"; then
  echo "PASS"
  ((PASSED++))
else
  echo "FAIL"
  ((FAILED++))
  FAIL_REASONS+=("Fallback chain validation failed")
  echo "  ↳ $FC_OUTPUT" | head -5
fi

# --------------------------------------------------
# Check 5: Version drift check
# --------------------------------------------------
echo -n "[5/8] OpenClaw version drift ... "
VC_OUTPUT=$(bash "$WORKSPACE/scripts/version-check.sh" 2>&1 || true)
if echo "$VC_OUTPUT" | grep -q "OK: up to date"; then
  echo "PASS"
  ((PASSED++))
elif echo "$VC_OUTPUT" | grep -q "DRIFT:"; then
  echo "FAIL — version drift detected"
  ((FAILED++))
  FAIL_REASONS+=("OpenClaw version drift detected")
  echo "  ↳ $VC_OUTPUT" | head -5
else
  echo "WARN — couldn't determine version"
  ((PASSED++))  # non-critical
  echo "  ↳ $VC_OUTPUT" | head -5
fi

# --------------------------------------------------
# Check 6: Cron health (no consecutive failures)
# --------------------------------------------------
echo -n "[6/8] Cron health ... "
CH_OUTPUT=$(zsh "$WORKSPACE/scripts/cron-health-check.sh" 2>&1 || true)
if echo "$CH_OUTPUT" | grep -q "OK: cron health clean"; then
  echo "PASS"
  ((PASSED++))
else
  echo "FAIL — cron issues found"
  ((FAILED++))
  FAIL_REASONS+=("Cron health check reported failures")
  echo "  ↳ $CH_OUTPUT" | head -10
fi

# --------------------------------------------------
# Check 7: Disk space
# --------------------------------------------------
echo -n "[7/8] Disk space ... "
DISK_USAGE=$(df -h / | tail -1 | awk '{print $5}' | sed 's/%//')
if [[ "$DISK_USAGE" -lt 90 ]]; then
  echo "PASS (${DISK_USAGE}% used)"
  ((PASSED++))
else
  echo "FAIL (${DISK_USAGE}% used — over 90%)"
  ((FAILED++))
  FAIL_REASONS+=("Disk usage at ${DISK_USAGE}% (≥90%)")
fi

# --------------------------------------------------
# Check 8: Script directory integrity
# --------------------------------------------------
echo -n "[8/8] Script directory integrity ... "
SCRIPT_COUNT=$(ls -1 "$WORKSPACE/scripts"/*.sh 2>/dev/null | wc -l)
if [[ "$SCRIPT_COUNT" -gt 10 ]]; then
  echo "PASS ($SCRIPT_COUNT scripts)"
  ((PASSED++))
else
  echo "FAIL — only $SCRIPT_COUNT scripts found"
  ((FAILED++))
  FAIL_REASONS+=("Script count abnormally low ($SCRIPT_COUNT)")
fi

# --------------------------------------------------
# Summary
# --------------------------------------------------
echo ""
echo "=== CI Cycle A Summary ==="
echo "Passed: $PASSED/$((PASSED+FAILED)) checks"

if [[ $FAILED -eq 0 ]]; then
  echo "CI CYCLE A: PASS ($PASSED/$((PASSED+FAILED)) checks)"
  exit 0
else
  for reason in "${FAIL_REASONS[@]}"; do
    echo "  ❌ $reason"
  done
  echo "CI CYCLE A: FAIL — ${FAIL_REASONS[0]}"
  exit 1
fi
