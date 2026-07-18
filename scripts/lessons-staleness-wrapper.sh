#!/usr/bin/env bash
# lessons-staleness-wrapper.sh — Warden pick-up for Strike-3 LESSONS.md staleness
# Runs lessons-staleness-check.sh and appends a JSON line per check to state/warden-findings.jsonl
# Owner: TKT-0401 / CHG-0503
# Pattern: parallel to warden-cron.sh model-drift pickup

set -u

WORKSPACE="/Users/ainchorsoc2a/.openclaw/workspace"
FINDINGS="$WORKSPACE/state/warden-findings.jsonl"
LOCAL_TIMESTAMP=$(date +"%Y-%m-%dT%H:%M:%S+08:00")

mkdir -p "$(dirname "$FINDINGS")" 2>/dev/null || true

# Run the check (allow non-zero exit so we can capture all statuses)
SKILL_GATE_BYPASS=1 bash "$WORKSPACE/scripts/lessons-staleness-check.sh"
EXIT_CODE=$?

# Read state file
STATE_FILE="$WORKSPACE/state/lessons-staleness-state.json"
if [[ ! -f "$STATE_FILE" ]]; then
  echo "{\"check\":\"lessons-staleness\",\"timestamp\":\"$LOCAL_TIMESTAMP\",\"status\":\"error\",\"note\":\"state file missing\",\"exitCode\":$EXIT_CODE}" >> "$FINDINGS"
  exit $EXIT_CODE
fi

# Append a single JSON line to warden-findings.jsonl
# Schema: {check, timestamp, status, lessonId, ageDays, lastUpdated, exitCode, note}
python3 - "$STATE_FILE" "$LOCAL_TIMESTAMP" "$EXIT_CODE" "$FINDINGS" <<'PYEOF'
import json, sys
state_file, ts, exit_code, findings = sys.argv[1], sys.argv[2], int(sys.argv[3]), sys.argv[4]
try:
    with open(state_file) as f:
        s = json.load(f)
    record = {
        "check": "lessons-staleness",
        "timestamp": ts,
        "status": s.get("status", "unknown"),
        "lessonId": s.get("mostRecentLesson"),
        "ageDays": s.get("ageDays"),
        "lastUpdated": s.get("lastUpdated"),
        "exitCode": exit_code,
    }
    with open(findings, "a") as f:
        f.write(json.dumps(record) + "\n")
except Exception as e:
    with open(findings, "a") as f:
        f.write(json.dumps({"check":"lessons-staleness","timestamp":ts,"status":"error","note":str(e),"exitCode":exit_code}) + "\n")
PYEOF

# Map exit code to severity for downstream escalation
case $EXIT_CODE in
  0) echo "[warden] lessons-staleness: PASS — no action" ;;
  1) echo "[warden] lessons-staleness: WARN — log lesson within 7 days" ;;
  2) echo "[warden] lessons-staleness: ALERT — log a lesson today (CHG-0503)" ;;
  3) echo "[warden] lessons-staleness: CRITICAL — system operating without recent memory" ;;
  4) echo "[warden] lessons-staleness: FILE MISSING — restore memory/LESSONS.md" ;;
  *) echo "[warden] lessons-staleness: UNKNOWN exit $EXIT_CODE" ;;
esac

exit $EXIT_CODE
