#!/usr/bin/env zsh
# linkedin-post.sh — Post text content to LinkedIn
# Supports multi-account posting: Ken personal (default), Angie personal, AInchors company page.
# Uses newer LinkedIn Posts API (REST) format.
#
# CHG-0766 / TKT-0743: Token health probe with auto-refresh before posting.
#   - Probes token via GET /v2/userinfo before building payload.
#   - On 401/revoked/expired: attempts refresh_token exchange.
#   - On refresh failure: emits clear re-auth command.
#   - Logs every probe result to state/linkedin-token-health-{account}.json.
#
# Usage:
#   linkedin-post.sh --text "post content" [--visibility PUBLIC|CONNECTIONS] [--image-asset-urn urn:li:image:XXX] [--dry-run]
#   linkedin-post.sh --content-file /path/to/draft.md [--image-asset-urn urn:li:image:XXX] [--dry-run]
#   zsh scripts/linkedin-post.sh --account angie --content-file /path/to/draft.md
#   zsh scripts/linkedin-post.sh --account business --organization-id 12345678 --content-file /path/to/draft.md
#
# Image workflow (TKT-0121):
#   1. Generate image:  zsh scripts/hf-generate-image.sh --prompt "..." → /path/to/image.jpg
#   2. Upload to LI:    zsh scripts/linkedin-upload-image.sh --image-file /path/to/image.jpg → urn:li:image:XXX
#   3. Attach to post:  zsh scripts/linkedin-post.sh --content-file draft.md --image-asset-urn urn:li:image:XXX
#
# Requirements:
#   - Run linkedin-auth.sh first to obtain and store tokens
#   - state/linkedin-auth.json (or -angie.json, -business.json) must exist with memberId

set -euo pipefail

WORKSPACE="/Users/ainchorsangiefpl/.openclaw/workspace"
# LinkedIn auth state lives in PG state_linkedin table — use db-read.sh as SSOT
DB_READ="$WORKSPACE/scripts/db-read.sh"
POSTS_ENDPOINT="https://api.linkedin.com/rest/posts"

# ── Account configuration ──────────────────────────────────────────────────────

# Maps account name → Keychain service prefix, state file suffix, author type
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

# ── Token health probe (CHG-0766 / TKT-0743) ─────────────────────────────────

USERINFO_ENDPOINT="https://api.linkedin.com/v2/userinfo"
TOKEN_ENDPOINT="https://www.linkedin.com/oauth/v2/accessToken"

# Probe token health with a lightweight GET to /v2/userinfo
# Returns: "ok" | "refresh_ok" | "refresh_failed" | "revoked"
probe_token_health() {
  local token="$1"
  local account="$2"
  local label="$3"

  local probe_response probe_http_status probe_body
  probe_response=$(curl -s -w "\n__HTTP_STATUS__%{http_code}" \
    -X GET "$USERINFO_ENDPOINT" \
    -H "Authorization: Bearer $token" \
    -H "LinkedIn-Version: 202503" 2>/dev/null)
  probe_http_status=$(echo "$probe_response" | grep "__HTTP_STATUS__" | sed 's/__HTTP_STATUS__//')
  probe_body=$(echo "$probe_response" | grep -v "__HTTP_STATUS__")

  if [[ "$probe_http_status" == "200" ]]; then
    log_token_health "$account" "ok" "200" "" ""
    echo "ok"
    return 0
  fi

  # Extract LinkedIn error code from response body
  local linkedin_error
  linkedin_error=$(echo "$probe_body" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('error', d.get('serviceErrorCode', d.get('message', ''))))
except:
    print('')
" 2>/dev/null)

  if [[ "$probe_http_status" == "401" ]]; then
    # Check for revoke/expire indicators
    if echo "$probe_body" | grep -qiE "REVOKED_ACCESS_TOKEN|EXPIRED_ACCESS_TOKEN|invalid_token"; then
      log_token_health "$account" "revoked" "401" "$linkedin_error" ""
      echo "revoked"
      return 0
    fi
    log_token_health "$account" "revoked" "401" "$linkedin_error" ""
    echo "revoked"
    return 0
  fi

  # Non-401 error (network, 5xx, etc.) — treat as revoked to trigger refresh attempt
  log_token_health "$account" "revoked" "$probe_http_status" "$linkedin_error" ""
  echo "revoked"
  return 0
}

