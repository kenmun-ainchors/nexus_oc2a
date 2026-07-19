#!/bin/bash
# notion-update-page-status.sh — Canonical Notion page Status update helper.
# CHG-0939: reads the Notion integration token from ~/.config/notion/api_key
# (no keychain fallback, no CLI token), PATCHes the page's Status select field.
#
# Usage:
#   scripts/notion-update-page-status.sh --auth-check
#   scripts/notion-update-page-status.sh <PAGE_ID> <STATUS_NAME>
#
# Exit codes:
#   0   success (auth-check ran, or PATCH applied)
#   1   usage / argument error
#   2   token missing or unreadable
#   3   auth failure (HTTP 401)
#   4   rate limit exhausted after retries
#   5   server error after retries
#   6   not found / missing page (HTTP 404)
#   7   other Notion API error
#   8   curl/network error
#
# The script NEVER prints the token, even in error messages.

set -u

# --- Constants ---
SCRIPT_NAME="notion-update-page-status.sh"
NOTION_KEY_FILE="$HOME/.config/notion/api_key"
NOTION_API="https://api.notion.com/v1"
NOTION_VERSION="2022-06-28"
MAX_RETRIES=3

# --- Output helpers (stderr for diagnostics, stdout for data) ---
log()  { echo "[$(date '+%H:%M:%S')] $1" >&2; }
die()  { echo "FATAL: $1" >&2; exit "${2:-1}"; }
usage() {
  cat >&2 <<EOF
Usage:
  $SCRIPT_NAME --auth-check
  $SCRIPT_NAME <PAGE_ID> <STATUS_NAME>

Options:
  --auth-check    Validate the Notion token by calling /v1/users/me (read-only)
  -h, --help      Show this help

Examples:
  $SCRIPT_NAME --auth-check
  $SCRIPT_NAME 3a2890b6-ece8-81eb-b196-dda393378979 "In Progress"
  $SCRIPT_NAME 3a2890b6-ece8-81eb-b196-dda393378979 "Done"
EOF
}

# --- Token loading (single source of truth) ---
load_notion_key() {
  if [[ ! -f "$NOTION_KEY_FILE" ]]; then
    die "Notion API key file not found: $NOTION_KEY_FILE" 2
  fi
  if [[ ! -r "$NOTION_KEY_FILE" ]]; then
    die "Notion API key file not readable: $NOTION_KEY_FILE" 2
  fi
  local key
  key=$(cat "$NOTION_KEY_FILE" 2>/dev/null) || die "Failed to read Notion API key file: $NOTION_KEY_FILE" 2
  # Strip trailing whitespace/newlines only; do NOT log key contents.
  key="${key%%[[:space:]]}"
  if [[ -z "$key" ]]; then
    die "Notion API key file is empty: $NOTION_KEY_FILE" 2
  fi
  echo "$key"
}

# --- Extract a Retry-After value from headers/body (seconds) ---
# Accepts either a header file (Retry-After: N) or an error JSON body.
extract_retry_after() {
  local header_file="$1"
  local body="$2"
  local ra=""

  # 1. Try the Retry-After header (seconds, per RFC 7231 §7.1.3)
  if [[ -s "$header_file" ]]; then
    ra=$(grep -i '^retry-after:' "$header_file" | tail -1 | sed -E 's/^[Rr]etry-[Aa]fter:[[:space:]]*//' | tr -d '[:space:]')
  fi

  # 2. Fallback: Notion sometimes returns a JSON body with a hint.
  if [[ -z "$ra" ]] && [[ -n "$body" ]]; then
    # Common shapes: {"retry_after": 1.2} or message containing "Try again in X seconds".
    ra=$(echo "$body" | grep -oE '"retry_after"[[:space:]]*:[[:space:]]*[0-9.]+' | head -1 | grep -oE '[0-9.]+' | head -1 || true)
    if [[ -z "$ra" ]]; then
      ra=$(echo "$body" | grep -oE 'Try again in [0-9.]+ seconds?' | head -1 | grep -oE '[0-9.]+' | head -1 || true)
    fi
  fi

  # Default to 1s if nothing usable, capped at 60s.
  if [[ -z "$ra" ]]; then
    ra=1
  fi
  # integer floor, cap 60
  python3 -c "
import math, sys
v = float('$ra')
if v < 0: v = 0
if v > 60: v = 60
print(int(math.ceil(v)))
" 2>/dev/null || echo 1
}

