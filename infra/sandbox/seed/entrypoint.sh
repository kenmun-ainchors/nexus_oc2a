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

# ─── Run seed script (non-fatal — mc may not be available in slim image) ──────
echo ""
echo "→ Phase 1: Seeding demo data..."
if command -v mc > /dev/null 2>&1; then
    /app/seed/seed.sh || echo "⚠ Seed script failed — continuing without demo data seed"
else
    echo "⚠ mc binary not found in image — skipping MinIO seed (bucket created by minio-init)"
fi
echo "→ Phase 1: Complete"

# ─── Start OpenClaw ──────────────────────────────────────────────────────────
echo ""
echo "→ Phase 2: Starting OpenClaw gateway..."
echo ""

# Execute the CMD passed to the container (openclaw gateway start --foreground)
exec "$@"
