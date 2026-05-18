#!/usr/bin/env bash
# nightly-gateway-restart.sh — Restart OpenClaw gateway (03:00 AEST daily)
# Created 2026-05-18 (CHG-0400) — script was missing, cron 20f59555 was failing silently

set -euo pipefail

echo "Restarting OpenClaw gateway..."
openclaw gateway restart 2>&1

# Wait for gateway to come back
sleep 5

# Verify
if openclaw gateway health --timeout 10000 2>/dev/null; then
    PID=$(pgrep -f "openclaw.*gateway" | head -1 || echo "unknown")
    echo "Gateway restarted successfully — PID ${PID}"
    exit 0
else
    echo "Gateway restart FAILED — health check did not respond"
    exit 1
fi
