#!/usr/bin/env bash
# standup-telegram-send.sh — Send a Telegram FLASH (≤600 chars) for the standup
# Called by cron: "AInchors Stand-up Telegram Delivery" (shell-only command)
# Runs ~20 min after standup generation (08:20 MYT, 5 min after email cron)
#
# MORNING_STANDUP_V2 architecture (CHG-0794, CHG-0899, CHG-0943):
#   Layer 0  canvas HTML  at  ~/.openclaw/canvas/documents/standup-daily/index.html
#                          (written by the main morning standup cron)
#   Layer 1  email         at  kenmun@gmail.com + cc angie.foong@ainchors.com
#                          (sent by scripts/standup-email-send.sh with full HTML)
#   Layer 2  Telegram flash here — ONE short message, max 600 chars, highlights
#                          only. NO full canvas. NO chunked full body.
#
# Flash content is built from .openclaw/tmp/standup-composer-input.json
# (the composer's input snapshot) — sections 1/2/6/7:
#   - frameworkMaturity  → System Health line
#   - businessStream     → Business line
#   - progress           → Progress line (first bullet)
#   - rtb.{rose,thorn,bud} → RTB line
# Ends with the engagement prompt "What's your focus for today, Ken?"
#
# Idempotency: state/standup-state.json → telegramSentConfirmed == today (MYT) → skip.
# On success: update state with telegramSentAt / telegramSentConfirmed.
# Degraded composer: prepend ⚠️ DEGRADED MODE banner.
#
# Recipients: Ken (8574109706) per task spec. Triage sender path: scripts/telegram-alert.sh.
set -euo pipefail

WORKSPACE="/Users/ainchorsoc2a/.openclaw/workspace"
SCRIPT_DIR_TG="${WORKSPACE}/scripts"
COMPOSER_FILE="${WORKSPACE}/.openclaw/tmp/standup-composer-input.json"
STATE_FILE="${WORKSPACE}/state/standup-state.json"
LOG_FILE="${WORKSPACE}/state/standup-telegram-log.json"
TELEGRAM_SCRIPT="${SCRIPT_DIR_TG}/telegram-alert.sh"
KEN_CHAT_ID="8574109706"
FLASH_MAX=600  # hard cap per MORNING_STANDUP_V2 (CHG-0794)

# --- Pre-flight: composer JSON must exist ---
if [[ ! -f "${COMPOSER_FILE}" ]]; then
    echo "ERROR: Composer JSON not found at ${COMPOSER_FILE}" >&2
    exit 1
fi

# --- Pre-flight: telegram sender must exist ---
if [[ ! -x "${TELEGRAM_SCRIPT}" ]]; then
    echo "ERROR: telegram-alert.sh missing or not executable at ${TELEGRAM_SCRIPT}" >&2
    exit 1
fi

# --- Defense in depth: ensure skill-gate does not block telegram-alert.sh ---
# CHG-0927: When this script runs from cron, the parent is `sh -lc` then `bash`,
# so skill-gate.sh's "is parent launchd/cron/openclaw?" heuristic fails.
# Always export SKILL_GATE_BYPASS=1 here so telegram-alert.sh can run regardless
# of how we were invoked.
export SKILL_GATE_BYPASS="${SKILL_GATE_BYPASS:-1}"

# --- Determine date (MYT) ---
TODAY_MYT=$(TZ=Asia/Kuala_Lumpur date '+%Y-%m-%d')
NOW_ISO=$(TZ=Asia/Kuala_Lumpur date -Iseconds)
DAY_N=$(python3 -c "from datetime import date; d=(date.today() - date(2026,4,25)).days + 1; print(d)")
TODAY_HUMAN=$(TZ=Asia/Kuala_Lumpur date '+%a %d %b %Y')

# --- Idempotency: skip if already confirmed today ---
if [[ -f "${STATE_FILE}" ]]; then
    TG_SENT=$(python3 -c "import json; d=json.load(open('${STATE_FILE}')); print(d.get('telegramSentConfirmed',''))" 2>/dev/null || echo "")
    if [[ "${TG_SENT}" == "${TODAY_MYT}" ]]; then
        echo "IDEMPOTENT: Telegram already confirmed sent for ${TODAY_MYT}. Skipping."
        python3 -c "
import json
json.dump({'date':'${TODAY_MYT}','dayNumber':${DAY_N},'sentAt':'${NOW_ISO}','status':'already_sent','flashLength':0,'composerStatus':'${COMPOSER_STATUS:-unknown}'}, open('${LOG_FILE}','w'))
" 2>/dev/null || true
        exit 0
    fi