# --- Auth check: GET /v1/users/me ---
auth_check() {
  local key
  key=$(load_notion_key) || return $?

  log "Calling ${NOTION_API}/users/me ..."
  local resp body http_code
  body=$(curl -sS -X GET "${NOTION_API}/users/me" \
    -H "Authorization: Bearer ${key}" \
    -H "Notion-Version: ${NOTION_VERSION}" \
    -w '\n__HTTP__:%{http_code}' 2>&1) || die "curl failed during auth check" 8

  http_code=$(echo "$body" | grep -E '^__HTTP__:' | tail -1 | sed 's/^__HTTP__://')
  body=$(echo "$body" | sed -E '/^__HTTP__:/d')

  case "$http_code" in
    200)
      local name id obj_type
      obj_type=$(echo "$body" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('object',''))" 2>/dev/null || echo "")
      name=$(echo "$body" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('name',''))" 2>/dev/null || echo "")
      id=$(echo "$body" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('id',''))" 2>/dev/null || echo "")
      echo "AUTH-CHECK: OK (object=${obj_type}, id=${id}, name=${name})"
      return 0
      ;;
    401)
      local msg
      msg=$(echo "$body" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('message','Unauthorized'))" 2>/dev/null || echo "Unauthorized")
      die "Auth check failed: HTTP 401 — ${msg} (token rejected; check $NOTION_KEY_FILE)" 3
      ;;
    *)
      local msg
      msg=$(echo "$body" | python3 -c "import sys,json
try:
  d=json.load(sys.stdin); print(d.get('message',''))
except: pass" 2>/dev/null || echo "")
      die "Auth check failed: HTTP ${http_code}${msg:+ — ${msg}}" 7
      ;;
  esac
}

