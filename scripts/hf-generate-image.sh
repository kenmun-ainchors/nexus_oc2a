#!/usr/bin/env zsh
# hf-generate-image.sh — Generate an image via Hugging Face Inference API (FLUX.1-schnell)
#
# Usage:
#   hf-generate-image.sh --prompt "prompt text" [--output /path/to/output.jpg] [--width 1024] [--height 1024] [--steps 4] [--dry-run]
#
# Requirements:
#   - HF API token stored in macOS Keychain: ainchors-hf-api-token
#     To store: security add-generic-password -s "ainchors-hf-api-token" -a "kenmun@ainchors.com" -w "<TOKEN>"
#   - curl available

set -euo pipefail

WORKSPACE="/Users/ainchorsangiefpl/.openclaw/workspace"
HF_ENDPOINT="https://api-inference.huggingface.co/models/black-forest-labs/FLUX.1-schnell"
IMAGES_DIR="$WORKSPACE/state/generated-images"
KEYCHAIN_SERVICE="ainchors-hf-api-token"
KEYCHAIN_ACCOUNT="kenmun@ainchors.com"

# ── Defaults ──────────────────────────────────────────────────────────────────

PROMPT=""
OUTPUT_FILE=""
WIDTH=1024
HEIGHT=1024
STEPS=4
DRY_RUN=false

# ── Parse args ────────────────────────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prompt)
      PROMPT="$2"
      shift 2
      ;;
    --output)
      OUTPUT_FILE="$2"
      shift 2
      ;;
    --width)
      WIDTH="$2"
      shift 2
      ;;
    --height)
      HEIGHT="$2"
      shift 2
      ;;
    --steps)
      STEPS="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    *)
      echo "❌ Unknown argument: $1" >&2
      echo "Usage: hf-generate-image.sh --prompt \"text\" [--output path.jpg] [--width 1024] [--height 1024] [--steps 4] [--dry-run]" >&2
      exit 1
      ;;
  esac
done

# ── Validate ──────────────────────────────────────────────────────────────────

if [[ -z "$PROMPT" ]]; then
  echo "❌ --prompt is required." >&2
  exit 1
fi

# ── Resolve output path ───────────────────────────────────────────────────────

mkdir -p "$IMAGES_DIR"

if [[ -z "$OUTPUT_FILE" ]]; then
  TIMESTAMP=$(date +%Y%m%d-%H%M%S)
  OUTPUT_FILE="$IMAGES_DIR/linkedin-${TIMESTAMP}.jpg"
fi

# ── Dry-run mode ──────────────────────────────────────────────────────────────

if [[ "$DRY_RUN" == "true" ]]; then
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  🧪 DRY RUN — no API call made"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "  Endpoint  : POST $HF_ENDPOINT"
  echo "  Prompt    : $PROMPT"
  echo "  Dimensions: ${WIDTH}x${HEIGHT}"
  echo "  Steps     : $STEPS"
  echo "  Output    : $OUTPUT_FILE"
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  ✅ Dry run complete. Remove --dry-run to generate for real."
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  exit 0
fi

# ── Load API token ────────────────────────────────────────────────────────────

HF_TOKEN=$(security find-generic-password -s "$KEYCHAIN_SERVICE" -a "$KEYCHAIN_ACCOUNT" -w 2>/dev/null || true)

if [[ -z "$HF_TOKEN" ]]; then
  echo "" >&2
  echo "❌ HF API token not found in Keychain." >&2
  echo "" >&2
  echo "   To set it up:" >&2
  echo "   1. Go to https://huggingface.co/settings/tokens" >&2
  echo "   2. Create a token (Read scope is sufficient)" >&2
  echo "   3. Run:" >&2
  echo "      security add-generic-password -s \"ainchors-hf-api-token\" -a \"kenmun@ainchors.com\" -w \"<YOUR_TOKEN>\"" >&2
  echo "" >&2
  exit 1
fi

# ── Build request payload ─────────────────────────────────────────────────────

PAYLOAD=$(python3 -c "
import json, sys
payload = {
    'inputs': sys.argv[1],
    'parameters': {
        'width': int(sys.argv[2]),
        'height': int(sys.argv[3]),
        'num_inference_steps': int(sys.argv[4]),
        'guidance_scale': 0.0
    }
}
print(json.dumps(payload))
" "$PROMPT" "$WIDTH" "$HEIGHT" "$STEPS")

# ── Call HF Inference API ─────────────────────────────────────────────────────

echo "  Generating image via FLUX.1-schnell..."
echo "  Prompt: $PROMPT"
echo "  Dimensions: ${WIDTH}x${HEIGHT}, Steps: ${STEPS}"

HTTP_RESPONSE=$(curl -s -w "\n__HTTP_STATUS__%{http_code}" \
  -X POST "$HF_ENDPOINT" \
  -H "Authorization: Bearer $HF_TOKEN" \
  -H "Content-Type: application/json" \
  -H "Accept: image/jpeg,image/*,*/*" \
  -d "$PAYLOAD" \
  -o "$OUTPUT_FILE.tmp")

HTTP_STATUS=$(echo "$HTTP_RESPONSE" | grep "__HTTP_STATUS__" | sed 's/__HTTP_STATUS__//')

# ── Handle errors ─────────────────────────────────────────────────────────────

if [[ "$HTTP_STATUS" == "503" ]]; then
  rm -f "$OUTPUT_FILE.tmp"
  echo "❌ Model is loading (HTTP 503). HF free tier may need a warm-up. Retry in 30s." >&2
  exit 1
fi

if [[ "$HTTP_STATUS" == "401" ]]; then
  rm -f "$OUTPUT_FILE.tmp"
  echo "❌ HF API token invalid or expired. Check Keychain entry: $KEYCHAIN_SERVICE" >&2
  exit 1
fi

if [[ "$HTTP_STATUS" == "429" ]]; then
  rm -f "$OUTPUT_FILE.tmp"
  echo "❌ Rate limit hit (HTTP 429). Free tier: ~1000 req/month. Try again later." >&2
  exit 1
fi

if [[ "$HTTP_STATUS" != "200" ]]; then
  # Try to read error from tmp file (may be JSON error)
  ERR=$(cat "$OUTPUT_FILE.tmp" 2>/dev/null || echo "(no body)")
  rm -f "$OUTPUT_FILE.tmp"
  echo "❌ HF API error (HTTP $HTTP_STATUS): $ERR" >&2
  exit 1
fi

# ── Validate output is an image ───────────────────────────────────────────────

FILE_TYPE=$(file -b "$OUTPUT_FILE.tmp" 2>/dev/null || echo "")

if echo "$FILE_TYPE" | grep -qi "json\|html\|text"; then
  # API returned an error JSON despite 200 — surface it
  ERR=$(cat "$OUTPUT_FILE.tmp" 2>/dev/null || echo "(empty)")
  rm -f "$OUTPUT_FILE.tmp"
  echo "❌ HF API returned non-image response: $ERR" >&2
  exit 1
fi

mv "$OUTPUT_FILE.tmp" "$OUTPUT_FILE"

# ── Output result ─────────────────────────────────────────────────────────────

FILE_SIZE=$(du -h "$OUTPUT_FILE" | cut -f1)

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ Image generated successfully!"
echo ""
echo "  File      : $OUTPUT_FILE"
echo "  Size      : $FILE_SIZE"
echo "  Type      : $FILE_TYPE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Output path to stdout for piping
echo "$OUTPUT_FILE"
