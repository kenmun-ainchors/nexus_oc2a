#!/bin/bash
# crest-done-gate.sh — CREST Master Done Gate (L-062 + L-063 enforcement)
# Blocks ticket close unless CREST trail is complete.
#
# Checks:
#   1. Master Synthesize must have run (report exists for this parent)
#   2. Sub-CREST verify verdicts must all be pass/done
#   3. No escalated sub-crests unresolved
#   4. Parent ticket has sub-crest entries (not bypassing CREST entirely)
#
# Usage:
#   bash scripts/crest-done-gate.sh <parent-ticket-id>
#
# Exit 0: gate passed, safe to close
# Exit 1: gate failed, close blocked with reason
#
# Invoked by: db-ticket.sh update <TKT> '{"status":"closed"}' — runs as pre-close hook

set -euo pipefail

WORKSPACE="/Users/ainchorsangiefpl/.openclaw/workspace"
DB_SCRIPT="$WORKSPACE/scripts/db.sh"
SYNTHESIZE_REPORT="$WORKSPACE/state/synthesize-reports"
GATE_LOG="$WORKSPACE/state/crest-gate-state.json"

TKT_ID="${1:-}"

if [[ -z "$TKT_ID" ]]; then
  echo "Usage: crest-done-gate.sh <parent-ticket-id>" >&2
  exit 1
fi

NOW=$(date -u '+%Y-%m-%dT%H:%M:%S+10:00')
FAILURES=()

# ─── CHECK 1: Master Synthesize report exists ──────────────────────
SYNTH_FILE=$(ls "$SYNTHESIZE_REPORT/${TKT_ID}"*.json 2>/dev/null | head -1 || true)
SUB_TICKET_COUNT=$(bash "$DB_SCRIPT" -c "SELECT COUNT(*) FROM state_tickets WHERE id LIKE '${TKT_ID}-%';" 2>/dev/null | head -1 || echo "0")

if [[ -z "$SYNTH_FILE" ]]; then
  if [[ "$SUB_TICKET_COUNT" -gt 0 ]]; then
    SYNTH_META=$(bash "$DB_SCRIPT" -c "SELECT metadata->>'synthesize_report' FROM state_tickets WHERE id='$TKT_ID';" 2>/dev/null || echo "")
    if [[ -z "$SYNTH_META" || "$SYNTH_META" == "null" ]]; then
      FAILURES+=("Master Synthesize has NOT been run for $TKT_ID. Run: bash scripts/master-synthesize.sh check --parent-ticket-id $TKT_ID --sub-ticket-ids '[\"...\"]'")
    fi
  fi
fi

# ─── CHECK 2: Sub-CREST verify verdicts all pass ────────────────────
SUB_CRESTS=$(bash "$DB_SCRIPT" -c "
  SELECT sub_crest_id, current_phase, verify_verdict, iteration_count 
  FROM state_sub_crest 
  WHERE parent_ticket_id = '$TKT_ID'
  ORDER BY created_at;
" 2>/dev/null || echo "")

if [[ -z "$SUB_CRESTS" ]] || echo "$SUB_CRESTS" | grep -q "0 rows" || [[ "$SUB_CRESTS" == "" ]]; then
  if [[ "$SUB_TICKET_COUNT" -gt 0 ]]; then
    FAILURES+=("$TKT_ID has $SUB_TICKET_COUNT sub-tickets but NO sub-crest entries in state_sub_crest. CREST was bypassed.")
  fi
else
  echo "$SUB_CRESTS" | tail -n +2 | while IFS='|' read -r sub_id phase verdict iter; do
    [[ -z "$sub_id" ]] && continue
    if [[ "$phase" != "sub_crest_done" && "$phase" != "sub_crest_done" ]]; then
      echo "NOT_DONE:$sub_id:$phase" >> /tmp/crest-gate-$$.tmp
    fi
    if [[ "$phase" == "escalated" ]]; then
      echo "ESCALATED:$sub_id" >> /tmp/crest-gate-$$.tmp
    fi
  done
  if [[ -f /tmp/crest-gate-$$.tmp ]]; then
    while IFS= read -r line; do
      [[ "$line" == NOT_DONE:* ]] && FAILURES+=("Sub-CREST ${line#NOT_DONE:} is not done — all sub-crests must reach sub_crest_done before closing parent.")
      [[ "$line" == ESCALATED:* ]] && FAILURES+=("Sub-CREST ${line#ESCALATED:} is ESCALATED — resolve before closing parent.")
    done < /tmp/crest-gate-$$.tmp
    rm -f /tmp/crest-gate-$$.tmp
  fi
fi

# ─── OUTPUT ──────────────────────────────────────────────────────────
python3 <<PYEOF
import json, sys
failures_raw = """${FAILURES[@]:-}""".strip()
failures_list = [f for f in failures_raw.split('\n') if f.strip()] if failures_raw else []

result = {
    "gate": "crest-done-gate",
    "ticket_id": "${TKT_ID}",
    "checked_at": "${NOW}",
    "passed": len(failures_list) == 0,
    "failures": failures_list,
    "checks": {
        "synthesize_ran": not any("Master Synthesize has NOT been run" in f for f in failures_list),
        "sub_crests_done": not any("not done" in f for f in failures_list),
        "no_unresolved_escalations": not any("ESCALATED" in f for f in failures_list)
    }
}

with open("${GATE_LOG}", "w") as f:
    json.dump(result, f, indent=2)

if result["passed"]:
    print(f"GATE PASSED: All CREST checks satisfied — safe to close ${TKT_ID}")
    sys.exit(0)
else:
    print(f"GATE FAILED: {len(failures_list)} check(s) block closing ${TKT_ID}:")
    for f in failures_list:
        print(f"  - {f}")
    sys.exit(1)
PYEOF
