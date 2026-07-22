#!/usr/bin/env zsh
# linkedin-auth.sh — LinkedIn OAuth 2.0 PKCE flow for AInchors
# Supports multi-account auth: Ken personal (default), Angie personal, AInchors business.
# Requires Ken to open the auth URL in a browser manually.
# Stores tokens in macOS Keychain ONLY. No secrets in files.
#
# Usage:
#   zsh scripts/linkedin-auth.sh                          # Ken personal (default, backward compatible)
#   zsh scripts/linkedin-auth.sh --account angie          # Angie personal
#   zsh scripts/linkedin-auth.sh --account business      # AInchors company page
#   zsh scripts/linkedin-auth.sh --dry-run                # Show what would happen
#   zsh scripts/linkedin-auth.sh --help                   # Show usage

set -euo pipefail

WORKSPACE="/Users/ainchorsoc2a/.openclaw/workspace"
STATE_DIR="$WORKSPACE/state"

REDIRECT_URI="http://localhost:8765/callback"
AUTH_ENDPOINT="https://www.linkedin.com/oauth/v2/authorization"
TOKEN_ENDPOINT="https://www.linkedin.com/oauth/v2/accessToken"
USERINFO_ENDPOINT="https://api.linkedin.com/v2/userinfo"
CALLBACK_PORT=8765

# ── Account configuration ──────────────────────────────────────────────────────

# Each account has: Keychain service prefix, scopes, state file suffix
# Ken personal: w_member_social (Share on LinkedIn) + OpenID Connect profile scopes
# Angie personal: same scopes as Ken
# Business (AInchors): Marketing/Advertising API product (approved CHG-0887 / TKT-1001).
#   Read-only probe set per https://learn.microsoft.com/en-us/linkedin/marketing/increasing-access
#   (Advertising API program permissions table, 2026-06 moniker):
#     r_ads               — read ad accounts
#     r_ads_reporting     — read ad reporting
#     r_basicprofile      — read basic profile (required for many ad API calls)
#     r_organization_social   — read org social actions (no write)
#     r_organization_admin    — read org admin / ad account membership
#     r_1st_connections_size  — read 1st-degree connection count
#   Plus openid profile email from OpenID Connect (needed for /v2/userinfo member identity).
#   Explicitly NOT included (write-side scopes blocked for the probe):
#     w_organization_social, w_member_social, rw_ads, rw_organization_admin
#   The probe is read-only; add write scopes later only when a real write workflow is queued.

declare -A ACCOUNT_SCOPES
ACCOUNT_SCOPES[ken]="openid profile email w_member_social"
ACCOUNT_SCOPES[angie]="openid profile email w_member_social"
ACCOUNT_SCOPES[business]="openid profile email r_basicprofile r_ads r_ads_reporting r_organization_social r_organization_admin r_1st_connections_size"

declare -A ACCOUNT_LABELS
ACCOUNT_LABELS[ken]="Ken Mun (personal)"
ACCOUNT_LABELS[angie]="Angie (personal)"
ACCOUNT_LABELS[business]="AInchors (company page)"

declare -A ACCOUNT_KEYCHAIN_PREFIX
ACCOUNT_KEYCHAIN_PREFIX[ken]="ainchors-linkedin"
ACCOUNT_KEYCHAIN_PREFIX[angie]="ainchors-linkedin-angie"
ACCOUNT_KEYCHAIN_PREFIX[business]="ainchors-linkedin-business"

declare -A ACCOUNT_STATE_SUFFIX
ACCOUNT_STATE_SUFFIX[ken]=""
ACCOUNT_STATE_SUFFIX[angie]="-angie"
ACCOUNT_STATE_SUFFIX[business]="-business"

# ── Defaults ──────────────────────────────────────────────────────────────────

ACCOUNT="ken"
DRY_RUN=false
REFRESH_MODE=false

