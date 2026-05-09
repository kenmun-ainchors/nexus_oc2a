#!/usr/bin/env zsh
# linkedin-upload-image.sh — Upload an image to LinkedIn Assets API
#
# Usage:
#   linkedin-upload-image.sh --image-file /path/to/image.jpg [--dry-run]
#
# Output (stdout):
#   urn:li:image:XXXXXXXXXXXXXXXX   (the LinkedIn image asset URN)
#
# Requirements:
#   - linkedin-auth.sh must have been run (token in Keychain + state/linkedin-auth.json)
#   - Image: JPEG or PNG, max 5MB, min 552x552px for feed posts
#
# LinkedIn API flow:
#   1. POST /rest/images?action=initializeUpload → get uploadUrl + image URN
#   2. PUT {uploadUrl} with binary image data
#   3. Return image URN for use in post payload

set -euo pipefail

WORKSPACE="/Users/ainchorsangiefpl/.openclaw/workspace"
AUTH_STATE_FILE="$WORKSPACE/state/linkedin-auth.json"
IMAGES_ENDPOINT="https://api.linkedin.com/rest/images?action=initializeUpload"
LI_VERSION="202503"

# ── Defaults ──────────────────────────────────────────────────────────────────

IMAGE_FILE=""
DRY_RUN=false

# ── Parse args ────────────────────────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
  case "$1" in
    --image-file)
      IMAGE_FILE="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    *)
      echo "❌ Unknown argument: $1" >&2
      echo "Usage: linkedin-upload-image.sh --image-file /path/to/image.jpg [--dry-run]" >&2
      exit 1
      ;;
  esac
done

# ── Validate ──────────────────────────────────────────────────────────────────

if [[ -z "$IMAGE_FILE" ]]; then
  echo "❌ --image-file is required." >&2
  exit 1
fi

if [[ ! -f "$IMAGE_FILE" ]]; then
  echo "❌ Image file not found: $IMAGE_FILE" >&2
  exit 1
fi

# Check file size (max 5MB)
FILE_SIZE_BYTES=$(wc -c < "$IMAGE_FILE" | tr -d ' ')
MAX_BYTES=5242880  # 5MB
if [[ "$FILE_SIZE_BYTES" -gt "$MAX_BYTES" ]]; then
  FILE_SIZE_MB=$(echo "scale=1; $FILE_SIZE_BYTES / 1048576" | bc)
  echo "❌ Image too large: ${FILE_SIZE_MB}MB. LinkedIn max is 5MB." >&2
  exit 1
fi

if [[ ! -f "$AUTH_STATE_FILE" ]]; then
  echo "❌ LinkedIn auth state not found: $AUTH_STATE_FILE" >&2
  echo "   Run linkedin-auth.sh first." >&2
  exit 1
fi

# ── Load auth ─────────────────────────────────────────────────────────────────

ACCESS_TOKEN=$(security find-generic-password -s "ainchors-linkedin-access-token" -w 2>/dev/null || true)
MEMBER_ID=$(python3 -c "import json; d=json.load(open('$AUTH_STATE_FILE')); print(d.get('memberId',''))")

if [[ -z "$ACCESS_TOKEN" ]]; then
  echo "❌ LinkedIn access token not found in Keychain. Run linkedin-auth.sh first." >&2
  exit 1
fi

if [[ -z "$MEMBER_ID" ]]; then
  echo "❌ memberId missing in $AUTH_STATE_FILE. Run linkedin-auth.sh first." >&2
  exit 1
fi

# ── Detect content type ───────────────────────────────────────────────────────

EXT="${IMAGE_FILE##*.}"
EXT=$(echo "$EXT" | tr '[:upper:]' '[:lower:]')  # lowercased extension
case "$EXT" in
  jpg|jpeg) CONTENT_TYPE="image/jpeg" ;;
  png)      CONTENT_TYPE="image/png" ;;
  gif)      CONTENT_TYPE="image/gif" ;;
  *)
    # Fallback: use file command to detect
    FILE_TYPE=$(file -b --mime-type "$IMAGE_FILE" 2>/dev/null || echo "image/jpeg")
    CONTENT_TYPE="$FILE_TYPE"
    ;;
