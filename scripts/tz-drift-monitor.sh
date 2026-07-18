#!/bin/zsh
# TZ Drift Monitor — Validates local-time alignment and NTP clock sync.
# Runs every 1h. Output: state/tz-drift-report.json
#
# CHG-0913: rewritten for Asia/Kuala_Lumpur (GMT+8) host. Original AEST
# anchoring is gone; the script now:
#   1. Confirms the system timezone is what crons expect (Asia/Kuala_Lumpur).
#   2. Confirms the system clock is in sync with an NTP reference (>60s = drift).
#   3. Validates that today-state files match the local-time today.
#
# Exit codes:
#   0 = OK (all checks pass)
#   2 = DRIFT_DETECTED (one or more checks failed)
#
# Note: sntp is read-only on macOS by default; `sntp 0.asia.pool.ntp.org` returns
# the offset but `sntp -s` (step) is admin-gated. The script uses the read-only
# form so it does not require sudo. The output includes the measured offset.

set -u

WORKSPACE="/Users/ainchorsoc2a/.openclaw/workspace"
STATE_DIR="$WORKSPACE/state"
REPORT="$STATE_DIR/tz-drift-report.json"
LOG="$STATE_DIR/tz-drift-monitor.log"

mkdir -p "$STATE_DIR"

log() {
    echo "[$(date '+%Y-%m-%dT%H:%M:%S%z')] $1" | tee -a "$LOG"
}

log "=== TZ DRIFT MONITOR START (CHG-0913) ==="

typeset -a DRIFTS

# ── 1. System timezone alignment ─────────────────────────────────────────────
SYS_TZ_NAME=$(date +%Z)
SYS_TZ_OFFSET=$(date +%z)
# macOS /etc/localtime symlink check (best effort)
LOCALTIME_TARGET=$(readlink /etc/localtime 2>/dev/null || echo "")
log "System TZ: $SYS_TZ_NAME ($SYS_TZ_OFFSET) | localtime: $LOCALTIME_TARGET"

case "$SYS_TZ_OFFSET" in
    +0800|-0800) log "System clock offset $SYS_TZ_OFFSET matches Asia/Kuala_Lumpur (GMT+8)." ;;
    +1000|-1000|+1100|-1100)
        DRIFTS+=("tz_offset_unexpected: system offset is $SYS_TZ_OFFSET, expected +0800 for Asia/Kuala_Lumpur")
        log "WARNING: System offset $SYS_TZ_OFFSET suggests an Australian timezone is still active."
        ;;
    *)
        DRIFTS+=("tz_offset_unexpected: system offset is $SYS_TZ_OFFSET, expected +0800")
        log "WARNING: System offset $SYS_TZ_OFFSET is not GMT+8."
        ;;
esac

# ── 2. NTP drift check (>60s = drift) ────────────────────────────────────────
NTP_OK=true
NTP_OFFSET_SEC="unknown"
NTP_SERVER="0.asia.pool.ntp.org"
SNTP_BIN="$(command -v sntp 2>/dev/null || echo /usr/sbin/sntp)"

if [[ -x "$SNTP_BIN" ]]; then
    log "Probing NTP via $SNTP_BIN $NTP_SERVER (read-only)..."
    NTP_OUTPUT="$("$SNTP_BIN" "$NTP_SERVER" 2>&1 || true)"
    # sntp prints a multi-line error block for a failed exchange, then a final
    # summary line of the form: "+0.033422 +/- 0.067889 0.asia.pool.ntp.org 1.2.3.4"
    # We only want the LAST summary line, which is the one with both "+/-" and a hostname.
    SUMMARY_LINE=$(echo "$NTP_OUTPUT" | grep -E '^[-+][0-9]+\.[0-9]+ \+/- [0-9]+\.[0-9]+' | tail -1 || true)
    NTP_OFFSET_SEC="unknown"
    if [[ -n "$SUMMARY_LINE" ]]; then
        NTP_OFFSET_SEC=$(echo "$SUMMARY_LINE" | awk '{print $1}' | head -1)
    fi
    log "NTP summary: ${SUMMARY_LINE:-<no summary line>}"
    if [[ "$NTP_OFFSET_SEC" == "unknown" || -z "$NTP_OFFSET_SEC" ]]; then
        NTP_OK=false
        DRIFTS+=("ntp_unreachable: sntp could not read $NTP_SERVER (timeout or no route)")
        log "WARNING: No usable NTP summary line in sntp output."
    else
        # Compare absolute offset to 60.0 seconds
        ABS_OFF=$(echo "$NTP_OFFSET_SEC" | sed 's/^[-+]//')
        OFF_OK=$(awk -v a="$ABS_OFF" 'BEGIN { print (a+0 <= 60.0) ? "yes" : "no" }')
        if [[ "$OFF_OK" != "yes" ]]; then
            NTP_OK=false
            DRIFTS+=("ntp_drift_exceeded: offset ${NTP_OFFSET_SEC}s exceeds 60s threshold")
            log "WARNING: NTP drift ${NTP_OFFSET_SEC}s exceeds 60s threshold."
        else
            log "NTP offset ${NTP_OFFSET_SEC}s is within 60s tolerance."
        fi
    fi
