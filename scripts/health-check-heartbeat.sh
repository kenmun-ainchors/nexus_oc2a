#!/bin/bash
# health-check-heartbeat.sh — TKT-1010: cron-friendly entrypoint that forces heartbeat mode
#
# Purpose: Provide a stable entrypoint the 15-min "AInchors Gateway Health Check"
# cron can call, which sets HEALTH_CHECK_MODE=heartbeat before invoking
# health-check.sh. This is the cleanest way to pass the mode flag — the cron
# payload is an agentTurn (LLM-mediated) and we cannot reliably inject env
# vars through that path, but we CAN call a dedicated wrapper script.
#
# Usage (in cron or direct):
#   bash /Users/ainchorsoc2a/.openclaw/workspace/scripts/health-check-heartbeat.sh
#
# Exit codes: same as health-check.sh (0/1/2).
#
# CHG-0914 — TKT-1010 self-staleness false positive fix (Ken approved 2026-07-18 13:16 AEST)

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
export HEALTH_CHECK_MODE=heartbeat
exec bash "$SCRIPT_DIR/health-check.sh" "$@"