# Attempt refresh_token exchange
# Returns: "ok" on success, "failed" on failure
refresh_access_token() {
  local account="$1"
  local keychain_prefix="$2"
  local state_suffix="$3"
  local label="$4"

  local refresh_token client_id client_secret

  refresh_token=$(security find-generic-password -a linkedin -s "${keychain_prefix}-refresh-token" -w 2>/dev/null) || {
    log_token_health "$account" "refresh_failed" "" "no_refresh_token" ""
    echo "failed"
    return 1
  }

  client_id=$(security find-generic-password -a linkedin -s "ainchors-linkedin-client-id" -w 2>/dev/null) || {
    log_token_health "$account" "refresh_failed" "" "no_client_id" ""
    echo "failed"
    return 1
  }

  client_secret=$(security find-generic-password -a linkedin -s "ainchors-linkedin-client-secret" -w 2>/dev/null) || {
    log_token_health "$account" "refresh_failed" "" "no_client_secret" ""
    echo "failed"
    return 1
  }

  local token_response access_token new_refresh_token expires_in token_error
  token_response=$(curl -s --max-time 30 -X POST "$TOKEN_ENDPOINT" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    --data-urlencode "grant_type=refresh_token" \
    --data-urlencode "refresh_token=$refresh_token" \
    --data-urlencode "client_id=$client_id" \
    --data-urlencode "client_secret=$client_secret" 2>/dev/null)

  access_token=$(echo "$token_response" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('access_token', ''))
except:
    print('')
" 2>/dev/null)

  new_refresh_token=$(echo "$token_response" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('refresh_token', ''))
except:
    print('')
" 2>/dev/null)

  expires_in=$(echo "$token_response" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('expires_in', 0))
except:
    print(0)
" 2>/dev/null)

  token_error=$(echo "$token_response" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('error', ''))
except:
    print('')
" 2>/dev/null)

  if [[ -n "$token_error" && "$token_error" != "None" ]] || [[ -z "$access_token" ]]; then
    log_token_health "$account" "refresh_failed" "" "${token_error:-empty_access_token}" ""
    echo "failed"
    return 1
  fi

  # Store new access token
  security add-generic-password -a linkedin -s "${keychain_prefix}-access-token" -w "$access_token" -U 2>/dev/null || {
    log_token_health "$account" "refresh_failed" "" "keychain_write_failed" ""
    echo "failed"
    return 1
  }

  # Store new refresh token if issued (rotation)
  if [[ -n "$new_refresh_token" && "$new_refresh_token" != "None" ]]; then
    security add-generic-password -a linkedin -s "${keychain_prefix}-refresh-token" -w "$new_refresh_token" -U 2>/dev/null || true
  fi

  # Update state file with new expiry
  local new_expiry authorized_at
  new_expiry=$(python3 -c "
from datetime import datetime, timezone, timedelta
expiry = datetime.now(timezone.utc) + timedelta(seconds=int(${expires_in:-0}))
print(expiry.strftime('%Y-%m-%dT%H:%M:%SZ'))
" 2>/dev/null)
  authorized_at=$(python3 -c "
from datetime import datetime, timezone
print(datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'))
" 2>/dev/null)

  local auth_state_file="$WORKSPACE/state/linkedin-auth${state_suffix}.json"
  if [[ -f "$auth_state_file" && -n "$new_expiry" ]]; then
    python3 -c "
import json
with open('$auth_state_file') as f:
    d = json.load(f)
d['authorizedAt'] = '$authorized_at'
d['tokenExpiry'] = '$new_expiry'
with open('$auth_state_file', 'w') as f:
    json.dump(d, f, indent=2)
" 2>/dev/null || true
  fi

  log_token_health "$account" "refresh_ok" "" "" ""
  echo "ok"
  return 0
}

# Log token health probe result to state file
log_token_health() {
  local account="$1"
  local health_status="$2"
  local http_status="$3"
  local linkedin_error="$4"
  local message_id_hint="$5"

  local health_file="$WORKSPACE/state/linkedin-token-health-${account}.json"
  local checked_at
  checked_at=$(python3 -c "
from datetime import datetime, timezone
print(datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'))
" 2>/dev/null)

  python3 -c "
import json
entry = {
    'checkedAt': '$checked_at',
    'account': '$account',
    'status': '$health_status',
    'httpStatus': '$http_status',
    'linkedInErrorCode': '$linkedin_error',
    'messageIdHint': '$message_id_hint',
    'nextAction': ''
}
# Append to array in health file, or create new array
import os
if os.path.exists('$health_file'):
    with open('$health_file') as f:
        try:
            records = json.load(f)
            if not isinstance(records, list):
                records = [records]
        except:
            records = []
else:
    records = []
records.append(entry)
with open('$health_file', 'w') as f:
    json.dump(records, f, indent=2)
" 2>/dev/null || true
}

# ── Defaults ──────────────────────────────────────────────────────────────────

POST_TEXT=""
CONTENT_FILE=""
VISIBILITY="PUBLIC"
IMAGE_ASSET_URN=""
DRY_RUN=false
ACCOUNT="ken"
ORGANIZATION_ID=""
QUEUE_CONTENT_ID=""

# ── Parse args ────────────────────────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
  case "$1" in
    --text)
      POST_TEXT="$2"
      shift 2
      ;;
    --content-file)
      # Preferred over --text: reads from file, no shell arg truncation on multiline content
      CONTENT_FILE="$2"
      shift 2
      ;;
    --visibility)
      VISIBILITY="$(echo "$2" | tr '[:lower:]' '[:upper:]')"   # uppercase
      shift 2
      ;;
    --image-asset-urn)
      # LinkedIn image asset URN (e.g. urn:li:image:XXXXX) — attach image to post
      IMAGE_ASSET_URN="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --queue-content-id)
      # Optional: content ID to update in linkedin-campaign.json with the activity URN after posting
      QUEUE_CONTENT_ID="$2"
      shift 2
      ;;
    --account)
      ACCOUNT="$2"
      shift 2
      ;;
    --organization-id)
      # LinkedIn organization ID for company page posts (required for --account business)
      ORGANIZATION_ID="$2"
      shift 2
      ;;
    --help|-h)
      echo "Usage: linkedin-post.sh [options]"
      echo ""
      echo "  --content-file <path>     Draft markdown file with post content (preferred)"
      echo "  --text <text>             Post text directly (use --content-file for multi-line)"
      echo "  --visibility <mode>       PUBLIC (default) or CONNECTIONS"
      echo "  --image-asset-urn <urn>   Attach image by LinkedIn asset URN"
      echo "  --dry-run                 Preview payload without posting"
      echo "  --queue-content-id <id>   Update campaign JSON with post URN after posting"
      echo "  --account <name>          Account to post as: ken (default), angie, business"
      echo "  --organization-id <id>    LinkedIn org ID (required for --account business)"
      echo "  --help, -h                Show this help"
      exit 0
      ;;
    *)
      echo "❌ Unknown argument: $1" >&2
      echo "Usage: linkedin-post.sh --content-file draft.md [--image-asset-urn urn:li:image:XXX] [--visibility PUBLIC|CONNECTIONS] [--dry-run] [--queue-content-id LI-C1-W2-P3] [--account ken|angie|business] [--organization-id ORG_ID]" >&2
      exit 1
      ;;
  esac
