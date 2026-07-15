#!/usr/bin/env bash
# Post-OpenClaw-upgrade shakedown for OC2A (production lead node).
# Runs read-only / safe checks and emits a JSON report.
# Exit 0 = all checks passed; 1 = one or more checks failed.

set -uo pipefail

WORKSPACE="/Users/ainchorsoc2a/.openclaw/workspace"
STATE_DIR="$WORKSPACE/state"
REPORT="$STATE_DIR/post-upgrade-shakedown-latest.json"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

mkdir -p "$STATE_DIR"

# ── helpers ───────────────────────────────────────────────────────────────

checks=()
overall_pass=true

add_check() {
  local name="$1"
  local status="$2"   # pass | fail | skip | warn
  local detail="${3:-}"
  local exit_code="${4:-0}"
  if [[ "$status" == "fail" ]]; then
    overall_pass=false
  fi
  checks+=("$(printf '{"name":"%s","status":"%s","detail":"%s","exit_code":%s}' "$name" "$status" "$detail" "$exit_code")")
}

warn_check() {
  local name="$1"
  local detail="${2:-}"
  add_check "$name" "warn" "$detail"
}

run_check() {
  local name="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    add_check "$name" "pass" "" 0
  else
    local rc=$?
    add_check "$name" "fail" "command returned $rc" "$rc"
  fi
}

# ── 1. openclaw status ────────────────────────────────────────────────────

OC_STATUS=$(openclaw status --json 2>/dev/null)
if [[ -n "$OC_STATUS" ]]; then
  OC_VERSION=$(echo "$OC_STATUS" | /usr/bin/jq -r '.runtimeVersion // "unknown"')
  add_check "openclaw-status" "pass" "runtimeVersion=$OC_VERSION"
else
  add_check "openclaw-status" "fail" "no JSON output from openclaw status"
fi

# ── 2. gateway status ─────────────────────────────────────────────────────

GW_STATUS=$(openclaw gateway status --json 2>/dev/null)
if [[ -n "$GW_STATUS" ]]; then
  GW_RUNNING=$(echo "$GW_STATUS" | /usr/bin/jq -r '.service.runtime.status // "unknown"')
  GW_PID=$(echo "$GW_STATUS" | /usr/bin/jq -r '.service.runtime.pid // "unknown"')
  GW_CONFIG_OK=$(echo "$GW_STATUS" | /usr/bin/jq -r '.service.configAudit.ok // false')
  GW_VERSION=$(echo "$GW_STATUS" | /usr/bin/jq -r '.gateway.version // "unknown"')
  if [[ "$GW_RUNNING" == "running" && "$GW_CONFIG_OK" == "true" ]]; then
    add_check "gateway-status" "pass" "pid=$GW_PID version=$GW_VERSION configAudit=ok"
  else
    add_check "gateway-status" "fail" "status=$GW_RUNNING configAudit=$GW_CONFIG_OK"
  fi
else
  add_check "gateway-status" "fail" "no JSON output from openclaw gateway status"
fi

# ── 3. openclaw doctor lint (errors only; warnings such as plaintext secrets are known) ──

DOCTOR=$(openclaw doctor --lint --severity-min error --json 2>/dev/null)
if [[ -n "$DOCTOR" ]]; then
  DOCTOR_OK=$(echo "$DOCTOR" | /usr/bin/jq -r '.ok')
  DOCTOR_FINDINGS=$(echo "$DOCTOR" | /usr/bin/jq -r '.findings | length')
  if [[ "$DOCTOR_OK" == "true" && "$DOCTOR_FINDINGS" -eq 0 ]]; then
    add_check "doctor-lint-errors" "pass" "no error-level findings"
  else
    FIRST=$(echo "$DOCTOR" | /usr/bin/jq -r '.findings[0] | "\(.checkId): \(.message)"')
    add_check "doctor-lint-errors" "fail" "$DOCTOR_FINDINGS error-level finding(s); first=$FIRST"
  fi
else
  add_check "doctor-lint-errors" "fail" "no JSON output from openclaw doctor --lint"
fi

# Surface warnings separately without failing the shakedown
DOCTOR_WARN=$(openclaw doctor --lint --json 2>/dev/null)
if [[ -n "$DOCTOR_WARN" ]]; then
  WARN_COUNT=$(echo "$DOCTOR_WARN" | /usr/bin/jq -r '[.findings[] | select(.severity == "warning")] | length')
  warn_check "doctor-warnings" "count=$WARN_COUNT (review with openclaw doctor --lint)"
fi

# ── 4. health state ─────────────────────────────────────────────────────────