# ── Parse args ────────────────────────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
  case "$1" in
    --account)
      ACCOUNT="$2"
      shift 2
      ;;
    --refresh)
      REFRESH_MODE=true
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --help|-h)
      echo "Usage: zsh scripts/linkedin-auth.sh [--account ken|angie|business] [--dry-run] [--refresh]"
      echo ""
      echo "  --account     Account to authenticate (default: ken)"
      echo "                ken     = Ken Mun personal profile"
      echo "                angie   = Angie personal profile"
      echo "                business = AInchors company page"
      echo "  --refresh     Refresh existing token using stored refresh_token (no browser needed)"
      echo "  --dry-run     Show what would happen without making changes"
      echo "  --help, -h    Show this help"
      exit 0
      ;;
    *)
      echo "❌ Unknown argument: $1" >&2
      echo "Usage: zsh scripts/linkedin-auth.sh [--account ken|angie|business] [--dry-run] [--refresh]" >&2
      exit 1
      ;;
  esac
done

# ── Validate account ──────────────────────────────────────────────────────────

if [[ -z "${ACCOUNT_SCOPES[$ACCOUNT]:-}" ]]; then
  echo "❌ Unknown account: $ACCOUNT. Valid: ken, angie, business" >&2
  exit 1
fi

SCOPES="${ACCOUNT_SCOPES[$ACCOUNT]}"
LABEL="${ACCOUNT_LABELS[$ACCOUNT]}"
KEYCHAIN_PREFIX="${ACCOUNT_KEYCHAIN_PREFIX[$ACCOUNT]}"
STATE_SUFFIX="${ACCOUNT_STATE_SUFFIX[$ACCOUNT]}"
AUTH_STATE_FILE="$STATE_DIR/linkedin-auth${STATE_SUFFIX}.json"

# ── Business product guard (historical note — see CHG-0887) ───────────────
# The AInchors LinkedIn developer app (client ID 86fb2cb4ga03jy) previously had
# only OpenID Connect + Share on LinkedIn products, which blocked business
# (company page) auth. As of 2026-07-15 the Marketing/Advertising API product
# has been approved (CHG-0887 / TKT-1001), so the business account is now
# re-enabled with the read-only Marketing/Advertising API scope set above.
# If Marketing/Advertising product access is later revoked, re-apply the guard
# here (the pre-CHG-0887 block message is preserved in
# scripts/linkedin-auth.sh.bak.CHANGELOG-0887-20260715T081011Z).

# ── Helpers ───────────────────────────────────────────────────────────────────

log()  { echo "  $*"; }
ok()   { echo "✅ $*"; }
err()  { echo "❌ $*" >&2; exit 1; }
warn() { echo "⚠️  $*"; }

# URL-encode a string
urlencode() {
  python3 -c "import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=''))" "$1"
}

# Generate a random state param
random_state() {
  python3 -c "import secrets; print(secrets.token_urlsafe(32))"
}

# ── Dry-run mode ──────────────────────────────────────────────────────────────

if [[ "$DRY_RUN" == "true" ]]; then
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  🧪 DRY RUN — auth preview (no changes made):"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "  Account     : $ACCOUNT ($LABEL)"
  echo "  Scopes      : $SCOPES"
  echo "  State file  : $AUTH_STATE_FILE"
  echo "  Keychain    : ${KEYCHAIN_PREFIX}-access-token"
  echo "              : ${KEYCHAIN_PREFIX}-refresh-token"
  echo ""
  if [[ "$REFRESH_MODE" == "true" ]]; then
    echo "  Mode        : REFRESH (token exchange, no browser needed)"
    echo ""
    echo "  What would happen:"
    echo "    1. Read stored refresh_token from Keychain"
    echo "    2. Call LinkedIn token endpoint for new access_token + refresh_token"
    echo "    3. Update Keychain with new tokens"
    echo "    4. Update state file with new tokenExpiry"
    echo "    5. Verify new token via /v2/userinfo"
    echo ""
  else
    echo "  What would happen:"
    echo "    1. Open LinkedIn OAuth URL in browser"
    echo "    2. Start callback listener on port $CALLBACK_PORT"
    echo "    3. Exchange auth code for tokens"
    echo "    4. Store access token in Keychain (service: ${KEYCHAIN_PREFIX}-access-token)"
    echo "    5. Store refresh token in Keychain (service: ${KEYCHAIN_PREFIX}-refresh-token)"
    echo "    6. Fetch member info from LinkedIn"
    echo "    7. Write state file: $AUTH_STATE_FILE"
    echo ""
  fi
  echo "  ✅ Dry run complete. Remove --dry-run to execute."
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  exit 0
fi

