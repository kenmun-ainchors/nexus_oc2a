#!/bin/zsh
# AInchors Fallback Chain Validator
# Run on gateway start — validates the full fallback chain is healthy.
# Fallback chain: Sonnet T1 → Haiku T2 (Aria-safe, CHG-0075)
# Note: Opus removed from auto-fallback — deliberate escalation only, not automatic.
#
# Output: state/fallback-chain-status.json
# Alert:  /tmp/pvt-alert.txt (appended if any link broken)
# Exit:   0 = all OK | 1 = one or more broken

set -uo pipefail

WORKSPACE="$HOME/.openclaw/workspace"
STATE_FILE="$WORKSPACE/state/fallback-chain-status.json"
ALERT_FILE="/tmp/pvt-alert.txt"
OPENCLAW_CFG="$HOME/.openclaw/openclaw.json"

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

# ── LINK 4b: Gemma4 warm and responsive (actual completion probe) ─────────────
if [[ "$GEMMA4_FOUND" == "yes" ]]; then
  log "LINK 4b (Gemma4 warmup): Sending test completion — may take up to 90s on cold start..."
  WARMUP_RESPONSE=$(curl -s \
    --connect-timeout 10 \
    --max-time 90 \
    -X POST "http://localhost:11434/api/generate" \
    -H "Content-Type: application/json" \
    -d '{"model":"gemma4:26b","prompt":"hi","stream":false,"options":{"num_predict":1}}' \
    2>/dev/null)
  WARMUP_OK=$(echo "$WARMUP_RESPONSE" | python3 -c \
    "import json,sys; d=json.load(sys.stdin); print('yes' if d.get('response') is not None else 'no')" \
    2>/dev/null || echo "no")
  if [[ "$WARMUP_OK" == "yes" ]]; then
    log "LINK 4b (Gemma4 warmup): OK — model responded"
    RESULTS+=("gemma4Warm:ok")
  else
    log "LINK 4b (Gemma4 warmup): BROKEN — no response within 90s (cold-load timeout or auth issue)"
    RESULTS+=("gemma4Warm:broken")
    BROKEN+=("Gemma4 warmup probe failed — not responsive within 90s")
  fi
else
  RESULTS+=("gemma4Warm:skipped")
fi

# ── LINK 5: openclaw.json fallback chain matches expected ────────────────────
EXPECTED_PRIMARY="anthropic/claude-sonnet-4-6"
EXPECTED_FALLBACK_1="anthropic/claude-haiku-4-5"
# Opus removed CHG-0075: deliberate escalation only, never automatic fallback
# Gemma4 prohibited for Aria (business agent) in interactive sessions

if [[ -f "$OPENCLAW_CFG" ]]; then
  PRIMARY=$(python3 -c "
import json
d = json.load(open('$OPENCLAW_CFG'))
model_cfg = d.get('agents', {}).get('defaults', {}).get('model', {})
print(model_cfg.get('primary', ''))
" 2>/dev/null || echo "")

  FALLBACK_0=$(python3 -c "
import json
d = json.load(open('$OPENCLAW_CFG'))
fb = d.get('agents', {}).get('defaults', {}).get('model', {}).get('fallbacks', [])
print(fb[0] if len(fb) > 0 else '')
" 2>/dev/null || echo "")

  # Only one fallback now (Haiku) — CHG-0075
  CHAIN_OK=true
  if [[ "$PRIMARY" != "$EXPECTED_PRIMARY" ]]; then
    log "LINK 5 (fallback chain): BROKEN — primary is '$PRIMARY', expected '$EXPECTED_PRIMARY'"
    BROKEN+=("Fallback chain: primary model wrong (got '$PRIMARY')")
    CHAIN_OK=false
  fi
  if [[ "$FALLBACK_0" != "$EXPECTED_FALLBACK_1" ]]; then
    log "LINK 5 (fallback chain): BROKEN — fallback[0] is '$FALLBACK_0', expected '$EXPECTED_FALLBACK_1'"
    BROKEN+=("Fallback chain: fallback[0] wrong (got '$FALLBACK_0') — should be haiku-4-5")
    CHAIN_OK=false
  fi
  # Check that Opus is NOT in fallbacks (policy violation for Aria)
  OPUS_IN_CHAIN=$(python3 -c "
import json
d = json.load(open('$OPENCLAW_CFG'))
fb = d.get('agents', {}).get('defaults', {}).get('model', {}).get('fallbacks', [])
print('yes' if 'anthropic/claude-opus-4-7' in fb else 'no')
" 2>/dev/null || echo "no")
  if [[ "$OPUS_IN_CHAIN" == "yes" ]]; then
    log "LINK 5 (fallback chain): POLICY VIOLATION — Opus found in fallbacks (prohibited for Aria)"
    BROKEN+=("Policy violation: Opus in defaults fallbacks — prohibited for business agent (Aria)")
    CHAIN_OK=false
  fi

  if [[ "$CHAIN_OK" == "true" ]]; then
    log "LINK 5 (fallback chain config): OK — $EXPECTED_PRIMARY → $EXPECTED_FALLBACK_1 (Aria-safe, CHG-0075)"
    RESULTS+=("fallbackChainConfig:ok")
  fi
else
  log "LINK 5 (fallback chain config): BROKEN — openclaw.json not found at $OPENCLAW_CFG"
  BROKEN+=("openclaw.json not found")
  RESULTS+=("fallbackChainConfig:broken:missing")
fi

# ── Write state/fallback-chain-status.json ────────────────────────────────────
OVERALL=$([[ ${#BROKEN[@]} -eq 0 ]] && echo "ok" || echo "broken")

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
    "$EXPECTED_PRIMARY",
    "$EXPECTED_FALLBACK_1"
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
