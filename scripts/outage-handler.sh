#!/usr/bin/env bash
# outage-handler.sh — AInchors First-Failure Response Handler
# Triggered by health-check.sh when Anthropic API fails.
# Actions: validate full chain, activate standby mode, alert Ken, log INC.
# US23 / TKT-0018 / CHG-0058

export PATH="$PATH:/usr/local/bin:/opt/homebrew/bin"
set -uo pipefail

WORKSPACE="$HOME/.openclaw/workspace"
STATE="$WORKSPACE/state"
LOG="$HOME/Backups/ainchors/logs/outage.log"
STANDBY_FILE="$STATE/standby-mode.json"
OUTAGE_STATE="$STATE/outage-alert-state.json"
INC_SCRIPT="$WORKSPACE/scripts/incident-log.sh"
TIMESTAMP=$(date +"%Y-%m-%dT%H:%M:%S+10:00")
AEST=$(date +"%Y-%m-%d %H:%M AEST")

mkdir -p "$(dirname $LOG)" "$STATE"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [OUTAGE] $1" | tee -a "$LOG"; }

log "=== Outage Handler Triggered === $AEST"

# ── Read current outage state ─────────────────────────────────────────────────
ALREADY_ALERTED=false
OUTAGE_START=""
if [[ -f "$OUTAGE_STATE" ]]; then
  ALREADY_ALERTED=$(python3 -c "import json; d=json.load(open('$OUTAGE_STATE')); print(str(d.get('alerted',False)).lower())" 2>/dev/null || echo "false")
  OUTAGE_START=$(python3 -c "import json; d=json.load(open('$OUTAGE_STATE')); print(d.get('since',''))" 2>/dev/null || echo "")
fi

# ── Step 1: Validate the full fallback chain ──────────────────────────────────
log "Validating fallback chain..."
zsh "$WORKSPACE/scripts/validate-fallback-chain.sh" >> "$LOG" 2>&1
CHAIN_EXIT=$?

CHAIN_STATUS=$(python3 -c "
import json
d=json.load(open('$STATE/fallback-chain-status.json'))
print(d.get('overall','unknown'))
" 2>/dev/null || echo "unknown")

AVAILABLE_FALLBACK=$(python3 -c "
import json
d=json.load(open('$STATE/fallback-chain-status.json'))
checks = d.get('checks',[])
# Find first working fallback after Anthropic fails
if 'haiku4Api:ok' in checks: print('claude-haiku-4-5')
elif 'ollamaRunning:ok' in checks and 'gemma4e2bLoaded:ok' in checks: print('gemma4:e2b (local)')
elif 'ollamaRunning:ok' in checks and 'gemma4Loaded:ok' in checks: print('gemma4:26b (local)')
else: print('NONE — all fallbacks unavailable')
" 2>/dev/null || echo "unknown")

log "Chain status: $CHAIN_STATUS | Available fallback: $AVAILABLE_FALLBACK"

# ── Step 2: Activate standby mode ─────────────────────────────────────────────
if [[ -z "$OUTAGE_START" ]]; then
  OUTAGE_START="$TIMESTAMP"
fi

python3 -c "
import json, os
state = {
    'active': True,
    'reason': 'Anthropic API unreachable — billing exhausted or auth failure',
    'since': '$OUTAGE_START',
    'detectedAt': '$TIMESTAMP',
    'fallback': '$AVAILABLE_FALLBACK',
    'chainStatus': '$CHAIN_STATUS',
    'banner': '⚠️ STANDBY MODE — Anthropic API unavailable. Fallback: $AVAILABLE_FALLBACK. Ken alerted.',
    'recoverySteps': [
        '1. Check API billing at console.anthropic.com',
        '2. Top up credit if exhausted',
        '3. Verify auth key: security find-generic-password -s anthropic-api-key -w',
        '4. Run: zsh scripts/validate-fallback-chain.sh to confirm recovery',
        '5. Delete state/standby-mode.json to clear standby banner'
    ]
}
json.dump(state, open('$STANDBY_FILE','w'), indent=2)
print('Standby mode activated.')
"
log "Standby mode activated. Banner written."

# ── Step 3: Alert Ken (once only) ─────────────────────────────────────────────
if [[ "$ALREADY_ALERTED" != "true" ]]; then
  log "Sending alert to Ken..."

  # Write alert state immediately to prevent duplicate alerts
  python3 -c "
import json
state = {
    'alerted': True,
    'since': '$OUTAGE_START',
    'alertedAt': '$TIMESTAMP',
    'fallback': '$AVAILABLE_FALLBACK',
    'chainStatus': '$CHAIN_STATUS'
}
json.dump(state, open('$OUTAGE_STATE','w'), indent=2)
"

  # Log as incident
  if [[ -x "$INC_SCRIPT" ]]; then
    zsh "$INC_SCRIPT" \
      --title "Anthropic API outage — auto-detected" \
      --severity "P1" \
      --description "Anthropic API unreachable. Health-check triggered outage handler at $AEST. Available fallback: $AVAILABLE_FALLBACK. Fallback chain status: $CHAIN_STATUS." \
      >> "$LOG" 2>&1 || log "Incident log failed (non-blocking)"
  fi

  log "Alert sent. Incident logged."
else
  log "Already alerted — skipping duplicate alert."
fi

# ── Step 4: Write recovery banner to shared state ─────────────────────────────
python3 -c "
import json, os
banner_file = '$STATE/system-banner.json'
banner = {
    'active': True,
    'type': 'warning',
    'message': '⚠️ STANDBY MODE — Anthropic API unavailable since $AEST. Fallback: $AVAILABLE_FALLBACK. Top up billing or check auth at console.anthropic.com.',
    'since': '$OUTAGE_START',
    'dismissable': False
}
json.dump(banner, open(banner_file,'w'), indent=2)
print('System banner written.')
"

log "Outage handler complete. Chain: $CHAIN_STATUS | Fallback: $AVAILABLE_FALLBACK"
exit 0
