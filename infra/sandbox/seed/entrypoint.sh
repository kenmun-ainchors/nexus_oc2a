#!/usr/bin/env bash
# TKT-0135 — Nexus Sandbox Container Entrypoint
# Runs seed script first, then starts OpenClaw gateway.
#
# Order of operations:
#   1. Run seed.sh — seeds MinIO demo bucket (waits for MinIO health)
#   2. Start OpenClaw gateway in foreground

set -euo pipefail

echo "══════════════════════════════════════════════════════"
echo "  TKT-0135 Nexus Sandbox — Container Starting"
echo "  Environment: SANDBOX"
echo "  Agents: Mini Yoda + Aria"
echo "══════════════════════════════════════════════════════"

# ─── Run seed script ──────────────────────────────────────────────────────────
echo ""
echo "→ Phase 1: Seeding demo data..."
/app/seed/seed.sh
echo "→ Phase 1: Complete"

# ─── Start OpenClaw ──────────────────────────────────────────────────────────
echo ""
echo "→ Phase 2: Starting OpenClaw gateway..."
echo ""

# Execute the CMD passed to the container (openclaw gateway start --foreground)
exec "$@"
