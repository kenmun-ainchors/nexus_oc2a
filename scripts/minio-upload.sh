#!/bin/zsh
# minio-upload.sh — Upload to MinIO (via localhost) + return Tailscale presigned URL
# Presigned URLs signed via pure AWS v4 stdlib (minio-presign.py) — no network needed.
# Usage: --file /path --bucket <bucket> [--expires 24h] [--key custom/path.ext]

set -uo pipefail

MC="/opt/homebrew/bin/mc"
MINIO_ALIAS="oc1"
MINIO_ENDPOINT="http://127.0.0.1:9000"
EXPIRES_HOURS="24"
BUCKET=""
FILE=""
KEY=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --file)    FILE="$2"; shift 2 ;;
    --bucket)  BUCKET="$2"; shift 2 ;;
    --expires) EXPIRES_HOURS="${2%h}"; shift 2 ;;  # strip trailing 'h'
    --key)     KEY="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

[[ -z "$FILE" ]]   && { echo "ERROR: --file required" >&2; exit 1; }
[[ -z "$BUCKET" ]] && { echo "ERROR: --bucket required" >&2; exit 1; }
[[ ! -f "$FILE" ]] && { echo "ERROR: file not found: $FILE" >&2; exit 1; }

[[ -z "$KEY" ]] && KEY=$(basename "$FILE")
EXPIRES_SEC=$(( EXPIRES_HOURS * 3600 ))

# Credentials (AC6: Keychain)
MINIO_USER=$(cat /Users/ainchorsangiefpl/.openclaw/workspace/infra/minio/secrets/minio_user.txt 2>/dev/null || echo "ainchors-minio")
MINIO_PASS=$(security find-generic-password -s "ainchors-minio" -w 2>/dev/null || \
             cat /Users/ainchorsangiefpl/.openclaw/workspace/infra/minio/secrets/minio_password.txt)

# Refresh mc alias to localhost (fast upload path)
$MC alias set "$MINIO_ALIAS" "$MINIO_ENDPOINT" "$MINIO_USER" "$MINIO_PASS" \
  --api S3v4 > /dev/null 2>&1

# Upload via localhost
$MC cp "$FILE" "${MINIO_ALIAS}/${BUCKET}/${KEY}" > /dev/null 2>&1 || \
  { echo "ERROR: upload failed for $FILE -> $BUCKET/$KEY" >&2; exit 1; }

# Generate presigned URL signed for Tailscale hostname (pure stdlib, no connection)
/usr/bin/python3 /Users/ainchorsangiefpl/.openclaw/workspace/scripts/minio-presign.py \
  "$BUCKET" "$KEY" "$EXPIRES_SEC" 2>/dev/null || \
  { echo "ERROR: presign failed" >&2; exit 1; }
