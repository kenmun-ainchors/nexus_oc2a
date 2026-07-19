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
# CHG-0927: Run the gate as a child process (do NOT `source` it) so that
# the gate's `exit` does not kill this script. The gate returns 0 if the
# skill is loaded (or the gate is bypassed), and non-zero if blocked.
# The gate's stderr box is preserved for the user.
SCRIPT_DIR_TG="$(cd "$(dirname "$0")" && pwd)"
if ! "${SCRIPT_DIR_TG}/skill-gate.sh" "telegram" 2>/tmp/telegram-alert-gate.err; then
  cat /tmp/telegram-alert-gate.err >&2
  rm -f /tmp/telegram-alert-gate.err
  exit 1
fi
rm -f /tmp/telegram-alert-gate.err
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
    --message-file|-f) MESSAGE_FILE="$2"; shift 2 ;;
    --chat-id|-c)   CHAT_ID="$2"; shift 2 ;;
    --recipients|-r) RECIPIENTS="$2"; shift 2 ;;
    --silent)       SILENT=true; shift ;;
    *)              /bin/echo "❌ Unknown arg: $1" >&2; exit 1 ;;
  esac
done

# Resolve --message-file: read the file content into MESSAGE so the rest of
# the pipeline is unchanged. (CHG-0927: helps LLM agents that struggle with
# multi-line message quoting on the command line.)
if [[ -n "${MESSAGE_FILE:-}" ]]; then
  if [[ ! -f "$MESSAGE_FILE" ]]; then
    /bin/echo "❌ --message-file: file not found: $MESSAGE_FILE" >&2
    exit 1
  fi
  MESSAGE=$(cat "$MESSAGE_FILE")
fi

if [[ -z "$MESSAGE" ]]; then
  /bin/echo "❌ --message or --message-file required" >&2
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
# CHG-0927: Sanitize chat IDs to strip whitespace and surrounding quote chars
#   (the most common LLM-agent artefact: an exec call with `"8574109706"`
#   passed as a single arg to --chat-id). Curly quotes are also stripped.
#   If a sanitized ID is non-numeric, skip it loudly rather than silently
#   sending to a malformed ID.
sanitize_chat_id() {
  local raw="$1"
  # Strip whitespace + straight quotes + curly quotes. The literal Unicode
  # chars (U+2018, U+2019, U+201C, U+201D) are written here as raw bytes
  # for portability across bash and zsh (no $'...' / \uXXXX escape needed).
  local stripped
  # Two passes: first strip whitespace + ASCII quotes, then strip Unicode curly quotes.
  stripped=$(printf '%s' "$raw" | tr -d "[:space:]\"'\"")
  stripped=$(printf '%s' "$stripped" | tr -d "“”‘’")
  # Validate: must be all digits, optional leading minus for groups
  if [[ "$stripped" =~ ^-?[0-9]+$ ]]; then
    printf '%s' "$stripped"
    return 0
  fi
  return 1
}

if [[ -n "${RECIPIENTS:-}" ]]; then
  CHAT_ID_LIST=()
  OLD_IFS="$IFS"
  IFS=','
  for _cid in $(echo "$RECIPIENTS"); do
    if _clean=$(sanitize_chat_id "$_cid"); then
      [[ -n "$_clean" ]] && CHAT_ID_LIST+=("$_clean")
    else
      /bin/echo "❌ Skipping non-numeric chat ID: '$_cid' (sanitize failed)" >&2
    fi
  done
  IFS="$OLD_IFS"
else
  if _clean=$(sanitize_chat_id "$CHAT_ID"); then
    CHAT_ID_LIST=("$_clean")
  else
    /bin/echo "❌ Telegram recipient must be a numeric chat ID (got: '$CHAT_ID')" >&2
    exit 2
  fi
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