fi

# --- Build flash from composer JSON (MORNING_STANDUP_V2 / CHG-0794) ---
# Sources (in order, from composer JSON):
#   frameworkMaturity  → 🟢 System line (truncate to ~80 chars)
#   businessStream     → 💼 Business line (truncate to ~80 chars)
#   progress           → 📈 Progress line — use first • bullet (truncate to ~80 chars)
#   rtb.{rose,thorn,bud} → 🌹 RTB line: "rose X · thorn Y · bud Z" (truncate each to ~25 chars)
# Ends with engagement prompt.
#
# CHG-0943: flash built in a temp python file so composer JSON can be read
# via a regular Python json.load (no stdin/heredoc stdin conflict), and the
# flash is validated to <= 600 chars before send.
_flash_py=$(mktemp -t standup_flash.XXXXXX.py)
trap 'rm -f "${_flash_py}"' EXIT
cat > "${_flash_py}" <<PYEOF
import json, sys

composer = json.load(open("${COMPOSER_FILE}"))
status = composer.get("composer_status", "unknown")

def trunc(s, n):
    s = (s or "").strip().replace("\n", " ").replace("  ", " ")
    if len(s) <= n:
        return s
    return s[: n - 1].rstrip() + "…"

fwm = trunc(composer.get("frameworkMaturity", ""), 95)
biz = trunc(composer.get("businessStream", ""), 110)
prog_raw = composer.get("progress", "")
first_bullet = ""
for line in prog_raw.splitlines():
    line = line.strip()
    if line.startswith("•") or line.startswith("-"):
        first_bullet = line.lstrip("•-").strip()
        break
if not first_bullet:
    first_bullet = trunc(prog_raw, 110)
prog = trunc(first_bullet, 110)

rtb = composer.get("rtb", {}) or {}
rose  = trunc(rtb.get("rose",  ""), 32)
thorn = trunc(rtb.get("thorn", ""), 32)
bud   = trunc(rtb.get("bud",   ""), 32)

lines = []
lines.append("☀️ AInchors Stand-up — Day ${DAY_N}")
lines.append("${TODAY_HUMAN}")
lines.append("")
lines.append(f"🟢 System: {fwm}" if fwm else "🟢 System: OK")
lines.append(f"💼 Business: {biz}" if biz else "💼 Business: —")
lines.append(f"📈 Progress: {prog}" if prog else "📈 Progress: —")
rtb_bits = " · ".join(b for b in (rose, thorn, bud) if b)
if rtb_bits:
    lines.append(f"🌹 RTB: {rtb_bits}")
lines.append("")
lines.append("What's your focus for today, Ken?")

flash = "\n".join(lines)

# Degraded banner
if status == "degraded":
    flash = "⚠️ DEGRADED MODE — composer is placeholder text only\n\n" + flash

# Sanity: hard cap at FLASH_MAX
if len(flash) > ${FLASH_MAX}:
    # Drop the business line first; it's usually the longest. Then progress. Then system.
    while len(flash) > ${FLASH_MAX}:
        for i, ln in enumerate(lines):
            if ln.startswith("💼 Business:") or ln.startswith("📈 Progress:") or ln.startswith("🟢 System:"):
                if len(ln) > 40:
                    lines[i] = ln[:37] + "…"
                else:
                    lines[i] = ""
                break
        else:
            # last resort: hard truncate
            lines[-1] = lines[-1][: ${FLASH_MAX} - len("\n".join(lines[:-1])) - 4] + "…"
            break
    flash = "\n".join(l for l in lines if l)

print(flash, file=sys.stdout)
PYEOF

