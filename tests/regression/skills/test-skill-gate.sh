#!/bin/bash
# test-skill-gate.sh — Regression test for skill-gate enforcement (TKT-0535 A4/A6)

set -euo pipefail

WORKSPACE_ROOT="${WORKSPACE_ROOT:-/Users/ainchorsoc2a/.openclaw/workspace}"
cd "$WORKSPACE_ROOT"

PASS=0
FAIL=0
ok() { echo "  ✅ $1"; PASS=$((PASS+1)); }
ko() { echo "  ❌ $1"; FAIL=$((FAIL+1)); }

echo "=== TKT-0535 Skill Gate Enforcement Regression ==="

# Setup: isolate registry
TEST_REGISTRY="$WORKSPACE_ROOT/state/skill-load-registry.json"
if [[ -f "$TEST_REGISTRY" ]]; then
  cp "$TEST_REGISTRY" "$TEST_REGISTRY.bak"
fi
rm -f "$TEST_REGISTRY"

# R1 — db-ticket.sh blocked without skill-load
if ! bash scripts/db-ticket.sh read TKT-0535 >/dev/null 2>&1; then
  ok "R1: db-ticket.sh blocked without pg-sprint-backlog skill"
else
  ko "R1: db-ticket.sh allowed without skill"
fi

# R2 — db-ticket.sh passes after skill-load
if bash scripts/skill-load.sh pg-sprint-backlog >/dev/null 2>&1; then
  if bash scripts/db-ticket.sh read TKT-0535 >/dev/null 2>&1; then
    ok "R2: db-ticket.sh passes after skill-load"
  else
    ko "R2: db-ticket.sh still blocked after skill-load"
  fi
else
  ko "R2: failed to load pg-sprint-backlog skill"
fi

# R3 — changelog-append.sh blocked without skill-load
rm -f "$TEST_REGISTRY"
if ! bash scripts/changelog-append.sh --type rule --source ken-prompt --title "gate test" --trigger test --changed test --why test --verified test >/dev/null 2>&1; then
  ok "R3: changelog-append.sh blocked without changelog skill"
else
  ko "R3: changelog-append.sh allowed without skill"
fi

# R4 — changelog-append.sh passes after skill-load
if bash scripts/skill-load.sh changelog >/dev/null 2>&1; then
  if bash scripts/changelog-append.sh --type rule --source ken-prompt --title "gate test pass" --trigger "TKT-0535 regression" --changed "Verified gate passes after skill-load." --why "Regression test" --verified "Test" >/dev/null 2>&1; then
    ok "R4: changelog-append.sh passes after skill-load"
  else
    ko "R4: changelog-append.sh still blocked after skill-load"
  fi
else
  ko "R4: failed to load changelog skill"
fi

# R5 — run-pg-ticket wrapper auto-loads skill and works
rm -f "$TEST_REGISTRY"
if bash scripts/run-pg-ticket.sh db-ticket read TKT-0535 >/dev/null 2>&1; then
  ok "R5: run-pg-ticket.sh wrapper auto-loads skill and executes"
else
  ko "R5: run-pg-ticket.sh wrapper failed"
fi

# R6 — run-changelog wrapper auto-loads skill and works
rm -f "$TEST_REGISTRY"
if bash scripts/run-changelog.sh --type rule --source ken-prompt --title "wrapper test" --trigger "TKT-0535 regression" --changed "Verified run-changelog wrapper auto-loads skill." --why "Regression test" --verified "Test" >/dev/null 2>&1; then
  ok "R6: run-changelog.sh wrapper auto-loads skill and executes"
else
  ko "R6: run-changelog.sh wrapper failed"
fi

# R7 — skill-gate.sh session-aware freshness
rm -f "$TEST_REGISTRY"
bash scripts/skill-load.sh pg-sprint-backlog >/dev/null 2>&1
# Tamper with timestamp to make it stale
python3 -c "
import json
r=json.load(open('$TEST_REGISTRY'))
r['pg-sprint-backlog']['loaded_at']='2026-01-01T00:00:00Z'
json.dump(r, open('$TEST_REGISTRY','w'), indent=2)
"
if ! bash scripts/db-ticket.sh read TKT-0535 >/dev/null 2>&1; then
  ok "R7: skill-gate rejects stale load timestamp"
else
  ko "R7: skill-gate accepted stale load timestamp"
fi

# Restore registry
if [[ -f "$TEST_REGISTRY.bak" ]]; then
  mv "$TEST_REGISTRY.bak" "$TEST_REGISTRY"
else
  rm -f "$TEST_REGISTRY"
fi

echo ""
echo "=== Summary ==="
echo "Pass: $PASS | Fail: $FAIL"
if [[ "$FAIL" -eq 0 ]]; then
  echo "RESULT: ALL CHECKS PASS"
  exit 0
else
  echo "RESULT: FAIL"
  exit 1
fi
