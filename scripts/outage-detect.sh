#!/bin/zsh
# AInchors Outage Detector — US23
# Tests Anthropic API health, activates standby mode on failure, clears on recovery.
#
# Fallback chain (CHG-0075): Sonnet → Haiku → (Anthropic down = standby; Gemma4 for bg crons only)
#
# Exit codes:
#   0 = Anthropic healthy
#   1 = Outage detected / standby activated
#
# State files written:
#   state/standby-mode.json       — present + active:true when in standby
#   state/system-banner.json      — active:true shows banner to Ken
#   state/fallback-chain-status.json — updated via validate-fallback-chain.sh on failure
#
# Trigger files (for main session to pick up and Telegram-alert Ken):
#   /tmp/outage-alert-pending.txt   — written when new outage detected
#   /tmp/outage-recovery-pending.txt — written when outage clears

set -uo pipefail

WORKSPACE="$HOME/.openclaw/workspace"
SCRIPTS="$WORKSPACE/scripts"
STATE="$WORKSPACE/state"
LOG="$HOME/Backups/ainchors/logs/outage-detect.log"
STANDBY_FILE="$STATE/standby-mode.json"
BANNER_FILE="$STATE/system-banner.json"
VALIDATE_CHAIN="$SCRIPTS/validate-fallback-chain.sh"

mkdir -p "$(dirname "$LOG")" "$STATE"

TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [outage-detect] $1" | tee -a "$LOG"
}

# ── Retrieve Anthropic key from keychain ──────────────────────────────────────
# Source of truth: auth-profiles.json (keychain may be stale after rotation)
ANTHROPIC_KEY=$(jq -r '.profiles["anthropic:default"].key // empty' /Users/ainchorsangiefpl/.openclaw/agents/main/agent/auth-profiles.json 2>/dev/null || security find-generic-password -s "ainchors-anthropic-api-key" -a "anthropic" -w 2>/dev/null || security find-generic-password -s "anthropic-api-key" -a "ainchors" -w 2>/dev/null || echo "")

if [[ -z "$ANTHROPIC_KEY" || ${#ANTHROPIC_KEY} -lt 20 ]]; then
  log "FAIL — Anthropic key missing from keychain"
  OUTAGE_REASON="Anthropic API key missing from keychain"
  ANTHROPIC_HTTP="no-key"
else
  # ── Test Anthropic API (10s timeout per spec) ─────────────────────────────
  ANTHROPIC_HTTP=$(curl -s -o /dev/null -w "%{http_code}" \
    --connect-timeout 10 \
    --max-time 10 \
    -H "x-api-key: $ANTHROPIC_KEY" \
    -H "anthropic-version: 2023-06-01" \
    "https://api.anthropic.com/v1/models" 2>/dev/null || echo "000")

  if [[ "$ANTHROPIC_HTTP" == "200" ]]; then
    ANTHROPIC_OK=true
  else
    ANTHROPIC_OK=false
    case "$ANTHROPIC_HTTP" in
      401|403) OUTAGE_REASON="Anthropic API auth/key failure (HTTP $ANTHROPIC_HTTP)" ;;
      402)     OUTAGE_REASON="Anthropic billing failure — account suspended (HTTP $ANTHROPIC_HTTP)" ;;
      429)     OUTAGE_REASON="Anthropic rate limit exceeded (HTTP $ANTHROPIC_HTTP)" ;;
      5*)      OUTAGE_REASON="Anthropic API server error (HTTP $ANTHROPIC_HTTP)" ;;
      000)     OUTAGE_REASON="Anthropic API unreachable — network/DNS failure" ;;
      *)       OUTAGE_REASON="Anthropic API unavailable (HTTP $ANTHROPIC_HTTP)" ;;
    esac
  fi
fi

# ── Was we already in standby? ────────────────────────────────────────────────
WAS_IN_STANDBY=false
if [[ -f "$STANDBY_FILE" ]]; then
  STANDBY_ACTIVE=$(python3 -c "import json; d=json.load(open('$STANDBY_FILE')); print(str(d.get('active',False)).lower())" 2>/dev/null || echo "false")
  [[ "$STANDBY_ACTIVE" == "true" ]] && WAS_IN_STANDBY=true
fi

# ═══════════════════════════════════════════════════════════════════════════════
# OUTAGE PATH
# ═══════════════════════════════════════════════════════════════════════════════
if [[ "${ANTHROPIC_OK:-false}" != "true" ]]; then
  log "OUTAGE — $OUTAGE_REASON"

  # ── Run validate-fallback-chain.sh ──────────────────────────────────────────
  if [[ -x "$VALIDATE_CHAIN" ]]; then
    log "Running validate-fallback-chain.sh..."
    zsh "$VALIDATE_CHAIN" >> "$LOG" 2>&1 && CHAIN_OK=true || CHAIN_OK=false
    log "Fallback chain validation: $( [[ "$CHAIN_OK" == "true" ]] && echo "OK" || echo "BROKEN" )"
  else
    log "WARN — validate-fallback-chain.sh not found at $VALIDATE_CHAIN"
    CHAIN_OK=false
  fi

  # ── Preserve original 'since' if already in standby ──────────────────────
  SINCE_TS="$TIMESTAMP"
  if [[ "$WAS_IN_STANDBY" == "true" ]]; then
    SINCE_TS=$(python3 -c "import json; d=json.load(open('$STANDBY_FILE')); print(d.get('since','$TIMESTAMP'))" 2>/dev/null || echo "$TIMESTAMP")
  fi

  # ── Write standby-mode.json ───────────────────────────────────────────────
  python3 - << PYEOF
