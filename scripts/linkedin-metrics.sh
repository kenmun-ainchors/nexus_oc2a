#!/usr/bin/env zsh
# linkedin-metrics.sh — Fetch engagement metrics for a LinkedIn post
# Uses socialActions endpoint for likes/comments/shares (no MDP needed).
# Impression/reach data requires MDP + Organization page (not yet onboarded).
#
# CHG-0743: Added --account argument for multi-account support.
# MDP approved: 2026-05-14 (CHG-0305). Organization page: deferred.
#
# Usage:
#   linkedin-metrics.sh --post-urn "urn:li:activity:123456" [--account ken|angie|business]
#
#   --account: Account context for auth lookup (default: ken, for backward compatibility).
#              angie/business may fail if token expired or post not owned by that account.
#
# Output: JSON with reactions, comments, shares counts

set -euo pipefail

WORKSPACE="/Users/ainchorsoc2a/.openclaw/workspace"
SOCIAL_ACTIONS_ENDPOINT="https://api.linkedin.com/v2/socialActions"

# ── Account configuration ──────────────────────────────────────────────────────

declare -A ACCOUNT_KEYCHAIN_PREFIX
ACCOUNT_KEYCHAIN_PREFIX[ken]="ainchors-linkedin"
ACCOUNT_KEYCHAIN_PREFIX[angie]="ainchors-linkedin-angie"
ACCOUNT_KEYCHAIN_PREFIX[business]="ainchors-linkedin-business"

declare -A ACCOUNT_STATE_SUFFIX
ACCOUNT_STATE_SUFFIX[ken]=""
ACCOUNT_STATE_SUFFIX[angie]="-angie"
ACCOUNT_STATE_SUFFIX[business]="-business"

# ── Defaults ──────────────────────────────────────────────────────────────────

POST_URN=""
ACCOUNT="ken"

# ── Parse args ────────────────────────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
  case "$1" in
    --post-urn)
      POST_URN="$2"
      shift 2
      ;;
    --account)
      ACCOUNT="$2"
      shift 2
      ;;
    *)
      echo "❌ Unknown argument: $1" >&2
      echo "Usage: linkedin-metrics.sh --post-urn \"urn:li:share:123456\" [--account ken|angie|business]" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$POST_URN" ]]; then
  echo "❌ --post-urn is required." >&2
  exit 1
fi

if [[ -z "${ACCOUNT_KEYCHAIN_PREFIX[$ACCOUNT]:-}" ]]; then
  echo "❌ Unknown account: $ACCOUNT. Valid: ken, angie, business" >&2
  exit 1
fi

KEYCHAIN_PREFIX="${ACCOUNT_KEYCHAIN_PREFIX[$ACCOUNT]}"
STATE_SUFFIX="${ACCOUNT_STATE_SUFFIX[$ACCOUNT]}"
AUTH_STATE_FILE="$WORKSPACE/state/linkedin-auth${STATE_SUFFIX}.json"

# ── Validate auth state ───────────────────────────────────────────────────────

