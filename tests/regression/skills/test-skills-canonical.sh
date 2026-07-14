#!/bin/bash
# test-skills-canonical.sh — Regression test for TKT-0535
# Ensures agents load skills from agent-skills/ as SSOT
# and legacy tribal paths are neutralized.

set -euo pipefail

WORKSPACE_ROOT="${WORKSPACE_ROOT:-/Users/ainchorsoc2a/.openclaw/workspace}"
cd "$WORKSPACE_ROOT"

PASS=0
FAIL=0

ok() { echo "  ✅ $1"; PASS=$((PASS+1)); }
ko() { echo "  ❌ $1"; FAIL=$((FAIL+1)); }

echo "=== TKT-0535 Skills Canonical Loader Regression ==="

# R1 — Skill index exists and lists approved skills
if [[ -f agent-skills/.index.json ]]; then
  ok "R1: skill index exists"
else
  ko "R1: skill index missing"
fi

skill_count=$(jq '.skills | length' agent-skills/.index.json 2>/dev/null || echo 0)
if [[ "$skill_count" -ge 6 ]]; then
  ok "R1: index contains $skill_count approved skills"
else
  ko "R1: index only contains $skill_count skills"
fi

# R2 — skill-load.sh validates against index and fails closed
if bash scripts/skill-load.sh nonexistent-test-skill >/dev/null 2>&1; then
  ko "R2: skill-load.sh accepted unknown skill"
else
  ok "R2: skill-load.sh rejects unknown skill"
fi

if bash scripts/skill-load.sh agile >/dev/null 2>&1; then
  ok "R2: skill-load.sh accepts canonical agile skill"
else
  ko "R2: skill-load.sh rejected canonical agile skill"
fi

# R2 — Registry tracks canonical path
if jq -e '.agile.canonical_path == "agent-skills/agile"' state/skill-load-registry.json >/dev/null 2>&1; then
  ok "R2: registry tracks agile canonical path"
else
  ko "R2: registry missing agile canonical path"
fi

# R3 — ticket.sh deprecated
if bash scripts/ticket.sh >/dev/null 2>&1; then
  ko "R3: deprecated ticket.sh still executes without error"
else
  ok "R3: deprecated ticket.sh errors and redirects"
fi

if [[ -f scripts/ticket.sh.deprecated-TKT-0535 ]]; then
  ok "R3: legacy ticket.sh preserved for rollback"
else
  ko "R3: legacy ticket.sh backup missing"
fi

# R4 — db-ticket.sh supports --sprint-current
if bash scripts/db-ticket.sh list --sprint-current >/dev/null 2>&1; then
  ok "R4: db-ticket.sh --sprint-current executes"
else
  ko "R4: db-ticket.sh --sprint-current failed"
fi

# R4 — Skill files exist at canonical paths
for skill in agile changelog crest model-routing pg-sprint-backlog telegram; do
  if [[ -f "agent-skills/$skill/SKILL.md" ]]; then
    ok "R4: $skill SKILL.md exists at canonical path"
  else
    ko "R4: $skill SKILL.md missing at canonical path"
  fi
done

# R5 — db-ticket.sh read TKT-0535 works
if bash scripts/db-ticket.sh read TKT-0535 >/dev/null 2>&1; then
  ok "R5: TKT-0535 readable in PG"
else
  ko "R5: TKT-0535 not readable in PG"
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
