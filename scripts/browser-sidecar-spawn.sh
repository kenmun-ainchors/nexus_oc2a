#!/bin/bash
# browser-sidecar-spawn.sh — TKT-1009: Lazy-spawn browser sidecar on port 18791
#
# Purpose: Start the browser control sidecar on first request (lazy spawn) instead of
# running it always-on. Idempotent: if 18791 is already listening, returns immediately.
# Used by browser-automation skill and any caller that needs CDP access on 18791.
#
# Algorithm:
#   1. Check if 127.0.0.1:18791 is already listening.
#        - If yes: log "already running", exit 0.
#   2. Otherwise, locate Chrome binary (or Chromium fallback).
#   3. Spawn Chrome with --remote-debugging-port=18791 --user-data-dir=<profile>
#      in the background, detached from the caller (so it survives).
#   4. Wait with health probe: poll TCP connect on 18791 until it accepts
#      a connection OR STARTUP_TIMEOUT elapses.
#   5. On success: write PID to /Users/ainchorsoc2a/.openclaw/state/browser-sidecar.pid
#      and exit 0.
#   6. On timeout: kill the spawned Chrome, log error, exit 1.
#
# Sidecar lifecycle:
#   - The spawned Chrome is long-lived. The lazy-spawn wrapper only starts it
#     once; subsequent calls return immediately.
#   - Graceful shutdown: send SIGTERM to the PID in browser-sidecar.pid and wait
#     for clean exit. Use browser-sidecar-stop.sh or kill the PID directly.
#   - No launchd dependency — the lazy-spawn design intentionally avoids an
#     always-on process. If the user wants auto-restart on crash, see the
#     optional browser-sidecar plist template.
#
# Usage:
#   bash scripts/browser-sidecar-spawn.sh                # Spawn if not running, return when ready
#   bash scripts/browser-sidecar-spawn.sh --quiet        # Suppress non-error output
#   bash scripts/browser-sidecar-spawn.sh --force        # Kill existing sidecar and respawn
#   bash scripts/browser-sidecar-spawn.sh --status       # Just report current state, exit
#
# Exit codes:
#   0  sidecar ready (already running or just spawned)
#   1  startup timeout
#   2  Chrome binary not found
#   3  user data dir creation failed
#   4  spawn failed
#   5  --status: not running
#
# CHG-0913 — TKT-1009 lazy-spawn design (Ken approved 2026-07-18 13:16 AEST)

set -uo pipefail

PORT="${BROWSER_SIDECAR_PORT:-18791}"
HOST="${BROWSER_SIDECAR_HOST:-127.0.0.1}"
PROFILE_DIR="${BROWSER_SIDECAR_PROFILE:-$HOME/.openclaw/state/browser-sidecar-profile}"
PID_FILE="$HOME/.openclaw/state/browser-sidecar.pid"
LOG_FILE="$HOME/.openclaw/logs/browser-sidecar.log"
STARTUP_TIMEOUT="${BROWSER_SIDECAR_STARTUP_TIMEOUT:-15}"
PROBE_INTERVAL="${BROWSER_SIDECAR_PROBE_INTERVAL:-0.5}"
QUIET=0
FORCE=0
STATUS_ONLY=0

mkdir -p "$(dirname "$PID_FILE")" "$(dirname "$LOG_FILE")" "$PROFILE_DIR"

for arg in "$@"; do
  case "$arg" in
    --quiet|-q) QUIET=1 ;;
    --force|-f) FORCE=1 ;;
    --status)   STATUS_ONLY=1 ;;
    --help|-h)  sed -n '2,40p' "$0"; exit 0 ;;
    *) echo "browser-sidecar-spawn: unknown flag: $arg" >&2; exit 1 ;;
  esac
done

log() {
  local level="$1"; shift
  if [[ "$QUIET" == "1" && "$level" != "ERROR" ]]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $*" >> "$LOG_FILE"
  else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $*" | tee -a "$LOG_FILE"
  fi
}

# ── Status check helper ────────────────────────────────────────────────────
is_listening() {
  lsof -nP -iTCP:"$PORT" -sTCP:LISTEN 2>/dev/null | grep -q LISTEN
}

# ── Status-only mode ───────────────────────────────────────────────────────
if [[ "$STATUS_ONLY" == "1" ]]; then
  if is_listening; then
    PID=$(lsof -nP -iTCP:"$PORT" -sTCP:LISTEN -t 2>/dev/null | head -1)
    echo "browser-sidecar: RUNNING pid=$PID port=$PORT"
    exit 0
  else
    echo "browser-sidecar: NOT RUNNING (port $PORT not listening)"
    exit 5
  fi
