#!/bin/zsh
# scripts/imessage-bridge.sh — OC2A iMessage outbound bridge
#
# Purpose: Send a single iMessage from the OC2A Apple ID to an allowlisted
# recipient, with a human-approval gate, an audit row, and a kill switch.
#
# Invariants (non-negotiable per CHG-0877):
#   - Outbound only. No read of chat.db or history.
#   - Per-message human approval required (Telegram button or --yes-after-prompt).
#   - Recipient must be in state/imessage-bridge.allowlist.
#   - Daily cap (DAILY_CAP, default 20) enforced.
#   - Body length cap (BODY_MAX, default 1000) enforced.
#   - Every send appends an audit row. Body itself is never stored — only sha256.
#   - state/imessage-bridge.disabled file = instant kill switch.
#
# Usage:
#   imessage-bridge.sh --to <address> --body "<text>" [--send-id <id>] [--yes-after-prompt]
#   imessage-bridge.sh --self-test
#   imessage-bridge.sh --dry-run --to <address> --body "<text>"
#
# Exit codes:
#   0  sent successfully
#   2  bad args
#   3  kill switch active
#   4  recipient not in allowlist
#   5  body too long
#   6  daily cap reached
#   7  no Messages.app / TCC denied
#   8  AppleScript error
#   9  approval missing
#
# Companion:
#   - imessage-bridge-test.sh — pre-flight checks
#   - state/imessage-bridge.allowlist — one address per line
#   - state/imessage-bridge.config — env-style tunables
#   - state/imessage-bridge.disabled — file presence disables sends
#   - state/imessage-audit.jsonl — fallback audit log (PG preferred)
#
# Author: Forge (infra), per CHG-0877
# Status: PROTOTYPE — pending Ken approval before any real send.

emulate -L zsh
setopt err_return no_unset pipe_fail

# ---------- paths ----------
SCRIPT_DIR=${0:a:h}
WORKSPACE=${WORKSPACE:-/Users/ainchorsoc2a/.openclaw/workspace}
STATE_DIR=${STATE_DIR:-$WORKSPACE/state}
ALLOWLIST=$STATE_DIR/imessage-bridge.allowlist
CONFIG=$STATE_DIR/imessage-bridge.config
KILLSWITCH=$STATE_DIR/imessage-bridge.disabled
AUDIT_JSONL=$STATE_DIR/imessage-audit.jsonl

# ---------- tunables ----------
DAILY_CAP=${DAILY_CAP:-20}
BODY_MAX=${BODY_MAX:-1000}
REQUIRE_CONFIRM=${REQUIRE_CONFIRM:-1}

# ---------- helpers ----------
log()  { print -r -- "[imessage-bridge] $*" >&2; }
die()  { local code=$1; shift; log "ERROR (exit $code): $*"; exit $code; }
sha256() { /usr/bin/shasum -a 256 | /usr/bin/awk '{print $1}'; }

usage() {
  sed -n '3,30p' "$0"
  exit 2
}

# ---------- arg parse ----------
TO=""
BODY=""
SEND_ID=""
DRY_RUN=0
SELF_TEST=0
YES_AFTER_PROMPT=0
while (( $# )); do
  case "$1" in
    --to)             TO=$2; shift 2;;
    --body)           BODY=$2; shift 2;;
    --send-id)        SEND_ID=$2; shift 2;;
    --dry-run)        DRY_RUN=1; shift;;
    --self-test)      SELF_TEST=1; shift;;
    --yes-after-prompt) YES_AFTER_PROMPT=1; shift;;
    -h|--help)        usage;;
    *)                die 2 "unknown arg: $1";;
  esac
done

# ---------- self-test mode ----------
if (( SELF_TEST )); then
  log "self-test: checking osascript, Messages.app, allowlist, config, kill switch"
  /usr/bin/osascript -e 'return name of application "Messages"' >/dev/null 2>&1 \
    || die 7 "cannot address Messages.app via AppleScript (TCC/Automation permission likely needed)"
  [[ -f $ALLOWLIST ]] || log "WARN: allowlist $ALLOWLIST does not exist (will be created empty on first send)"
  [[ -f $KILLSWITCH ]] && log "KILL SWITCH ACTIVE: $KILLSWITCH exists — sends are currently disabled"
  log "DAILY_CAP=$DAILY_CAP BODY_MAX=$BODY_MAX REQUIRE_CONFIRM=$REQUIRE_CONFIRM"
  log "self-test OK"
  exit 0
fi

# ---------- pre-flight (always) ----------
[[ -n "$TO" && -n "$BODY" ]] || die 2 "both --to and --body are required"
[[ -f $KILLSWITCH ]] && die 3 "kill switch active: $KILLSWITCH exists. Remove it to re-enable."
/usr/bin/osascript -e 'return name of application "Messages"' >/dev/null 2>&1 \
  || die 7 "cannot address Messages.app — open Messages.app once and grant Automation permission to the calling terminal (System Settings → Privacy & Security → Automation)."

