#!/bin/zsh
# AInchors Fallback Chain Validator
# Run on gateway start — validates the full fallback chain is healthy.
# CHG-0426: Auto-derives expected chain from model-policy.json (nightly cache; PG is SSOT per CREST v1.3).
# CHG-0394: Permanent baseline is deepseek-v4-pro → gemma4:31b-cloud → kimi.
#
# Output: state/fallback-chain-status.json
# Alert:  /tmp/pvt-alert.txt (appended if any link broken)
# Exit:   0 = all OK | 1 = one or more broken

set -uo pipefail

WORKSPACE="$HOME/.openclaw/workspace"
STATE_FILE="$WORKSPACE/state/fallback-chain-status.json"
ALERT_FILE="/tmp/pvt-alert.txt"
OPENCLAW_CFG="$HOME/.openclaw/openclaw.json"
POLICY_FILE="$WORKSPACE/state/model-policy.json"

mkdir -p "$(dirname "$STATE_FILE")"

TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
BROKEN=()
RESULTS=()

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"; }

# ── LINK 1: Anthropic API key accessible ─────────────────────────────────────
# Source of truth: auth-profiles.json (keychain may be stale after rotation)
ANTHROPIC_KEY=$(jq -r '.profiles["anthropic:default"].key // empty' /Users/ainchorsangiefpl/.openclaw/agents/main/agent/auth-profiles.json 2>/dev/null || security find-generic-password -s "ainchors-anthropic-api-key" -a "anthropic" -w 2>/dev/null || security find-generic-password -s "anthropic-api-key" -a "ainchors" -w 2>/dev/null || echo "")
if [[ -n "$ANTHROPIC_KEY" && ${#ANTHROPIC_KEY} -gt 20 ]]; then
  log "LINK 1 (Anthropic key): OK"
  RESULTS+=("anthropicKey:ok")
  ANTHROPIC_KEY_OK=true
else
  log "LINK 1 (Anthropic key): BROKEN — not found in keychain"
  RESULTS+=("anthropicKey:broken")
  BROKEN+=("Anthropic API key missing from keychain")
  ANTHROPIC_KEY_OK=false
fi

# ── LINK 2: Anthropic API reachable ──────────────────────────────────────────
if [[ "$ANTHROPIC_KEY_OK" == "true" ]]; then
  HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    --connect-timeout 8 \
    -H "x-api-key: $ANTHROPIC_KEY" \
    -H "anthropic-version: 2023-06-01" \
    "https://api.anthropic.com/v1/models" 2>/dev/null)
  if [[ "$HTTP_STATUS" == "200" ]]; then
    log "LINK 2 (Anthropic API): OK (HTTP $HTTP_STATUS)"
    RESULTS+=("anthropicApi:ok")
  else
    log "LINK 2 (Anthropic API): BROKEN (HTTP $HTTP_STATUS)"
    RESULTS+=("anthropicApi:broken:$HTTP_STATUS")
    BROKEN+=("Anthropic API unreachable (HTTP $HTTP_STATUS)")
  fi
else
  RESULTS+=("anthropicApi:skipped")
fi

# ── LINK 3: Ollama running ────────────────────────────────────────────────────
OLLAMA_HTTP=$(curl -s -o /dev/null -w "%{http_code}" \
  --connect-timeout 5 \
  "http://localhost:11434/api/tags" 2>/dev/null)
if [[ "$OLLAMA_HTTP" == "200" ]]; then
  log "LINK 3 (Ollama process): OK"
  RESULTS+=("ollamaRunning:ok")
  OLLAMA_OK=true
else
  log "LINK 3 (Ollama process): BROKEN (HTTP $OLLAMA_HTTP)"
  RESULTS+=("ollamaRunning:broken:$OLLAMA_HTTP")
  BROKEN+=("Ollama not running (HTTP $OLLAMA_HTTP)")
  OLLAMA_OK=false
fi

# ── LINK 4: Gemma4 model loaded ───────────────────────────────────────────────
if [[ "$OLLAMA_OK" == "true" ]]; then
  GEMMA4_FOUND=$(curl -s "http://localhost:11434/api/tags" 2>/dev/null \
    | python3 -c "import json,sys; d=json.load(sys.stdin); found=any('gemma4' in m['name'] for m in d.get('models',[])); print('yes' if found else 'no')" 2>/dev/null || echo "no")
  if [[ "$GEMMA4_FOUND" == "yes" ]]; then
    log "LINK 4 (Gemma4 model): OK"
    RESULTS+=("gemma4Loaded:ok")
  else
    log "LINK 4 (Gemma4 model): BROKEN — gemma4 not in Ollama model list"
    RESULTS+=("gemma4Loaded:broken")
    BROKEN+=("Gemma4 model not loaded in Ollama")
  fi
else
  RESULTS+=("gemma4Loaded:skipped")
fi

# ── LINK 4b: Gemma4 warmup probe — DISABLED (Ken, 2026-06-02) ──────────────
# OC1 cannot load gemma4:26b within 90s (M4 24GB RAM pressure).
# Revisit at OC2 (TRIGGER-03) when 48GB M4 Pro arrives.
RESULTS+=("gemma4Warm:skipped")


# ── LINK 5: openclaw.json fallback chain for main (Yoda) agent ───────────────
# CHG-0426: Auto-derives expected chain from model-policy.json (nightly cache; PG is SSOT per CREST v1.3).
# Falls back to openclaw.json defaults if model-policy.json is missing.
# Also validates against globalAllowedModels for policy compliance.

# ── Derive expected chain from model-policy.json ──────────────────────────
if [[ -f "$POLICY_FILE" ]]; then
  DERIVED=$(python3 << EOF
import json
d = json.load(open('$POLICY_FILE'))
agent_tier = d.get('agents', {}).get('main', {}).get('tier', 'userFacing')
tier = d.get('agentTiers', {}).get(agent_tier, {})
expected_primary = tier.get('primary', '')
expected_fallbacks = tier.get('fallbacks', [])
expected_fallback_0 = expected_fallbacks[0] if len(expected_fallbacks) > 0 else ''
allowed = d.get('globalAllowedModels', [])
print(f'{expected_primary}|{expected_fallback_0}|{",".join(allowed)}')
EOF
  )
  EXPECTED_PRIMARY="${DERIVED%%|*}"
  DERIVED="${DERIVED#*|}"
  EXPECTED_FALLBACK_1="${DERIVED%%|*}"
  ALLOWED_MODELS="${DERIVED#*|}"
  log "LINK 5 (policy-derived): expected chain = $EXPECTED_PRIMARY → $EXPECTED_FALLBACK_1 (from model-policy.json)"
else
  # Failsafe: if model-policy.json is missing, fall back to config defaults
  log "LINK 5 (policy-derived): model-policy.json NOT FOUND — falling back to openclaw.json defaults"
  EXPECTED_PRIMARY=$(python3 -c "
import json
d = json.load(open('$OPENCLAW_CFG'))
print(d.get('agents', {}).get('defaults', {}).get('model', {}).get('primary', ''))
" 2>/dev/null || echo "")
  EXPECTED_FALLBACK_1=$(python3 -c "
import json
d = json.load(open('$OPENCLAW_CFG'))
fb = d.get('agents', {}).get('defaults', {}).get('model', {}).get('fallbacks', [])
print(fb[0] if len(fb) > 0 else '')
" 2>/dev/null || echo "")
  ALLOWED_MODELS=""
fi

if [[ -f "$OPENCLAW_CFG" ]]; then
  PRIMARY=$(python3 -c "
import json
d = json.load(open('$OPENCLAW_CFG'))
agent_list = d.get('agents', {}).get('list', [])
main_agent = next((a for a in agent_list if a.get('id') == 'main'), {})
model_cfg = main_agent.get('model', {})
print(model_cfg.get('primary', ''))
" 2>/dev/null || echo "")

  FALLBACK_0=$(python3 -c "
import json
d = json.load(open('$OPENCLAW_CFG'))
agent_list = d.get('agents', {}).get('list', [])
main_agent = next((a for a in agent_list if a.get('id') == 'main'), {})
fb = main_agent.get('model', {}).get('fallbacks', [])
print(fb[0] if len(fb) > 0 else '')
" 2>/dev/null || echo "")

  ALL_FALLBACKS=$(python3 -c "
import json
d = json.load(open('$OPENCLAW_CFG'))
agent_list = d.get('agents', {}).get('list', [])
main_agent = next((a for a in agent_list if a.get('id') == 'main'), {})
fb = main_agent.get('model', {}).get('fallbacks', [])
print(','.join(fb))
" 2>/dev/null || echo "")

  CHAIN_OK=true
  if [[ "$PRIMARY" != "$EXPECTED_PRIMARY" ]]; then
    log "LINK 5 (fallback chain): BROKEN — main agent primary is '$PRIMARY', expected '$EXPECTED_PRIMARY'"
    BROKEN+=("Fallback chain: main agent primary model wrong (got '$PRIMARY')")
    CHAIN_OK=false
  fi
  if [[ "$FALLBACK_0" != "$EXPECTED_FALLBACK_1" ]]; then
    log "LINK 5 (fallback chain): BROKEN — main agent fallback[0] is '$FALLBACK_0', expected '$EXPECTED_FALLBACK_1'"
    BROKEN+=("Fallback chain: main agent fallback[0] wrong (got '$FALLBACK_0') — should be $EXPECTED_FALLBACK_1")
    CHAIN_OK=false
  fi

  # ── Policy compliance: verify all models in chain are in globalAllowedModels ──
  if [[ -n "$ALLOWED_MODELS" ]]; then
    IFS=',' read -rA ALLOWED_ARR <<< "$ALLOWED_MODELS"
    IFS=',' read -rA FB_ARR <<< "$ALL_FALLBACKS"
    CHAIN_MODELS=("$PRIMARY" "${FB_ARR[@]}")
    for model in "${CHAIN_MODELS[@]}"; do
      [[ -z "$model" ]] && continue
      if [[ ! " ${ALLOWED_ARR[@]} " =~ " ${model} " ]]; then
        log "LINK 5 (policy compliance): WARNING — model '$model' not in globalAllowedModels"
        # Non-fatal warning — model-policy.json may be stale
      fi
    done
  fi

  if [[ "$CHAIN_OK" == "true" ]]; then
    log "LINK 5 (fallback chain config): OK — $EXPECTED_PRIMARY → $EXPECTED_FALLBACK_1 (from model-policy.json (nightly cache; PG SSOT per CREST v1.3))"
    RESULTS+=("fallbackChainConfig:ok")
  else
    RESULTS+=("fallbackChainConfig:broken")
  fi
else
  log "LINK 5 (fallback chain config): BROKEN — openclaw.json not found at $OPENCLAW_CFG"
  BROKEN+=("openclaw.json not found")
  RESULTS+=("fallbackChainConfig:broken:missing")
fi

# ── Write state/fallback-chain-status.json ────────────────────────────────────
OVERALL=$([[ ${#BROKEN[@]} -eq 0 ]] && echo "ok" || echo "broken")

# Set default chain values for interim period reporting
CHAIN_PRIMARY="${EXPECTED_PRIMARY:-interim}"
CHAIN_FALLBACK="${EXPECTED_FALLBACK_1:-interim}"

RESULTS_CSV=$(IFS=,; echo "${RESULTS[*]:-}")
BROKEN_NL=$(IFS=$'\n'; echo "${BROKEN[*]:-}")

python3 - << PYEOF
import json
results_raw = """$RESULTS_CSV"""
broken_raw = """$BROKEN_NL"""

results_list = [r.strip() for r in results_raw.split(',') if r.strip()]
broken_list = [b.strip() for b in broken_raw.split('\n') if b.strip()]

state = {
  "checkedAt": "$TIMESTAMP",
  "overall": "$OVERALL",
  "chain": [
    "$CHAIN_PRIMARY",
    "$CHAIN_FALLBACK"
  ],
  "checks": results_list,
  "broken": broken_list,
  "brokenCount": len(broken_list)
}
json.dump(state, open("$STATE_FILE", "w"), indent=2)
print(f"fallback-chain-status.json written: {state['overall']} ({len(broken_list)} broken)")
PYEOF

# ── Append to pvt-alert.txt if broken ────────────────────────────────────────
if (( ${#BROKEN[@]} > 0 )); then
  {
    echo ""
    echo "=== validate-fallback-chain.sh: BROKEN LINKS ($(date)) ==="
    for issue in "${BROKEN[@]}"; do
      echo "  ✗ $issue"
    done
    echo ""
  } >> "$ALERT_FILE"
  log "ALERT: ${#BROKEN[@]} broken link(s) appended to $ALERT_FILE"
  exit 1
fi

log "All fallback chain links OK."
exit 0
