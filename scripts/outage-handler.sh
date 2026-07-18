#!/usr/bin/env bash
# outage-handler.sh — AInchors First-Failure Response Handler (CHG-0858)
# Triggered by health-check.sh when Ollama Cloud API fails.
# Actions: validate full chain, activate standby mode, alert Ken, log INC.
# Anthropic-specific handling removed per CHG-0855/CHG-0858.
# US23 / TKT-0018 / CHG-0058

export PATH="$PATH:/usr/local/bin:/opt/homebrew/bin"
set -uo pipefail

WORKSPACE="$HOME/.openclaw/workspace"
STATE="$WORKSPACE/state"
LOG="$HOME/Backups/ainchors/logs/outage.log"
STANDBY_FILE="$STATE/standby-mode.json"
OUTAGE_STATE="$STATE/outage-alert-state.json"
INC_SCRIPT="$WORKSPACE/scripts/incident-log.sh"
TIMESTAMP=$(date +"%Y-%m-%dT%H:%M:%S+08:00")
MYT=$(date +"%Y-%m-%d %H:%M MYT")

mkdir -p "$(dirname $LOG)" "$STATE"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [OUTAGE] $1" | tee -a "$LOG"; }

log "=== Outage Handler Triggered === $MYT"

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
# Find first working fallback after primary fails
if 'ollamaRunning:ok' in checks and 'gemma4Loaded:ok' in checks: print('gemma4:31b-cloud (Ollama)')
elif 'ollamaRunning:ok' in checks: print('Ollama running (models unknown)')
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
    'reason': 'Ollama Cloud unreachable — primary API failure',
    'since': '$OUTAGE_START',
    'detectedAt': '$TIMESTAMP',
    'fallback': '$AVAILABLE_FALLBACK',
    'chainStatus': '$CHAIN_STATUS',
    'banner': '⚠️ STANDBY MODE — Ollama Cloud unavailable. Fallback: $AVAILABLE_FALLBACK. Ken alerted.',
    'recoverySteps': [
        '1. Check Ollama service: curl http://localhost:11434/api/tags',
        '2. Verify network connectivity',
        '3. Run: zsh scripts/validate-fallback-chain.sh to confirm recovery',
        '4. Delete state/standby-mode.json to clear standby banner'
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
      --title "Ollama Cloud outage — auto-detected" \
      --severity "P1" \
      --description "Ollama Cloud unreachable. Health-check triggered outage handler at $MYT. Available fallback: $AVAILABLE_FALLBACK. Fallback chain status: $CHAIN_STATUS." \
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
    'message': '⚠️ STANDBY MODE — Ollama Cloud unavailable since $MYT. Fallback: $AVAILABLE_FALLBACK. Check connectivity or restart Ollama.',
    'since': '$OUTAGE_START',
    'dismissable': False
}
json.dump(banner, open(banner_file,'w'), indent=2)
print('System banner written.')
"

log "Outage handler complete. Chain: $CHAIN_STATUS | Fallback: $AVAILABLE_FALLBACK"
exit 0