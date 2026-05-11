#!/bin/zsh
# minio-upload.sh — Upload a file to MinIO and return a presigned URL
# AC3: Presigned URL generation, Tailscale accessible
# Usage:
#   minio-upload.sh --file /path/to/file --bucket ainchors-generated-media [--expires 24h] [--key custom/path/name.ext]
#   Returns: presigned URL on stdout, or error on stderr

set -uo pipefail

MC="/opt/homebrew/bin/mc"
MINIO_ALIAS="oc1"
MINIO_ENDPOINT="http://127.0.0.1:9000"
EXPIRES="24h"
BUCKET=""
FILE=""
KEY=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --file)    FILE="$2"; shift 2 ;;
    --bucket)  BUCKET="$2"; shift 2 ;;
    --expires) EXPIRES="$2"; shift 2 ;;
    --key)     KEY="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

[[ -z "$FILE" ]]   && { echo "ERROR: --file required" >&2; exit 1; }
[[ -z "$BUCKET" ]] && { echo "ERROR: --bucket required" >&2; exit 1; }
[[ ! -f "$FILE" ]] && { echo "ERROR: file not found: $FILE" >&2; exit 1; }

# Default key = filename
[[ -z "$KEY" ]] && KEY=$(basename "$FILE")

# Refresh credentials — user from secrets file, password from Keychain (AC6)
MINIO_USER=$(cat /Users/ainchorsangiefpl/.openclaw/workspace/infra/minio/secrets/minio_user.txt 2>/dev/null || echo "ainchors-minio")
MINIO_PASS=$(security find-generic-password -s "ainchors-minio" -w 2>/dev/null || \
             cat /Users/ainchorsangiefpl/.openclaw/workspace/infra/minio/secrets/minio_password.txt)

# Ensure mc alias is current
$MC alias set "$MINIO_ALIAS" "$MINIO_ENDPOINT" "$MINIO_USER" "$MINIO_PASS" \
  --api S3v4 > /dev/null 2>&1

# Upload
$MC cp "$FILE" "${MINIO_ALIAS}/${BUCKET}/${KEY}" > /dev/null 2>&1 || \
  { echo "ERROR: upload failed for $FILE -> $BUCKET/$KEY" >&2; exit 1; }

# Generate presigned URL and rewrite to Tailscale endpoint for external access
INTERNAL_URL=$($MC share download "${MINIO_ALIAS}/${BUCKET}/${KEY}" --expire "$EXPIRES" 2>/dev/null \
      | grep "^Share:" | awk '{print $2}')

if [[ -z "$INTERNAL_URL" ]]; then
  echo "ERROR: failed to generate presigned URL" >&2; exit 1
fi

# Rewrite localhost endpoint to Tailscale HTTPS for external access
TAILSCALE_HOST="https://ainchorss-mac-mini.tail5e2567.ts.net"
URL=$(echo "$INTERNAL_URL" | sed "s|http://127.0.0.1:9000|${TAILSCALE_HOST}|")

echo "$URL"