else
    NTP_OK=false
    DRIFTS+=("ntp_unavailable: sntp binary not found at $SNTP_BIN")
    log "WARNING: sntp binary not found — NTP drift check skipped."
fi

# ── 3. Local-time today-state file check ────────────────────────────────────
# Idempotency: state files for the current local day must exist (or be in grace).
# Match by date string in filename, NOT by file modification time.
EXPECTED_DATE=$(date '+%Y-%m-%d')
LOCAL_HOUR=$(date '+%H' | sed 's/^0*//')
LOCAL_MIN=$(date '+%M' | sed 's/^0*//')
LOCAL_HOUR=${LOCAL_HOUR:-0}
LOCAL_MIN=${LOCAL_MIN:-0}
LOCAL_TOTAL_MIN=$((LOCAL_HOUR * 60 + LOCAL_MIN))

TODAY_JOURNAL="$WORKSPACE/memory/journal-$EXPECTED_DATE.md"
TODAY_AH="$STATE_DIR/auto-heal-$EXPECTED_DATE.json"

# Grace windows in minutes since midnight (local time)
# - Journal: first daily activity window is 00:05 local (Telegram standup). Expect present by 00:30.
# - Auto-Heal: not expected until after 01:00 local. Grace until 01:30.
JOURNAL_GRACE_MIN=$((0 * 60 + 30))    # 00:30 local
AUTOHEAL_GRACE_MIN=$((1 * 60 + 30))   # 01:30 local

# --- Journal Check ---
JOURNAL_IN_GRACE=false
if [[ $LOCAL_TOTAL_MIN -lt $JOURNAL_GRACE_MIN ]]; then
    JOURNAL_IN_GRACE=true
    log "Journal check: in grace window (${LOCAL_HOUR}:${LOCAL_MIN} local < 00:30). Skipping drift check."
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
if [[ $LOCAL_TOTAL_MIN -lt $AUTOHEAL_GRACE_MIN ]]; then
    AH_IN_GRACE=true
    log "Auto-heal check: in grace window (${LOCAL_HOUR}:${LOCAL_MIN} local < 01:30). Skipping drift check."
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

# ── 4. Cron schedule verification (cron jobs missing explicit tz) ───────────
# Validate against host local timezone (now Asia/Kuala_Lumpur), not AEST.
# Best-effort: probe the gateway cron list. Treat HTTP failure as a soft warning.
CRON_OUTPUT=$(curl -s --max-time 5 "http://localhost:18789/api/cron/list" 2>/dev/null || echo "")
if [[ -z "$CRON_OUTPUT" || "$CRON_OUTPUT" == "Not Found" ]]; then
    # Fall back to openclaw CLI JSON
    CRON_OUTPUT=$(openclaw cron list --json 2>/dev/null || echo "")
fi
if [[ -n "$CRON_OUTPUT" ]]; then
    CRON_DRIFT=$(echo "$CRON_OUTPUT" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    jobs = data.get('jobs', data) if isinstance(data, dict) else data
    bad = [j for j in jobs
           if (j.get('schedule', {}) or {}).get('kind') == 'cron'
           and not (j.get('schedule', {}) or {}).get('tz')]
    print(len(bad))
    for j in bad:
        print('  - ' + j.get('id','') + ' ' + j.get('name','') + ' (no explicit tz; uses host local)')
except Exception as e:
    print('0')
" 2>/dev/null)
    if [[ -n "$CRON_DRIFT" && "$CRON_DRIFT" -gt 0 ]]; then
        log "INFO: $CRON_DRIFT cron job(s) lack explicit tz — they now use host local (Asia/Kuala_Lumpur). Verify intent."
    fi
else
    log "INFO: could not query cron list — skipping cron check."
fi

# ── Write report ────────────────────────────────────────────────────────────
if [[ ${#DRIFTS[@]} -eq 0 ]]; then
    DRIFTS_JSON="[]"
else
    DRIFTS_JSON=$(printf '%s\n' "${DRIFTS[@]}" | jq -R . | jq -s .)
fi

cat > "$REPORT" <<EOF
{
  "timestamp": "$(date -u '+%Y-%m-%dT%H:%M:%SZ')",
  "host_time": "$(date)",
  "host_timezone": "$SYS_TZ_NAME",
  "host_offset": "$SYS_TZ_OFFSET",
  "expected_timezone": "Asia/Kuala_Lumpur",
  "expected_offset": "+08:00",
  "ntp_server": "$NTP_SERVER",
  "ntp_offset_seconds": "$NTP_OFFSET_SEC",
  "ntp_ok": $([[ "$NTP_OK" == "true" ]] && echo "true" || echo "false"),
  "drifts_detected": ${#DRIFTS[@]},
  "drifts": $DRIFTS_JSON,
  "status": "$([[ ${#DRIFTS[@]} -eq 0 ]] && echo "OK" || echo "DRIFT_DETECTED")"
}
EOF

log "Report written to $REPORT. Drifts found: ${#DRIFTS[@]}"
[[ ${#DRIFTS[@]} -eq 0 ]] && exit 0 || exit 2