esac

# ── Dry-run mode ──────────────────────────────────────────────────────────────

if [[ "$DRY_RUN" == "true" ]]; then
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  🧪 DRY RUN — no API calls made"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "  Step 1  : POST $IMAGES_ENDPOINT"
  echo "  Owner   : urn:li:person:$MEMBER_ID"
  echo "  Image   : $IMAGE_FILE"
  echo "  Type    : $CONTENT_TYPE"
  FILE_SIZE_KB=$(echo "scale=1; $FILE_SIZE_BYTES / 1024" | bc)
  echo "  Size    : ${FILE_SIZE_KB}KB"
  echo "  Step 2  : PUT {uploadUrl} with binary image data"
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  ✅ Dry run complete. Remove --dry-run to upload for real."
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  exit 0
fi

# ── Step 1: Initialize upload ─────────────────────────────────────────────────

echo "  Initializing LinkedIn image upload..."

INIT_PAYLOAD="{\"initializeUploadRequest\":{\"owner\":\"urn:li:person:${MEMBER_ID}\"}}"

INIT_RESPONSE=$(curl -s -w "\n__HTTP_STATUS__%{http_code}" \
  -X POST "$IMAGES_ENDPOINT" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -H "LinkedIn-Version: $LI_VERSION" \
  -H "X-Restli-Protocol-Version: 2.0.0" \
  -d "$INIT_PAYLOAD")

INIT_STATUS=$(echo "$INIT_RESPONSE" | grep "__HTTP_STATUS__" | sed 's/__HTTP_STATUS__//')
INIT_BODY=$(echo "$INIT_RESPONSE" | grep -v "__HTTP_STATUS__")

if [[ "$INIT_STATUS" == "401" ]]; then
  echo "❌ LinkedIn token expired. Run linkedin-auth.sh to refresh." >&2
  exit 1
fi

if [[ "$INIT_STATUS" != "200" && "$INIT_STATUS" != "201" ]]; then
  echo "❌ Upload initialization failed (HTTP $INIT_STATUS): $INIT_BODY" >&2
  exit 1
fi

# Extract uploadUrl and image URN
UPLOAD_URL=$(echo "$INIT_BODY" | python3 -c "
import json, sys
d = json.load(sys.stdin)
val = d.get('value', {})
print(val.get('uploadUrl', ''))
")

IMAGE_URN=$(echo "$INIT_BODY" | python3 -c "
import json, sys
d = json.load(sys.stdin)
val = d.get('value', {})
print(val.get('image', ''))
")

if [[ -z "$UPLOAD_URL" || -z "$IMAGE_URN" ]]; then
  echo "❌ Could not parse uploadUrl or image URN from response: $INIT_BODY" >&2
  exit 1
fi

echo "  Asset URN : $IMAGE_URN"
echo "  Uploading binary..."

# ── Step 2: Upload binary ─────────────────────────────────────────────────────

UPLOAD_STATUS=$(curl -s -w "%{http_code}" -o /dev/null \
  -X PUT "$UPLOAD_URL" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: $CONTENT_TYPE" \
  --data-binary @"$IMAGE_FILE")

if [[ "$UPLOAD_STATUS" != "200" && "$UPLOAD_STATUS" != "201" && "$UPLOAD_STATUS" != "204" ]]; then
  echo "❌ Binary upload failed (HTTP $UPLOAD_STATUS)" >&2
  exit 1
fi

# ── Output result ─────────────────────────────────────────────────────────────

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ Image uploaded successfully!"
echo ""
echo "  Asset URN : $IMAGE_URN"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Output URN to stdout for piping (last line)
echo "$IMAGE_URN"
