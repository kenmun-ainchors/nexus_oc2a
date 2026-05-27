#!/bin/bash
# Sentry Daemon — keeps the TQP monitor running in the background
SENTRY_PY="/Users/ainchorsangiefpl/.openclaw/workspace/scripts/tqp-sentry.py"
LOG_OUT="/Users/ainchorsangiefpl/.openclaw/workspace/state/sentry-daemon.log"

echo "[$(date)] Starting TQP Sentry Daemon..." >> "$LOG_OUT"
# Use nohup to keep it running after session ends
nohup python3 "$SENTRY_PY" >> "$LOG_OUT" 2>&1 &
echo $! > /Users/ainchorsangiefpl/.openclaw/workspace/state/sentry.pid
echo "[$(date)] Sentry PID $! started." >> "$LOG_OUT"
