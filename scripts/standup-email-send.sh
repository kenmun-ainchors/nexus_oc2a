#!/bin/bash
# standup-email-send.sh — Send the standup canvas HTML as email
# Called by cron: AInchors Stand-up Email Delivery (shell-only systemEvent)
# Runs ~15 min after standup generation (08:15 AEST)
set -euo pipefail

WORKSPACE="/Users/ainchorsangiefpl/.openclaw/workspace"
CANVAS_HTML="/Users/ainchorsangiefpl/.openclaw/canvas/documents/standup-daily/index.html"
STATE_FILE="${WORKSPACE}/state/standup-state.json"
LOG_FILE="${WORKSPACE}/state/standup-email-log.json"
GOG="/opt/homebrew/bin/gog"
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
TODAY_AEST=$(TZ=Australia/Melbourne date '+%Y-%m-%d')
DAY_N=$(python3 -c "from datetime import date; d=(date.today() - date(2026,4,25)).days + 1; print(d)")
SUBJECT="☀️ AInchors Stand-up — Day ${DAY_N} | $(TZ=Australia/Melbourne date '+%A %d %B %Y')"

# --- Idempotency: check if already sent ---
if [[ -f "${STATE_FILE}" ]]; then
    EMAIL_SENT=$(python3 -c "import json; d=json.load(open('${STATE_FILE}')); print(d.get('emailSentConfirmed',''))" 2>/dev/null || echo "")
    if [[ "${EMAIL_SENT}" == "${TODAY_AEST}" ]]; then
        echo "IDEMPOTENT: Email already confirmed sent for ${TODAY_AEST}. Skipping."
        exit 0
    fi
fi

# --- Send email ---
echo "Sending stand-up email for Day ${DAY_N} (${TODAY_AEST})..."
${GOG} mail send \
    --to "kenmun@gmail.com" \
    --subject "${SUBJECT}" \
    --body "AInchors Stand-up — Day ${DAY_N}. Full HTML brief attached below." \
    --body-html-file "${CANVAS_HTML}" \
    --no-input \
    --json 2>&1 | tee /tmp/standup-email-result.json

SEND_EXIT=${PIPESTATUS[0]}

# --- Log result ---
NOW_ISO=$(TZ=Australia/Melbourne date -Iseconds)

if [[ ${SEND_EXIT} -eq 0 ]]; then
    MESSAGE_ID=$(python3 -c "import json; d=json.load(open('/tmp/standup-email-result.json')); print(d.get('id',''))" 2>/dev/null || echo "unknown")
    echo "SUCCESS: Email sent. Message ID: ${MESSAGE_ID}"

    # Update state with confirmed flag (separate from the cron's emailSentDate)
    if [[ -f "${STATE_FILE}" ]]; then
        python3 -c "
import json
d = json.load(open('${STATE_FILE}'))
d['emailSentConfirmed'] = '${TODAY_AEST}'
d['emailSentAt'] = '${NOW_ISO}'
json.dump(d, open('${STATE_FILE}','w'))
print('State updated: emailSentConfirmed = ${TODAY_AEST}')
" 2>/dev/null || true
    fi

    # Write success log
    python3 -c "
import json
json.dump({'date':'${TODAY_AEST}','dayNumber':${DAY_N},'sentAt':'${NOW_ISO}','messageId':'${MESSAGE_ID}','status':'ok','canvasSize':${CANVAS_SIZE}}, open('${LOG_FILE}','w'))
" 2>/dev/null || true
else
    echo "FAILED: Email send returned exit code ${SEND_EXIT}"

    # Write error log
    python3 -c "
import json
json.dump({'date':'${TODAY_AEST}','dayNumber':${DAY_N},'attemptedAt':'${NOW_ISO}','status':'failed','exitCode':${SEND_EXIT},'canvasSize':${CANVAS_SIZE}}, open('${LOG_FILE}','w'))
" 2>/dev/null || true

    exit ${SEND_EXIT}
fi
