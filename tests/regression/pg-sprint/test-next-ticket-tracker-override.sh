#!/bin/bash
# test-next-ticket-tracker-override.sh — Regression test for TKT-0761
# CRESTv2-P1 tracker override in db-sprint.sh next-ticket
#
# Black-box tests at the default entrypoint only (L-170 compliant).
# Tests call only: bash scripts/db-sprint.sh next-ticket [--agent <name>]
#
# Test cases:
#   T1 — Tracker override: --agent yoda returns TKT-0721, reason=tracker-override
#   T2 — Tracker override: --agent forge returns TKT-0344 (seq 2, forge-assigned)
#   T3 — Tracker override: unfiltered returns TKT-0721, reason=tracker-override
#   T4 — Fallback: tracker absent returns TKT-0530, reason=active-sprint-ready
#   T5 — Cache parity: state/next-ticket.json matches stdout

set -euo pipefail

WORKSPACE_ROOT="${WORKSPACE_ROOT:-/Users/ainchorsoc2a/.openclaw/workspace}"
cd "$WORKSPACE_ROOT"

PASS=0
FAIL=0
ok() { echo "  ✅ $1"; PASS=$((PASS+1)); }
ko() { echo "  ❌ $1"; FAIL=$((FAIL+1)); }

TRACKER_FILE="state/crestv2-p1-tracker.json"
TRACKER_BAK="state/crestv2-p1-tracker.json.bak-tkt0761-test"
CACHE_FILE="state/next-ticket.json"

echo "=== TKT-0761: CRESTv2-P1 Tracker Override Regression ==="
echo ""

# ── Pre-flight: ensure tracker exists and is locked ──
if [[ ! -f "$TRACKER_FILE" ]]; then
  echo "  ⚠️  Tracker file not found — checking for backup..."
  if [[ -f "$TRACKER_BAK" ]]; then
    cp "$TRACKER_BAK" "$TRACKER_FILE"
    echo "  Restored from backup"
  else
    echo "  ❌ Cannot run tests without tracker file. Create state/crestv2-p1-tracker.json first."
    exit 1
  fi
fi

TRACKER_STATUS=$(jq -r '.status // ""' "$TRACKER_FILE" 2>/dev/null || echo "")
if [[ "$TRACKER_STATUS" != "locked" ]]; then
  echo "  ⚠️  Tracker status is '$TRACKER_STATUS', expected 'locked'. Tests may behave unexpectedly."
fi

# ── T1: Tracker override — yoda (lenient) ──
echo "--- T1: Tracker override with --agent yoda ---"
T1_OUTPUT=$(bash scripts/db-sprint.sh next-ticket --agent yoda 2>/dev/null)
T1_TICKET=$(echo "$T1_OUTPUT" | jq -r '.ticket // ""' 2>/dev/null || true)
T1_REASON=$(echo "$T1_OUTPUT" | jq -r '.reason // ""' 2>/dev/null || true)
if [[ "$T1_TICKET" == "TKT-0721" && "$T1_REASON" == "tracker-override" ]]; then
  ok "T1: --agent yoda → ticket=$T1_TICKET, reason=$T1_REASON"
else
  ko "T1: --agent yoda → expected ticket=TKT-0721 reason=tracker-override, got ticket=$T1_TICKET reason=$T1_REASON"
fi

# ── T2: Tracker override — forge (strict) ──
echo "--- T2: Tracker override with --agent forge ---"
T2_OUTPUT=$(bash scripts/db-sprint.sh next-ticket --agent forge 2>/dev/null)
T2_TICKET=$(echo "$T2_OUTPUT" | jq -r '.ticket // ""' 2>/dev/null || true)
T2_REASON=$(echo "$T2_OUTPUT" | jq -r '.reason // ""' 2>/dev/null || true)
# TKT-0721 has empty agent, so forge skips it. Next eligible in locked_execution_order
# is TKT-0344 (seq 2, WS-3, agent=forge, sprint=Sprint 9).
if [[ "$T2_TICKET" == "TKT-0344" && "$T2_REASON" == "tracker-override" ]]; then
  ok "T2: --agent forge → ticket=$T2_TICKET, reason=$T2_REASON"
