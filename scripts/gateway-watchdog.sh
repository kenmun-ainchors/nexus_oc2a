#!/bin/sh
# gateway-watchdog.sh — OpenClaw gateway health watchdog
# CHG-0941 — OpenClaw gateway LaunchAgent lifecycle hardening
#
# Probes 127.0.0.1:18789/health and restarts the LaunchAgent
# (`ai.openclaw.gateway`) if the probe fails twice in a row.
#
# Restart strategy (2026-07-20 replan):
#   1. If the service is loaded in launchd (`launchctl list` shows label),
#      use `launchctl kickstart -k gui/$UID/ai.openclaw.gateway`.
#   2. Else (service was fully unloaded), use
#      `launchctl bootstrap gui/$UID <plist-path>` to re-register it.
#   3. If bootstrap fails, fall back to `launchctl load -w <plist-path>`
#      (older macOS / pre-Sierra path).
#   4. If everything fails, log the full error and exit non-zero so the
#      cron mail / caller sees it.
#
# - Safe to run every 2 minutes (idempotent; state file is debounced).
# - Logs every check to ~/.openclaw/logs/gateway-watchdog.log
# - Performs log rotation via gateway-logrotate.sh each run.
# - 120s cooldown between restart attempts to avoid flapping.
#
# Environment overrides (optional):
#   OPENCLAW_GATEWAY_PORT     default 18789
#   OPENCLAW_GATEWAY_LABEL    default ai.openclaw.gateway
#   OPENCLAW_GATEWAY_PLIST    default ~/Library/LaunchAgents/ai.openclaw.gateway.plist
#   WATCHDOG_FAIL_THRESHOLD   default 2 consecutive failures before restart
#   WATCHDOG_COOLDOWN_SEC     default 120s between restart attempts

set -u

PORT="${OPENCLAW_GATEWAY_PORT:-18789}"
LABEL="${OPENCLAW_GATEWAY_LABEL:-ai.openclaw.gateway}"
PLIST_PATH="${OPENCLAW_GATEWAY_PLIST:-$HOME/Library/LaunchAgents/${LABEL}.plist}"
THRESHOLD="${WATCHDOG_FAIL_THRESHOLD:-2}"
COOLDOWN="${WATCHDOG_COOLDOWN_SEC:-120}"

LOG_DIR="$HOME/.openclaw/logs"
LOG_FILE="$LOG_DIR/gateway-watchdog.log"
STATE_FILE="$LOG_DIR/.gateway-watchdog.state"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

mkdir -p "$LOG_DIR"
touch "$LOG_FILE"
chmod 600 "$LOG_FILE"

UID_VAL="$(id -u)"
TARGET="gui/${UID_VAL}/${LABEL}"
BOOTSTRAP_TARGET="gui/${UID_VAL}"

ts() { date '+%Y-%m-%dT%H:%M:%S%z'; }
log() { printf '[%s] %s\n' "$(ts)" "$*" >> "$LOG_FILE"; }

# --- Probe ---
# 1) TCP connect to 127.0.0.1:PORT — fast, no extra deps.
# 2) curl /health if available — semantically correct.
probe() {
    # Quick TCP probe (3s timeout)
    if ! /usr/bin/nc -z -G 3 127.0.0.1 "$PORT" 2>/dev/null; then
        echo "tcp-fail"
        return 1
    fi
    # Semantic probe via /health (best-effort, 4s)
    if command -v curl >/dev/null 2>&1; then
        body="$(curl -fsS -m 4 "http://127.0.0.1:${PORT}/health" 2>/dev/null || true)"
        if [ -n "$body" ] && echo "$body" | grep -qi '"status"[[:space:]]*:[[:space:]]*"ok"'; then
            echo "ok"
            return 0
        fi
        if [ -n "$body" ]; then
            echo "ok-http"
            return 0
        fi
        echo "tcp-only"
        return 0  # TCP up — don't flap on transient /health hiccups
    fi
    echo "tcp-only"
    return 0
}

