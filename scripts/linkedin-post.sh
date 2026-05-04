#!/usr/bin/env zsh
# linkedin-post.sh — Post text content to LinkedIn on Ken's behalf
# Uses newer LinkedIn Posts API (REST) format.
#
# Usage:
#   linkedin-post.sh --text "post content" [--visibility PUBLIC|CONNECTIONS] [--dry-run]
#
# Requirements:
#   - Run linkedin-auth.sh first to obtain and store tokens
#   - state/linkedin-auth.json must exist with memberId

set -euo pipefail

WORKSPACE="/Users/ainchorsangiefpl/.openclaw/workspace"
AUTH_STATE_FILE="$WORKSPACE/state/linkedin-auth.json"
POSTS_ENDPOINT="https://api.linkedin.com/rest/posts"

# ── Defaults ──────────────────────────────────────────────────────────────────

POST_TEXT=""
VISIBILITY="PUBLIC"
DRY_RUN=false

# ── Parse args ────────────────────────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
  case "$1" in
    --text)
      POST_TEXT="$2"
      shift 2
      ;;
    --visibility)
      VISIBILITY="${2:u}"   # uppercase
      shift 2
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    *)
      echo "❌ Unknown argument: $1" >&2
      echo "Usage: linkedin-post.sh --text \"content\" [--visibility PUBLIC|CONNECTIONS] [--dry-run]" >&2
      exit 1
      ;;
  esac
done

# ── Validate ──────────────────────────────────────────────────────────────────

if [[ -z "$POST_TEXT" ]]; then
  echo "❌ --text is required." >&2
  exit 1
fi

if [[ "$VISIBILITY" != "PUBLIC" && "$VISIBILITY" != "CONNECTIONS" ]]; then
  echo "❌ --visibility must be PUBLIC or CONNECTIONS (got: $VISIBILITY)" >&2
  exit 1
fi

if [[ ! -f "$AUTH_STATE_FILE" ]]; then
  echo "❌ Auth state not found: $AUTH_STATE_FILE" >&2
  echo "   Run linkedin-auth.sh first." >&2
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
  echo "❌ memberId missing from $AUTH_STATE_FILE. Re-run linkedin-auth.sh." >&2
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
    echo "❌ Token expired — re-run linkedin-auth.sh" >&2
    exit 1
  fi
fi

# ── Retrieve access token from Keychain ───────────────────────────────────────

ACCESS_TOKEN=$(security find-generic-password -a linkedin -s ainchors-linkedin-access-token -w 2>/dev/null) \
  || { echo "❌ Access token not found in Keychain — re-run linkedin-auth.sh" >&2; exit 1; }

# ── Build post payload ────────────────────────────────────────────────────────

# Map visibility: CONNECTIONS → "CONNECTIONS", PUBLIC → "PUBLIC"
PAYLOAD=$(python3 -c "
import json, sys

text = sys.argv[1]
visibility = sys.argv[2]
member_id = sys.argv[3]

payload = {
    'author': f'urn:li:person:{member_id}',
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

print(json.dumps(payload, indent=2, ensure_ascii=False))
" "$POST_TEXT" "$VISIBILITY" "$MEMBER_ID")

# ── Dry-run mode ──────────────────────────────────────────────────────────────

if [[ "$DRY_RUN" == "true" ]]; then
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  🧪 DRY RUN — payload preview (no API call made):"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "  Endpoint  : POST $POSTS_ENDPOINT"
  echo "  Member ID : $MEMBER_ID"
  echo "  Visibility: $VISIBILITY"
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

echo "  Posting to LinkedIn..."

HTTP_RESPONSE=$(curl -s -w "\n__HTTP_STATUS__%{http_code}" \
  -X POST "$POSTS_ENDPOINT" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -H "LinkedIn-Version: 202503" \
  -H "X-Restli-Protocol-Version: 2.0.0" \
  -d "$PAYLOAD")

HTTP_STATUS=$(echo "$HTTP_RESPONSE" | grep "__HTTP_STATUS__" | sed 's/__HTTP_STATUS__//')
RESPONSE_BODY=$(echo "$HTTP_RESPONSE" | grep -v "__HTTP_STATUS__")

# ── Handle response ───────────────────────────────────────────────────────────

if [[ "$HTTP_STATUS" == "401" ]]; then
  echo "❌ Token expired — re-run linkedin-auth.sh" >&2
  exit 1
fi

if [[ "$HTTP_STATUS" == "201" || "$HTTP_STATUS" == "200" ]]; then
  # Extract post URN from X-RestLi-Id header or response body
  # LinkedIn REST API returns the post URN in the response body or header
  POST_URN=$(echo "$RESPONSE_BODY" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    # Newer API returns 'id' field
    urn = d.get('id', '')
    if not urn:
        # Try to extract URN from various response shapes
        urn = d.get('postUrn', d.get('urn', ''))
    print(urn)
except:
    print('')
" 2>/dev/null)

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  ✅ Post published successfully!"
  echo ""
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
else
  echo "❌ Post failed (HTTP $HTTP_STATUS):" >&2
  echo "$RESPONSE_BODY" >&2
  exit 1
fi