import json
state = {
  "active": True,
  "since": "$SINCE_TS",
  "detectedAt": "$TIMESTAMP",
  "reason": "$OUTAGE_REASON",
  "fallback": "ollama/gemma4:26b",
  "fallbackScope": "background-crons-only",
  "policy": "CHG-0075: Gemma4 standby for bg crons only. Interactive sessions paused until Anthropic restored.",
  "anthropicHttp": "$ANTHROPIC_HTTP"
}
json.dump(state, open("$STANDBY_FILE", "w"), indent=2)
print("standby-mode.json written — active=true")
PYEOF
  log "standby-mode.json written"

  # ── Write system-banner.json ──────────────────────────────────────────────
  python3 - << PYEOF
import json
banner = {
  "active": True,
  "type": "critical",
  "title": "⚠️ STANDBY MODE — Anthropic API Unavailable",
  "message": "$OUTAGE_REASON. Switched to standby mode. Gemma4 (local) handling background crons only. Interactive sessions paused. Check billing console and Anthropic status page.",
  "since": "$SINCE_TS",
  "dismissable": False,
  "links": [
    {"label": "Anthropic Status", "url": "https://status.anthropic.com"},
    {"label": "Billing Console", "url": "https://console.anthropic.com/settings/billing"}
  ],
  "recovery": "Run scripts/outage-detect.sh after resolving. Banner clears automatically on recovery."
}
json.dump(banner, open("$BANNER_FILE", "w"), indent=2)
print("system-banner.json written — active=true (critical)")
PYEOF
  log "system-banner.json written (critical banner active)"

  # ── Write /tmp/outage-alert-pending.txt (only if NEW outage) ─────────────
  if [[ "$WAS_IN_STANDBY" != "true" ]]; then
    cat > /tmp/outage-alert-pending.txt << EOF
🚨 ANTHROPIC API OUTAGE DETECTED

Time: $(date '+%Y-%m-%d %H:%M:%S AEST')
Reason: $OUTAGE_REASON

Yoda is now in STANDBY MODE.
• Background crons: Gemma4 (local) only
• Interactive sessions: PAUSED
• All state saved — ready to resume when Anthropic is back

To triage:
1. Check https://status.anthropic.com
2. Check https://console.anthropic.com/settings/billing
3. Verify key: security find-generic-password -s "ainchors-anthropic-api-key" -a "anthropic" -w 2>/dev/null || security find-generic-password -s "anthropic-api-key" -w | head -c 20
4. Re-run: zsh scripts/outage-detect.sh

Fallback chain: Sonnet → Haiku → STANDBY (CHG-0075)
Recovery doc: Operations/GatewayRecovery.md
EOF
    log "Trigger file written: /tmp/outage-alert-pending.txt (new outage)"
  else
    log "Already in standby — skipping duplicate outage-alert-pending.txt"
  fi

  exit 1
fi

# ═══════════════════════════════════════════════════════════════════════════════
# HEALTHY PATH
# ═══════════════════════════════════════════════════════════════════════════════
log "OK — Anthropic API healthy (HTTP $ANTHROPIC_HTTP)"

# ── Clear standby if we were in it ────────────────────────────────────────────
if [[ "$WAS_IN_STANDBY" == "true" ]]; then
  # Read 'since' for recovery message before deleting
  STANDBY_SINCE=$(python3 -c "import json; d=json.load(open('$STANDBY_FILE')); print(d.get('since','unknown'))" 2>/dev/null || echo "unknown")

  # Clear standby
  python3 - << PYEOF
import json
state = {"active": False, "clearedAt": "$TIMESTAMP", "reason": "Anthropic API recovered"}
json.dump(state, open("$STANDBY_FILE", "w"), indent=2)
print("standby-mode.json updated — active=false (cleared)")
PYEOF
  log "standby-mode.json cleared"

  # Update banner to inactive
  python3 - << PYEOF
import json
banner = {
  "active": False,
  "type": "recovery",
  "title": "✅ Anthropic API Recovered",
  "message": "Anthropic API is back online. Standby mode cleared. Normal operations resumed.",
  "clearedAt": "$TIMESTAMP",
  "dismissable": True
}
json.dump(banner, open("$BANNER_FILE", "w"), indent=2)
print("system-banner.json updated — active=false (recovery)")
PYEOF
  log "system-banner.json updated (recovery banner)"

  # Write recovery trigger file
  cat > /tmp/outage-recovery-pending.txt << EOF
✅ ANTHROPIC API RECOVERED

Time: $(date '+%Y-%m-%d %H:%M:%S AEST')
Standby since: $STANDBY_SINCE

Yoda is back to NORMAL OPERATIONS.
• Sonnet (primary) restored
• Haiku (fallback) on standby
• Gemma4 background crons resumed normally

All systems green. No action needed.
EOF
  log "Trigger file written: /tmp/outage-recovery-pending.txt"
else
  log "Anthropic OK — not in standby, nothing to clear"
fi

exit 0