# ── Refresh mode (Atom B — TKT-0743 / CHG-0865) ──────────────────────────────
# Exchanges stored refresh_token for new access_token + refresh_token + expires_in.
# Updates Keychain and state file. Falls back to full OAuth PKCE if no refresh token.

if [[ "$REFRESH_MODE" == "true" ]]; then
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  🔄 REFRESH MODE — $ACCOUNT ($LABEL)"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  # Retrieve refresh token from Keychain
  local REFRESH_TOKEN_SAVED
  REFRESH_TOKEN_SAVED=$(security find-generic-password -a linkedin -s "${KEYCHAIN_PREFIX}-refresh-token" -w 2>/dev/null) || {
    echo "  ⚠️  No refresh token found in Keychain for $ACCOUNT."
    echo "  → Falling back to full OAuth PKCE flow (browser required)."
    echo ""
    # Fall through to full auth below
    REFRESH_MODE=false
  }

  if [[ "$REFRESH_MODE" == "true" && -n "$REFRESH_TOKEN_SAVED" ]]; then
    # Retrieve client credentials
    CLIENT_ID=$(security find-generic-password -a linkedin -s ainchors-linkedin-client-id -w 2>/dev/null) \
      || err "LinkedIn client ID not found in Keychain."
    CLIENT_SECRET=$(security find-generic-password -a linkedin -s ainchors-linkedin-client-secret -w 2>/dev/null) \
      || err "LinkedIn client secret not found in Keychain."

    log "Exchanging refresh token for new access token..."

    local TOKEN_RESPONSE ACCESS_TOKEN NEW_REFRESH_TOKEN EXPIRES_IN TOKEN_ERROR
    TOKEN_RESPONSE=$(curl -s --max-time 30 -X POST "$TOKEN_ENDPOINT" \
      -H "Content-Type: application/x-www-form-urlencoded" \
      --data-urlencode "grant_type=refresh_token" \
      --data-urlencode "refresh_token=$REFRESH_TOKEN_SAVED" \
      --data-urlencode "client_id=$CLIENT_ID" \
      --data-urlencode "client_secret=$CLIENT_SECRET" 2>/dev/null)

    ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('access_token', ''))
except:
    print('')" 2>/dev/null)

    NEW_REFRESH_TOKEN=$(echo "$TOKEN_RESPONSE" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('refresh_token', ''))
except:
    print('')" 2>/dev/null)

    EXPIRES_IN=$(echo "$TOKEN_RESPONSE" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('expires_in', 0))
except:
    print(0)" 2>/dev/null)

    TOKEN_ERROR=$(echo "$TOKEN_RESPONSE" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('error', ''))
