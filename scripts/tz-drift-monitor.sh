#!/bin/zsh
# TZ Drift Monitor — Validates that system tasks are anchored to AEST despite GMT host clock
# Runs every 30 min. Output: state/tz-drift-report.json

WORKSPACE="/Users/ainchorsangiefpl/.openclaw/workspace"
STATE_DIR="$WORKSPACE/state"
REPORT="$STATE_DIR/tz-drift-report.json"
LOG="$STATE_DIR/tz-drift-monitor.log"

log() {
    echo "[$(date '+%H:%M:%S')] $1" | tee -a "$LOG"
}

log "=== TZ DRIFT MONITOR START ==="

# 1. System Clock Check
SYS_TIME=$(date)
SENS_TZ=$(TZ="Australia/Melbourne" date)
log "System Time (Host): $SYS_TIME"
log "Target Time (AEST): $SENS_TZ"

# 2. Verify Key State Files for "Date Flip"
# IMPORTANT: Match by date string in filename, NOT by file modification time (ls -t).
# The EOD finalizer touches yesterday's file after midnight, so ls -t would pick the wrong file.
#
# GRACE WINDOWS:
# - Journal: today's file not expected to exist until 10:00 AEST (first daily activity window).
#   EOD finalizer runs at 23:55 AEST for YESTERDAY's journal. Today's starts empty.
# - Auto-Heal: not expected until after 01:00 AEST run. Grace until 01:30.
EXPECTED_DATE=$(TZ="Australia/Melbourne" date '+%Y-%m-%d')
AEST_HOUR=$(TZ="Australia/Melbourne" date '+%H' | sed 's/^0*//')
AEST_MIN=$(TZ="Australia/Melbourne" date '+%M' | sed 's/^0*//')
AEST_HOUR=${AEST_HOUR:-0}
AEST_MIN=${AEST_MIN:-0}
AEST_TOTAL_MIN=$((AEST_HOUR * 60 + AEST_MIN))

TODAY_JOURNAL="$WORKSPACE/memory/journal-$EXPECTED_DATE.md"
TODAY_AH="$STATE_DIR/auto-heal-$EXPECTED_DATE.json"

# Grace thresholds in minutes since midnight AEST
JOURNAL_GRACE_MIN=$((23 * 60))      # 23:00 AEST — journal built inline throughout day; only missing if absent by EOD
AUTOHEAL_GRACE_MIN=$((1 * 60 + 30)) # 01:30 AEST — auto-heal runs at 01:00

typeset -a DRIFTS

# --- Journal Check ---
JOURNAL_IN_GRACE=false
if [[ $AEST_TOTAL_MIN -lt $JOURNAL_GRACE_MIN ]]; then
    JOURNAL_IN_GRACE=true
    log "Journal check: in grace window (${AEST_HOUR}:${AEST_MIN} AEST < 23:00). Skipping drift check."
fi

if [[ -f "$TODAY_JOURNAL" ]]; then
    : # Journal file exists for today — OK.
elif $JOURNAL_IN_GRACE; then
    : # Still in grace window — no alert.
elif ls "$WORKSPACE/memory/journal-"*.md >/dev/null 2>&1; then
    LATEST_JOURNAL=$(ls "$WORKSPACE/memory/journal-"*.md 2>/dev/null | sort | tail -1)
    FILE_DATE=$(basename "$LATEST_JOURNAL" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}')
    DRIFTS+=("journal_date_mismatch: expected $EXPECTED_DATE file missing, latest is $FILE_DATE")
else
    DRIFTS+=("journal_missing: no journal files found at all")
fi

# --- Auto-Heal Check ---
AH_IN_GRACE=false
if [[ $AEST_TOTAL_MIN -lt $AUTOHEAL_GRACE_MIN ]]; then
    AH_IN_GRACE=true
    log "Auto-heal check: in grace window (${AEST_HOUR}:${AEST_MIN} AEST < 01:30). Skipping drift check."
fi

if [[ -f "$TODAY_AH" ]]; then
    :
elif $AH_IN_GRACE; then
    : # Still in grace window — no alert.
elif ls "$STATE_DIR/auto-heal-"*.json >/dev/null 2>&1; then
    LATEST_AH=$(ls "$STATE_DIR/auto-heal-"*.json 2>/dev/null | sort | tail -1)
    FILE_DATE=$(basename "$LATEST_AH" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}')
    DRIFTS+=("autoheal_date_mismatch: expected $EXPECTED_DATE file missing, latest is $FILE_DATE")
else
    DRIFTS+=("autoheal_missing: no auto-heal files found at all")
fi

# 3. Cron Schedule Verification
CRON_DRIFT=$(curl -s "http://localhost:18789/cron/list" | jq '[.jobs[] | select(.schedule.tz == null and .schedule.kind == "cron")] | length' 2>/dev/null || echo 0)
if (( CRON_DRIFT > 0 )); then
    DRIFTS+=("cron_tz_missing: $CRON_DRIFT jobs lack explicit timezone")
fi

# Write Report
# Convert DRIFTS array to JSON array (handle empty case)
if [[ ${#DRIFTS[@]} -eq 0 ]]; then
    DRIFTS_JSON="[]"
else
    DRIFTS_JSON=$(printf '%s\n' "${DRIFTS[@]}" | jq -R . | jq -s .)
fi

cat > "$REPORT" <<EOF
{
  "timestamp": "$(date -u '+%Y-%m-%dT%H:%M:%SZ')",
  "host_time": "$SYS_TIME",
  "target_time": "$SENS_TZ",
  "drifts_detected": ${#DRIFTS[@]},
  "drifts": $DRIFTS_JSON,
  "status": "$([[ ${#DRIFTS[@]} -eq 0 ]] && echo "OK" || echo "DRIFT_DETECTED")"
}
EOF

log "Report written to $REPORT. Drifts found: ${#DRIFTS[@]}"
[[ ${#DRIFTS[@]} -eq 0 ]] && exit 0 || exit 2
