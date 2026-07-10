#!/bin/zsh
# AInchors Canonical Secret Lookup
# Usage: KEY=$(zsh scripts/get-secret.sh <secret-name>)
#
# CANONICAL SECRET REGISTRY — single source of truth for all keychain lookups.
# When a key is rotated or renamed, update ONLY this file.
# All other scripts MUST source this helper; never hardcode keychain lookups directly.
#
# Rule: S5 — No hardcoded credentials. Keychain + env vars only.
# CHG: CHG-0141

SECRET_NAME="${1:-}"

case "$SECRET_NAME" in
  anthropic-api-key)
    # Source of truth: auth-profiles.json (what the gateway actually uses)
    # Keychain is fallback only — may be stale after key rotation
    AUTH_PROFILES="/Users/ainchorsangiefpl/.openclaw/agents/main/agent/auth-profiles.json"
    jq -r '.profiles["anthropic:default"].key // empty' "$AUTH_PROFILES" 2>/dev/null \
      | grep -q '^sk-ant' && jq -r '.profiles["anthropic:default"].key' "$AUTH_PROFILES" 2>/dev/null \
      || security find-generic-password -s "ainchors-anthropic-api-key" -a "anthropic" -w 2>/dev/null \
      || security find-generic-password -s "anthropic-api-key" -a "ainchors" -w 2>/dev/null \
      || security find-generic-password -s "anthropic-api-key" -w 2>/dev/null \
      || echo ""
    ;;
  notion-api-key)
    security find-generic-password -s "notion-api-key" -w 2>/dev/null \
      || echo ""
    ;;
  telegram-bot-token)
    security find-generic-password -a "ainchors" -s "telegram-bot-token" -w 2>/dev/null \
      || security find-generic-password -s "telegram-bot-token" -w 2>/dev/null \
      || echo ""
    ;;
  telegram-aria-bot-token)
    security find-generic-password -a "ainchors" -s "telegram-aria-bot-token" -w 2>/dev/null \
      || echo ""
    ;;
  dinner-crew-bot-token)
    security find-generic-password -a "ainchors" -s "dinner-crew-bot-token" -w 2>/dev/null \
      || echo ""
    ;;
  ollama-api-key)
    security find-generic-password -s "ollama-api-key" -w 2>/dev/null \
      || echo ""
    ;;
  *)
    echo "ERROR: Unknown secret '$SECRET_NAME'. Add it to scripts/get-secret.sh." >&2
    echo ""
    ;;
esac
