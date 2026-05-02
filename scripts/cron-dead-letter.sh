#!/bin/zsh
# cron-dead-letter.sh — Fail-fast dead-letter handler for cron jobs
# Call this from any cron on failure to track repeat failures and suppress retry cascades.
#
# Usage: cron-dead-letter.sh <cron_id> <cron_name> <error_message>
#
# Outputs:
#   state/cron-dead-letter.json   — per-cron failure state
#   state/cron-dead-letter-alert.json — alert file for heartbeat (if failCount >= 3 in 1h)
#   obs.db                        — cron_dead_letter event
#
# Exit codes:
#   0 = logged, cron may proceed (< 3 fails in 1h)
#   1 = dead-lettered (>= 3 fails in 1h) — cron should abort/skip this run

set -uo pipefail

WORKSPACE="${WORKSPACE:-$HOME/.openclaw/workspace}"
STATE_DIR="$WORKSPACE/state"
DL_FILE="$STATE_DIR/cron-dead-letter.json"
ALERT_FILE="$STATE_DIR/cron-dead-letter-alert.json"
OBS_LOG="$WORKSPACE/scripts/obs-log.sh"

DEAD_LETTER_THRESHOLD=3   # failures within window = dead-lettered
DEAD_LETTER_WINDOW=3600   # 1 hour in seconds

