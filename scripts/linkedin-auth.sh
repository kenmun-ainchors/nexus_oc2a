#!/usr/bin/env zsh
# linkedin-auth.sh — LinkedIn OAuth 2.0 PKCE flow for AInchors
# Requires Ken to open the auth URL in a browser manually.
# Stores tokens in macOS Keychain ONLY. No secrets in files.
#
# Usage: bash scripts/linkedin-auth.sh

set -euo pipefail

WORKSPACE="/Users/ainchorsangiefpl/.openclaw/workspace"
STATE_DIR="$WORKSPACE/state"
AUTH_STATE_FILE="$STATE_DIR/linkedin-auth.json"

REDIRECT_URI="http://localhost:8765/callback"
SCOPES="openid profile email w_member_social r_basicprofile r_1st_connections_size r_organization_social r_organization_admin r_ads_reporting r_ads"
AUTH_ENDPOINT="https://www.linkedin.com/oauth/v2/authorization"
TOKEN_ENDPOINT="https://www.linkedin.com/oauth/v2/accessToken"
USERINFO_ENDPOINT="https://api.linkedin.com/v2/userinfo"
CALLBACK_PORT=8765

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

# Generate PKCE code verifier (43-128 chars, URL-safe base64)
pkce_verifier() {
  python3 -c "import secrets, base64; v=secrets.token_bytes(48); print(base64.urlsafe_b64encode(v).rstrip(b'=').decode())"
}

# Generate PKCE code challenge (S256)
pkce_challenge() {
  local verifier="$1"
  python3 -c "
import sys, hashlib, base64
v = sys.argv[1].encode()
digest = hashlib.sha256(v).digest()
challenge = base64.urlsafe_b64encode(digest).rstrip(b'=').decode()
print(challenge)
" "$verifier"
}

# ── Retrieve credentials from Keychain ────────────────────────────────────────

log "Retrieving LinkedIn credentials from Keychain..."

CLIENT_ID=$(security find-generic-password -a linkedin -s ainchors-linkedin-client-id -w 2>/dev/null) \
  || err "LinkedIn client ID not found in Keychain. Run: security add-generic-password -a linkedin -s ainchors-linkedin-client-id -w 'YOUR_CLIENT_ID'"

CLIENT_SECRET=$(security find-generic-password -a linkedin -s ainchors-linkedin-client-secret -w 2>/dev/null) \
  || err "LinkedIn client secret not found in Keychain. Run: security add-generic-password -a linkedin -s ainchors-linkedin-client-secret -w 'YOUR_CLIENT_SECRET'"

ok "Credentials loaded from Keychain."

# ── Build auth URL ─────────────────────────────────────────────────────────────

STATE=$(random_state)
# PKCE disabled — using standard OAuth with client_secret (web app flow)
# CODE_VERIFIER and CODE_CHALLENGE removed

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

# ── Store tokens in Keychain ───────────────────────────────────────────────────

log "Storing access token in Keychain..."
security add-generic-password -a linkedin -s ainchors-linkedin-access-token -w "$ACCESS_TOKEN" -U \
  || err "Failed to store access token in Keychain."

if [[ -n "$REFRESH_TOKEN" && "$REFRESH_TOKEN" != "None" ]]; then
  log "Storing refresh token in Keychain..."
  security add-generic-password -a linkedin -s ainchors-linkedin-refresh-token -w "$REFRESH_TOKEN" -U \
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
    'memberId': '$MEMBER_ID',
    'displayName': '$DISPLAY_NAME',
    'authorizedAt': '$AUTHORIZED_AT',
    'scopes': ['openid', 'profile', 'email', 'w_member_social', 'r_basicprofile', 'r_1st_connections_size', 'r_organization_social', 'r_organization_admin', 'r_ads_reporting', 'r_ads'],
    'tokenExpiry': '$TOKEN_EXPIRY'
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
echo "  Member ID  : $MEMBER_ID"
echo "  Name       : $DISPLAY_NAME"
echo "  Scopes     : $SCOPES"
echo "  Token valid: until $TOKEN_EXPIRY"
echo ""
echo "  Tokens stored securely in macOS Keychain."
echo "  State file: $AUTH_STATE_FILE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