fi

# ── Already running? ───────────────────────────────────────────────────────
if is_listening; then
  EXISTING_PID=$(lsof -nP -iTCP:"$PORT" -sTCP:LISTEN -t 2>/dev/null | head -1)
  log INFO "sidecar already running on $PORT (pid=$EXISTING_PID) — no-op"
  exit 0
fi

# ── Force mode: kill any stale processes on the port ───────────────────────
if [[ "$FORCE" == "1" ]]; then
  STALE_PIDS=$(lsof -nP -iTCP:"$PORT" -sTCP:LISTEN -t 2>/dev/null || true)
  if [[ -n "$STALE_PIDS" ]]; then
    log INFO "--force: killing existing sidecar pid(s): $STALE_PIDS"
    kill $STALE_PIDS 2>/dev/null || true
    sleep 1
    kill -9 $STALE_PIDS 2>/dev/null || true
  fi
fi

# ── Locate Chrome binary ───────────────────────────────────────────────────
CHROME_BIN=""
for candidate in \
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
  "/Applications/Chromium.app/Contents/MacOS/Chromium" \
  "/usr/bin/google-chrome" \
  "/usr/bin/chromium" \
  "/opt/homebrew/bin/chromium"; do
  if [[ -x "$candidate" ]]; then
    CHROME_BIN="$candidate"
    break
  fi
done

if [[ -z "$CHROME_BIN" ]]; then
  log ERROR "no Chrome/Chromium binary found (checked /Applications/Google Chrome.app and common paths)"
  exit 2
fi

log INFO "sidecar not running on $PORT — lazy-spawning Chrome"
log INFO "chrome=$CHROME_BIN profile=$PROFILE_DIR port=$PORT"

# ── Ensure profile dir exists ──────────────────────────────────────────────
if ! mkdir -p "$PROFILE_DIR" 2>/dev/null; then
  log ERROR "cannot create profile dir $PROFILE_DIR"
  exit 3
fi

# ── Spawn Chrome detached ──────────────────────────────────────────────────
# We use `nohup` + `&` + `disown` so the sidecar survives the calling shell.
# --no-first-run, --no-default-browser-check, --disable-background-networking,
# --disable-component-update suppress first-run dialogs and background network.
# --remote-debugging-address=$HOST binds to localhost only (no external exposure).
nohup "$CHROME_BIN" \
  --headless=new \
  --disable-gpu \
  --no-sandbox \
  --no-first-run \
  --no-default-browser-check \
  --disable-background-networking \
  --disable-component-update \
  --disable-features=Translate,BackForwardCache \
  --user-data-dir="$PROFILE_DIR" \
  --remote-debugging-port="$PORT" \
  --remote-debugging-address="$HOST" \
  about:blank \
  >> "$LOG_FILE" 2>&1 < /dev/null &

CHROME_PID=$!
disown $CHROME_PID 2>/dev/null || true
echo $CHROME_PID > "$PID_FILE"
log INFO "spawned Chrome pid=$CHROME_PID (detached, log=$LOG_FILE)"

# ── Health probe with timeout ─────────────────────────────────────────────
elapsed=0
while (( $(echo "$elapsed < $STARTUP_TIMEOUT" | bc -l) )); do
  sleep "$PROBE_INTERVAL"
  elapsed=$(echo "$elapsed + $PROBE_INTERVAL" | bc -l)
  if is_listening; then
    # Double-check the spawned PID is alive
    if ! kill -0 "$CHROME_PID" 2>/dev/null; then
      log ERROR "spawned Chrome pid=$CHROME_PID died shortly after startup"
      rm -f "$PID_FILE"
      exit 4
    fi
    log INFO "sidecar READY on $PORT after ${elapsed}s (pid=$CHROME_PID)"
    exit 0
  fi
  # Bail early if Chrome died
  if ! kill -0 "$CHROME_PID" 2>/dev/null; then
    log ERROR "spawned Chrome pid=$CHROME_PID died before binding $PORT (see $LOG_FILE for stderr)"
    rm -f "$PID_FILE"
    exit 4
  fi
done

# ── Timeout reached ────────────────────────────────────────────────────────
log ERROR "startup timeout: $PORT not listening after ${STARTUP_TIMEOUT}s — killing pid=$CHROME_PID"
kill "$CHROME_PID" 2>/dev/null || true
sleep 1
kill -9 "$CHROME_PID" 2>/dev/null || true
rm -f "$PID_FILE"
exit 1
