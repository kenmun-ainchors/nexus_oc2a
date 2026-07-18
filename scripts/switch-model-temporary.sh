#!/usr/bin/env bash
# switch-model-temporary.sh — Temporary model switch with auto-reset cron
# Replaces raw session_status model=... calls for temporary pro switches.
# Schedules a one-shot cron to reset to primary after the specified duration.
# TKT-0547: Session model drift structural lock (Atom 2 of 3).
#
# Usage:
#   switch-model-temporary.sh <model> [duration]
#   model: model alias or full provider/model (e.g., deepseek-v4-pro, ollama/deepseek-v4-pro:cloud)
#   duration: auto-reset after (default: 30m). Supports: 15m, 30m, 1h, 2h
#
# Examples:
#   switch-model-temporary.sh deepseek-v4-pro 30m   # Switch to pro, reset to primary after 30 min
#   switch-model-temporary.sh deepseek-v4-pro 1h     # Switch to pro, reset after 1 hour
#
# The script does NOT actually switch the model — it outputs the instructions
# for Yoda to execute via session_status tool, AND schedules the reset cron.
# This is because session model switching requires the in-session session_status tool.

set -euo pipefail

WORKSPACE_ROOT="${WORKSPACE_ROOT:-/Users/ainchorsoc2a/.openclaw/workspace}"
POLICY="$WORKSPACE_ROOT/state/model-policy.json"

MODEL="${1:-}"
DURATION="${2:-30m}"

if [[ -z "$MODEL" ]]; then
  echo "Usage: switch-model-temporary.sh <model> [duration]"
  echo "  model: model alias (e.g., deepseek-v4-pro)"
  echo "  duration: 15m, 30m (default), 1h, 2h"
  exit 1
fi

# ── Resolve model alias to full provider/model ───────────────────────────────
resolve_model() {
  local alias="$1"
  case "$alias" in
    deepseek-v4-pro)    echo "ollama/deepseek-v4-pro:cloud" ;;
    deepseek-v4-flash)  echo "ollama/deepseek-v4-flash:cloud" ;;
    kimi-k2.7-code)     echo "ollama/kimi-k2.7-code:cloud" ;;
    kimi-k2.6)          echo "ollama/kimi-k2.6:cloud" ;;
    gemma4:31b)         echo "ollama/gemma4:31b-cloud" ;;
    minimax-m3)         echo "ollama/minimax-m3:cloud" ;;
    glm-5.1)            echo "ollama/glm-5.1:cloud" ;;
    ollama/*)           echo "$alias" ;;  # Already full path
    *)                  echo "ollama/${alias}:cloud" ;;  # Best-effort
  esac
}

FULL_MODEL=$(resolve_model "$MODEL")

# ── Resolve primary model to return to ────────────────────────────────────────
PRIMARY=$(python3 -c "
import json
with open('$POLICY') as f:
    policy = json.load(f)
tiers = policy.get('agentTiers', {})
for tier_key, tier in tiers.items():
    if 'main' in tier.get('agentIds', []):
        primary = tier.get('exceptions', {}).get('main') or tier.get('primary', 'NOT_SET')
        print(primary)
        break
" 2>/dev/null || echo "ollama/kimi-k2.7-code:cloud")

# ── Parse duration to minutes ────────────────────────────────────────────────
parse_duration_mins() {
  local d="$1"
  case "$d" in
    *m) echo "${d%m}" ;;
    *h) echo "$(( ${d%h} * 60 ))" ;;
    *) echo "30" ;;  # default
  esac
}

DURATION_MINS=$(parse_duration_mins "$DURATION")

# ── Calculate reset time ─────────────────────────────────────────────────────
RESET_EPOCH_MS=$(( $(date +%s) * 1000 + DURATION_MINS * 60 * 1000 ))
RESET_ISO=$(date -u -r $(( RESET_EPOCH_MS / 1000 )) +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u -d @$(( RESET_EPOCH_MS / 1000 )) +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null)
RESET_LOCAL=$(date -r $(( RESET_EPOCH_MS / 1000 )) +"%Y-%m-%dT%H:%M:%S+08:00" 2>/dev/null)

# ── Output instructions for Yoda ─────────────────────────────────────────────
cat <<EOF
═══════════════════════════════════════════════════════════════
  TEMPORARY MODEL SWITCH
═══════════════════════════════════════════════════════════════

  Switch to:    $FULL_MODEL
  Duration:     ${DURATION_MINS}min
  Reset to:     $PRIMARY
  Reset at:     $RESET_LOCAL

  ACTION REQUIRED (in-session):
    session_status model="$FULL_MODEL"

  AUTO-RESET CRON: scheduling now...
EOF

# ── Schedule the reset cron ──────────────────────────────────────────────────
# We write a cron payload file that the heartbeat handler (Yoda) picks up
# and executes via the cron tool. The cron will fire a systemEvent to the
# main session telling Yoda to reset the model.

CRON_PAYLOAD="$WORKSPACE_ROOT/state/pending-model-reset.json"

python3 -c "
import json
payload = {
    'action': 'reset-session-model',
    'agentId': 'main',
    'targetModel': '$PRIMARY',
    'currentModel': '$FULL_MODEL',
    'scheduledAt': '$(date -u +"%Y-%m-%dT%H:%M:%SZ")',
    'resetAt': '$RESET_ISO',
    'resetAtLocal': '$RESET_LOCAL',
    'durationMins': $DURATION_MINS,
    'triggeredBy': 'switch-model-temporary.sh',
    'status': 'pending'
}
with open('$CRON_PAYLOAD', 'w') as f:
    json.dump(payload, f, indent=2)
print('Pending reset written to state/pending-model-reset.json')
"

echo ""
echo "  ✅ Reset cron payload written."
echo "  Yoda will pick up state/pending-model-reset.json on next heartbeat"
echo "  and schedule the actual cron job via the cron tool."
echo ""
echo "  MANUAL OVERRIDE (anytime):"
echo "    session_status model=$PRIMARY"
echo ""
echo "═══════════════════════════════════════════════════════════════"
