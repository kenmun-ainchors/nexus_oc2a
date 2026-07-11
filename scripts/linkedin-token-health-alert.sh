#!/usr/bin/env zsh
# linkedin-token-health-alert.sh — Telegram alert for LinkedIn token health issues
# Called by cron after linkedin-token-health.sh --all runs.
# Sends Telegram alert if any account status != ok OR expiry within 7 days.
#
# Usage:
#   zsh scripts/linkedin-token-health-alert.sh [--dry-run]
#
# SKILL GATE: telegram skill must be loaded before use.

set -uo pipefail

WORKSPACE="/Users/ainchorsangiefpl/.openclaw/workspace"
STATE_DIR="$WORKSPACE/state"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Source telegram skill gate (non-fatal if not available)
source "${SCRIPT_DIR}/skill-gate.sh" "telegram" 2>/dev/null || true

DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    *) /bin/echo "❌ Unknown arg: $1" >&2; exit 1 ;;
  esac
done

# ── Check health files ────────────────────────────────────────────────────────

ALERTS=""
ANY_ISSUE=false

for account in ken angie business; do
  local health_file="$STATE_DIR/linkedin-token-health-${account}.json"
  local auth_file="$STATE_DIR/linkedin-auth"
  if [[ "$account" == "ken" ]]; then
    auth_file="${auth_file}.json"
  else
    auth_file="${auth_file}-${account}.json"
  fi

  if [[ ! -f "$health_file" ]]; then
    ALERTS="${ALERTS}⚠️ $account: No health check data found.
"
    ANY_ISSUE=true
    continue
  fi

  # Read the latest entry
  local latest
  latest=$(python3 -c "
import json, sys
with open('$health_file') as f:
    records = json.load(f)
if not isinstance(records, list):
    records = [records]
if records:
    print(json.dumps(records[-1]))
else:
    print('{}')
" 2>/dev/null || echo '{}')

  local hstatus
  hstatus=$(echo "$latest" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('status', 'unknown'))
except:
    print('unknown')
" 2>/dev/null)

  local hreason
  hreason=$(echo "$latest" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('reason', ''))
except:
    print('')
" 2>/dev/null)

  local hnext_action
  hnext_action=$(echo "$latest" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('nextAction', ''))
except:
    print('')
" 2>/dev/null)

  local htoken_expiry
  htoken_expiry=$(echo "$latest" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('tokenExpiry', ''))
except:
    print('')
" 2>/dev/null)

  local hchecked_at
  hchecked_at=$(echo "$latest" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('checkedAt', ''))
except:
    print('')
" 2>/dev/null)

  local label
  case "$account" in
    ken)      label="Ken Mun" ;;
    angie)    label="Angie" ;;
    business) label="AInchors Business" ;;
  esac

  if [[ "$hstatus" != "ok" ]]; then
    ALERTS="${ALERTS}🔴 $label: $hstatus"
    if [[ -n "$hreason" ]]; then
      ALERTS="${ALERTS} ($hreason)"
    fi
    if [[ -n "$htoken_expiry" ]]; then
      ALERTS="${ALERTS} — Expires: $htoken_expiry"
    fi
    if [[ "$hnext_action" == "reauth_now" ]]; then
      ALERTS="${ALERTS}
   → Re-auth needed: zsh scripts/linkedin-auth.sh --account $account"
    elif [[ "$hnext_action" == "reauth_soon" ]]; then
      ALERTS="${ALERTS}
   → Re-auth recommended soon: zsh scripts/linkedin-auth.sh --account $account"
    fi
    ALERTS="${ALERTS}
"
    ANY_ISSUE=true
  fi
done

# ── Send alert if issues found ────────────────────────────────────────────────

if [[ "$ANY_ISSUE" == "false" ]]; then
  /bin/echo "✅ All LinkedIn tokens healthy — no alert needed."
  exit 0
fi

MESSAGE="🔐 LinkedIn Token Health Alert

${ALERTS}
Checked at: $(date '+%Y-%m-%d %H:%M:%S AEST')"

if [[ "$DRY_RUN" == "true" ]]; then
  /bin/echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  /bin/echo "  🧪 DRY RUN — Telegram alert preview (no message sent):"
  /bin/echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  /bin/echo ""
  /bin/echo "$MESSAGE"
  /bin/echo ""
  /bin/echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  exit 0
fi

# Send via sovereign-alert.sh (direct Bot API, no session dependency)
"$SCRIPT_DIR/sovereign-alert.sh" --source LINKEDIN --message "$MESSAGE" 2>/dev/null || {
  # Fallback: try telegram-alert.sh directly
  "$SCRIPT_DIR/telegram-alert.sh" --message "$MESSAGE" 2>/dev/null || {
    /bin/echo "❌ Failed to send Telegram alert for LinkedIn token health." >&2
    exit 1
  }
}
