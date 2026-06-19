#!/bin/bash
# notion-env-check.sh — Validate Notion API auth and DB reachability
# Usage: bash agent-skills/notion/scripts/notion-env-check.sh
# Exit codes: 0 = all OK, 1 = auth/key issue, 2 = DB unreachable, 3 = other

set -euo pipefail

NOTION_KEY_FILE="${HOME}/.config/notion/api_key"
NOTION_API="https://api.notion.com/v1"
NOTION_VERSION="2022-06-28"

DB_BACKLOG="34dc1829-53ff-814b-8257-d3a3bf351d44"
DB_AUTOHEAL="364c1829-53ff-81c0-9dbd-ff2c907d1a6b"
DB_ARCHIVE="364c1829-53ff-818e-a783-ebafcb6a9880"

log() { echo "[notion-env-check] $1"; }

# 1. API key exists
if [[ ! -f "$NOTION_KEY_FILE" ]]; then
  log "ERROR: Notion API key file not found at $NOTION_KEY_FILE"
  exit 1
fi

NOTION_KEY="$(cat "$NOTION_KEY_FILE" 2>/dev/null || true)"
if [[ -z "$NOTION_KEY" ]]; then
  log "ERROR: Notion API key file is empty"
  exit 1
fi

# 2. Auth check
AUTH_RESP="$(curl -s -w "\nHTTP_CODE:%{http_code}" "$NOTION_API/users/me" \
  -H "Authorization: Bearer $NOTION_KEY" \
  -H "Notion-Version: $NOTION_VERSION")"
AUTH_CODE="$(echo "$AUTH_RESP" | grep "HTTP_CODE:" | cut -d: -f2)"
AUTH_BODY="$(echo "$AUTH_RESP" | sed '/HTTP_CODE:/d')"

if [[ "$AUTH_CODE" != "200" ]]; then
  log "ERROR: Notion auth failed (HTTP $AUTH_CODE)"
  echo "$AUTH_BODY" | jq . 2>/dev/null || echo "$AUTH_BODY"
  exit 1
fi

USER_NAME="$(echo "$AUTH_BODY" | jq -r '.name // "unknown"')"
log "Auth OK: user=$USER_NAME"

# 3. DB reachability
DB_ERRORS=0
check_db() {
  local name="$1"
  local db_id="$2"

  local resp
  resp="$(curl -s -w "\nHTTP_CODE:%{http_code}" "$NOTION_API/databases/$db_id" \
    -H "Authorization: Bearer $NOTION_KEY" \
    -H "Notion-Version: $NOTION_VERSION")"

  local code
  code="$(echo "$resp" | grep "HTTP_CODE:" | cut -d: -f2)"

  if [[ "$code" == "200" ]]; then
    log "DB OK: $name ($db_id)"
  else
    log "DB FAIL: $name ($db_id) — HTTP $code"
    DB_ERRORS=$((DB_ERRORS+1))
  fi
}

check_db "Backlog" "$DB_BACKLOG"
check_db "Auto-Heal" "$DB_AUTOHEAL"
check_db "Archive" "$DB_ARCHIVE"

if [[ "$DB_ERRORS" -gt 0 ]]; then
  log "ERROR: $DB_ERRORS database(s) unreachable"
  exit 2
fi

log "All checks passed"
exit 0