done

# ── Validate account ──────────────────────────────────────────────────────────

if [[ -z "${ACCOUNT_KEYCHAIN_PREFIX[$ACCOUNT]:-}" ]]; then
  echo "❌ Unknown account: $ACCOUNT. Valid: ken, angie, business" >&2
  exit 1
fi

if [[ "$ACCOUNT" == "business" && -z "$ORGANIZATION_ID" ]]; then
  echo "❌ --organization-id is required when --account is 'business'" >&2
  echo "   Usage: linkedin-post.sh --account business --organization-id 12345678 --content-file draft.md" >&2
  exit 1
fi

KEYCHAIN_PREFIX="${ACCOUNT_KEYCHAIN_PREFIX[$ACCOUNT]}"
STATE_SUFFIX="${ACCOUNT_STATE_SUFFIX[$ACCOUNT]}"
LABEL="${ACCOUNT_LABELS[$ACCOUNT]}"
AUTH_STATE_FILE="$WORKSPACE/state/linkedin-auth${STATE_SUFFIX}.json"

# ── Validate ──────────────────────────────────────────────────────────────────

# Prefer --content-file (safe for multi-line) over --text
if [[ -n "$CONTENT_FILE" ]]; then
  if [[ ! -f "$CONTENT_FILE" ]]; then
    echo "❌ --content-file not found: $CONTENT_FILE" >&2; exit 1
  fi
  POST_TEXT=$(python3 -c "
import sys
with open(sys.argv[1]) as f:
    content = f.read()
# Extract clean body between --- delimiters, stop at ## Hashtags/## Metadata
lines = content.split('\n')
body, in_body, hashtag_line, found_delimiters = [], False, '', False
for line in lines:
    s = line.strip()
    if s == '---':
        in_body = not in_body
        found_delimiters = True
        continue
    if in_body:
        if s.startswith('## Hashtags') or s.startswith('## Metadata'): break
        # Skip section marker headings (## DRAFT, ## CONTENT, etc.) — not post content
        if s.startswith('## '): continue
        if s.startswith('#') and not s.startswith('##'):
            hashtag_line = line
        body.append(line)
if not found_delimiters:
    print('ERROR: No --- delimiters found in content file. Cannot post. Wrap post body in --- delimiters.', file=sys.stderr)
    sys.exit(1)
if not body:
    print('ERROR: No content found between --- delimiters.', file=sys.stderr)
    sys.exit(1)
if hashtag_line and hashtag_line not in body:
    body.append(hashtag_line)
print('\n'.join(body).strip())
" "$CONTENT_FILE")
elif [[ -z "$POST_TEXT" ]]; then
  echo "❌ --content-file or --text required." >&2; exit 1
fi

if [[ "$VISIBILITY" != "PUBLIC" && "$VISIBILITY" != "CONNECTIONS" ]]; then
  echo "❌ --visibility must be PUBLIC or CONNECTIONS (got: $VISIBILITY)" >&2
  exit 1
fi

# ── Pre-flight content validation ────────────────────────────────────────────────────────────────────────────────────

# TKT-0126: em dash check — bot signal per SPARK_RULES.md. Block before API call.
if echo "$POST_TEXT" | python3 -c "
import sys
text = sys.stdin.read()
em_dashes = [i for i, c in enumerate(text) if c == '\u2014']
if em_dashes:
    print(f'ERROR: Em dash (\u2014) found at positions: {em_dashes[:5]}', file=sys.stderr)
    print('Replace with hyphen (-) before posting. Em dashes are a bot signal.', file=sys.stderr)
    sys.exit(1)
" 2>&1; then
  : # clean
else
  echo "❌ Content validation failed — em dash (\u2014) detected in post text." >&2
  echo "   Replace all \u2014 with hyphen (-) per SPARK_RULES.md." >&2
  exit 1
fi

if [[ ! -f "$AUTH_STATE_FILE" ]]; then
  echo "❌ Auth state not found: $AUTH_STATE_FILE" >&2
  echo "   Run: zsh scripts/linkedin-auth.sh --account $ACCOUNT" >&2
  exit 1
fi

# ── Load member ID ────────────────────────────────────────────────────────────

MEMBER_ID=$(python3 -c "
import json, sys
with open('$AUTH_STATE_FILE') as f:
    d = json.load(f)
mid = d.get('memberId', '')
if not mid:
    print('', end='')
else:
    print(mid, end='')
")

if [[ -z "$MEMBER_ID" ]]; then
  echo "❌ memberId missing from $AUTH_STATE_FILE. Re-run: zsh scripts/linkedin-auth.sh --account $ACCOUNT" >&2
  exit 1
fi

# ── Check token expiry ────────────────────────────────────────────────────────

TOKEN_EXPIRY=$(python3 -c "
import json
with open('$AUTH_STATE_FILE') as f:
    d = json.load(f)
print(d.get('tokenExpiry', ''))
")

if [[ -n "$TOKEN_EXPIRY" ]]; then
  EXPIRED=$(python3 -c "
from datetime import datetime, timezone
from datetime import timezone; expiry = datetime.fromisoformat('$TOKEN_EXPIRY'.replace('Z','').split('+')[0]).replace(tzinfo=timezone.utc)
now = datetime.now(timezone.utc)
print('yes' if now >= expiry else 'no')
")
  if [[ "$EXPIRED" == "yes" ]]; then
    echo "❌ Token expired — re-run: zsh scripts/linkedin-auth.sh --account $ACCOUNT" >&2
    exit 1
  fi
fi

# ── Retrieve access token from Keychain (per-account) ──────────────────────────

ACCESS_TOKEN=$(security find-generic-password -a linkedin -s "${KEYCHAIN_PREFIX}-access-token" -w 2>/dev/null) \
  || { echo "❌ Access token not found in Keychain (service: ${KEYCHAIN_PREFIX}-access-token) — re-run: zsh scripts/linkedin-auth.sh --account $ACCOUNT" >&2; exit 1; }

# ── Token health probe (CHG-0766 / TKT-0743) ─────────────────────────────────
# Probe token before building payload. Dry-run skips this entirely.

if [[ "$DRY_RUN" != "true" ]]; then
  echo "  Probing token health for $LABEL..."
  HEALTH_STATUS=$(probe_token_health "$ACCESS_TOKEN" "$ACCOUNT" "$LABEL")

  if [[ "$HEALTH_STATUS" == "revoked" ]]; then
    echo "  ⚠️  Token revoked or expired — attempting refresh..."
    REFRESH_STATUS=$(refresh_access_token "$ACCOUNT" "$KEYCHAIN_PREFIX" "$STATE_SUFFIX" "$LABEL")

    if [[ "$REFRESH_STATUS" == "ok" ]]; then
      echo "  ✅ Token refreshed successfully."
      # Reload the new access token from Keychain
      ACCESS_TOKEN=$(security find-generic-password -a linkedin -s "${KEYCHAIN_PREFIX}-access-token" -w 2>/dev/null) \
        || { echo "❌ Failed to reload refreshed access token from Keychain." >&2; exit 1; }
    else
      echo "❌ Token refresh failed for $LABEL." >&2
      echo "   Re-run: zsh scripts/linkedin-auth.sh --account $ACCOUNT" >&2
      exit 1
    fi
  elif [[ "$HEALTH_STATUS" == "ok" ]]; then
    echo "  ✅ Token health OK."
  else
    echo "  ⚠️  Token probe returned: $HEALTH_STATUS — continuing anyway."
  fi
fi

# ── Build post payload ────────────────────────────────────────────────────────

# Determine author URN based on account type
if [[ "$ACCOUNT" == "business" ]]; then
  # Company page post: author is the organization
  AUTHOR_URN="urn:li:organization:$ORGANIZATION_ID"
else
  # Personal profile post: author is the person
  AUTHOR_URN="urn:li:person:$MEMBER_ID"
fi

# Map visibility: CONNECTIONS → "CONNECTIONS", PUBLIC → "PUBLIC"
# Clean up any stale payload files from previous runs (mktemp collision guard)
rm -f /tmp/li_payload_*.json 2>/dev/null || true
PAYLOAD_FILE=$(mktemp /tmp/li_payload_XXXXXX.json)

python3 - "$POST_TEXT" "$VISIBILITY" "$AUTHOR_URN" "$PAYLOAD_FILE" "$IMAGE_ASSET_URN" "$ACCOUNT" << 'PYEOF'
import json, sys

text = sys.argv[1]
visibility = sys.argv[2]
author_urn = sys.argv[3]
out_file = sys.argv[4]
image_urn = sys.argv[5] if len(sys.argv) > 5 else ''
account = sys.argv[6] if len(sys.argv) > 6 else 'ken'

payload = {
    'author': author_urn,
    'commentary': text,
    'visibility': visibility,
    'distribution': {
        'feedDistribution': 'MAIN_FEED',
        'targetEntities': [],
        'thirdPartyDistributionChannels': []
    },
    'lifecycleState': 'PUBLISHED',
    'isReshareDisabledByAuthor': False
}

# Attach image if asset URN provided (TKT-0121: HF FLUX.1-schnell integration)
if image_urn:
    payload['content'] = {
        'media': {
            'id': image_urn
        }
    }

with open(out_file, 'w', encoding='utf-8') as f:
    json.dump(payload, f, ensure_ascii=False, indent=2)
PYEOF

# Also capture payload string for dry-run preview
PAYLOAD=$(cat "$PAYLOAD_FILE")

# ── Dry-run mode ──────────────────────────────────────────────────────────────

if [[ "$DRY_RUN" == "true" ]]; then
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  🧪 DRY RUN — payload preview (no API call made):"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "  Endpoint    : POST $POSTS_ENDPOINT"
  echo "  Account     : $ACCOUNT ($LABEL)"
  echo "  Author URN  : $AUTHOR_URN"
  echo "  Visibility  : $VISIBILITY"
  if [[ -n "$IMAGE_ASSET_URN" ]]; then
    echo "  Image URN   : $IMAGE_ASSET_URN"
  fi
  if [[ "$ACCOUNT" == "business" ]]; then
    echo "  Org ID      : $ORGANIZATION_ID"
  fi
  echo ""
  echo "  Payload:"
  echo "$PAYLOAD" | sed 's/^/    /'
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  ✅ Dry run complete. Remove --dry-run to post for real."
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  exit 0
fi

# ── Post to LinkedIn ──────────────────────────────────────────────────────────

echo "  Posting to LinkedIn as $LABEL..."

HEADER_FILE=$(mktemp /tmp/li_headers_XXXXXX.txt)

HTTP_RESPONSE=$(curl -s -D "$HEADER_FILE" -w "\n__HTTP_STATUS__%{http_code}" \
  -X POST "$POSTS_ENDPOINT" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -H "LinkedIn-Version: 202503" \
  -H "X-Restli-Protocol-Version: 2.0.0" \
  --data-binary @"$PAYLOAD_FILE")

rm -f "$PAYLOAD_FILE"

HTTP_STATUS=$(echo "$HTTP_RESPONSE" | grep "__HTTP_STATUS__" | sed 's/__HTTP_STATUS__//')
RESPONSE_BODY=$(echo "$HTTP_RESPONSE" | grep -v "__HTTP_STATUS__")

# ── Handle response ───────────────────────────────────────────────────────────

if [[ "$HTTP_STATUS" == "401" ]]; then
  rm -f "$HEADER_FILE"
  echo "❌ Token expired — re-run: zsh scripts/linkedin-auth.sh --account $ACCOUNT" >&2
  exit 1
fi

if [[ "$HTTP_STATUS" == "201" || "$HTTP_STATUS" == "200" ]]; then
  # Extract post URN from X-RestLi-Id header (primary) or response body (fallback)
  # LinkedIn REST API returns the post URN in the x-restli-id response header
  POST_URN=$(grep -i "^x-restli-id:" "$HEADER_FILE" | sed 's/.*: //' | tr -d '\r')
  if [[ -z "$POST_URN" ]]; then
    POST_URN=$(echo "$RESPONSE_BODY" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    urn = d.get('id', '')
    if not urn:
        urn = d.get('postUrn', d.get('urn', ''))
    print(urn)
except:
    print('')
" 2>/dev/null)
  fi
  rm -f "$HEADER_FILE"

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  ✅ Post published successfully!"
  echo "  Account     : $ACCOUNT ($LABEL)"
  echo "  HTTP Status : $HTTP_STATUS"
  if [[ -n "$POST_URN" ]]; then
    echo "  Post URN    : $POST_URN"
  else
    echo "  Post URN    : (see response headers — check LinkedIn app)"
  fi
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  # Output post URN to stdout for piping/capture
  if [[ -n "$POST_URN" ]]; then
    echo "$POST_URN"
  fi

  # ── Update linkedin-campaign.json with activity URN ──────────────────────
  # CHG-0362: Updated to write to linkedin-campaign.json (SSOT) instead of old linkedin-queue.json
  if [[ -n "$POST_URN" && -n "$QUEUE_CONTENT_ID" ]]; then
    python3 - "$WORKSPACE/state/linkedin-campaign.json" "$QUEUE_CONTENT_ID" "$POST_URN" "$ACCOUNT" "$ORGANIZATION_ID" << 'PYEOF'
import json, sys, os

def build_post_url(post_urn, account, org_id):
    """Build the correct public LinkedIn post URL based on account and URN type.
    CHG-0746: Correct URL format for personal vs company page posts.
    Stores legacy activity-format URL as postUrlLegacy for backward compatibility.
    """
    numeric_id = post_urn.split(':')[-1]
    legacy_url = f'https://www.linkedin.com/posts/activity-{numeric_id}/'
    
    if account == 'business':
        # Company page post: use company-page URL
        if org_id:
            # Try company-specific format; fall back to feed/update if no org slug
            return f'https://www.linkedin.com/posts/company/{org_id}-{numeric_id}/', legacy_url
        else:
            return legacy_url, None
    else:
        # Personal profile post: use feed/update format (canonical for share URNs)
        # For activity URNs, still use activity- format
        if post_urn.startswith('urn:li:activity:'):
            canonical_url = f'https://www.linkedin.com/posts/activity-{numeric_id}/'
        else:
            # share URN or other format -> use feed/update
            canonical_url = f'https://www.linkedin.com/feed/update/{post_urn}/'
        return canonical_url, legacy_url if canonical_url != legacy_url else None

try:
    sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'lib'))
    from atomic_write import atomic_write_json as aw
    campaign_file, content_id, post_urn = sys.argv[1], sys.argv[2], sys.argv[3]
    account = sys.argv[4] if len(sys.argv) > 4 else 'ken'
    org_id = sys.argv[5] if len(sys.argv) > 5 else ''
    try:
        with open(campaign_file) as f:
            c = json.load(f)
    except:
        c = {'published': [], 'drafts': {}}
    updated = False
    now = __import__('datetime').datetime.utcnow().isoformat() + 'Z'
    
    post_url, legacy_url = build_post_url(post_urn, account, org_id)
    
    # Update published entries
    for item in c.get('published', []):
        if item.get('id') == content_id:
            item['postUrn'] = post_urn
            item['postUrl'] = post_url
            if legacy_url:
                item['postUrlLegacy'] = legacy_url
            elif 'postUrlLegacy' in item:
                del item['postUrlLegacy']
            item['urnCapturedAt'] = now
            updated = True
            break
    # Update draft slots too
    drafts = c.get('drafts', {}).get('thisWeek', {}).get('slots', [])
    for slot in drafts:
        if slot.get('id') == content_id:
            slot['postUrn'] = post_urn
            slot['urnCapturedAt'] = now
            updated = True
            break
    if updated:
        c['lastUpdated'] = now
        ok = aw(campaign_file, c)
        print(f'  Campaign updated: {content_id} → postUrn={post_urn} postUrl={post_url}' if ok else f'  Campaign atomic write FAILED')
    else:
        print(f'  Campaign: contentId {content_id} not found in published or drafts')
except Exception as e:
    print(f'  Campaign update failed: {e}')
PYEOF
  fi
else
  echo "❌ Post failed (HTTP $HTTP_STATUS):" >&2
  echo "$RESPONSE_BODY" >&2
  exit 1
fi