# Run the flash builder. It reads the composer file directly (no stdin) and
# writes the composed flash to stdout.
FLASH=$(python3 "${_flash_py}")
FLASH_LEN=${#FLASH}

if [[ -z "${FLASH}" ]]; then
    echo "ERROR: Flash builder produced empty output" >&2
    exit 1
fi

if [[ ${FLASH_LEN} -gt ${FLASH_MAX} ]]; then
    echo "WARNING: Flash length ${FLASH_LEN} > cap ${FLASH_MAX}; truncating" >&2
    FLASH="${FLASH:0:$((FLASH_MAX-1))}…"
    FLASH_LEN=${#FLASH}
fi

# --- Pre-send self-test (CHG-0942 follow-up, Ken approved 2026-07-20) ---
# Defense in depth against the heredoc-stdin / partial-flash bug class
# that previously sent only the header/footer (~129 chars) to Telegram.
# A healthy flash has 4 substantive body lines (🟢 System, 💼 Business,
# 📈 Progress, 🌹 RTB) plus header + prompt. If the flash is suspiciously
# short OR missing the body lines, abort BEFORE any Telegram message is
# dispatched and write a failure log. We intentionally do NOT collapse this
# into the existing degraded-mode warning path — degraded still sends a
# banner; near-empty must not send at all.
FLASH_MIN=200        # below this, the body is missing or stripped
BODY_LINES_MIN=2     # at least 2 of the 4 body line prefixes must be present
if [[ ${FLASH_LEN} -lt ${FLASH_MIN} ]]; then
    BODY_COUNT=$(printf '%s' "${FLASH}" | grep -cE '^(🟢|💼|📈|🌹)' || true)
    echo "ERROR: Flash self-test FAILED — length ${FLASH_LEN} < minimum ${FLASH_MIN} (body lines detected: ${BODY_COUNT}/4). Possible partial-pipe regression. NOT sending to Telegram." >&2
    python3 -c "
import json
json.dump({'date':'${TODAY_MYT}','dayNumber':${DAY_N},'attemptedAt':'${NOW_ISO}','status':'self_test_failed','reason':'flash_too_short','flashLength':${FLASH_LEN},'minLength':${FLASH_MIN},'bodyLineCount':${BODY_COUNT}}, open('${LOG_FILE}','w'))
" 2>/dev/null || true
    exit 1
fi
BODY_COUNT=$(printf '%s' "${FLASH}" | grep -cE '^(🟢|💼|📈|🌹)' || true)
if [[ ${BODY_COUNT} -lt ${BODY_LINES_MIN} ]]; then
    echo "ERROR: Flash self-test FAILED — only ${BODY_COUNT} body lines present (min ${BODY_LINES_MIN}). Possible partial-pipe regression. NOT sending to Telegram." >&2
    python3 -c "
import json
json.dump({'date':'${TODAY_MYT}','dayNumber':${DAY_N},'attemptedAt':'${NOW_ISO}','status':'self_test_failed','reason':'body_lines_missing','flashLength':${FLASH_LEN},'bodyLineCount':${BODY_COUNT},'minBodyLines':${BODY_LINES_MIN}}, open('${LOG_FILE}','w'))
" 2>/dev/null || true
    exit 1
fi

echo "Sending ${FLASH_LEN}-char flash to ${KEN_CHAT_ID} (day ${DAY_N}, ${TODAY_MYT}, body lines: ${BODY_COUNT}/4)..."

# --- Send via telegram-alert.sh ---
if ! "${TELEGRAM_SCRIPT}" --message "${FLASH}" --chat-id "${KEN_CHAT_ID}" >/dev/null 2>&1; then
    echo "FAILED: Telegram flash send returned non-zero" >&2
    python3 -c "
import json
json.dump({'date':'${TODAY_MYT}','dayNumber':${DAY_N},'attemptedAt':'${NOW_ISO}','status':'failed','exitCode':1,'flashLength':${FLASH_LEN}}, open('${LOG_FILE}','w'))
" 2>/dev/null || true
    exit 1
fi

# --- Update state file on success ---
if [[ -f "${STATE_FILE}" ]]; then
    python3 -c "
import json
d = json.load(open('${STATE_FILE}'))
d['telegramSentConfirmed'] = '${TODAY_MYT}'
d['telegramSentAt'] = '${NOW_ISO}'
json.dump(d, open('${STATE_FILE}','w'))
print('State updated: telegramSentConfirmed = ${TODAY_MYT}')
" 2>/dev/null || true
else
    python3 -c "
import json
json.dump({'telegramSentConfirmed':'${TODAY_MYT}','telegramSentAt':'${NOW_ISO}','lastStandupDate':'${TODAY_MYT}','dayNumber':${DAY_N}}, open('${STATE_FILE}','w'))
" 2>/dev/null || true
fi

# --- Log success ---
python3 -c "
import json
json.dump({'date':'${TODAY_MYT}','dayNumber':${DAY_N},'sentAt':'${NOW_ISO}','status':'ok','flashLength':${FLASH_LEN},'recipient':'${KEN_CHAT_ID}','mode':'flash'}, open('${LOG_FILE}','w'))
" 2>/dev/null || true

echo "SUCCESS: Telegram standup flash delivered (${FLASH_LEN} chars, day ${DAY_N})"
