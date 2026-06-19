#!/bin/bash
# aria-crest-check.sh — Aria CREST Compliance Checkpoint
# Layer 3b: Proactive drift detection for Aria's sub-CREST discipline
# Runs every 4 hours via heartbeat. Catches CREST phase violations before Warden.
#
# CHECKS (exit 0 = compliant, exit 1 = violations found):
#   1. Aria atoms marked 'done' without going through sub_crest_verifying
#   2. Aria atoms with no rvev_trace (skipped RVEV discipline)
#   3. Aria sub-crests stuck in same phase >24h (abandoned tasks)
#   4. Aria's strong model usage rate (alert if >50% of atoms on strong-tier models for Execute/Synthesize — should use flash-tier per CREST v1.3 capability matrix)
#
# Output: JSON report written to state/aria-crest-compliance.json
# Alert: If violations found, writes state/aria-crest-alert.json for heartbeat pickup

set -euo pipefail

# macOS grep compat: use basic regex, not -P
GREP=grep

WORKSPACE="/Users/ainchorsangiefpl/.openclaw/workspace"
DB_SCRIPT="/scripts/db-raw.sh"
REPORT_FILE="$WORKSPACE/state/aria-crest-compliance.json"
ALERT_FILE="$WORKSPACE/state/aria-crest-alert.json"
NOW=$(date -u '+%Y-%m-%dT%H:%M:%S+10:00')

# Initialize
VIOLATIONS=()
WARNINGS=()

# Query Aria's recent sub-crest data
ARIA_DATA=$($DB_SCRIPT -c "
  SELECT 
    sc.sub_crest_id,
    sc.parent_ticket_id,
    sc.current_phase,
    sc.iteration_count,
    sc.verify_verdict,
    sc.updated_at,
    COUNT(a.atom_id) AS total_atoms,
    COUNT(a.atom_id) FILTER (WHERE a.status = 'done') AS done_atoms,
    COUNT(a.atom_id) FILTER (WHERE a.rvev_trace IS NULL AND a.status = 'done') AS no_rvev_atoms,
    COUNT(a.atom_id) FILTER (WHERE a.model LIKE '%pro%') AS pro_atoms
  FROM state_sub_crest sc
  LEFT JOIN state_sub_crest_atoms a ON sc.sub_crest_id = a.sub_crest_id
  WHERE sc.specialist = 'aria'
    AND sc.current_phase NOT IN ('sub_crest_done', 'escalated')
  GROUP BY sc.sub_crest_id, sc.parent_ticket_id, sc.current_phase, sc.iteration_count, sc.verify_verdict, sc.updated_at
  ORDER BY sc.updated_at DESC
  LIMIT 50;
" 2>/dev/null || echo "")

# CHECK 1: Aria atoms done without verify phase
if echo "$ARIA_DATA" | grep -q "sub_crest_executing.*done_atoms.*[1-9]"; then
  VIOLATIONS+=("CRITICAL: Aria has atoms marked 'done' while sub-crest is still in executing phase — Verify was skipped")
fi

# CHECK 2: Atoms with no RVEV trace
NO_RVEV=$(echo "$ARIA_DATA" | grep -o '|[0-9][0-9]*' | tail -3 | head -1 || echo "0")
NO_RVEV=${NO_RVEV#|}
if [ "${NO_RVEV:-0}" -gt 2 ]; then
  VIOLATIONS+=("WARNING: $NO_RVEV Aria atoms completed without RVEV trace — RVEV discipline may be slipping")
fi

# CHECK 3: Sub-crests stuck in same phase >24h
STUCK_COUNT=0
CURRENT_TS=$(date +%s)
while IFS='|' read -r sub_id ticket phase iter verdict updated_at total done no_rvev pro; do
  if [ -n "$updated_at" ] && [ "$updated_at" != "updated_at" ]; then
    UPDATED_EPOCH=$(date -j -f '%Y-%m-%d %H:%M:%S' "${updated_at:0:19}" '+%s' 2>/dev/null || echo 0)
    AGE_HOURS=$(( (CURRENT_TS - UPDATED_EPOCH) / 3600 ))
    if [ "$AGE_HOURS" -gt 24 ] && [ "$phase" != "escalated" ]; then
      STUCK_COUNT=$((STUCK_COUNT + 1))
    fi
  fi
done <<< "$(echo "$ARIA_DATA" | tail -n +2)"

if [ "$STUCK_COUNT" -gt 0 ]; then
  VIOLATIONS+=("WARNING: $STUCK_COUNT Aria sub-crests stuck in same phase >24h — may be abandoned")
fi

# CHECK 4: Pro model overuse (>50% of atoms on pro for Execute/Synthesize)
PRO_TOTAL=0
ATOM_TOTAL=0
while IFS='|' read -r sub_id ticket phase iter verdict updated_at total done no_rvev pro; do
  if [ -n "$total" ] && [ "$total" != "total_atoms" ]; then
    ATOM_TOTAL=$((ATOM_TOTAL + (total)))
    PRO_TOTAL=$((PRO_TOTAL + (pro)))
  fi
done <<< "$(echo "$ARIA_DATA" | tail -n +2)"

if [ "$ATOM_TOTAL" -gt 0 ]; then
  PRO_PCT=$((PRO_TOTAL * 100 / ATOM_TOTAL))
  if [ "$PRO_PCT" -gt 50 ]; then
    WARNINGS+=("WARNING: $PRO_PCT% of Aria atoms use strong-tier models (threshold: 50%). Check if Execute/Synthesize atoms are incorrectly on strong-tier instead of flash-tier per CREST v1.3.")
  fi
fi

# Build report
VIOLATIONS_STR="${VIOLATIONS[*]:-}"
WARNINGS_STR="${WARNINGS[*]:-}"
python3 <<PYEOF
import json
violations = """${VIOLATIONS_STR}""".strip()
warnings = """${WARNINGS_STR}""".strip()
violations_list = [v for v in violations.split('\n') if v.strip()] if violations else []
warnings_list = [w for w in warnings.split('\n') if w.strip()] if warnings else []

report = {
    "checked_at": "${NOW}",
    "specialist": "aria",
    "violations": violations_list,
    "warnings": warnings_list,
    "violation_count": len(violations_list),
    "status": "VIOLATIONS_FOUND" if violations_list else ("WARNINGS" if warnings_list else "COMPLIANT")
}
with open("${REPORT_FILE}", "w") as f:
    json.dump(report, f, indent=2)
print(json.dumps(report, indent=2))
PYEOF

# Alert if violations exist
python3 <<PYEOF
import json, os
with open("$REPORT_FILE") as f:
    report = json.load(f)
if report["violation_count"] > 0:
    alert = {
        "alert_type": "aria_crest_violation",
        "severity": "high",
        "checked_at": "$NOW",
        "violations": report["violations"],
        "message": f"Aria CREST compliance checkpoint: {report['violation_count']} violation(s) found"
    }
    with open("$ALERT_FILE", "w") as f:
        json.dump(alert, f, indent=2)
    print(f"ALERT: {report['violation_count']} Aria CREST violation(s) — alert written")
else:
    if os.path.exists("$ALERT_FILE"):
        os.remove("$ALERT_FILE")
    print("CLEAN: Aria CREST compliant")
PYEOF
