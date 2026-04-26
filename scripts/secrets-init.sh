#!/usr/bin/env bash
# secrets-init.sh — Load AInchors secrets from 1Password and export as env vars
# Usage: source scripts/secrets-init.sh [vault]
#        OR: eval "$(bash scripts/secrets-init.sh --export)"
#
# Prerequisites:
#   1. 1Password CLI installed: brew install 1password-cli
#   2. Signed in: op signin
#   3. Items stored in the "AInchors" vault (see SecretsManagement.md)
#
# Exit codes: 0=success, 1=op not found, 2=not signed in, 3=item not found (non-fatal)

set -euo pipefail

VAULT="${1:-AInchors}"
EXPORT_MODE="${1:-}"

# ── Helpers ──────────────────────────────────────────────────────────────────

log()  { echo "[secrets-init] $*" >&2; }
warn() { echo "[secrets-init] WARN: $*" >&2; }

# ── Preflight ─────────────────────────────────────────────────────────────────

if ! command -v op &>/dev/null; then
  echo "[secrets-init] ERROR: 1Password CLI (op) not found. Run: brew install 1password-cli" >&2
  exit 1
fi

# Check signed-in status (op whoami exits non-zero if not signed in)
if ! op whoami &>/dev/null 2>&1; then
  echo "[secrets-init] ERROR: Not signed in to 1Password. Run: op signin" >&2
  exit 2
fi

# ── Secret loader helper ───────────────────────────────────────────────────────
# Usage: load_secret ENV_VAR_NAME "Item Title" field [vault]
load_secret() {
  local var_name="$1"
  local item="$2"
  local field="${3:-password}"
  local vault="${4:-$VAULT}"

  local value
  value="$(op item get "$item" --vault "$vault" --fields "$field" 2>/dev/null)" || {
    warn "Could not load '$item' ($field) from vault '$vault' — skipping $var_name"
    return 0
  }

  if [[ "$EXPORT_MODE" == "--export" ]]; then
    printf 'export %s=%q\n' "$var_name" "$value"
  else
    export "$var_name"="$value"
    log "Loaded $var_name"
  fi
}

# ── AInchors Secrets ──────────────────────────────────────────────────────────
# Add entries here as new secrets are onboarded to 1Password.
# Format: load_secret ENV_VAR_NAME "1Password Item Title" field_name [vault_override]
#
# ── Notion ────────────────────────────────────────────────────────────────────
load_secret "NOTION_API_KEY"         "AInchors Notion"          "api_key"

# ── Telegram ─────────────────────────────────────────────────────────────────
load_secret "TELEGRAM_BOT_TOKEN"     "AInchors Telegram Bot"    "token"
load_secret "TELEGRAM_CHAT_ID"       "AInchors Telegram Bot"    "chat_id"

# ── OpenAI / LLM APIs ─────────────────────────────────────────────────────────
load_secret "OPENAI_API_KEY"         "AInchors OpenAI"          "api_key"
load_secret "ANTHROPIC_API_KEY"      "AInchors Anthropic"       "api_key"

# ── Add new secrets above this line ───────────────────────────────────────────

log "Done. Secrets loaded from vault: $VAULT"
