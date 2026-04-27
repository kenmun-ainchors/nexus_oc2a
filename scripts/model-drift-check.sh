#!/usr/bin/env bash
# model-drift-check.sh — Warden 🔍 Model Compliance Check
# Checks all agent models against model-policy.json
# Outputs: state/model-drift-state.json + state/model-drift-violations.json
# Silent on clean. Violations written to files — Warden cron handles escalation.
# TKT-0013

set -euo pipefail

WORKSPACE="/Users/ainchorsangiefpl/.openclaw/workspace"
OC_CONFIG="/Users/ainchorsangiefpl/.openclaw/openclaw.json"
POLICY="$WORKSPACE/state/model-policy.json"
STATE="$WORKSPACE/state/model-drift-state.json"
VIOLATIONS="$WORKSPACE/state/model-drift-violations.json"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
AEST_TIMESTAMP=$(date +"%Y-%m-%dT%H:%M:%S+10:00")

PASS=0
FAIL=0
FINDINGS=()

# ── Helper: check a single agent ─────────────────────────────────────────────
check_agent() {
  local agent_id="$1"
  local expected="$2"
  local is_exception="${3:-false}"

  local actual
  actual=$(python3 -c "
import json, sys
with open('$OC_CONFIG') as f:
    d = json.load(f)
agents = d.get('agents', {}).get('list', [])
for a in agents:
    if a.get('id') == '$agent_id':
        print(a.get('model', 'NOT_SET'))
        sys.exit(0)
print('AGENT_NOT_FOUND')
" 2>/dev/null || echo "ERROR")

  if [ "$actual" = "$expected" ]; then
    PASS=$((PASS + 1))
    echo "  PASS  agent:$agent_id → $actual"
  else
    FAIL=$((FAIL + 1))
    local severity="VIOLATION"
    local note=""
    if [ "$is_exception" = "true" ]; then
      severity="EXCEPTION_DRIFT"
      note="Note: agent has documented exceptions — check model-policy.json for allowed values."
    fi
    echo "  FAIL  agent:$agent_id → actual=$actual expected=$expected [$severity]"
    FINDINGS+=("{\"agentId\":\"$agent_id\",\"expected\":\"$expected\",\"actual\":\"$actual\",\"severity\":\"$severity\",\"note\":\"$note\",\"detectedAt\":\"$AEST_TIMESTAMP\"}")
  fi
}

# ── Helper: check default model ───────────────────────────────────────────────
check_default() {
  local field="$1"
  local expected="$2"
  local label="$3"

  local actual
  actual=$(python3 -c "
import json
with open('$OC_CONFIG') as f:
    d = json.load(f)
val = d.get('agents', {}).get('defaults', {}).get('model', {})
# handle nested or flat
parts = '$field'.split('.')
for p in parts:
    val = val.get(p, 'NOT_SET') if isinstance(val, dict) else 'NOT_SET'
print(val)
" 2>/dev/null || echo "ERROR")

  if [ "$actual" = "$expected" ]; then
    PASS=$((PASS + 1))
    echo "  PASS  default:$label → $actual"
  else
    FAIL=$((FAIL + 1))
    echo "  FAIL  default:$label → actual=$actual expected=$expected [VIOLATION]"
    FINDINGS+=("{\"agentId\":\"default.$label\",\"expected\":\"$expected\",\"actual\":\"$actual\",\"severity\":\"VIOLATION\",\"note\":\"\",\"detectedAt\":\"$AEST_TIMESTAMP\"}")
  fi
}

# ── Helper: check Ollama key is not placeholder ───────────────────────────────
check_ollama_key() {
  local actual
  actual=$(python3 -c "
import json
with open('$OC_CONFIG') as f:
    d = json.load(f)
print(d.get('models', {}).get('providers', {}).get('ollama', {}).get('apiKey', 'NOT_SET'))
" 2>/dev/null || echo "ERROR")

  if [ "$actual" = "ollama-local" ]; then
    PASS=$((PASS + 1))
    echo "  PASS  ollama apiKey → $actual"
  else
    FAIL=$((FAIL + 1))
    echo "  FAIL  ollama apiKey → actual=$actual expected=ollama-local [VIOLATION]"
    FINDINGS+=("{\"agentId\":\"system.ollama_apikey\",\"expected\":\"ollama-local\",\"actual\":\"$actual\",\"severity\":\"CRITICAL\",\"note\":\"Placeholder key will break fallback chain during billing outage.\",\"detectedAt\":\"$AEST_TIMESTAMP\"}")
  fi
}

# ── Helper: check cron models ─────────────────────────────────────────────────
check_cron_models() {
  # Check cron jobs via openclaw crons list (if available)
  local cron_output
  if command -v openclaw &>/dev/null; then
    cron_output=$(openclaw crons list 2>/dev/null || echo "")
  else
    cron_output=""
  fi

  if [ -z "$cron_output" ]; then
    echo "  SKIP  cron model check (openclaw CLI not available or no output)"
    return
  fi

  # Check for Gemma4 in non-allowed cron names
  local violations
  violations=$(echo "$cron_output" | python3 -c "
import json, sys
data = json.load(sys.stdin)
jobs = data.get('jobs', [])
allowed_names = ['AInchors Midday Cost Tracker', 'AInchors Workspace Backup']
issues = []
for j in jobs:
    model = j.get('payload', {}).get('model', '')
    name = j.get('name', '')
    if 'gemma4' in model.lower() or 'gemma4:26b' in model:
        if name not in allowed_names:
            issues.append(f'cron:{name}|model:{model}')
for i in issues:
    print(i)
" 2>/dev/null || echo "")

  if [ -z "$violations" ]; then
    PASS=$((PASS + 1))
    echo "  PASS  cron job model review → all compliant"
  else
    while IFS= read -r line; do
      FAIL=$((FAIL + 1))
      local cron_name model_val
      cron_name=$(echo "$line" | cut -d'|' -f1 | sed 's/cron://')
      model_val=$(echo "$line" | cut -d'|' -f2 | sed 's/model://')
      echo "  FAIL  cron:\"$cron_name\" → model=$model_val [GEMMA4_INTERACTIVE_VIOLATION]"
      FINDINGS+=("{\"agentId\":\"cron.$cron_name\",\"expected\":\"non-gemma4\",\"actual\":\"$model_val\",\"severity\":\"GEMMA4_INTERACTIVE_VIOLATION\",\"note\":\"Gemma4 only permitted for: AInchors Midday Cost Tracker, AInchors Workspace Backup\",\"detectedAt\":\"$AEST_TIMESTAMP\"}")
    done <<< "$violations"
  fi
}

# ═══════════════════════════════════════════════════════════════════
echo "🔍 Warden Model Compliance Check — $AEST_TIMESTAMP"
echo "─────────────────────────────────────────────────────────────"

# Agent model checks
echo ""
echo "[ Agent Models ]"
check_agent "main"       "anthropic/claude-sonnet-4-6"
check_agent "business"   "anthropic/claude-sonnet-4-6"
check_agent "security"   "anthropic/claude-sonnet-4-6"
check_agent "legal"      "anthropic/claude-opus-4-7"   "true"   # documented exception
check_agent "qa"         "anthropic/claude-sonnet-4-6"
check_agent "governance" "anthropic/claude-sonnet-4-6"

echo ""
echo "[ Default Config ]"
check_default "primary" "anthropic/claude-sonnet-4-6" "primary"

echo ""
echo "[ Fallback Chain ]"
FALLBACK_CHECK=$(python3 -c "
import json
with open('$OC_CONFIG') as f:
    d = json.load(f)
fb = d.get('agents', {}).get('defaults', {}).get('model', {}).get('fallbacks', [])
expected = ['anthropic/claude-opus-4-7', 'ollama/gemma4:26b']
if fb == expected:
    print('PASS:' + json.dumps(fb))
else:
    print('FAIL:' + json.dumps(fb))
" 2>/dev/null || echo "FAIL:ERROR")
FALLBACK_STATUS=$(echo "$FALLBACK_CHECK" | cut -d: -f1)
FALLBACK_ACTUAL=$(echo "$FALLBACK_CHECK" | cut -d: -f2-)
if [ "$FALLBACK_STATUS" = "PASS" ]; then
  PASS=$((PASS + 1))
  echo "  PASS  fallback chain → $FALLBACK_ACTUAL"
else
  FAIL=$((FAIL + 1))
  FALLBACK_EXPECTED='["anthropic/claude-opus-4-7","ollama/gemma4:26b"]'
  echo "  FAIL  fallback chain → actual=$FALLBACK_ACTUAL expected=$FALLBACK_EXPECTED [VIOLATION]"
  FINDINGS+=("{\"agentId\":\"default.fallbacks\",\"expected\":$FALLBACK_EXPECTED,\"actual\":$FALLBACK_ACTUAL,\"severity\":\"VIOLATION\",\"note\":\"Fallback chain drift breaks resilient outage handling.\",\"detectedAt\":\"$AEST_TIMESTAMP\"}")
fi

echo ""
echo "[ System Config ]"
check_ollama_key

echo ""
echo "[ Cron Job Models ]"
check_cron_models

# ═══════════════════════════════════════════════════════════════════
echo ""
echo "─────────────────────────────────────────────────────────────"
echo "  Result: ${PASS} PASS  ${FAIL} FAIL"
echo "─────────────────────────────────────────────────────────────"

# ── Build findings JSON array ──────────────────────────────────────────────────
FINDINGS_JSON="["
if [ ${#FINDINGS[@]} -gt 0 ]; then
  for i in "${!FINDINGS[@]}"; do
    if [ $i -gt 0 ]; then FINDINGS_JSON+=","; fi
    FINDINGS_JSON+="${FINDINGS[$i]}"
  done
fi
FINDINGS_JSON+="]"

# ── Update state file ──────────────────────────────────────────────────────────
STATUS="clean"
if [ $FAIL -gt 0 ]; then STATUS="violation"; fi

python3 -c "
import json, os
state_file = '$STATE'
# Load existing state or create new
if os.path.exists(state_file):
    with open(state_file) as f:
        state = json.load(f)
else:
    state = {'totalChecksRun': 0, 'totalViolationsFound': 0, 'consecutiveClean': 0, 'violationHistory': []}

state['lastCheck'] = '$AEST_TIMESTAMP'
state['lastStatus'] = '$STATUS'
state['lastPassCount'] = $PASS
state['lastFailCount'] = $FAIL
state['totalChecksRun'] = state.get('totalChecksRun', 0) + 1

if '$STATUS' == 'clean':
    state['consecutiveClean'] = state.get('consecutiveClean', 0) + 1
    state['lastViolationAt'] = state.get('lastViolationAt', None)
else:
    state['consecutiveClean'] = 0
    state['totalViolationsFound'] = state.get('totalViolationsFound', 0) + $FAIL
    state['lastViolationAt'] = '$AEST_TIMESTAMP'

with open(state_file, 'w') as f:
    json.dump(state, f, indent=2)
print('State updated.')
"

# ── Write violations if any ────────────────────────────────────────────────────
if [ $FAIL -gt 0 ]; then
  python3 -c "
import json, os
vfile = '$VIOLATIONS'
# Load existing
if os.path.exists(vfile):
    with open(vfile) as f:
        data = json.load(f)
else:
    data = {'violations': [], 'totalUnresolved': 0}

findings = $FINDINGS_JSON
for f in findings:
    f['id'] = 'DRIFT-' + '$TIMESTAMP'.replace(':','').replace('-','').replace('T','').replace('Z','')[:14] + '-' + f['agentId'].replace('.','_').replace(' ','_')[:20]
    f['status'] = 'unresolved'
    f['escalatedToYoda'] = False
    data['violations'].append(f)

# Keep last 100 violations max
data['violations'] = data['violations'][-100:]
data['totalUnresolved'] = sum(1 for v in data['violations'] if v.get('status') == 'unresolved')
data['lastUpdated'] = '$AEST_TIMESTAMP'

with open(vfile, 'w') as f2:
    json.dump(data, f2, indent=2)
print(f'Violations written: {len(findings)}')
"
  echo ""
  echo "⚠️  VIOLATIONS DETECTED — written to state/model-drift-violations.json"
  echo "    Warden will escalate to Yoda."
  exit 2
else
  echo ""
  echo "✅ All checks passed. No model drift detected."
  exit 0
fi