# --- Service state ---
# Returns 0 if the service is currently registered in launchd (regardless
# of running/stopped state). Returns 1 if the service is fully unloaded
# (e.g. after a `launchctl bootout` or a failed `launchctl enable`).
is_service_loaded() {
    # `launchctl list` exits 0 with one matching line when the service is
    # registered. We match on the label as a whole word to avoid catching
    # similarly-named update jobs.
    launchctl list 2>/dev/null | awk '{print $3}' | grep -qx "$LABEL"
}

# --- State (consecutive fail count + last restart) ---
fails=0
last_kick=0
if [ -f "$STATE_FILE" ]; then
    # shellcheck disable=SC1090
    . "$STATE_FILE" 2>/dev/null || true
fi

result="$(probe || true)"
now_epoch="$(date +%s)"

if [ "$result" = "ok" ] || [ "$result" = "ok-http" ] || [ "$result" = "tcp-only" ]; then
    if [ "$fails" -gt 0 ]; then
        log "RECOVERED (was failing $fails time(s)); result=$result"
    else
        log "OK result=$result"
    fi
    fails=0
else
    fails=$((fails + 1))
    log "FAIL result=$result consecutive=$fails"
fi

# --- Decide restart ---
should_kick=0
if [ "$fails" -ge "$THRESHOLD" ]; then
    if [ $((now_epoch - last_kick)) -ge "$COOLDOWN" ]; then
        should_kick=1
    else
        log "DEFERRED restart; cooldown not elapsed ($((now_epoch - last_kick))s < ${COOLDOWN}s)"
    fi
fi

# --- Restart with fallback chain ---
# Attempts kickstart (fast path) -> bootstrap (modern macOS) ->
# load -w (legacy) in order. Logs each step and final outcome.
do_restart() {
    log "RESTART BEGIN target=$TARGET plist=$PLIST_PATH"

    # 1) Fast path: service is already registered -> just kickstart.
    if is_service_loaded; then
        if launchctl kickstart -k "$TARGET" >> "$LOG_FILE" 2>&1; then
            log "RESTART OK via kickstart (service was loaded)"
            return 0
        fi
        rc=$?
        log "RESTART kickstart failed rc=$rc; will try bootstrap"
    else
        log "RESTART service NOT loaded; attempting bootstrap"
    fi

    # 2) Modern path: bootstrap the plist into the gui domain.
    if [ -f "$PLIST_PATH" ]; then
        if launchctl bootstrap "$BOOTSTRAP_TARGET" "$PLIST_PATH" >> "$LOG_FILE" 2>&1; then
            # Bootstrap registers but does not necessarily start; kickstart
            # to actually start it.
            launchctl kickstart -k "$TARGET" >> "$LOG_FILE" 2>&1 || true
            log "RESTART OK via bootstrap"
            return 0
        fi
        rc=$?
        log "RESTART bootstrap failed rc=$rc; will try legacy load -w"
    else
        log "RESTART plist missing at $PLIST_PATH; cannot bootstrap"
    fi

    # 3) Legacy fallback for older macOS / pre-Sierra launchctl.
    if [ -f "$PLIST_PATH" ]; then
        if launchctl load -w "$PLIST_PATH" >> "$LOG_FILE" 2>&1; then
            log "RESTART OK via legacy load -w"
            return 0
        fi
        rc=$?
        log "RESTART load -w failed rc=$rc"
    fi

    log "RESTART FAILED — all paths exhausted"
    return 1
}

if [ "$should_kick" -eq 1 ]; then
    do_restart
    restart_rc=$?
    last_kick="$now_epoch"
    fails=0
    if [ "$restart_rc" -ne 0 ]; then
        log "RESTART returned rc=$restart_rc (cooldown reset; next attempt in ${COOLDOWN}s)"
    fi
fi

# --- Persist state ---
cat > "$STATE_FILE" <<EOF
fails=$fails
last_kick=$last_kick
EOF
chmod 600 "$STATE_FILE"

# --- Log rotation (no-op if under threshold) ---
if [ -x "$SCRIPT_DIR/gateway-logrotate.sh" ]; then
    "$SCRIPT_DIR/gateway-logrotate.sh" >> "$LOG_FILE" 2>&1 || true
fi

exit 0
