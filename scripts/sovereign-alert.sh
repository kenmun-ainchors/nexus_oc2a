#!/usr/bin/env zsh
# sovereign-alert.sh — One-shot wrapper around telegram-alert.sh with a
# consistent "[SOURCE] message" prefix and a fallback log file.
#
# TKT-0501 fix: Replaces `sessions_send` calls in crons that previously
# relied on the main session's last-channel routing, which collapsed to
# whichever chat lane was active (silence failure on Telegram alerts).
#
# TKT-1004 (CHG-0898) + CHG-0799 + CHG-0886: platform/cron/infra/business-
# impacting alerts route to BOTH Ken (8574109706) and Angie (8141152780)
# so neither is the implicit "always on" sink. Use --single-recipient to
# opt out for tests or one-off pings.
#
# Usage:
#   sovereign-alert.sh --source WARDEN --message "Model drift detected: ..."
#   sovereign-alert.sh --source HEALTH --file state/diagnostics-summary.txt
#   sovereign-alert.sh --source HEALTH --message "..." --single-recipient  # Ken only
#
# Behavior:
#   1. Sends to Telegram via telegram-alert.sh (direct Bot API, L-001 compliant)
#      to BOTH Ken + Angie by default.
#   2. Logs to state/sovereign-alert.log with timestamp, source, and outcome.
#   3. Returns non-zero ONLY if any Telegram send fails (so cron knows to escalate).

set -uo pipefail

SCRIPT_DIR_SA="$(cd "$(dirname "$0")" && pwd)"
LOG="/Users/ainchorsoc2a/.openclaw/workspace/state/sovereign-alert.log"
TS=$(date '+%Y-%m-%d %H:%M:%S AEST')

# TKT-1004 (CHG-0898) + CHG-0799: default to BOTH Ken + Angie.
# Override with --single-recipient for tests / one-off pings.
DEFAULT_RECIPIENTS="8574109706,8141152780"

SOURCE=""
MESSAGE=""
FILE=""
SINGLE_RECIPIENT=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --source)  SOURCE="$2"; shift 2 ;;
    --message|-m)  MESSAGE="$2"; shift 2 ;;
    --message|-m) MESSAGE="$2"; shift 2 ;;
    --file|-f)   FILE="$2"; shift 2 ;;
    --single-recipient) SINGLE_RECIPIENT=true; shift ;;
    *) /bin/echo "❌ Unknown arg: $1" >&2; exit 1 ;;
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
case "$SOURCE" in
  WARDEN)        PREFIX="🛡️ WARDEN" ;;
  HEALTH)        PREFIX="💓 HEALTH" ;;
  TASK)          PREFIX="📋 TASK" ;;
  TQP)           PREFIX="⚙️ TQP" ;;
  TZDRIFT)       PREFIX="🕐 TZ-DRIFT" ;;
  DOD)           PREFIX="✅ DoD" ;;
  RESTART)       PREFIX="🔄 RESTART" ;;
  STALE)         PREFIX="🧹 STALE" ;;
  AKB)           PREFIX="📚 AKB" ;;
  DRIVE)         PREFIX="☁️ DRIVE" ;;
  *)             PREFIX="📢 ${SOURCE}" ;;
esac

FULL="${PREFIX}: ${MESSAGE}"

# Telegram send via direct Bot API (L-001 compliant — bypasses session layer).
# TKT-1004 (CHG-0898) + CHG-0799: default to BOTH Ken + Angie. Use --single-recipient
# to opt out (e.g. for tests).
if [[ "$SINGLE_RECIPIENT" == "true" ]]; then
  "${SCRIPT_DIR_SA}/telegram-alert.sh" --message "$FULL"
  RC=$?
  RECIPIENTS="8574109706(single)"
else
  "${SCRIPT_DIR_SA}/telegram-alert.sh" --message "$FULL" --recipients "$DEFAULT_RECIPIENTS"
  RC=$?
  RECIPIENTS="$DEFAULT_RECIPIENTS"
fi

if [[ $RC -eq 0 ]]; then
  echo "${TS} OK    ${SOURCE} → telegram to ${RECIPIENTS}" >> "$LOG"
else
  echo "${TS} FAIL  ${SOURCE} → telegram to ${RECIPIENTS} rc=${RC}" >> "$LOG"
fi

exit $RC
