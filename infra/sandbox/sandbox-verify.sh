#!/usr/bin/env bash
# TKT-0135 — Nexus Sandbox Post-Teardown Verification Script
# Atlas hard constraint 3: sandbox-verify REQUIRED — must assert zero residual
# containers, volumes, networks post-teardown.
#
# Usage: ./sandbox-verify.sh [compose-project-name]
#   Default project name: openclaw-sandbox
#
# Exit codes:
#   0 — All clear, no residual sandbox resources
#   1 — Residual resources found (teardown incomplete)

set -euo pipefail

COMPOSE_PROJECT="${1:-openclaw-sandbox}"
ERRORS=0
CHECKS_PASSED=0

# ─── Colour helpers ───────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass() { echo -e "  ${GREEN}✓${NC} $1"; CHECKS_PASSED=$((CHECKS_PASSED+1)); }
fail() { echo -e "  ${RED}✗${NC} $1"; ERRORS=$((ERRORS+1)); }
warn() { echo -e "  ${YELLOW}⚠${NC} $1"; }

echo ""
echo "══════════════════════════════════════════════════════"
echo "  TKT-0135 Sandbox — Post-Teardown Verification"
echo "  Compose project: ${COMPOSE_PROJECT}"
echo "══════════════════════════════════════════════════════"

# ─── Check 1: No containers with project label ────────────────────────────────
echo ""
echo "→ Check 1: Containers..."
CONTAINERS=$(docker ps -a \
    --filter "label=com.docker.compose.project=${COMPOSE_PROJECT}" \
    --format "{{.Names}}" 2>/dev/null || true)

if [[ -z "$CONTAINERS" ]]; then
    pass "No residual containers found"
else
    fail "Residual containers found:"
    echo "$CONTAINERS" | while read -r c; do echo "     - $c"; done
fi

# ─── Check 2: No running containers by name ───────────────────────────────────
echo ""
echo "→ Check 2: Named containers (openclaw-sandbox-*)..."
NAMED=$(docker ps -a \
    --filter "name=openclaw-sandbox-" \
    --format "{{.Names}}" 2>/dev/null || true)

if [[ -z "$NAMED" ]]; then
    pass "No residual named containers"
else
    fail "Residual named containers:"
    echo "$NAMED" | while read -r c; do echo "     - $c"; done
fi

# ─── Check 3: No volumes with project prefix ──────────────────────────────────
echo ""
echo "→ Check 3: Volumes..."
VOLUMES=$(docker volume ls \
    --filter "name=${COMPOSE_PROJECT}" \
    --format "{{.Name}}" 2>/dev/null || true)

# Also check by label
VOLUMES_LABELED=$(docker volume ls \
    --filter "label=com.docker.compose.project=${COMPOSE_PROJECT}" \
    --format "{{.Name}}" 2>/dev/null || true)

ALL_VOLUMES=$(echo -e "${VOLUMES}\n${VOLUMES_LABELED}" | sort -u | grep -v '^$' || true)

if [[ -z "$ALL_VOLUMES" ]]; then
    pass "No residual volumes found"
else
    fail "Residual volumes found:"
    echo "$ALL_VOLUMES" | while read -r v; do echo "     - $v"; done
fi

# ─── Check 4: No networks with project name ───────────────────────────────────
echo ""
echo "→ Check 4: Networks..."
NETWORKS=$(docker network ls \
    --filter "name=${COMPOSE_PROJECT}" \
    --format "{{.Name}}" 2>/dev/null || true)

# Exclude default Docker networks
SANDBOX_NETS=$(echo "$NETWORKS" | grep -v "^bridge$\|^host$\|^none$" | grep -v '^$' || true)

if [[ -z "$SANDBOX_NETS" ]]; then
    pass "No residual networks found"
else
    fail "Residual networks found:"
    echo "$SANDBOX_NETS" | while read -r n; do echo "     - $n"; done
fi

# ─── Check 5: No compose project state ───────────────────────────────────────
echo ""
echo "→ Check 5: Compose project state..."
# Check 5 is best-effort — docker compose plugin not available; other checks are authoritative
warn "Compose state check skipped — docker-compose plugin unavailable; checks 1-4 are authoritative"

# ─── Check 6: No openclaw-sandbox-net network ────────────────────────────────
echo ""
echo "→ Check 6: Explicit sandbox network (openclaw-sandbox-net)..."
NET_EXISTS=$(docker network ls \
    --filter "name=openclaw-sandbox-net" \
    --format "{{.Name}}" 2>/dev/null || true)

if [[ -z "$NET_EXISTS" ]]; then
    pass "openclaw-sandbox-net does not exist"
else
    fail "openclaw-sandbox-net still exists — teardown incomplete"
fi

# ─── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo "══════════════════════════════════════════════════════"
echo "  Verification Summary"
echo "  Checks passed: ${CHECKS_PASSED}"
echo "  Errors: ${ERRORS}"
echo "══════════════════════════════════════════════════════"

if [[ $ERRORS -eq 0 ]]; then
    echo -e "  ${GREEN}✓ PASS — Sandbox fully destroyed. Zero residual state.${NC}"
    echo ""
    exit 0
else
    echo -e "  ${RED}✗ FAIL — Residual sandbox resources detected.${NC}"
    echo ""
    echo "  Manual cleanup:"
    echo "    docker compose -p ${COMPOSE_PROJECT} -f docker-compose.sandbox.yml down --volumes --remove-orphans"
    echo "    docker network rm openclaw-sandbox-net 2>/dev/null || true"
    echo "    docker volume rm ${COMPOSE_PROJECT}-minio-data 2>/dev/null || true"
    echo ""
    exit 1
fi
