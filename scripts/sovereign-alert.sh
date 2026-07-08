#!/usr/bin/env zsh
# sovereign-alert.sh — One-shot wrapper around telegram-alert.sh with a
# consistent "[SOURCE] message" prefix and a fallback log file.
#
# TKT-0501 fix: Replaces `sessions_send` calls in crons that previously
# relied on the main session's last-channel routing, which collapsed to
# whichever chat lane was active (silence failure on Telegram alerts).
#
# Usage:
#   sovereign-alert.sh --source WARDEN --message "Model drift detected: ..."
#   sovereign-alert.sh --source HEALTH --file state/diagnostics-summary.txt
#
# Behavior:
#   1. Sends to Telegram via telegram-alert.sh (direct Bot API, L-001 compliant)
#   2. Logs to state/sovereign-alert.log with timestamp, source, and outcome
#   3. Returns non-zero ONLY if Telegram send fails (so cron knows to escalate)

set -uo pipefail

SCRIPT_DIR_SA="$(cd "$(dirname "$0")" && pwd)"
LOG="/Users/ainchorsangiefpl/.openclaw/workspace/state/sovereign-alert.log"
TS=$(date '+%Y-%m-%d %H:%M:%S AEST')

SOURCE=""
MESSAGE=""
FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --source)  SOURCE="$2"; shift 2 ;;
    --message|-m)  MESSAGE="$2"; shift 2 ;;
    --message|-m) MESSAGE="$2"; shift 2 ;;
    --file|-f)   FILE="$2"; shift 2 ;;
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

# Telegram send via direct Bot API (L-001 compliant — bypasses session layer)
"${SCRIPT_DIR_SA}/telegram-alert.sh" --message "$FULL"
RC=$?

if [[ $RC -eq 0 ]]; then
  echo "${TS} OK    ${SOURCE} → telegram" >> "$LOG"
else
  echo "${TS} FAIL  ${SOURCE} rc=${RC}" >> "$LOG"
fi

exit $RC
