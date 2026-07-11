#!/usr/bin/env zsh
# linkedin-token-health.sh — LinkedIn token health probe (Atom C — TKT-0743 / CHG-0865)
# Non-destructive read-only probe. Calls /v2/userinfo for each account.
# Writes state/linkedin-token-health-{account}.json with status, expiry, next_action.
#
# Usage:
#   zsh scripts/linkedin-token-health.sh --account ken|angie|business [--dry-run]
#   zsh scripts/linkedin-token-health.sh --all [--dry-run]
#   zsh scripts/linkedin-token-health.sh --help

set -euo pipefail

WORKSPACE="/Users/ainchorsangiefpl/.openclaw/workspace"
STATE_DIR="$WORKSPACE/state"

USERINFO_ENDPOINT="https://api.linkedin.com/v2/userinfo"

# ── Account configuration ──────────────────────────────────────────────────────

declare -A ACCOUNT_KEYCHAIN_PREFIX
ACCOUNT_KEYCHAIN_PREFIX[ken]="ainchors-linkedin"
ACCOUNT_KEYCHAIN_PREFIX[angie]="ainchors-linkedin-angie"
ACCOUNT_KEYCHAIN_PREFIX[business]="ainchors-linkedin-business"

declare -A ACCOUNT_STATE_SUFFIX
ACCOUNT_STATE_SUFFIX[ken]=""
ACCOUNT_STATE_SUFFIX[angie]="-angie"
ACCOUNT_STATE_SUFFIX[business]="-business"

declare -A ACCOUNT_LABELS
ACCOUNT_LABELS[ken]="Ken Mun (personal)"
ACCOUNT_LABELS[angie]="Angie (personal)"
ACCOUNT_LABELS[business]="AInchors (company page)"

# ── Defaults ──────────────────────────────────────────────────────────────────

ACCOUNT=""
ALL_MODE=false
DRY_RUN=false

# ── Parse args ────────────────────────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
  case "$1" in
    --account)
      ACCOUNT="$2"
      shift 2
      ;;
    --all)
      ALL_MODE=true
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --help|-h)
      echo "Usage: zsh scripts/linkedin-token-health.sh [--account ken|angie|business] [--all] [--dry-run]"
      echo ""
      echo "  --account     Account to probe (ken, angie, business)"
      echo "  --all         Probe all three accounts"
      echo "  --dry-run     Show what would happen without making changes"
      echo "  --help, -h    Show this help"
      echo ""
      echo "Non-destructive: reads /v2/userinfo, writes state file, no posting."
      exit 0
      ;;
    *)
      echo "❌ Unknown argument: $1" >&2
      echo "Usage: zsh scripts/linkedin-token-health.sh [--account ken|angie|business] [--all] [--dry-run]" >&2
      exit 1
      ;;
  esac
done

# ── Validate ──────────────────────────────────────────────────────────────────

if [[ "$ALL_MODE" == "false" && -z "$ACCOUNT" ]]; then
  echo "❌ --account or --all required." >&2
  echo "Usage: zsh scripts/linkedin-token-health.sh [--account ken|angie|business] [--all] [--dry-run]" >&2
  exit 1
fi

if [[ "$ALL_MODE" == "true" && -n "$ACCOUNT" ]]; then
  echo "❌ Use --account OR --all, not both." >&2
  exit 1
fi

# ── Helpers ───────────────────────────────────────────────────────────────────

log()  { echo "  $*"; }
ok()   { echo "✅ $*"; }
err()  { echo "❌ $*" >&2; }
warn() { echo "⚠️  $*"; }

# ── Probe function ────────────────────────────────────────────────────────────

