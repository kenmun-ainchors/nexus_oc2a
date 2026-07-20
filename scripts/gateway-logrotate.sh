#!/bin/sh
# gateway-logrotate.sh — User-level log rotation for OpenClaw gateway logs
# CHG-0941 — OpenClaw gateway LaunchAgent lifecycle hardening
#
# Rotates gateway.log, gateway.err.log, and gateway-watchdog.log when they
# exceed a size threshold. Safe to run repeatedly (idempotent). Designed to
# run alongside the watchdog cron (no separate cron needed).
#
# Policy (kept in sync with config/newsyslog-openclaw.conf):
#   - gateway.log / gateway.err.log : keep 5 generations, rotate at 10MB, gzip
#   - gateway-watchdog.log          : keep 3 generations, rotate at 2MB, gzip
#
# Usage:
#   gateway-logrotate.sh                # rotate anything over threshold
#   gateway-logrotate.sh --force        # rotate everything regardless
#   gateway-logrotate.sh --status       # show sizes + last rotation
#
# Exit codes: 0 success, 1 minor error (e.g. file missing)

set -eu

LOG_DIR="$HOME/Library/Logs/openclaw"
WD_LOG="$HOME/.openclaw/logs/gateway-watchdog.log"

# Per-file: name, max_bytes, keep
rotate_one() {
    file="$1"
    max_bytes="$2"
    keep="$3"

    if [ ! -f "$file" ]; then
        return 0
    fi

    size=$(stat -f %z "$file" 2>/dev/null || echo 0)
    force="$FORCE_ROTATE"

    if [ "$force" != "1" ] && [ "$size" -lt "$max_bytes" ]; then
        return 0
    fi

    # Drop the oldest
    if [ -f "${file}.${keep}.gz" ]; then
        rm -f "${file}.${keep}.gz"
    fi
    # Shift generations
    i=$((keep - 1))
    while [ "$i" -ge 1 ]; do
        if [ -f "${file}.$i.gz" ]; then
            mv "${file}.$i.gz" "${file}.$((i + 1)).gz"
        fi
        i=$((i - 1))
    done
    # Compress current as .1.gz, then truncate the original
    if [ "$size" -gt 0 ]; then
        gzip -c "$file" > "${file}.1.gz"
    fi
    # Truncate in place (preserve file handle if held by launchd)
    : > "$file"
    chmod 600 "$file"
    printf "[%s] gateway-logrotate: rotated %s (was %d bytes, keep=%d)\n" \
        "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$file" "$size" "$keep"
}

FORCE_ROTATE=0
if [ "${1:-}" = "--force" ]; then FORCE_ROTATE=1; fi
if [ "${1:-}" = "--status" ]; then
    echo "=== gateway.log sizes ==="
    ls -la "$LOG_DIR"/gateway.log* 2>/dev/null || echo "no gateway.log"
    echo "=== gateway-watchdog.log sizes ==="
    ls -la "$WD_LOG"* 2>/dev/null || echo "no watchdog log"
    exit 0
fi

# Defaults: 10MB = 10485760 ; 2MB = 2097152
rotate_one "$LOG_DIR/gateway.log"     10485760 5
rotate_one "$LOG_DIR/gateway.err.log" 10485760 5
rotate_one "$WD_LOG"                  2097152 3

exit 0