# --- PATCH /v1/pages/{page_id} with retry-on-429 ---
patch_status() {
  local page_id="$1"
  local status_name="$2"
  local key
  key=$(load_notion_key) || return $?

  # Build JSON body safely with python (handles quoting).
  local payload
  payload=$(STATUS_NAME="$status_name" python3 -c '
import json, os
print(json.dumps({"properties": {"Status": {"select": {"name": os.environ["STATUS_NAME"]}}}}))
') || die "Failed to build JSON payload" 7

  local attempt=0
  while (( attempt <= MAX_RETRIES )); do
    attempt=$((attempt + 1))
    local hdr_file body_file resp http_code obj msg ra_seconds

    hdr_file=$(mktemp)
    body_file=$(mktemp)
    # shellcheck disable=SC2064
    trap "rm -f '$hdr_file' '$body_file'" RETURN

    log "PATCH ${NOTION_API}/pages/${page_id} (attempt ${attempt}/${MAX_RETRIES}) status='${status_name}'"

    # -D writes headers to file; -o writes body to file; -w prints http_code.
    http_code=$(curl -sS -X PATCH "${NOTION_API}/pages/${page_id}" \
      -H "Authorization: Bearer ${key}" \
      -H "Notion-Version: ${NOTION_VERSION}" \
      -H "Content-Type: application/json" \
      -D "$hdr_file" \
      -o "$body_file" \
      -w '%{http_code}' 2>&1) || { rm -f "$hdr_file" "$body_file"; die "curl failed during PATCH" 8; }

    body=$(cat "$body_file" 2>/dev/null || echo "")

    case "$http_code" in
      200)
        # Success — confirm via body.
        obj=$(echo "$body" | python3 -c "import sys,json
try:
  d=json.load(sys.stdin); print(d.get('object',''))
except: pass" 2>/dev/null || echo "")
        if [[ "$obj" == "error" ]]; then
          msg=$(echo "$body" | python3 -c "import sys,json
try:
  d=json.load(sys.stdin); print(d.get('message',''))
except: pass" 2>/dev/null || echo "")
          rm -f "$hdr_file" "$body_file"
          die "PATCH returned object=error: ${msg}" 7
        fi
        local got_status
        got_status=$(echo "$body" | python3 -c "import sys,json
try:
  d=json.load(sys.stdin)
  s=d.get('properties',{}).get('Status',{}).get('select')
  print(s.get('name','') if isinstance(s, dict) else '')
except: pass" 2>/dev/null || echo "")
        echo "PATCH-OK: page=${page_id} status_now='${got_status}'"
        rm -f "$hdr_file" "$body_file"
        return 0
        ;;
      429)
        # Rate-limited — respect Retry-After if present, retry up to MAX_RETRIES.
        if (( attempt > MAX_RETRIES )); then
          rm -f "$hdr_file" "$body_file"
          die "Rate limit (HTTP 429) — exhausted ${MAX_RETRIES} retries" 4
        fi
        ra_seconds=$(extract_retry_after "$hdr_file" "$body")
        log "Rate limited (HTTP 429); sleeping ${ra_seconds}s before retry ${attempt}/${MAX_RETRIES}"
        sleep "$ra_seconds"
        rm -f "$hdr_file" "$body_file"
        continue
        ;;
      401)
        msg=$(echo "$body" | python3 -c "import sys,json
try:
  d=json.load(sys.stdin); print(d.get('message','Unauthorized'))
except: pass" 2>/dev/null || echo "Unauthorized")
        rm -f "$hdr_file" "$body_file"
        die "Auth failed (HTTP 401): ${msg}" 3
        ;;
      404)
        msg=$(echo "$body" | python3 -c "import sys,json
try:
  d=json.load(sys.stdin); print(d.get('message','Not found'))
except: pass" 2>/dev/null || echo "Not found")
        rm -f "$hdr_file" "$body_file"
        die "Page not found (HTTP 404): page_id=${page_id} — ${msg}" 6
        ;;
      5*)
        # Transient server error — retry with a small backoff.
        if (( attempt > MAX_RETRIES )); then
          msg=$(echo "$body" | python3 -c "import sys,json
try:
  d=json.load(sys.stdin); print(d.get('message',''))
except: pass" 2>/dev/null || echo "")
          rm -f "$hdr_file" "$body_file"
          die "Server error (HTTP ${http_code}) — exhausted ${MAX_RETRIES} retries${msg:+ — ${msg}}" 5
        fi
        log "Server error (HTTP ${http_code}); backing off 2s before retry ${attempt}/${MAX_RETRIES}"
        sleep 2
        rm -f "$hdr_file" "$body_file"
        continue
        ;;
      *)
        msg=$(echo "$body" | python3 -c "import sys,json
try:
  d=json.load(sys.stdin); print(d.get('message',''))
except: pass" 2>/dev/null || echo "")
        rm -f "$hdr_file" "$body_file"
        die "PATCH failed: HTTP ${http_code}${msg:+ — ${msg}}" 7
        ;;
    esac
  done
  die "PATCH failed: exceeded retry budget" 7
}

# --- Argument parsing ---
if [[ $# -eq 0 ]]; then
  usage
  exit 1
fi

case "$1" in
  -h|--help)
    usage
    exit 0
    ;;
  --auth-check)
    if [[ $# -ne 1 ]]; then
      log "ERROR: --auth-check takes no arguments"
      usage
      exit 1
    fi
    auth_check
    exit $?
    ;;
  --*)
    log "ERROR: unknown option: $1"
    usage
    exit 1
    ;;
  *)
    if [[ $# -ne 2 ]]; then
      log "ERROR: expected exactly 2 positional arguments (PAGE_ID STATUS_NAME), got $#"
      usage
      exit 1
    fi
    PAGE_ID="$1"
    STATUS_NAME="$2"
    if [[ -z "$PAGE_ID" ]]; then
      log "ERROR: PAGE_ID is empty"
      usage
      exit 1
    fi
    if [[ -z "$STATUS_NAME" ]]; then
      log "ERROR: STATUS_NAME is empty"
      usage
      exit 1
    fi
    # Basic UUID-shape sanity (8-4-4-4-12 hex). Allows dashes, no length check beyond pattern.
    if ! [[ "$PAGE_ID" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]]; then
      log "WARNING: PAGE_ID does not look like a UUID (proceeding anyway): $PAGE_ID"
    fi
    patch_status "$PAGE_ID" "$STATUS_NAME"
    exit $?
    ;;
esac