probe_account() {
  local account="$1"
  local dry_run="$2"

  local keychain_prefix="${ACCOUNT_KEYCHAIN_PREFIX[$account]}"
  local state_suffix="${ACCOUNT_STATE_SUFFIX[$account]}"
  local label="${ACCOUNT_LABELS[$account]}"
  local auth_state_file="$STATE_DIR/linkedin-auth${state_suffix}.json"
  local health_file="$STATE_DIR/linkedin-token-health-${account}.json"

  local checked_at
  checked_at=$(python3 -c "
from datetime import datetime, timezone
print(datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'))
" 2>/dev/null)

  # Default result values — declare locals separately from assignment
  local hstatus
  local hhttp_status
  local hservice_error_code
  local hreason
  local hnext_action
  local htoken_expiry
  local hrefresh_token_present
  hstatus="unknown"
  hhttp_status=""
  hservice_error_code=""
  hreason=""
  hnext_action="investigate"
  htoken_expiry=""
  hrefresh_token_present="false"

  # Read auth state file for tokenExpiry and refreshTokenPresent
  if [[ -f "$auth_state_file" ]]; then
    htoken_expiry=$(python3 -c "
import json
with open('$auth_state_file') as f:
    d = json.load(f)
print(d.get('tokenExpiry', ''))
" 2>/dev/null || echo "")

    hrefresh_token_present=$(python3 -c "
import json
with open('$auth_state_file') as f:
    d = json.load(f)
print(str(d.get('refreshTokenPresent', False)).lower())
" 2>/dev/null || echo "false")
  fi

  if [[ "$dry_run" == "true" ]]; then
    echo ""
    echo "  🧪 DRY RUN — $label"
    echo "     Auth state: $auth_state_file"
    echo "     Token expiry: ${htoken_expiry:-unknown}"
    echo "     Refresh token present: $hrefresh_token_present"
    echo "     Would probe: GET $USERINFO_ENDPOINT"
    echo "     Would write: $health_file"
    return 0
  fi

  # Retrieve access token from Keychain
  local access_token
  access_token=$(security find-generic-password -a linkedin -s "${keychain_prefix}-access-token" -w 2>/dev/null) || {
    hstatus="unknown"
    hreason="access_token_not_found_in_keychain"
    hnext_action="reauth_now"
    write_health_file "$account" "$health_file" "$checked_at" "$hstatus" "$hhttp_status" "$hservice_error_code" "$hreason" "$hnext_action" "$htoken_expiry" "$hrefresh_token_present"
    err "Access token not found in Keychain for $label."
    return 1
  }

  # Probe /v2/userinfo
  local probe_response probe_http_status probe_body
  probe_response=$(curl -s -w "\n__HTTP_STATUS__%{http_code}" \
    -X GET "$USERINFO_ENDPOINT" \
    -H "Authorization: Bearer $access_token" \
    -H "LinkedIn-Version: 202503" 2>/dev/null)
  probe_http_status=$(echo "$probe_response" | grep "__HTTP_STATUS__" | sed 's/__HTTP_STATUS__//')
  probe_body=$(echo "$probe_response" | grep -v "__HTTP_STATUS__")

  hhttp_status="$probe_http_status"

  if [[ "$probe_http_status" == "200" ]]; then
    # Token is valid
    local display_name
    display_name=$(echo "$probe_body" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('name', 'unknown'))
except:
    print('unknown')
" 2>/dev/null)

    hstatus="ok"
    hreason="token_valid"
    hnext_action="none"

    # Check if expiry is within 7 days
    if [[ -n "$htoken_expiry" ]]; then
      local days_until_expiry
      days_until_expiry=$(python3 -c "
from datetime import datetime, timezone
expiry = datetime.fromisoformat('$htoken_expiry'.replace('Z','').split('+')[0]).replace(tzinfo=timezone.utc)
now = datetime.now(timezone.utc)
delta = (expiry - now).days
print(max(0, delta))
" 2>/dev/null || echo "0")

      if [[ "$days_until_expiry" -le 7 ]]; then
        hstatus="refresh_needed"
        hreason="expires_within_${days_until_expiry}_days"
        hnext_action="reauth_soon"
        warn "Token for $label expires in $days_until_expiry days."
      fi
    fi

    # If no refresh token, flag for reauth
    if [[ "$hrefresh_token_present" != "true" ]]; then
      if [[ "$hstatus" == "ok" ]]; then
        hstatus="refresh_needed"
        hreason="no_refresh_token"
        hnext_action="reauth_soon"
        warn "No refresh token stored for $label — will need browser re-auth when token expires."
      fi
    fi

    ok "Token health OK for $label ($display_name). Status: $hstatus"
  elif [[ "$probe_http_status" == "401" ]]; then
    # Extract LinkedIn error details
    hservice_error_code=$(echo "$probe_body" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('serviceErrorCode', d.get('error', d.get('message', ''))))
except:
    print('')
" 2>/dev/null)

    # Distinguish expired vs revoked vs scope lost
    if echo "$probe_body" | grep -qiE "EXPIRED_ACCESS_TOKEN|expired"; then
      hstatus="expired"
      hreason="token_expired"
      hnext_action="reauth_now"
    elif echo "$probe_body" | grep -qiE "REVOKED_ACCESS_TOKEN|revoked"; then
      hstatus="revoked"
      hreason="token_revoked"
      hnext_action="reauth_now"
    elif echo "$probe_body" | grep -qiE "scope|insufficient_scope"; then
      hstatus="revoked"
      hreason="scope_lost"
      hnext_action="reauth_now"
    else
      hstatus="revoked"
      hreason="unauthorized_401"
      hnext_action="reauth_now"
    fi

    err "Token $hstatus for $label — $hreason (HTTP 401, code: $hservice_error_code)"
  else
    # Non-401 error (network, 5xx, etc.)
    hservice_error_code="http_${probe_http_status}"
    hstatus="unknown"
    hreason="unexpected_http_${probe_http_status}"
    hnext_action="investigate"
    warn "Unexpected HTTP $probe_http_status for $label."
  fi

  write_health_file "$account" "$health_file" "$checked_at" "$hstatus" "$hhttp_status" "$hservice_error_code" "$hreason" "$hnext_action" "$htoken_expiry" "$hrefresh_token_present"
  return 0
}

# ── Write health state file ───────────────────────────────────────────────────

write_health_file() {
  local waccount="$1"
  local whealth_file="$2"
  local wchecked_at="$3"
  local wstatus="$4"
  local whttp_status="$5"
  local wservice_error_code="$6"
  local wreason="$7"
  local wnext_action="$8"
  local wtoken_expiry="$9"
  local wrefresh_token_present="${10}"

  mkdir -p "$STATE_DIR"

  if ! python3 -c "
import json, os

# refresh_token_present passed as string from shell
refresh_raw = '$wrefresh_token_present'
refresh_present = refresh_raw.lower() in ('true', '1', 'yes')

entry = {
    'checkedAt': '$wchecked_at',
    'account': '$waccount',
    'status': '$wstatus',
    'httpStatus': '$whttp_status',
    'serviceErrorCode': '$wservice_error_code',
    'reason': '$wreason',
    'tokenExpiry': '$wtoken_expiry',
    'refreshTokenPresent': refresh_present,
    'nextAction': '$wnext_action'
}

if os.path.exists('$whealth_file'):
    with open('$whealth_file') as f:
        try:
            records = json.load(f)
            if not isinstance(records, list):
                records = [records]
        except:
            records = []
else:
    records = []
records.append(entry)
with open('$whealth_file', 'w') as f:
    json.dump(records, f, indent=2)
print('  Written:', '$whealth_file')
" 2>&1; then
    warn "Failed to write health file for $waccount."
  fi
}

# ── Main ──────────────────────────────────────────────────────────────────────

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  🔍 LinkedIn Token Health Probe"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [[ "$ALL_MODE" == "true" ]]; then
  for acct in ken angie business; do
    echo "  Probing: ${ACCOUNT_LABELS[$acct]}..."
    probe_account "$acct" "$DRY_RUN" || true
    echo ""
  done
else
  echo "  Probing: ${ACCOUNT_LABELS[$ACCOUNT]}..."
  probe_account "$ACCOUNT" "$DRY_RUN" || true
  echo ""
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ Health probe complete."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
