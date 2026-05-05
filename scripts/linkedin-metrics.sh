#!/usr/bin/env zsh
# linkedin-metrics.sh — Fetch basic engagement metrics for a LinkedIn post
# No MDP (Marketing Developer Platform) required for reactions/comments/shares.
# Impression/reach data requires MDP (request #69747 pending).
#
# Usage:
#   linkedin-metrics.sh --post-urn "urn:li:share:123456"
#
# Output: JSON with reactions, comments, shares counts

set -euo pipefail

WORKSPACE="/Users/ainchorsangiefpl/.openclaw/workspace"
AUTH_STATE_FILE="$WORKSPACE/state/linkedin-auth.json"

REACTIONS_ENDPOINT="https://api.linkedin.com/v2/reactions"
SOCIAL_ACTIONS_ENDPOINT="https://api.linkedin.com/v2/socialActions"

# ── Parse args ────────────────────────────────────────────────────────────────

POST_URN=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --post-urn)
      POST_URN="$2"
      shift 2
      ;;
    *)
      echo "❌ Unknown argument: $1" >&2
      echo "Usage: linkedin-metrics.sh --post-urn \"urn:li:share:123456\"" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$POST_URN" ]]; then
  echo "❌ --post-urn is required." >&2
  exit 1
fi

# ── Validate auth state ───────────────────────────────────────────────────────

if [[ ! -f "$AUTH_STATE_FILE" ]]; then
  echo "❌ Auth state not found: $AUTH_STATE_FILE" >&2
  echo "   Run linkedin-auth.sh first." >&2
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
from dateutil import parser as dp
try:
    expiry = dp.parse('$TOKEN_EXPIRY').astimezone(timezone.utc)
except:
    expiry = datetime.strptime('$TOKEN_EXPIRY', '%Y-%m-%dT%H:%M:%SZ').replace(tzinfo=timezone.utc)
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

# URL-encode the post URN for query params
POST_URN_ENCODED=$(python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1], safe=''))" "$POST_URN")

echo "  Fetching metrics for: $POST_URN" >&2

# ── Fetch reactions ───────────────────────────────────────────────────────────

REACTIONS_RESPONSE=$(curl -s -w "\n__HTTP_STATUS__%{http_code}" \
  "${REACTIONS_ENDPOINT}?q=entity&entity=${POST_URN_ENCODED}" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "LinkedIn-Version: 202503" \
  -H "X-Restli-Protocol-Version: 2.0.0")

REACTIONS_STATUS=$(echo "$REACTIONS_RESPONSE" | grep "__HTTP_STATUS__" | sed 's/__HTTP_STATUS__//')
REACTIONS_BODY=$(echo "$REACTIONS_RESPONSE" | grep -v "__HTTP_STATUS__")

if [[ "$REACTIONS_STATUS" == "401" ]]; then
  echo "❌ Token expired — re-run linkedin-auth.sh" >&2
  exit 1
fi

REACTIONS_COUNT=$(echo "$REACTIONS_BODY" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    # paging.total gives total count
    total = d.get('paging', {}).get('total', None)
    if total is not None:
        print(total)
    else:
        # Fall back to counting elements
        elements = d.get('elements', [])
        print(len(elements))
except:
    print(0)
" 2>/dev/null || echo "0")

# ── Fetch social actions (comments + shares) ──────────────────────────────────

SOCIAL_RESPONSE=$(curl -s -w "\n__HTTP_STATUS__%{http_code}" \
  "${SOCIAL_ACTIONS_ENDPOINT}/${POST_URN_ENCODED}" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "LinkedIn-Version: 202503" \
  -H "X-Restli-Protocol-Version: 2.0.0")

SOCIAL_STATUS=$(echo "$SOCIAL_RESPONSE" | grep "__HTTP_STATUS__" | sed 's/__HTTP_STATUS__//')
SOCIAL_BODY=$(echo "$SOCIAL_RESPONSE" | grep -v "__HTTP_STATUS__")

if [[ "$SOCIAL_STATUS" == "401" ]]; then
  echo "❌ Token expired — re-run linkedin-auth.sh" >&2
  exit 1
fi

COMMENTS_COUNT=$(echo "$SOCIAL_BODY" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('commentsSummary', {}).get('totalFirstLevelComments', 0))
except:
    print(0)
" 2>/dev/null || echo "0")

SHARES_COUNT=$(echo "$SOCIAL_BODY" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('shareStatistics', {}).get('shareCount', 0))
except:
    print(0)
" 2>/dev/null || echo "0")

# ── Output JSON result ────────────────────────────────────────────────────────

FETCHED_AT=$(python3 -c "from datetime import datetime, timezone; print(datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'))")

python3 -c "
import json, sys
result = {
    'postUrn': sys.argv[1],
    'reactions': int(sys.argv[2]),
    'comments': int(sys.argv[3]),
    'shares': int(sys.argv[4]),
    'impressions': None,
    'reach': None,
    'fetchedAt': sys.argv[5]
}
print(json.dumps(result, indent=2))
" "$POST_URN" "$REACTIONS_COUNT" "$COMMENTS_COUNT" "$SHARES_COUNT" "$FETCHED_AT"

# Note about MDP-gated data
echo "" >&2
echo "  ℹ️  Note: impressions/reach require LinkedIn MDP access (request #69747 pending)." >&2
echo "      Those fields are null until MDP is granted." >&2