if [[ -f "$STATE_DIR/health-state.json" ]]; then
  HEALTH_STATUS=$(/usr/bin/jq -r '.status // "unknown"' "$STATE_DIR/health-state.json")
  if [[ "$HEALTH_STATUS" == "ok" ]]; then
    add_check "health-state" "pass" "status=ok"
  else
    add_check "health-state" "fail" "status=$HEALTH_STATUS"
  fi
else
  add_check "health-state" "skip" "state/health-state.json not found"
fi

# ── 5. cron health ────────────────────────────────────────────────────────

if zsh "$WORKSPACE/scripts/cron-health-check.sh" >/dev/null 2>&1; then
  add_check "cron-health" "pass" ""
else
  add_check "cron-health" "fail" "cron-health-check.sh returned $?"
fi

# ── 6. delegated auth health ──────────────────────────────────────────────

if zsh "$WORKSPACE/scripts/check-delegated-auth.sh" --json >/dev/null 2>&1; then
  add_check "delegated-auth" "pass" ""
else
  add_check "delegated-auth" "fail" "check-delegated-auth.sh returned $?"
fi

# ── 7. request budget ───────────────────────────────────────────────────────

if zsh "$WORKSPACE/scripts/request-budget-check.sh" --report >/dev/null 2>&1; then
  add_check "request-budget" "pass" ""
else
  add_check "request-budget" "fail" "request-budget-check.sh returned $?"
fi

# ── 8. session model drift ──────────────────────────────────────────────────

if bash "$WORKSPACE/scripts/check-session-model.sh" --json >/dev/null 2>&1; then
  add_check "session-model" "pass" ""
else
  add_check "session-model" "fail" "check-session-model.sh returned $?"
fi

# ── 9. main-session context watchdog ────────────────────────────────────────

if bash "$WORKSPACE/scripts/main-session-context-watchdog.sh" >/dev/null 2>&1; then
  add_check "main-session-context" "pass" ""
else
  add_check "main-session-context" "fail" "main-session-context-watchdog.sh returned $?"
fi

# ── 10. agent-status.json (heartbeat agents) ────────────────────────────────

if [[ -f "$STATE_DIR/agent-status.json" ]]; then
  FAILED=$(/usr/bin/jq -r '[.agents // {} | to_entries[] | select(.value.status != "ok")] | length' "$STATE_DIR/agent-status.json")
  if [[ "$FAILED" -eq 0 ]]; then
    add_check "agent-status" "pass" "no failed agents"
  else
    add_check "agent-status" "fail" "$FAILED failed agent(s)"
  fi
else
  add_check "agent-status" "skip" "state/agent-status.json not found"
fi

# ── 11. browser automation sidecar port (on-demand; warn only) ────────────────

if (exec 3<>/dev/tcp/127.0.0.1/18791) 2>/dev/null; then
  add_check "browser-sidecar" "pass" "127.0.0.1:18791 reachable"
else
  warn_check "browser-sidecar" "127.0.0.1:18791 not reachable (sidecar is started on demand by browser automation tools)"
fi

# ── 12. Tailscale mesh reachability ────────────────────────────────────────

if ping -c 1 -W 2 100.123.95.47 >/dev/null 2>&1; then
  add_check "tailscale-ip" "pass" "100.123.95.47 reachable"
else
  add_check "tailscale-ip" "fail" "100.123.95.47 not reachable"
fi

if ping -c 1 -W 2 ainchorss-mac-mini.tailfc3ed1.ts.net >/dev/null 2>&1; then
  add_check "tailscale-oc1" "pass" "OC1 MagicDNS reachable"
else
  add_check "tailscale-oc1" "fail" "OC1 MagicDNS not reachable (dev/test standby may be offline)"
fi

# ── emit report ───────────────────────────────────────────────────────────

OVERALL_STATUS="pass"
$overall_pass || OVERALL_STATUS="fail"

/usr/bin/jq -n \
  --arg timestamp "$TIMESTAMP" \
  --arg overall "$OVERALL_STATUS" \
  --arg version "${OC_VERSION:-unknown}" \
  --argjson checks "[$(printf '%s,' "${checks[@]}" | sed 's/,$//')]" \
  '{
    timestamp: $timestamp,
    overall: $overall,
    openclawVersion: $version,
    checks: $checks
  }' > "$REPORT"

if $overall_pass; then
  echo "✅ Post-upgrade shakedown passed. Report: $REPORT"
  exit 0
else
  echo "❌ Post-upgrade shakedown failed. Report: $REPORT"
  exit 1
fi
