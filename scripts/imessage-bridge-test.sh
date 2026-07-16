#!/bin/zsh
# scripts/imessage-bridge-test.sh — pre-flight checks for imessage-bridge.sh
# Safe to run any time. Performs no send.

emulate -L zsh
setopt err_return no_unset pipe_fail

SCRIPT_DIR=${0:a:h}
WORKSPACE=${WORKSPACE:-/Users/ainchorsoc2a/.openclaw/workspace}
STATE_DIR=${STATE_DIR:-$WORKSPACE/state}
ALLOWLIST=$STATE_DIR/imessage-bridge.allowlist
CONFIG=$STATE_DIR/imessage-bridge.config
KILLSWITCH=$STATE_DIR/imessage-bridge.disabled
AUDIT_JSONL=$STATE_DIR/imessage-audit.jsonl

ok()   { print -r -- "  ✅ $*"; }
fail() { print -r -- "  ❌ $*"; FAIL=1; }
info() { print -r -- "  • $*"; }
FAIL=0

print -r -- "iMessage Bridge — pre-flight"
print -r -- ""

# 1. osascript
if /usr/bin/osascript -e 'return name of application "Messages"' >/dev/null 2>&1; then
  ok "osascript can address Messages.app (Automation permission granted)"
else
  fail "osascript cannot address Messages.app — grant Automation permission to Terminal in System Settings → Privacy & Security → Automation"
fi

# 2. Messages.app installed
if [[ -d "/System/Applications/Messages.app" ]]; then
  ok "Messages.app installed"
else
  fail "Messages.app not found at /System/Applications/Messages.app"
fi

# 3. Allowlist
if [[ -f $ALLOWLIST ]]; then
  LINES=$(/usr/bin/wc -l < "$ALLOWLIST" | /usr/bin/tr -d ' ')
  ok "allowlist exists: $ALLOWLIST ($LINES entries)"
else
  fail "allowlist missing: $ALLOWLIST — create with one E.164 or iCloud email per line"
fi

# 4. Kill switch
if [[ -f $KILLSWITCH ]]; then
  fail "kill switch ACTIVE: $KILLSWITCH exists — sends are disabled. Remove the file to re-enable."
else
  ok "kill switch clear ($KILLSWITCH does not exist)"
fi

# 5. Audit log
if [[ -f $AUDIT_JSONL ]]; then
  SIZE=$(/bin/ls -l "$AUDIT_JSONL" | /usr/bin/awk '{print $5}')
  ok "audit log present: $AUDIT_JSONL ($SIZE bytes)"
else
  info "audit log will be created on first send: $AUDIT_JSONL"
fi

# 6. jq
if /usr/bin/command -v jq >/dev/null 2>&1; then
  ok "jq available"
else
  fail "jq missing — install with: brew install jq"
fi

# 7. Config (optional)
if [[ -f $CONFIG ]]; then
  ok "config present: $CONFIG"
  /bin/cat "$CONFIG" | while IFS= read -r line; do
    [[ -z "$line" || "$line" == \#* ]] && continue
    info "  $line"
  done
else
  info "config not present (defaults: DAILY_CAP=20 BODY_MAX=1000 REQUIRE_CONFIRM=1)"
fi

# 8. Daily count
if [[ -f $AUDIT_JSONL ]]; then
  TODAY=$(/bin/date +%Y-%m-%d)
  COUNT=$(/usr/bin/awk -v ts="$TODAY" '$0 ~ ts {n++} END{print n+0}' "$AUDIT_JSONL")
  info "today's send count: $COUNT/20"
fi

print -r -- ""
if (( FAIL )); then
  print -r -- "Result: ❌ one or more pre-flight checks failed"
  exit 1
fi
print -r -- "Result: ✅ pre-flight OK — ready for human-approved send"
exit 0
