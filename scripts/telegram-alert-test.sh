#!/usr/bin/env zsh
# telegram-alert-test.sh — Verify whether a Telegram bot token is available.
# TKT-0769: env var primary, Keychain fallback. Does NOT send a message.
#
# Usage:
#   telegram-alert-test.sh                  # human-readable output, exit 0/1
#   telegram-alert-test.sh --json           # single-line JSON to stdout
#   telegram-alert-test.sh --check          # exit 0 if available, exit 2 if missing
#
# Exit codes:
#   0 = token available
#   1 = runtime error (script bug, missing tools)
#   2 = token not available (env unset AND Keychain missing)

set -uo pipefail

SCRIPT_DIR_TEST="$(cd "$(dirname "$0")" && pwd)"
BOT_KEYCHAIN_SERVICE="telegram-bot-token"

JSON=false
CHECK_ONLY=false
for _a in "$@"; do
  case "$_a" in
    --json)        JSON=true ;;
    --check)       CHECK_ONLY=true ;;
    --help|-h)
      sed -n '3,15p' "$0"
      exit 0
      ;;
  esac
done

TOKEN_SOURCE=""
TOKEN_AVAILABLE=false
TOKEN_LENGTH=0

# 1. Env var
if [[ -n "${TELEGRAM_BOT_TOKEN:-}" ]]; then
  TOKEN_SOURCE="env"
  TOKEN_AVAILABLE=true
  TOKEN_LENGTH=${#TELEGRAM_BOT_TOKEN}
fi

# 2. Keychain fallback
if [[ "$TOKEN_AVAILABLE" == "false" ]]; then
  if command -v /usr/bin/security >/dev/null 2>&1; then
    _kc=$(/usr/bin/security find-generic-password -s "$BOT_KEYCHAIN_SERVICE" -w 2>/dev/null || true)
    if [[ -n "$_kc" ]]; then
      TOKEN_SOURCE="keychain"
      TOKEN_AVAILABLE=true
      TOKEN_LENGTH=${#_kc}
    fi
  fi
fi

# Report
if [[ "$JSON" == "true" ]]; then
  if [[ "$TOKEN_AVAILABLE" == "true" ]]; then
    /bin/echo "{\"available\":true,\"source\":\"${TOKEN_SOURCE}\",\"length\":${TOKEN_LENGTH}}"
  else
    /bin/echo "{\"available\":false,\"source\":null,\"length\":0}"
  fi
else
  if [[ "$TOKEN_AVAILABLE" == "true" ]]; then
    /bin/echo "✅ Telegram bot token available (source: ${TOKEN_SOURCE}, length: ${TOKEN_LENGTH})"
  else
    /bin/echo "❌ Telegram bot token NOT available (env TELEGRAM_BOT_TOKEN unset, Keychain service '${BOT_KEYCHAIN_SERVICE}' missing)"
  fi
fi

# Exit code
if [[ "$CHECK_ONLY" == "true" ]]; then
  if [[ "$TOKEN_AVAILABLE" == "true" ]]; then
    exit 0
  else
    exit 2
  fi
fi

[[ "$TOKEN_AVAILABLE" == "true" ]] && exit 0 || exit 2
