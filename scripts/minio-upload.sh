#!/bin/zsh
# minio-upload.sh — Upload to MinIO (via localhost) + return Tailscale presigned URL
# Presigned URLs signed via pure AWS v4 stdlib (minio-presign.py) — no network needed.
# Usage: --file /path --bucket <bucket> [--expires 24h] [--key custom/path.ext]
#
# CHG-MINIO-RESTORE 2026-07-14:
#   - Resolve `mc` via `command -v` with Homebrew prefix fallback.
#   - Resolve workspace root from script location (env override: MINIO_WORKSPACE).
#   - Read secrets from resolved workspace paths (env override: MINIO_SECRETS_DIR).

set -uo pipefail

# --- Resolve workspace root & secrets dir ------------------------------------
# SCRIPT_DIR: prefer zsh-native ${0:A:h}, fall back to POSIX readlink/bash BASH_SOURCE.
SCRIPT_DIR=""
if [[ -n "${ZSH_VERSION:-}" ]]; then
  SCRIPT_DIR="${0:A:h}"
elif [[ -n "${BASH_VERSION:-}" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
fi
# WORKSPACE_ROOT: scripts/ is one level under the workspace root.
WORKSPACE_ROOT="${MINIO_WORKSPACE:-$(cd "${SCRIPT_DIR}/.." && pwd)}"
SECRETS_DIR="${MINIO_SECRETS_DIR:-${WORKSPACE_ROOT}/infra/minio/secrets}"

# --- Resolve mc binary (env override: MC_BIN) --------------------------------
if [[ -n "${MC_BIN:-}" ]]; then
  MC="$MC_BIN"
else
  MC="$(command -v mc 2>/dev/null || true)"
  if [[ -z "$MC" ]]; then
    if [[ -x "/Users/ainchorsoc2a/homebrew/bin/mc" ]]; then
      MC="/Users/ainchorsoc2a/homebrew/bin/mc"
    elif [[ -x "/opt/homebrew/bin/mc" ]]; then
      MC="/opt/homebrew/bin/mc"
    else
      MC="mc"   # let it fail loudly with command-not-found if truly missing
    fi
  fi
fi

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

# Credentials (Keychain primary, file fallback; paths come from SECRETS_DIR)
MINIO_USER=""
if [[ -f "${SECRETS_DIR}/minio_user.txt" ]]; then
  MINIO_USER=$(cat "${SECRETS_DIR}/minio_user.txt")
else
  MINIO_USER="ainchors-minio"
fi

MINIO_PASS=""
if command -v security >/dev/null 2>&1; then
  MINIO_PASS=$(security find-generic-password -s "ainchors-minio" -w 2>/dev/null || true)
fi
if [[ -z "$MINIO_PASS" && -f "${SECRETS_DIR}/minio_password.txt" ]]; then
  MINIO_PASS=$(cat "${SECRETS_DIR}/minio_password.txt")
fi
[[ -z "$MINIO_PASS" ]] && { echo "ERROR: MinIO password not found in keychain or ${SECRETS_DIR}/minio_password.txt" >&2; exit 1; }

# Refresh mc alias to localhost (fast upload path)
"$MC" alias set "$MINIO_ALIAS" "$MINIO_ENDPOINT" "$MINIO_USER" "$MINIO_PASS" \
  --api S3v4 > /dev/null 2>&1

# Upload via localhost
"$MC" cp "$FILE" "${MINIO_ALIAS}/${BUCKET}/${KEY}" > /dev/null 2>&1 || \
  { echo "ERROR: upload failed for $FILE -> $BUCKET/$KEY" >&2; exit 1; }

# Generate presigned URL signed for Tailscale hostname (pure stdlib, no connection)
/usr/bin/python3 "${SCRIPT_DIR}/minio-presign.py" \
  "$BUCKET" "$KEY" "$EXPIRES_SEC" 2>/dev/null || \
  { echo "ERROR: presign failed" >&2; exit 1; }
