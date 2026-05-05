#!/bin/bash
# AInchors Secrets Manager — macOS Keychain
# Uses macOS built-in `security` CLI. No third-party tools required.
#
# Usage:
#   secrets-init.sh store <service> <value>   — Store a secret
#   secrets-init.sh get <service>             — Read a secret
#   secrets-init.sh list                      — List all AInchors secrets
#   secrets-init.sh export                    — Export all secrets as env vars (source this)
#   secrets-init.sh verify                    — Check all expected secrets are present
#   secrets-init.sh delete <service>          — Remove a secret
#
# Keychain account: ainchors
# All secrets stored under account "ainchors" for easy namespacing.

ACCOUNT="ainchors"

# Canonical list of expected secrets
# NOTE: anthropic-api-key resolves via get-secret.sh → ainchors-anthropic-api-key (account: anthropic)
# Do NOT add bare keychain lookups in other scripts — use scripts/get-secret.sh instead.
EXPECTED_SECRETS=(
  "ainchors-anthropic-api-key"  # Resolved via get-secret.sh as 'anthropic-api-key'
  "notion-api-key"
  "telegram-bot-token"
)

case "$1" in

  store)
    SERVICE="$2"
    VALUE="$3"
    if [[ -z "$SERVICE" || -z "$VALUE" ]]; then
      echo "Usage: $0 store <service> <value>"
      exit 1
    fi
    # Delete existing entry first (avoid duplicate)
    security delete-generic-password -a "$ACCOUNT" -s "$SERVICE" 2>/dev/null
    security add-generic-password -a "$ACCOUNT" -s "$SERVICE" -w "$VALUE"
    echo "✅ Stored: $SERVICE"
    ;;

  get)
    SERVICE="$2"
    if [[ -z "$SERVICE" ]]; then
      echo "Usage: $0 get <service>"
      exit 1
    fi
    VALUE=$(security find-generic-password -s "$SERVICE" -w 2>/dev/null)
    if [[ -z "$VALUE" ]]; then
      echo "❌ Not found: $SERVICE" >&2
      exit 1
    fi
    echo "$VALUE"
    ;;

  list)
    echo "AInchors secrets in macOS Keychain (account: $ACCOUNT):"
    echo ""
    for SERVICE in "${EXPECTED_SECRETS[@]}"; do
      VALUE=$(security find-generic-password -s "$SERVICE" -w 2>/dev/null)
      if [[ -n "$VALUE" ]]; then
        echo "  ✅ $SERVICE"
      else
        echo "  ❌ $SERVICE (missing)"
      fi
    done
    ;;

  export)
    # Source this to load secrets as env vars:
    # eval $(scripts/secrets-init.sh export)
    for SERVICE in "${EXPECTED_SECRETS[@]}"; do
      VALUE=$(security find-generic-password -s "$SERVICE" -w 2>/dev/null)
      if [[ -n "$VALUE" ]]; then
        # Convert service name to env var: notion-api-key -> NOTION_API_KEY
        ENV_VAR=$(echo "$SERVICE" | tr '[:lower:]-' '[:upper:]_')
        echo "export ${ENV_VAR}='${VALUE}'"
      fi
    done
    ;;

  verify)
    echo "Verifying AInchors secrets..."
    MISSING=0
    for SERVICE in "${EXPECTED_SECRETS[@]}"; do
      VALUE=$(security find-generic-password -s "$SERVICE" -w 2>/dev/null)
      if [[ -z "$VALUE" ]]; then
        echo "  ❌ MISSING: $SERVICE"
        MISSING=$((MISSING + 1))
      else
        echo "  ✅ $SERVICE"
      fi
    done
    echo ""
    if [[ $MISSING -eq 0 ]]; then
      echo "All secrets present."
      exit 0
    else
      echo "$MISSING secret(s) missing. Run: scripts/secrets-init.sh store <service> <value>"
      exit 1
    fi
    ;;

  delete)
    SERVICE="$2"
    if [[ -z "$SERVICE" ]]; then
      echo "Usage: $0 delete <service>"
      exit 1
    fi
    security delete-generic-password -a "$ACCOUNT" -s "$SERVICE" 2>/dev/null
    echo "🗑️  Deleted: $SERVICE"
    ;;

  *)
    echo "AInchors Secrets Manager"
    echo ""
    echo "Usage:"
    echo "  $0 store <service> <value>   Store a secret"
    echo "  $0 get <service>             Read a secret"
    echo "  $0 list                      List all expected secrets + status"
    echo "  $0 export                    Print export statements (source this)"
    echo "  $0 verify                    Check all secrets are present"
    echo "  $0 delete <service>          Remove a secret"
    echo ""
    echo "Expected secrets: ${EXPECTED_SECRETS[*]}"
    ;;

esac
