#!/usr/bin/env zsh
# linkedin-post.sh — Post text content to LinkedIn on Ken's behalf
# Uses newer LinkedIn Posts API (REST) format.
#
# Usage:
#   linkedin-post.sh --text "post content" [--visibility PUBLIC|CONNECTIONS] [--image-asset-urn urn:li:image:XXX] [--dry-run]
#   linkedin-post.sh --content-file /path/to/draft.md [--image-asset-urn urn:li:image:XXX] [--dry-run]
#
# Image workflow (TKT-0121):
#   1. Generate image:  bash scripts/hf-generate-image.sh --prompt "..." → /path/to/image.jpg
#   2. Upload to LI:    bash scripts/linkedin-upload-image.sh --image-file /path/to/image.jpg → urn:li:image:XXX
#   3. Attach to post:  bash scripts/linkedin-post.sh --content-file draft.md --image-asset-urn urn:li:image:XXX
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
CONTENT_FILE=""
VISIBILITY="PUBLIC"
IMAGE_ASSET_URN=""
DRY_RUN=false

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
      VISIBILITY="${2:u}"   # uppercase
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
      # Optional: content ID to update in linkedin-queue.json with the activity URN after posting
      QUEUE_CONTENT_ID="$2"
      shift 2
      ;;
    *)
      echo "❌ Unknown argument: $1" >&2
      echo "Usage: linkedin-post.sh --content-file draft.md [--image-asset-urn urn:li:image:XXX] [--visibility PUBLIC|CONNECTIONS] [--dry-run] [--queue-content-id LI-C1-W2-P3]" >&2
      exit 1
      ;;
  esac
done

QUEUE_CONTENT_ID="${QUEUE_CONTENT_ID:-}"

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
        body.append(line)
    if s.startswith('#') and not s.startswith('##'):
        hashtag_line = line
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
# Clean up any stale payload files from previous runs (mktemp collision guard)
rm -f /tmp/li_payload_*.json 2>/dev/null || true
PAYLOAD_FILE=$(mktemp /tmp/li_payload_XXXXXX.json)

python3 - "$POST_TEXT" "$VISIBILITY" "$MEMBER_ID" "$PAYLOAD_FILE" "$IMAGE_ASSET_URN" << 'PYEOF'
import json, sys

text = sys.argv[1]
visibility = sys.argv[2]
member_id = sys.argv[3]
out_file = sys.argv[4]
image_urn = sys.argv[5] if len(sys.argv) > 5 else ''

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
  echo "  Endpoint  : POST $POSTS_ENDPOINT"
  echo "  Member ID : $MEMBER_ID"
  echo "  Visibility: $VISIBILITY"
  if [[ -n "$IMAGE_ASSET_URN" ]]; then
    echo "  Image URN : $IMAGE_ASSET_URN"
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

echo "  Posting to LinkedIn..."

HTTP_RESPONSE=$(curl -s -w "\n__HTTP_STATUS__%{http_code}" \
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

  # ── Update linkedin-campaign.json with activity URN ──────────────────────
  # CHG-0362: Updated to write to linkedin-campaign.json (SSOT) instead of old linkedin-queue.json
  if [[ -n "$POST_URN" && -n "$QUEUE_CONTENT_ID" ]]; then
    python3 - "$WORKSPACE/state/linkedin-campaign.json" "$QUEUE_CONTENT_ID" "$POST_URN" << 'PYEOF'
import json, sys
campaign_file, content_id, post_urn = sys.argv[1], sys.argv[2], sys.argv[3]
try:
    with open(campaign_file) as f:
        c = json.load(f)
    updated = False
    now = __import__('datetime').datetime.utcnow().isoformat() + 'Z'
    # Update published entries
    for item in c.get('published', []):
        if item.get('id') == content_id:
            item['postUrn'] = post_urn
            item['postUrl'] = f'https://www.linkedin.com/posts/activity-{post_urn.split(":")[-1]}/'
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
        with open(campaign_file, 'w') as f:
            json.dump(c, f, indent=2)
        print(f'  Campaign updated: {content_id} → postUrn={post_urn}')
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
