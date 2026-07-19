#!/bin/bash
# browser-sidecar-stop.sh — TKT-1009: Graceful shutdown for browser sidecar
#
# Sends SIGTERM to the sidecar PID, waits up to 10s for clean exit, then
# escalates to SIGKILL if needed. Idempotent: no-op if sidecar not running.
#
# Usage:
#   bash scripts/browser-sidecar-stop.sh             # Graceful stop
#   bash scripts/browser-sidecar-stop.sh --force    # SIGKILL immediately
#   bash scripts/browser-sidecar-stop.sh --quiet    # Suppress non-error output
#
# Exit codes:
#   0  sidecar stopped (or was not running)
#   1  error during shutdown

set -uo pipefail

PORT="${BROWSER_SIDECAR_PORT:-18791}"
PID_FILE="$HOME/.openclaw/state/browser-sidecar.pid"
LOG_FILE="$HOME/.openclaw/logs/browser-sidecar.log"
QUIET=0
FORCE=0

for arg in "$@"; do
  case "$arg" in
    --quiet|-q) QUIET=1 ;;
    --force|-f) FORCE=1 ;;
    --help|-h)  sed -n '2,25p' "$0"; exit 0 ;;
    *) echo "browser-sidecar-stop: unknown flag: $arg" >&2; exit 1 ;;
  esac
done

mkdir -p "$(dirname "$LOG_FILE")"
log() {
  local level="$1"; shift
  if [[ "$QUIET" == "1" && "$level" != "ERROR" ]]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $*" >> "$LOG_FILE"
  else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $*" | tee -a "$LOG_FILE"
  fi
}

# Find PIDs on the port (more reliable than the stale PID file)
PIDS=$(lsof -nP -iTCP:"$PORT" -sTCP:LISTEN -t 2>/dev/null || true)

if [[ -z "$PIDS" ]]; then
  log INFO "sidecar not running on $PORT — nothing to stop"
  rm -f "$PID_FILE"
  exit 0
fi

for PID in $PIDS; do
  if [[ "$FORCE" == "1" ]]; then
    log INFO "force-stop: sending SIGKILL to pid=$PID"
    kill -9 "$PID" 2>/dev/null || true
  else
    log INFO "graceful stop: sending SIGTERM to pid=$PID"
    kill "$PID" 2>/dev/null || true
    # Wait up to 10s for clean exit
    for i in 1 2 3 4 5 6 7 8 9 10; do
      if ! kill -0 "$PID" 2>/dev/null; then
        log INFO "sidecar pid=$PID exited cleanly after ${i}s"
        break
      fi
      sleep 1
    done
    # Escalate if still alive
    if kill -0 "$PID" 2>/dev/null; then
      log ERROR "graceful stop timeout: escalating to SIGKILL pid=$PID"
      kill -9 "$PID" 2>/dev/null || true
    fi
  fi
done

rm -f "$PID_FILE"

# Verify port is free
sleep 1
if lsof -nP -iTCP:"$PORT" -sTCP:LISTEN 2>/dev/null | grep -q LISTEN; then
  log ERROR "port $PORT still listening after stop — something else is bound"
  exit 1
fi

log INFO "sidecar stopped, port $PORT free"
exit 0