# ── Args ──────────────────────────────────────────────────────────────────────
if (( $# < 3 )); then
  echo "[cron-dead-letter] ERROR: Usage: $0 <cron_id> <cron_name> <error_message>" >&2
  exit 1
fi

CRON_ID="$1"
CRON_NAME="$2"
ERROR_MSG="$3"
NOW=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
NOW_EPOCH=$(date +%s)

mkdir -p "$STATE_DIR"

# ── Load or init dead-letter state ────────────────────────────────────────────
if [[ -f "$DL_FILE" ]]; then
  DL_JSON=$(cat "$DL_FILE")
else
  DL_JSON='[]'
fi

# ── Check if this cron already has an entry ───────────────────────────────────
EXISTING=$(echo "$DL_JSON" | jq -r --arg id "$CRON_ID" '.[] | select(.cronId == $id) | @json' 2>/dev/null || echo "")

if [[ -z "$EXISTING" ]]; then
  # New entry
  FAIL_COUNT=1
  FIRST_FAIL_AT="$NOW"
  FIRST_FAIL_EPOCH=$NOW_EPOCH
  STATUS="active"
else
  FAIL_COUNT=$(echo "$EXISTING" | jq -r '.failCount // 0')
  FAIL_COUNT=$(( FAIL_COUNT + 1 ))
  FIRST_FAIL_AT=$(echo "$EXISTING" | jq -r '.firstFailAt // empty')
  FIRST_FAIL_EPOCH=$(echo "$EXISTING" | jq -r '.firstFailEpoch // 0')
  STATUS=$(echo "$EXISTING" | jq -r '.status // "active"')
fi

# ── Determine if within dead-letter window ────────────────────────────────────
WINDOW_AGE=$(( NOW_EPOCH - FIRST_FAIL_EPOCH ))
if (( FIRST_FAIL_EPOCH > 0 && WINDOW_AGE > DEAD_LETTER_WINDOW )); then
  # Window expired — reset counter (new failure window)
  FAIL_COUNT=1
  FIRST_FAIL_AT="$NOW"
  FIRST_FAIL_EPOCH=$NOW_EPOCH
  STATUS="active"
fi

# ── Determine status ──────────────────────────────────────────────────────────
if (( FAIL_COUNT >= DEAD_LETTER_THRESHOLD )); then
  STATUS="dead-lettered"
fi

# ── Build updated entry ───────────────────────────────────────────────────────
NEW_ENTRY=$(jq -n \
  --arg cronId      "$CRON_ID" \
  --arg name        "$CRON_NAME" \
  --arg lastError   "$ERROR_MSG" \
  --argjson failCount "$FAIL_COUNT" \
  --arg firstFailAt "$FIRST_FAIL_AT" \
  --argjson firstFailEpoch "$FIRST_FAIL_EPOCH" \
  --arg lastFailAt  "$NOW" \
  --arg status      "$STATUS" \
  '{
    cronId: $cronId,
    name: $name,
    lastError: $lastError,
    failCount: $failCount,
    firstFailAt: $firstFailAt,
    firstFailEpoch: $firstFailEpoch,
    lastFailAt: $lastFailAt,
    status: $status
  }')

# ── Upsert into DL_JSON ───────────────────────────────────────────────────────
UPDATED_JSON=$(echo "$DL_JSON" | jq \
  --arg id "$CRON_ID" \
  --argjson entry "$NEW_ENTRY" \
  'map(select(.cronId != $id)) + [$entry]')

echo "$UPDATED_JSON" > "$DL_FILE"
echo "[cron-dead-letter] [$CRON_ID] '$CRON_NAME' failCount=$FAIL_COUNT status=$STATUS"

# ── Write alert if dead-lettered ─────────────────────────────────────────────
if [[ "$STATUS" == "dead-lettered" ]]; then
  # Load or init alert file
  if [[ -f "$ALERT_FILE" ]]; then
    ALERT_JSON=$(cat "$ALERT_FILE")
  else
    ALERT_JSON='{"alerts":[]}'
  fi

  # Upsert alert entry for this cron
  ALERT_ENTRY=$(jq -n \
    --arg cronId      "$CRON_ID" \
    --arg name        "$CRON_NAME" \
    --arg lastError   "$ERROR_MSG" \
    --argjson failCount "$FAIL_COUNT" \
    --arg detectedAt  "$NOW" \
    --arg ack         "false" \
    '{
      cronId: $cronId,
      name: $name,
      lastError: $lastError,
      failCount: $failCount,
      detectedAt: $detectedAt,
      acknowledged: $ack
    }')

  UPDATED_ALERT=$(echo "$ALERT_JSON" | jq \
    --arg id "$CRON_ID" \
    --argjson entry "$ALERT_ENTRY" \
    '.alerts = (.alerts | map(select(.cronId != $id))) + [$entry]')

  echo "$UPDATED_ALERT" > "$ALERT_FILE"
  echo "[cron-dead-letter] ⚠️  Dead-lettered: '$CRON_NAME' ($FAIL_COUNT failures). Alert written."
fi

# ── Emit obs event ────────────────────────────────────────────────────────────
OBS_LEVEL="WARN"
[[ "$STATUS" == "dead-lettered" ]] && OBS_LEVEL="ERROR"

OBS_DETAIL=$(jq -n \
  --arg cronId    "$CRON_ID" \
  --arg name      "$CRON_NAME" \
  --arg err       "$ERROR_MSG" \
  --argjson count "$FAIL_COUNT" \
  --arg status    "$STATUS" \
  '{cronId: $cronId, name: $name, failCount: $count, status: $status, lastError: ($err | .[0:200])}' \
  | tr -d '\n')

if [[ -x "$OBS_LOG" ]]; then
  bash "$OBS_LOG" \
    --source cron-dead-letter \
    --level "$OBS_LEVEL" \
    --type cron_dead_letter \
    --message "[$CRON_ID] '$CRON_NAME' failCount=$FAIL_COUNT status=$STATUS: ${ERROR_MSG:0:120}" \
    --job-id "$CRON_ID" \
    --detail "$OBS_DETAIL" 2>/dev/null || true
else
  echo "[cron-dead-letter] WARN: obs-log.sh not found/executable — skipping obs event" >&2
fi

# ── Exit code signals whether cron should abort ───────────────────────────────
if [[ "$STATUS" == "dead-lettered" ]]; then
  exit 1   # cron should skip/abort this run
fi
exit 0     # cron may proceed (but failure is logged)