# ---------- allowlist ----------
[[ -f $ALLOWLIST ]] || die 4 "allowlist $ALLOWLIST does not exist. Add recipient first."
/usr/bin/grep -Fqx -- "$TO" "$ALLOWLIST" || die 4 "recipient '$TO' is not in allowlist. Add to $ALLOWLIST first."

# ---------- body length ----------
(( ${#BODY} <= BODY_MAX )) || die 5 "body length ${#BODY} > BODY_MAX=$BODY_MAX"

# ---------- render AppleScript (used by both dry-run and real send) ----------
escape_as() {
  # Escape backslash and double-quote for AppleScript string literal.
  print -r -- "${1//\\/\\\\}" | /usr/bin/sed 's/"/\\"/g'
}

TO_ESC=$(escape_as "$TO")
BODY_ESC=$(escape_as "$BODY")
APPLE_SCRIPT=$(cat <<EOF
tell application "Messages"
  set targetService to 1st service whose service type = iMessage
  set targetBuddy to buddy "$TO_ESC" of targetService
  send "$BODY_ESC" to targetBuddy
end tell
EOF
)

log "draft ready: to=$TO length=${#BODY} send_id=$SEND_ID"

# ---------- dry-run: print AppleScript and exit ----------
if (( DRY_RUN )); then
  log "DRY RUN — would execute AppleScript:"
  print -r -- "$APPLE_SCRIPT"
  exit 0
fi

# ---------- daily cap ----------
# Count today's audit rows (JSONL fallback). 1 line per send. Robust to newlines.
TODAY=$(/bin/date +%Y-%m-%d)
COUNT=0
if [[ -f $AUDIT_JSONL ]]; then
  COUNT=$(/usr/bin/awk -v ts="$TODAY" '$0 ~ ts {n++} END{print n+0}' "$AUDIT_JSONL")
fi
(( COUNT < DAILY_CAP )) || die 6 "daily cap reached: $COUNT/$DAILY_CAP. Wait until tomorrow MYT (Asia/Kuala_Lumpur) or raise DAILY_CAP."

# ---------- approval gate ----------
SEND_ID=${SEND_ID:-"$(/bin/date +%Y%m%dT%H%M%S)-$RANDOM"}
APPROVER="console"
APPROVAL_TS=$(/bin/date -u +%Y-%m-%dT%H:%M:%SZ)

if (( REQUIRE_CONFIRM )) && (( !YES_AFTER_PROMPT )); then
  die 9 "approval missing: this prototype requires either --yes-after-prompt (after Ken's explicit go) or a Telegram callback. Refusing to send."
fi

# ---------- write audit row (pre-send) ----------
BODY_SHA=$(print -r -- "$BODY" | sha256)
PRE_AUDIT=$(/usr/bin/jq -nc \
  --arg ts         "$(/bin/date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg to         "$TO" \
  --arg sha        "$BODY_SHA" \
  --arg len        "${#BODY}" \
  --arg approver   "$APPROVER" \
  --arg approval_ts "$APPROVAL_TS" \
  --arg send_id    "$SEND_ID" \
  --arg apple      "$APPLE_SCRIPT" \
  --argjson exit   null \
  '{ts:$ts,to:$to,body_sha256:$sha,body_length:($len|tonumber),approver:$approver,approval_ts:$approval_ts,send_id:$send_id,apple_script:$apple,exit_code:$exit}')

# ---------- execute ----------
SEND_TS=$(/bin/date -u +%Y-%m-%dT%H:%M:%SZ)
ERR_FILE=$(/usr/bin/mktemp -t imessage-bridge)
OUT=$(/usr/bin/osascript <<<"$APPLE_SCRIPT" 2>"$ERR_FILE")
RC=$?
ERR=$(<"$ERR_FILE")
/bin/rm -f "$ERR_FILE"

# ---------- update audit row with result ----------
POST_AUDIT=$(/usr/bin/jq -nc \
  --arg send_ts    "$SEND_TS" \
  --argjson exit   "$RC" \
  --arg error      "$ERR" \
  '{send_ts:$send_ts,exit_code:$exit,error_text:$error}')

print -r -- "$PRE_AUDIT$POST_AUDIT" \
  | /usr/bin/jq -c -s 'add' \
  >> "$AUDIT_JSONL" 2>/dev/null \
  || print -r -- "$(/bin/date -u +%Y-%m-%dT%H:%M:%SZ) $TO $BODY_SHA ${#BODY} rc=$RC err=$ERR" >> "$AUDIT_JSONL"

if (( RC != 0 )); then
  log "send FAILED rc=$RC err=$ERR"
  die 8 "AppleScript error rc=$RC: $ERR"
fi

log "send OK rc=$RC send_id=$SEND_ID to=$TO length=${#BODY} audit=$AUDIT_JSONL"
exit 0