if [[ ! -f "$AUTH_STATE_FILE" ]]; then
  echo "❌ Auth state not found: $AUTH_STATE_FILE" >&2
  echo "   Run: zsh scripts/linkedin-auth.sh --account $ACCOUNT" >&2
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
  # TKT-0771: dateutil may be missing on OC2A system Python.
  # Vendor a minimal ISO-8601 parser fallback so the script doesn't break
  # if system Python changes or python-dateutil is not installed.
  # Supports the LinkedIn token formats: 'YYYY-MM-DDTHH:MM:SSZ' and
  # 'YYYY-MM-DDTHH:MM:SS.fffZ' (with optional fractional seconds / tz offset).
  EXPIRED=$(TOKEN_EXPIRY="$TOKEN_EXPIRY" python3 -c "
import os, re
from datetime import datetime, timezone, timedelta

def parse_iso8601(s):
    s = s.strip()
    m = re.match(r'^(\d{4})-(\d{2})-(\d{2})[Tt](\d{2}):(\d{2}):(\d{2})(?:\.(\d+))?(Z|[+-]\d{2}:?\d{2})?$', s)
    if not m:
        raise ValueError('Unrecognised ISO-8601 timestamp: ' + repr(s))
    y, mo, d, h, mi, se = (int(x) for x in m.groups()[:6])
    frac = m.group(7)
    tz = m.group(8)
    micros = int((frac or '0').ljust(6, '0')[:6]) if frac else 0
    if tz is None or tz == 'Z':
        tzinfo = timezone.utc
    else:
        sign = 1 if tz[0] == '+' else -1
        tzn = tz[1:].replace(':', '')
        oh = int(tzn[0:2]); om = int(tzn[2:4]) if len(tzn) >= 4 else 0
        tzinfo = timezone(sign * timedelta(hours=oh, minutes=om))
    return datetime(y, mo, d, h, mi, se, micros, tzinfo=tzinfo)

raw = os.environ.get('TOKEN_EXPIRY', '')
if not raw:
    print('no')
    raise SystemExit(0)
try:
    expiry = parse_iso8601(raw).astimezone(timezone.utc)
except Exception as e:
    print('no')
    print('warn: could not parse tokenExpiry: ' + str(e), flush=True)
    raise SystemExit(0)
now = datetime.now(timezone.utc)
print('yes' if now >= expiry else 'no')
")
  if [[ "$EXPIRED" == "yes" ]]; then
    echo "❌ Token expired — re-run: zsh scripts/linkedin-auth.sh --account $ACCOUNT" >&2
    exit 1
  fi
fi

# ── Retrieve access token from Keychain (per-account) ─────────────────────────

ACCESS_TOKEN=$(security find-generic-password -a linkedin -s "${KEYCHAIN_PREFIX}-access-token" -w 2>/dev/null) \
  || { echo "❌ Access token not found in Keychain (service: ${KEYCHAIN_PREFIX}-access-token) — re-run linkedin-auth.sh --account $ACCOUNT" >&2; exit 1; }

# URL-encode the post URN for query params
POST_URN_ENCODED=$(python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1], safe=''))" "$POST_URN")

echo "  Fetching metrics for: $POST_URN (account: $ACCOUNT)" >&2

# ── Fetch social actions (likes + comments + shares) ──────────────────────────
# CHG-0362: Fixed 2026-05-20 — likes now parsed from socialActions endpoint
# instead of /v2/reactions which was returning zeros due to URN format mismatch.

SOCIAL_RESPONSE=$(curl -s -w "\n__HTTP_STATUS__%{http_code}" \
  "${SOCIAL_ACTIONS_ENDPOINT}/${POST_URN_ENCODED}" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "LinkedIn-Version: 202503")

SOCIAL_STATUS=$(echo "$SOCIAL_RESPONSE" | grep "__HTTP_STATUS__" | sed 's/__HTTP_STATUS__//')
SOCIAL_BODY=$(echo "$SOCIAL_RESPONSE" | grep -v "__HTTP_STATUS__")

if [[ "$SOCIAL_STATUS" == "401" ]]; then
  echo "❌ Token expired — re-run: zsh scripts/linkedin-auth.sh --account $ACCOUNT" >&2
  exit 1
fi

if [[ "$SOCIAL_STATUS" == "404" ]]; then
  echo "❌ Post not found (404) — URN may be invalid: $POST_URN" >&2
  exit 1
fi

REACTIONS_COUNT=$(echo "$SOCIAL_BODY" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('likesSummary', {}).get('totalLikes', 0))
except:
    print(0)
" 2>/dev/null || echo "0")

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
    # shares may not be in socialActions; default 0
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
    'account': sys.argv[6],
    'reactions': int(sys.argv[2]),
    'comments': int(sys.argv[3]),
    'shares': int(sys.argv[4]),
    'impressions': None,
    'reach': None,
    'fetchedAt': sys.argv[5]
}
print(json.dumps(result, indent=2))
" "$POST_URN" "$REACTIONS_COUNT" "$COMMENTS_COUNT" "$SHARES_COUNT" "$FETCHED_AT" "$ACCOUNT"

# MDP approved 2026-05-14 — impressions/reach can be added once Organization page is onboarded.
echo "" >&2
echo "  ℹ️  Note: impressions/reach require Organization page (deferred)." >&2
echo "      Those fields are null until org is onboarded to MDP." >&2
