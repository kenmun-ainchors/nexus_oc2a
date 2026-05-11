#!/usr/bin/env bash
# TKT-0135 — Nexus Sandbox Seed Script
# Runs at container startup to seed the MinIO demo bucket with synthetic data.
#
# Usage: ./seed.sh (called from entrypoint.sh)
# Depends on: mc (MinIO client), MINIO_ENDPOINT, MINIO_PORT, SANDBOX_MINIO_USER, SANDBOX_MINIO_PASSWORD

set -euo pipefail

MINIO_ALIAS="sandbox"
MINIO_ENDPOINT="${MINIO_ENDPOINT:-minio-sb}"
MINIO_PORT="${MINIO_PORT:-9000}"
MINIO_BUCKET="${MINIO_BUCKET:-demo}"
SEED_DATA_DIR="/app/seed/data"
MAX_WAIT=30
WAITED=0

echo "══════════════════════════════════════════════════════"
echo "  TKT-0135 Nexus Sandbox — Seed Script"
echo "  Target: minio://${MINIO_ENDPOINT}:${MINIO_PORT}/${MINIO_BUCKET}"
echo "══════════════════════════════════════════════════════"

# ─── Wait for MinIO to be ready ───────────────────────────────────────────────
echo "→ Waiting for MinIO to be ready..."
until mc alias set "${MINIO_ALIAS}" \
    "http://${MINIO_ENDPOINT}:${MINIO_PORT}" \
    "${SANDBOX_MINIO_USER}" \
    "${SANDBOX_MINIO_PASSWORD}" > /dev/null 2>&1; do
    if [[ $WAITED -ge $MAX_WAIT ]]; then
        echo "ERROR: MinIO did not become ready after ${MAX_WAIT}s. Aborting seed."
        exit 1
    fi
    sleep 1
    ((WAITED++))
    echo "  ...waiting (${WAITED}s)"
done
echo "✓ MinIO ready"

# ─── Create demo bucket ───────────────────────────────────────────────────────
echo "→ Creating demo bucket: ${MINIO_BUCKET}..."
mc mb --ignore-existing "${MINIO_ALIAS}/${MINIO_BUCKET}"
echo "✓ Bucket ready: ${MINIO_BUCKET}"

# ─── Seed demo data ───────────────────────────────────────────────────────────
echo "→ Seeding synthetic demo data..."

if [[ -d "${SEED_DATA_DIR}" ]]; then
    mc cp --recursive "${SEED_DATA_DIR}/" "${MINIO_ALIAS}/${MINIO_BUCKET}/demo-data/"
    echo "✓ Demo data seeded to ${MINIO_BUCKET}/demo-data/"
else
    echo "⚠ No seed data directory found at ${SEED_DATA_DIR} — skipping data seed"
fi

# ─── Verify seed ─────────────────────────────────────────────────────────────
echo "→ Verifying seed..."
OBJECT_COUNT=$(mc ls "${MINIO_ALIAS}/${MINIO_BUCKET}/demo-data/" 2>/dev/null | wc -l || echo "0")
echo "✓ Seed complete — ${OBJECT_COUNT} objects in demo bucket"

echo ""
echo "══════════════════════════════════════════════════════"
echo "  Seed complete — MinIO demo bucket ready"
echo "══════════════════════════════════════════════════════"
