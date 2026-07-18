#!/bin/bash
# standup-email-send.sh — Send the standup canvas HTML as email
# Called by cron: AInchors Stand-up Email Delivery (shell-only systemEvent)
# Runs ~15 min after standup generation (08:15 MYT)
# CHG-0765 / TKT-0742: Fix messageId extraction (gog returns 'messageId', not 'id')
#   and ensure idempotency skip updates state/standup-email-log.json
# CHG-0799: Send to both Ken (kenmun@gmail.com) and Angie (angie.foong@ainchors.com)
set -euo pipefail

WORKSPACE="/Users/ainchorsoc2a/.openclaw/workspace"
CANVAS_HTML="/Users/ainchorsoc2a/.openclaw/canvas/documents/standup-daily/index.html"
STATE_FILE="${WORKSPACE}/state/standup-state.json"
LOG_FILE="${WORKSPACE}/state/standup-email-log.json"
GOG="$(command -v gog 2>/dev/null || brew --prefix 2>/dev/null)/bin/gog"
export GOG_ACCOUNT="kenmun@ainchors.com"

# --- Check canvas exists ---
if [[ ! -f "${CANVAS_HTML}" ]]; then
    echo "ERROR: Canvas HTML not found at ${CANVAS_HTML}"
    exit 1
fi

CANVAS_SIZE=$(wc -c < "${CANVAS_HTML}" | tr -d ' ')
if [[ "${CANVAS_SIZE}" -lt 500 ]]; then
    echo "ERROR: Canvas HTML too small (${CANVAS_SIZE} bytes) — likely empty or broken"
    exit 1
fi

# --- Determine date/subject ---
TODAY_LOCAL=$(TZ=Asia/Kuala_Lumpur date '+%Y-%m-%d')
DAY_N=$(python3 -c "from datetime import date; d=(date.today() - date(2026,4,25)).days + 1; print(d)")
SUBJECT="☀️ AInchors Stand-up — Day ${DAY_N} | $(TZ=Asia/Kuala_Lumpur date '+%A %d %B %Y')"

# --- Idempotency: check if already sent ---
if [[ -f "${STATE_FILE}" ]]; then
    EMAIL_SENT=$(python3 -c "import json; d=json.load(open('${STATE_FILE}')); print(d.get('emailSentConfirmed',''))" 2>/dev/null || echo "")
    if [[ "${EMAIL_SENT}" == "${TODAY_LOCAL}" ]]; then
        echo "IDEMPOTENT: Email already confirmed sent for ${TODAY_LOCAL}. Skipping."
        # Still update the log so it reflects today's state
        NOW_ISO=$(TZ=Asia/Kuala_Lumpur date -Iseconds)
        python3 -c "
import json
json.dump({'date':'${TODAY_LOCAL}','dayNumber':${DAY_N},'sentAt':'${NOW_ISO}','messageId':'already_sent','status':'already_sent','canvasSize':${CANVAS_SIZE}}, open('${LOG_FILE}','w'))
" 2>/dev/null || true
        exit 0
    fi
fi

# --- Check composer status for degraded mode ---
COMPOSER_FILE="${WORKSPACE}/.openclaw/tmp/standup-composer-input.json"
COMPOSER_DEGRADED=false
if [[ -f "$COMPOSER_FILE" ]]; then
    COMPOSER_STATUS=$(python3 -c "
import json
try:
    d = json.load(open('${COMPOSER_FILE}'))
    print(d.get('composer_status', 'unknown'))
except:
    print('unknown')
" 2>/dev/null)
    if [[ "$COMPOSER_STATUS" == "degraded" ]]; then
        COMPOSER_DEGRADED=true
        echo "WARNING: Composer is in degraded mode — content may be placeholder text" >&2
    fi
fi

# --- Build email body ---
EMAIL_BODY="AInchors Stand-up — Day ${DAY_N}. Full HTML brief attached below."
if [[ "$COMPOSER_DEGRADED" == "true" ]]; then
    EMAIL_BODY="⚠️ STAND-UP CONTENT COMPOSER DEGRADED — Sections 2, 5, 6, 7 contain placeholder text only. Do not present as authoritative. Manual update required.\n\n${EMAIL_BODY}"
fi

# --- Send email ---
echo "Sending stand-up email for Day ${DAY_N} (${TODAY_LOCAL})..."
${GOG} mail send \
    --to "kenmun@gmail.com" \
    --cc "angie.foong@ainchors.com" \
    --subject "${SUBJECT}" \
    --body "${EMAIL_BODY}" \
    --body-html-file "${CANVAS_HTML}" \
    --no-input \
    --json 2>&1 | tee /tmp/standup-email-result.json

SEND_EXIT=${PIPESTATUS[0]}

# --- Log result ---
NOW_ISO=$(TZ=Asia/Kuala_Lumpur date -Iseconds)

if [[ ${SEND_EXIT} -eq 0 ]]; then
    MESSAGE_ID=$(python3 -c "import json; d=json.load(open('/tmp/standup-email-result.json')); print(d.get('messageId','') or d.get('id',''))" 2>/dev/null || echo "unknown")
    echo "SUCCESS: Email sent. Message ID: ${MESSAGE_ID}"

    # Update state with confirmed flag (separate from the cron's emailSentDate)
    if [[ -f "${STATE_FILE}" ]]; then
        python3 -c "
import json
d = json.load(open('${STATE_FILE}'))
d['emailSentConfirmed'] = '${TODAY_LOCAL}'
d['emailSentAt'] = '${NOW_ISO}'
json.dump(d, open('${STATE_FILE}','w'))
print('State updated: emailSentConfirmed = ${TODAY_LOCAL}')
" 2>/dev/null || true
    fi

    # PG primary write: update email operational columns
    PSQL="${PSQL_BIN:-$(brew --prefix postgresql@16 2>/dev/null)/bin/psql} -U ${PGUSER:-$(whoami)} -d ainchors_nexus"
    PG_SQL="UPDATE state_standups SET email_sent_at = '${NOW_ISO}'::timestamptz, email_sent_confirmed = '${TODAY_LOCAL}'::date WHERE standup_date = '${TODAY_LOCAL}'::date;"
    if $PSQL -c "$PG_SQL" 2>/dev/null; then
        echo "PG primary write: state_standups email fields updated for ${TODAY_LOCAL}"
    else
        echo "PG write WARNING: could not update state_standups email fields"
    fi

    # Write success log
    python3 -c "
import json
json.dump({'date':'${TODAY_LOCAL}','dayNumber':${DAY_N},'sentAt':'${NOW_ISO}','messageId':'${MESSAGE_ID}','status':'ok','canvasSize':${CANVAS_SIZE},'recipients':['kenmun@gmail.com','angie.foong@ainchors.com']}, open('${LOG_FILE}','w'))
" 2>/dev/null || true
else
    echo "FAILED: Email send returned exit code ${SEND_EXIT}"

    # Write error log
    python3 -c "
import json
json.dump({'date':'${TODAY_LOCAL}','dayNumber':${DAY_N},'attemptedAt':'${NOW_ISO}','status':'failed','exitCode':${SEND_EXIT},'canvasSize':${CANVAS_SIZE}}, open('${LOG_FILE}','w'))
" 2>/dev/null || true

    exit ${SEND_EXIT}
fi