except:
    print('')" 2>/dev/null)

    if [[ -n "$TOKEN_ERROR" && "$TOKEN_ERROR" != "None" ]] || [[ -z "$ACCESS_TOKEN" ]]; then
      echo "  ❌ Refresh failed: ${TOKEN_ERROR:-empty_access_token}"
      echo "  → Falling back to full OAuth PKCE flow (browser required)."
      echo ""
      REFRESH_MODE=false
    else
      ok "New access token received."

      # Store new access token
      security add-generic-password -a linkedin -s "${KEYCHAIN_PREFIX}-access-token" -w "$ACCESS_TOKEN" -U \
        || err "Failed to store access token in Keychain."

      # Store new refresh token if issued (rotation)
      if [[ -n "$NEW_REFRESH_TOKEN" && "$NEW_REFRESH_TOKEN" != "None" ]]; then
        security add-generic-password -a linkedin -s "${KEYCHAIN_PREFIX}-refresh-token" -w "$NEW_REFRESH_TOKEN" -U \
          || warn "Failed to store new refresh token."
        ok "Refresh token rotated."
      fi

      # Calculate new expiry
      local NEW_EXPIRY NEW_AUTHORIZED_AT
      NEW_EXPIRY=$(python3 -c "
from datetime import datetime, timezone, timedelta
expiry = datetime.now(timezone.utc) + timedelta(seconds=int(${EXPIRES_IN:-0}))
print(expiry.strftime('%Y-%m-%dT%H:%M:%SZ'))
" 2>/dev/null)
      NEW_AUTHORIZED_AT=$(python3 -c "
from datetime import datetime, timezone
print(datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'))
" 2>/dev/null)

      # Update state file with new expiry and refreshTokenPresent.
      # CHG-0987 / TKT-1035: refreshTokenPresent must reflect whether
      # LinkedIn actually issued a NEW refresh token in this response, not
      # the previous state. LinkedIn does not always rotate refresh tokens,
      # and the previous version of this block hard-coded True, leaving
      # the state file stale and triggering TKT-1002 follow-up work.
      if [[ -f "$AUTH_STATE_FILE" && -n "$NEW_EXPIRY" ]]; then
        if [[ -n "$NEW_REFRESH_TOKEN" && "$NEW_REFRESH_TOKEN" != "None" ]]; then
          REFRESH_PRESENT_PY="True"
        else
          REFRESH_PRESENT_PY="False"
        fi
        python3 -c "
import json
with open('$AUTH_STATE_FILE') as f:
    d = json.load(f)
d['authorizedAt'] = '$NEW_AUTHORIZED_AT'
d['tokenExpiry'] = '$NEW_EXPIRY'
d['refreshTokenPresent'] = $REFRESH_PRESENT_PY
with open('$AUTH_STATE_FILE', 'w') as f:
    json.dump(d, f, indent=2)
" 2>/dev/null || true
      fi

      # Verify new token works
      log "Verifying new token via /v2/userinfo..."
      local VERIFY_RESPONSE
      VERIFY_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" \
        -X GET "$USERINFO_ENDPOINT" \
        -H "Authorization: Bearer $ACCESS_TOKEN" \
        -H "LinkedIn-Version: 202503" 2>/dev/null)

      if [[ "$VERIFY_RESPONSE" == "200" ]]; then
        ok "Token verified — LinkedIn API accessible."
      else
        warn "Token refresh completed but verification returned HTTP $VERIFY_RESPONSE."
      fi

      # ── Summary ──────────────────────────────────────────────────────────
      echo ""
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo "  ✅ Token refresh complete!"
      echo ""
      echo "  Account    : $ACCOUNT ($LABEL)"
      echo "  Token valid: until $NEW_EXPIRY"
      echo ""
      echo "  Tokens stored securely in macOS Keychain."
      echo "  State file: $AUTH_STATE_FILE"
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      exit 0
    fi
  fi
fi

# ── Retrieve credentials from Keychain ────────────────────────────────────────

log "Retrieving LinkedIn credentials from Keychain..."

CLIENT_ID=$(security find-generic-password -a linkedin -s ainchors-linkedin-client-id -w 2>/dev/null) \
  || err "LinkedIn client ID not found in Keychain. Run: security add-generic-password -a linkedin -s ainchors-linkedin-client-id -w 'YOUR_CLIENT_ID'"

CLIENT_SECRET=$(security find-generic-password -a linkedin -s ainchors-linkedin-client-secret -w 2>/dev/null) \
  || err "LinkedIn client secret not found in Keychain. Run: security add-generic-password -a linkedin -s ainchors-linkedin-client-secret -w 'YOUR_CLIENT_SECRET'"

ok "Credentials loaded from Keychain."

# ── Build auth URL ─────────────────────────────────────────────────────────────

STATE=$(random_state)

SCOPE_ENCODED=$(urlencode "$SCOPES")
REDIRECT_ENCODED=$(urlencode "$REDIRECT_URI")

AUTH_URL="${AUTH_ENDPOINT}?response_type=code"
AUTH_URL+="&client_id=${CLIENT_ID}"
AUTH_URL+="&redirect_uri=${REDIRECT_ENCODED}"
AUTH_URL+="&scope=${SCOPE_ENCODED}"
AUTH_URL+="&state=${STATE}"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  STEP 1 — Open this URL in your browser:"
echo ""
echo "  $AUTH_URL"
echo ""
echo "  LinkedIn will redirect to: $REDIRECT_URI"
echo "  Account: $ACCOUNT ($LABEL)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Try to auto-open browser (non-blocking, won't fail if it can't)
if command -v open &>/dev/null; then
  open "$AUTH_URL" 2>/dev/null && log "Browser opened automatically." || warn "Could not auto-open browser. Copy the URL above manually."
else
  warn "open not available — copy the URL above manually."
fi

# ── Start local callback server ───────────────────────────────────────────────

log "Starting callback listener on port $CALLBACK_PORT..."

# Use Python to capture callback (more reliable than nc for parsing)
CALLBACK_RESULT=$(python3 - "$CALLBACK_PORT" "$STATE" <<'PYEOF'
import sys, socket, urllib.parse

port = int(sys.argv[1])
expected_state = sys.argv[2]

srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
srv.bind(('127.0.0.1', port))
srv.listen(1)
print(f"  Listening on port {port}...", file=sys.stderr)

conn, addr = srv.accept()
request = b""
while True:
    chunk = conn.recv(4096)
    request += chunk
    if b"\r\n\r\n" in request:
        break

# Send a nice response back
response_body = b"<html><body><h2>LinkedIn authorised! You can close this tab.</h2></body></html>"
http_response = (
    b"HTTP/1.1 200 OK\r\n"
    b"Content-Type: text/html\r\n"
    b"Connection: close\r\n\r\n" + response_body
)
conn.sendall(http_response)
conn.close()
srv.close()

# Parse the request line
first_line = request.split(b"\r\n")[0].decode()
# e.g. GET /callback?code=...&state=... HTTP/1.1
path = first_line.split(" ")[1]
qs = urllib.parse.parse_qs(urllib.parse.urlparse(path).query)

code = qs.get("code", [None])[0]
state = qs.get("state", [None])[0]
error = qs.get("error", [None])[0]
error_desc = qs.get("error_description", [None])[0]

if error:
    print(f"ERROR:{error}:{error_desc or ''}")
    sys.exit(1)

if state != expected_state:
    print(f"STATE_MISMATCH:{state}")
    sys.exit(1)

print(f"CODE:{code}")
PYEOF
)

if [[ "$CALLBACK_RESULT" == ERROR:* ]]; then
  err "OAuth error: ${CALLBACK_RESULT#ERROR:}"
fi

if [[ "$CALLBACK_RESULT" == STATE_MISMATCH:* ]]; then
  err "State mismatch — possible CSRF. Aborting."
fi

AUTH_CODE="${CALLBACK_RESULT#CODE:}"
ok "Authorisation code received."

# ── Exchange code for tokens ───────────────────────────────────────────────────

log "Exchanging code for access token..."
log "Auth code length: ${#AUTH_CODE}"

TOKEN_RESPONSE=$(curl -s --max-time 30 -X POST "$TOKEN_ENDPOINT" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --data-urlencode "grant_type=authorization_code" \
  --data-urlencode "code=$AUTH_CODE" \
  --data-urlencode "redirect_uri=$REDIRECT_URI" \
  --data-urlencode "client_id=$CLIENT_ID" \
  --data-urlencode "client_secret=$CLIENT_SECRET" \
)

# Parse fields
ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('access_token',''))")
REFRESH_TOKEN=$(echo "$TOKEN_RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('refresh_token',''))")
EXPIRES_IN=$(echo "$TOKEN_RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('expires_in',0))")
TOKEN_ERROR=$(echo "$TOKEN_RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('error',''))")

log "Token response: $TOKEN_RESPONSE"

if [[ -n "$TOKEN_ERROR" && "$TOKEN_ERROR" != "None" ]]; then
  err "Token exchange failed: $TOKEN_RESPONSE"
fi

if [[ -z "$ACCESS_TOKEN" ]]; then
  err "No access token in response: $TOKEN_RESPONSE"
fi

ok "Tokens received."

# ── Store tokens in Keychain (per-account) ────────────────────────────────────

log "Storing access token in Keychain (service: ${KEYCHAIN_PREFIX}-access-token)..."
security add-generic-password -a linkedin -s "${KEYCHAIN_PREFIX}-access-token" -w "$ACCESS_TOKEN" -U \
  || err "Failed to store access token in Keychain."

if [[ -n "$REFRESH_TOKEN" && "$REFRESH_TOKEN" != "None" ]]; then
  log "Storing refresh token in Keychain (service: ${KEYCHAIN_PREFIX}-refresh-token)..."
  security add-generic-password -a linkedin -s "${KEYCHAIN_PREFIX}-refresh-token" -w "$REFRESH_TOKEN" -U \
    || warn "Failed to store refresh token (LinkedIn may not have issued one — that's OK)."
else
  warn "No refresh token issued by LinkedIn (standard for personal OAuth apps)."
fi

ok "Tokens stored in Keychain."

# ── Get member ID via userinfo ─────────────────────────────────────────────────

log "Fetching member info from LinkedIn..."

USERINFO_RESPONSE=$(curl -s "$USERINFO_ENDPOINT" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "LinkedIn-Version: 202503")

MEMBER_ID=$(echo "$USERINFO_RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('sub',''))")
DISPLAY_NAME=$(echo "$USERINFO_RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('name','unknown'))")

if [[ -z "$MEMBER_ID" || "$MEMBER_ID" == "None" ]]; then
  err "Failed to retrieve member ID. Response: $USERINFO_RESPONSE"
fi

ok "Member ID: $MEMBER_ID ($DISPLAY_NAME)"

# ── Calculate token expiry ─────────────────────────────────────────────────────

TOKEN_EXPIRY=$(python3 -c "
from datetime import datetime, timezone, timedelta
expiry = datetime.now(timezone.utc) + timedelta(seconds=int($EXPIRES_IN))
print(expiry.strftime('%Y-%m-%dT%H:%M:%SZ'))
")

AUTHORIZED_AT=$(python3 -c "
from datetime import datetime, timezone
print(datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'))
")

# ── Write state file (no secrets) ─────────────────────────────────────────────

mkdir -p "$STATE_DIR"

python3 -c "
import json
data = {
    'account': '$ACCOUNT',
    'memberId': '$MEMBER_ID',
    'displayName': '$DISPLAY_NAME',
    'authorizedAt': '$AUTHORIZED_AT',
    'scopes': '${SCOPES}'.split(),
    'tokenExpiry': '$TOKEN_EXPIRY',
    'refreshTokenPresent': $([ -n "$REFRESH_TOKEN" ] && [ "$REFRESH_TOKEN" != "None" ] && echo 'True' || echo 'False')
}
with open('$AUTH_STATE_FILE', 'w') as f:
    json.dump(data, f, indent=2)
print('  Written:', '$AUTH_STATE_FILE')
"

ok "Auth state saved to $AUTH_STATE_FILE (no secrets stored)."

# ── Summary ────────────────────────────────────────────────────────────────────

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ LinkedIn OAuth complete!"
echo ""
echo "  Account    : $ACCOUNT ($LABEL)"
echo "  Member ID  : $MEMBER_ID"
echo "  Name       : $DISPLAY_NAME"
echo "  Scopes     : $SCOPES"
echo "  Token valid: until $TOKEN_EXPIRY"
echo ""
echo "  Tokens stored securely in macOS Keychain."
echo "  State file: $AUTH_STATE_FILE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
