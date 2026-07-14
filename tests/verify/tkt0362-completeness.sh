#!/bin/bash
# tests/verify/tkt0362-completeness.sh
# TKT-0362 Verifier — checks every known lesson ID exists in PG state_lessons.
# Phase A: ~15 lessons with bodies, Phase B: ~78 stub IDs.
# Idempotent; safe to re-run.

set -euo pipefail

DB_NAME="ainchors_nexus"
DB_USER="${PGUSER:-$(whoami)}"
DB_HOST="127.0.0.1"

echo "=== TKT-0362 Completeness Verification ==="

# ── Known Phase A lesson IDs (lessons with bodies) ───────────────────────
PHASE_A_IDS=(
  L-172 L-171 L-170 L-169 L-168
  L-FREEFORM-d7a33e88
  L-028 L-029 L-030 L-065 L-066
  L-106 L-107 L-108 L-140
)

# ── Verify all Phase A lessons exist ─────────────────────────────────────
echo ""
echo "--- Phase A: Lessons with bodies ---"
PASS_A=0
FAIL_A=0
MISSING_A=""
for lid in "${PHASE_A_IDS[@]}"; do
  EXISTS=$(${PSQL_BIN:-$(brew --prefix postgresql@16 2>/dev/null)/bin/psql} -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -t -A -c "SELECT 1 FROM state_lessons WHERE lesson_id = '${lid}';" 2>/dev/null)
  if [[ -z "$EXISTS" ]]; then
    echo "  MISSING Phase A: $lid"
    MISSING_A="$MISSING_A $lid"
    ((FAIL_A++)) || true
  else
    STATUS=$(${PSQL_BIN:-$(brew --prefix postgresql@16 2>/dev/null)/bin/psql} -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -t -A -c "SELECT status FROM state_lessons WHERE lesson_id = '${lid}';" 2>/dev/null)
    if [[ "$STATUS" != "active" ]]; then
      echo "  WRONG STATUS Phase A: $lid (expected 'active', got '$STATUS')"
      ((FAIL_A++)) || true
    else
      echo "  ✅ $lid (status=active)"
      ((PASS_A++)) || true
    fi
  fi
done
echo "Phase A: $PASS_A/$((PASS_A + FAIL_A)) PASS"

# ── Count Phase B stubs ──────────────────────────────────────────────────
echo ""
echo "--- Phase B: Stub rows (referenced in entity_links, no body) ---"
STUB_COUNT=$(${PSQL_BIN:-$(brew --prefix postgresql@16 2>/dev/null)/bin/psql} -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -t -A -c "SELECT count(*) FROM state_lessons WHERE status = 'stub';" 2>/dev/null)
echo "Stub rows in state_lessons: $STUB_COUNT"

# Check a sample of known stubs
SAMPLE_STUBS=("L-001" "L-050" "L-146" "L-147")
STUB_PASS=0
STUB_FAIL=0
for lid in "${SAMPLE_STUBS[@]}"; do
  EXISTS=$(${PSQL_BIN:-$(brew --prefix postgresql@16 2>/dev/null)/bin/psql} -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -t -A -c "SELECT 1 FROM state_lessons WHERE lesson_id = '${lid}';" 2>/dev/null)
  if [[ -z "$EXISTS" ]]; then
    echo "  MISSING stub: $lid"
    ((STUB_FAIL++)) || true
  else
    STATUS=$(${PSQL_BIN:-$(brew --prefix postgresql@16 2>/dev/null)/bin/psql} -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -t -A -c "SELECT status FROM state_lessons WHERE lesson_id = '${lid}';" 2>/dev/null)
    echo "  ✅ $lid (status=$STATUS)"
    ((STUB_PASS++)) || true
  fi
done
echo "Stub sample: $STUB_PASS/$((STUB_PASS + STUB_FAIL)) found"

# ── Total counts ─────────────────────────────────────────────────────────
echo ""
echo "--- Totals ---"
TOTAL_LESSONS=$(${PSQL_BIN:-$(brew --prefix postgresql@16 2>/dev/null)/bin/psql} -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -t -A -c "SELECT count(*) FROM state_lessons;" 2>/dev/null)
echo "Total rows in state_lessons: $TOTAL_LESSONS"

# Check for duplicate lesson_ids (should be none due to PK but verify)
DUPES=$(${PSQL_BIN:-$(brew --prefix postgresql@16 2>/dev/null)/bin/psql} -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -t -A -c "SELECT count(*) - count(DISTINCT lesson_id) FROM state_lessons;" 2>/dev/null)
echo "Duplicate lesson_ids: $DUPES"

# ── Verify entity_links for sample lessons ───────────────────────────────
echo ""
echo "--- Entity Links Check ---"
for lid in L-168 L-172 L-050; do
  LINK_COUNT=$(${PSQL_BIN:-$(brew --prefix postgresql@16 2>/dev/null)/bin/psql} -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -t -A -c "SELECT count(*) FROM entity_links WHERE from_type = 'lesson' AND from_id = '${lid}';" 2>/dev/null)
  echo "  $lid → $LINK_COUNT entity_links"
done

# ── Final Verdict ────────────────────────────────────────────────────────
echo ""
if [[ "$FAIL_A" -eq 0 && "$STUB_FAIL" -eq 0 && "$DUPES" -eq 0 && -n "$STUB_COUNT" && "$STUB_COUNT" -gt 50 ]]; then
  echo "Verification complete: PASS"
  echo "  Phase A: $PASS_A body lessons present"
  echo "  Phase B: $STUB_COUNT stub rows present"
  echo "  Total: $TOTAL_LESSONS rows, 0 duplicates"
  exit 0
else
  echo "Verification FAIL"
  echo "  Phase A missing: $MISSING_A"
  echo "  Stub sample fails: $STUB_FAIL"
  [[ "$DUPES" -gt 0 ]] && echo "  Duplicates: $DUPES"
  exit 1
fi
