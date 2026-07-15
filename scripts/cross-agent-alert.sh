#!/usr/bin/env zsh
# cross-agent-alert.sh — Source-agnostic wrapper that routes critical alerts
# to BOTH Ken and Angie via Telegram in a single call.
#
# CHG-0799 + CHG-0886 + TKT-0780:
#   platform/cron/infra/business-impacting alerts route to both Ken (8574109706)
#   and Angie (8141152780) so neither has to be the implicit "always on" sink.
#
# Usage:
#   cross-agent-alert.sh --source HEALTH --message "text"
#   cross-agent-alert.sh --source WARDEN --file state/diagnostics-summary.txt
#   cross-agent-alert.sh --source TASK --message "..." --recipients '8574109706,8141152780,1234567890'
#
# Behavior:
#   1. Composes "[SOURCE] message" prefix with emoji (re-uses sovereign-alert.sh mapping).
#   2. Sends to Telegram via telegram-alert.sh --recipients (direct Bot API, L-001 compliant).
#   3. Logs to state/cross-agent-alert.log with timestamp + OK|FAIL + recipients.
#   4. Returns non-zero ONLY if Telegram send fails (so cron knows to escalate).
#   5. NEVER logs the bot token (telegram-alert.sh handles that).
#
# SKILL GATE: telegram skill MUST be loaded before use (or SKILL_GATE_BYPASS=1).

set -uo pipefail

SCRIPT_DIR_XA="$(cd "$(dirname "$0")" && pwd)"

# Skill gate: load telegram skill unless bypassed
if [[ "${SKILL_GATE_BYPASS:-}" != "1" ]]; then
  source "${SCRIPT_DIR_XA}/skill-gate.sh" "telegram" || exit $?
fi

LOG="/Users/ainchorsoc2a/.openclaw/workspace/state/cross-agent-alert.log"
TS=$(date '+%Y-%m-%d %H:%M:%S AEST')

# Default dual recipients per CHG-0799 (Ken + Angie)
DEFAULT_RECIPIENTS="8574109706,8141152780"

SOURCE=""
MESSAGE=""
FILE=""
RECIPIENTS="$DEFAULT_RECIPIENTS"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --source)        SOURCE="$2"; shift 2 ;;
    --message|-m)    MESSAGE="$2"; shift 2 ;;
    --file|-f)       FILE="$2"; shift 2 ;;
    --recipients|-r) RECIPIENTS="$2"; shift 2 ;;
    --help|-h)
      /bin/echo "Usage: cross-agent-alert.sh --source SOURCE --message MSG [--file FILE] [--recipients 'id1,id2']"
      exit 0
      ;;
    *)
      /bin/echo "❌ Unknown arg: $1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$SOURCE" ]]; then
  /bin/echo "❌ --source required" >&2
  exit 1
fi

if [[ -n "$FILE" ]]; then
  if [[ ! -f "$FILE" ]]; then
    /bin/echo "❌ --file $FILE not found" >&2
    exit 1
  fi
  MESSAGE=$(cat "$FILE")
fi

if [[ -z "$MESSAGE" ]]; then
  /bin/echo "❌ --message or --file required" >&2
  exit 1
fi

# Compose prefixed message — emoji per source for scannability
# Mirrors sovereign-alert.sh so the two wrappers read consistently.
case "$SOURCE" in
  WARDEN)          PREFIX="🛡️ WARDEN" ;;
  HEALTH)          PREFIX="💓 HEALTH" ;;
  TASK)            PREFIX="📋 TASK" ;;
  TQP)             PREFIX="⚙️ TQP" ;;
  TZDRIFT)         PREFIX="🕐 TZ-DRIFT" ;;
  DOD)             PREFIX="✅ DoD" ;;
  RESTART)         PREFIX="🔄 RESTART" ;;
  STALE|STALE_CLEANUP) PREFIX="🧹 STALE" ;;
  AKB)             PREFIX="📚 AKB" ;;
  DRIVE)           PREFIX="☁️ DRIVE" ;;
  CLOUD-CRON)      PREFIX="☁️🚨 CLOUD-CRON" ;;
  QUOTA-CANARY)    PREFIX="⏱️🚨 QUOTA-CANARY" ;;
  CROSS-AGENT)     PREFIX="📣 CROSS-AGENT" ;;
  *)               PREFIX="📢 ${SOURCE}" ;;
esac

FULL="${PREFIX}: ${MESSAGE}"

# Telegram send via direct Bot API (L-001 compliant — bypasses session layer)
# Use --recipients to fan out to both Ken + Angie in one call.
"${SCRIPT_DIR_XA}/telegram-alert.sh" --message "$FULL" --recipients "$RECIPIENTS"
RC=$?

# Log line per plan §5 Step 2
# Format: "YYYY-MM-DD HH:MM:SS AEST OK|FAIL SOURCE → telegram to RECIPIENTS"
if [[ $RC -eq 0 ]]; then
  /bin/echo "${TS} OK    ${SOURCE} → telegram to ${RECIPIENTS}" >> "$LOG"
else
  /bin/echo "${TS} FAIL  ${SOURCE} → telegram to ${RECIPIENTS} rc=${RC}" >> "$LOG"
fi

exit $RC