else
  ko "T2: --agent forge → expected ticket=TKT-0344 reason=tracker-override, got ticket=$T2_TICKET reason=$T2_REASON"
fi

# ── T3: Tracker override — unfiltered ──
echo "--- T3: Tracker override without agent filter ---"
T3_OUTPUT=$(bash scripts/db-sprint.sh next-ticket 2>/dev/null)
T3_TICKET=$(echo "$T3_OUTPUT" | jq -r '.ticket // ""' 2>/dev/null || true)
T3_REASON=$(echo "$T3_OUTPUT" | jq -r '.reason // ""' 2>/dev/null || true)
if [[ "$T3_TICKET" == "TKT-0721" && "$T3_REASON" == "tracker-override" ]]; then
  ok "T3: unfiltered → ticket=$T3_TICKET, reason=$T3_REASON"
else
  ko "T3: unfiltered → expected ticket=TKT-0721 reason=tracker-override, got ticket=$T3_TICKET reason=$T3_REASON"
fi

# ── T4: Fallback — tracker absent ──
echo "--- T4: Fallback with tracker absent ---"
if [[ -f "$TRACKER_FILE" ]]; then
  mv "$TRACKER_FILE" "$TRACKER_BAK"
fi
T4_OUTPUT=$(bash scripts/db-sprint.sh next-ticket --agent yoda 2>/dev/null)
T4_TICKET=$(echo "$T4_OUTPUT" | jq -r '.ticket // ""' 2>/dev/null || true)
T4_REASON=$(echo "$T4_OUTPUT" | jq -r '.reason // ""' 2>/dev/null || true)
if [[ "$T4_TICKET" == "TKT-0530" && "$T4_REASON" == "active-sprint-ready" ]]; then
  ok "T4: tracker absent → ticket=$T4_TICKET, reason=$T4_REASON"
else
  ko "T4: tracker absent → expected ticket=TKT-0530 reason=active-sprint-ready, got ticket=$T4_TICKET reason=$T4_REASON"
fi
# Restore tracker
if [[ -f "$TRACKER_BAK" ]]; then
  mv "$TRACKER_BAK" "$TRACKER_FILE"
fi

# ── T5: Cache parity — state/next-ticket.json matches stdout ──
echo "--- T5: Cache parity ---"
# Run with tracker present to get override result
T5_OUTPUT=$(bash scripts/db-sprint.sh next-ticket --agent yoda 2>/dev/null)
T5_TICKET_STDOUT=$(echo "$T5_OUTPUT" | jq -r '.ticket // ""' 2>/dev/null || true)
T5_REASON_STDOUT=$(echo "$T5_OUTPUT" | jq -r '.reason // ""' 2>/dev/null || true)
if [[ -f "$CACHE_FILE" ]]; then
  T5_TICKET_CACHE=$(jq -r '.ticket // ""' "$CACHE_FILE" 2>/dev/null || true)
  T5_REASON_CACHE=$(jq -r '.reason // ""' "$CACHE_FILE" 2>/dev/null || true)
  if [[ "$T5_TICKET_STDOUT" == "$T5_TICKET_CACHE" && "$T5_REASON_STDOUT" == "$T5_REASON_CACHE" ]]; then
    ok "T5: cache matches stdout (ticket=$T5_TICKET_CACHE, reason=$T5_REASON_CACHE)"
  else
    ko "T5: cache mismatch — stdout: ticket=$T5_TICKET_STDOUT reason=$T5_REASON_STDOUT, cache: ticket=$T5_TICKET_CACHE reason=$T5_REASON_CACHE"
  fi
else
  ko "T5: cache file $CACHE_FILE not found"
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
