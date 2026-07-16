#!/usr/bin/env zsh
# telegram-alert.sh — API-independent Telegram alert via direct Bot HTTP
# TKT-0113: Fallback alert that works even when Anthropic API is down
# CHG-0799: Multi-recipient via --recipients flag (comma-separated chat IDs)
# TKT-1004 (CHG-0898): platform/cron/infra/business alerts MUST use
#   --recipients "8574109706,8141152780" (Ken + Angie). The --chat-id
#   single-recipient path is for tests / Foodie group / one-off pings only.
#
# Usage:
#   telegram-alert.sh --message "text" --recipients '8574109706,8141152780' [--silent]
#   telegram-alert.sh --message "text" --chat-id CHAT_ID [--silent]
#
# SKILL GATE: telegram skill MUST be loaded before use.
SCRIPT_DIR_TG="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR_TG}/skill-gate.sh" "telegram" || exit $?
#
# Requirements:
#   - Telegram bot token in Keychain: telegram-bot-token
#   - curl available at /usr/bin/curl
#
# CRITICAL: This script must NEVER depend on Anthropic API, OpenClaw gateway,
# Python3 from PATH, or any component that may be down during an outage.
# Uses only: /usr/bin/curl, /usr/bin/security, /bin/echo, built-in zsh.

set -uo pipefail

BOT_KEYCHAIN_SERVICE="telegram-bot-token"
# TKT-1004 (CHG-0898): single-recipient default is Ken for backwards compat only.
# Platform/cron/infra alerts MUST use --recipients "8574109706,8141152780".
DEFAULT_CHAT_ID="8574109706"  # Ken Mun
TELEGRAM_API="https://api.telegram.org"

# ── Parse args ────────────────────────────────────────────────────────────────

MESSAGE=""
CHAT_ID="$DEFAULT_CHAT_ID"
SILENT=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --message|-m)   MESSAGE="$2"; shift 2 ;;
    --chat-id|-c)   CHAT_ID="$2"; shift 2 ;;
    --recipients|-r) RECIPIENTS="$2"; shift 2 ;;
    --silent)       SILENT=true; shift ;;
    *)              /bin/echo "❌ Unknown arg: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$MESSAGE" ]]; then
  /bin/echo "❌ --message required" >&2
  exit 1
fi

# ── Load bot token (env var primary, Keychain fallback) ──────────────────────
# TKT-0769: TELEGRAM_BOT_TOKEN env var is now the primary source.
# Keychain (service: telegram-bot-token) remains as fallback for existing paths.
# CRITICAL: token MUST NEVER be logged.

TOKEN_SOURCE=""
if [[ -n "${TELEGRAM_BOT_TOKEN:-}" ]]; then
  BOT_TOKEN="$TELEGRAM_BOT_TOKEN"
  TOKEN_SOURCE="env"
elif BOT_TOKEN=$(/usr/bin/security find-generic-password -s "$BOT_KEYCHAIN_SERVICE" -w 2>/dev/null || true); then
  [[ -n "$BOT_TOKEN" ]] && TOKEN_SOURCE="keychain"
fi

if [[ -z "${BOT_TOKEN:-}" ]]; then
  /bin/echo "❌ Telegram bot token not found (env TELEGRAM_BOT_TOKEN unset, and Keychain service '$BOT_KEYCHAIN_SERVICE' missing)" >&2
  exit 1
fi

# ── Send via direct HTTP (no Python, no OpenClaw, no Anthropic) ───────────────

# Build chat ID list: use --recipients if given, else --chat-id
# CHG-0799: Multi-recipient support
if [[ -n "${RECIPIENTS:-}" ]]; then
  # Split comma-separated IDs and trim whitespace
  CHAT_ID_LIST=()
  OLD_IFS="$IFS"
  IFS=','
  for _cid in $(echo "$RECIPIENTS"); do
    # Trim whitespace
    _cid=$(echo "$_cid" | xargs)
    CHAT_ID_LIST+=("$_cid")
  done
  IFS="$OLD_IFS"
else
  CHAT_ID_LIST=("$CHAT_ID")
fi

OVERALL_EXIT=0
for TARGET_CHAT in "${CHAT_ID_LIST[@]}"; do
  [[ -z "$TARGET_CHAT" ]] && continue

  # Build JSON payload using printf — no jq dependency
  PAYLOAD=$(/bin/echo "{\"chat_id\":\"${TARGET_CHAT}\",\"text\":$(printf '%s' "$MESSAGE" | /usr/bin/python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))' 2>/dev/null || /bin/echo "\"${MESSAGE//\"/\\\"}\""),\"parse_mode\":\"\"}")

  HTTP_STATUS=$(/usr/bin/curl -s -o /dev/null -w "%{http_code}" \
    -X POST "${TELEGRAM_API}/bot${BOT_TOKEN}/sendMessage" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD" \
    --max-time 10 \
    --retry 2 \
    --retry-delay 3 2>/dev/null)

  if [[ "$HTTP_STATUS" == "200" ]]; then
    [[ "$SILENT" != "true" ]] && /bin/echo "✅ Telegram alert sent to $TARGET_CHAT (HTTP 200, source: ${TOKEN_SOURCE})"
  else
    /bin/echo "❌ Telegram alert to $TARGET_CHAT failed (HTTP $HTTP_STATUS)" >&2
    OVERALL_EXIT=1
  fi
done

exit $OVERALL_EXIT
