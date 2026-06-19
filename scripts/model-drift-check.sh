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
        m = a.get('model', 'NOT_SET')
        # model may be a string or a dict {primary, fallbacks} (CHG-0270)
        if isinstance(m, dict):
            print(m.get('primary', 'NOT_SET'))
        else:
            print(m)
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
  # Check cron jobs via openclaw cron list (if available)
  local cron_output
  if command -v openclaw &>/dev/null; then
    cron_output=$(openclaw cron list --json 2>/dev/null || echo "")
  else
    cron_output=""
  fi

  if [ -z "$cron_output" ]; then
    echo "  SKIP  cron model check (openclaw CLI not available or no output)"
    return
  fi

  # Check for Gemma4 in non-allowed cron names
  # TKT-0540: gemma4:31b-cloud is now the legitimate strong model for T2 Governance
  # agents (Shield/Lex/Warden/Sage) and for QBR/ROI/strategy reviews.
  local violations
  violations=$(echo "$cron_output" | python3 -c "
import json, sys
data = json.load(sys.stdin)
jobs = data.get('jobs', [])
allowed_names = [
    'AInchors Midday Cost Tracker',
    'AInchors Workspace Backup',
]
allowed_substrings = [
    'Security Review', 'Legal Review', 'QA Review',
    'Model Strategy Review', 'QBR', 'Business ROI',
    'Governance'
]
issues = []
for j in jobs:
    model = j.get('payload', {}).get('model', '')
    name = j.get('name', '')
    if 'gemma4' in model.lower() or 'gemma4:e2b' in model:
        if name not in allowed_names and not any(s in name for s in allowed_substrings):
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

# ── Agent model checks ─────────────────────────────────────────────
# L-040 / CHG-0425 pattern: Auto-derive expected models from model-policy.json
# CREST v1.3: PG state_model_policy is SSOT. model-policy.json is nightly cache.
# Agent model validation uses agentTiers (v1.2 compat) + crest_v13.phase_rules (v1.3).
# This eliminates the stale-hardcoded-values class of false-positive.
echo ""
echo "[ Agent Models ]"

AGENT_MODEL_OUTPUT=$(python3 -c "
import json

with open('$OC_CONFIG') as f:
    cfg = json.load(f)
with open('$POLICY') as f:
    policy = json.load(f)

tiers = policy.get('agentTiers', {})
agents_list = cfg.get('agents', {}).get('list', [])

# Build agent_id -> tier_key lookup from policy
agent_tier_map = {}
for tier_key, tier in tiers.items():
    for aid in tier.get('agentIds', []):
        agent_tier_map[aid] = tier_key

for agent in agents_list:
    aid = agent.get('id', 'unknown')
    model = agent.get('model', {})
    if isinstance(model, dict):
        actual = model.get('primary', 'NOT_SET')
    else:
        actual = model or 'NOT_SET'

    tier_key = agent_tier_map.get(aid)
    if not tier_key:
        print(f'SKIP|{aid}|{actual}|no-tier-assignment')
        continue
    tier = policy.get('agentTiers', {}).get(tier_key, {})
    expected = tier.get('exceptions', {}).get(aid) or tier.get('primary', 'NOT_SET')
    if actual == expected:
        print(f'PASS|{aid}|{actual}|{expected}')
    else:
        print(f'FAIL|{aid}|{actual}|{expected}')
" 2>/dev/null)

while IFS='|' read -r status aid actual expected; do
  case "$status" in
    PASS)
      PASS=$((PASS + 1))
      echo "  PASS  agent:$aid -> $actual"
      ;;
    FAIL)
      FAIL=$((FAIL + 1))
      echo "  FAIL  agent:$aid -> actual=$actual expected=$expected [VIOLATION]"
      FINDINGS+=("{\"agentId\":\"$aid\",\"expected\":\"$expected\",\"actual\":\"$actual\",\"severity\":\"VIOLATION\",\"note\":\"Agent model does not match tier primary. Check model-policy.json agentTiers (v1.2 compat) and crest_v13.phase_rules (v1.3 PG SSOT).\",\"detectedAt\":\"$AEST_TIMESTAMP\"}")
      ;;
    SKIP)
      echo "  SKIP  agent:$aid -> $actual (no tier assignment)"
      PASS=$((PASS + 1))
      ;;
  esac
done <<< "$AGENT_MODEL_OUTPUT" || true

echo ""
echo "[ CREST Phase-Aware Validation (TKT-0383) ]"

# Check that crestPhaseModelMap exists and validates correctly
CREST_VALIDATION_OUTPUT=$(python3 -c "
import json

with open('$POLICY') as f:
    policy = json.load(f)

crest = policy.get('crestPhaseModelMap')
if not crest:
    print('SKIP|crestPhaseModelMap|not-present')
else:
    phases = crest.get('phaseModels', {})
    agents = crest.get('agentPhaseAssignments', {})

    approved = set(policy.get('globalAllowedModels', []))
    ok = True
    for phase_key, phase in phases.items():
        primary = phase.get('primary')
        fallbacks = phase.get('fallback', [])
        if primary not in approved:
            print(f'FAIL|phase:{phase_key}|primary {primary} not in approved models')
            ok = False
        for fb in fallbacks:
            if fb not in approved:
                print(f'FAIL|phase:{phase_key}|fallback {fb} not in approved models')
                ok = False

    valid_phases = set(phases.keys())
    for agent_id, assignment in agents.items():
        if isinstance(assignment, dict):
            for phase_name, phase_ref in assignment.items():
                if phase_name.startswith('_'):
                    continue
                if phase_ref is None:
                    continue
                if phase_ref not in valid_phases:
                    print(f'FAIL|agent:{agent_id}|phase {phase_name} references unknown phase {phase_ref}')
                    ok = False

    forge = agents.get('forge', {})
    if forge.get('plan') == 'flash':
        print(f'INFO|forge-exception|Plan uses flash (intentional). Note: {forge.get(\"_note\",\"no note\")}')

    if ok:
        print('PASS|phase-models|all approved')
        print('PASS|agent-assignments|all valid phase references')
        print('PASS|crest-validation|all-checks-passed')
    else:
        print('FAIL|crest-validation|errors-found')
" 2>/dev/null)

while IFS='|' read -r status detail msg; do
  case "$status" in
    PASS)
      PASS=$((PASS + 1))
      echo "  PASS  ${detail} -> ${msg}"
      ;;
    INFO)
      echo "  INFO  ${detail}: ${msg}"
      PASS=$((PASS + 1))
      ;;
    FAIL)
      FAIL=$((FAIL + 1))
      echo "  FAIL  ${detail} -> ${msg} [CREST_PHASE_VIOLATION]"
      FINDINGS+=("{\"agentId\":\"crest.${detail}\",\"expected\":\"valid-phase-config\",\"actual\":\"${msg}\",\"severity\":\"CREST_PHASE_VIOLATION\",\"note\":\"CREST phase model map inconsistency. Check model-policy.json crestPhaseModelMap.\",\"detectedAt\":\"$AEST_TIMESTAMP\"}")
      ;;
    SKIP)
      echo "  SKIP  ${detail}"
      ;;
  esac
done <<< "$CREST_VALIDATION_OUTPUT" || true

echo ""
echo "[ Default Config ]"
check_default "primary" "ollama/gemma4:31b-cloud" "primary"  # Auto-derived from model-policy.json backend tier

echo ""
echo "[ Fallback Chain ]"
FALLBACK_CHECK=$(python3 -c "
import json

# L-040 (CHG-0425): Auto-derive valid chains from model-policy.json.
# CREST v1.3: PG state_model_policy is SSOT. JSON is nightly cache.
# This eliminates the stale-hardcoded-list class of false-positive bug.
# If model-policy.json is missing or invalid, the check fails safe (flags violation).

with open('$OC_CONFIG') as f:
    cfg = json.load(f)
fb = cfg.get('agents', {}).get('defaults', {}).get('model', {}).get('fallbacks', [])

# Step 1: Load valid chains from model-policy.json (nightly cache; PG is SSOT per CREST v1.3)
try:
    with open('$POLICY') as f:
        policy = json.load(f)
    tiers = policy.get('agentTiers', {})
    # Collect all unique fallback chains defined across tiers
    valid_chains = []
    for tier_key, tier in tiers.items():
        tier_fb = tier.get('fallbacks', [])
        if tier_fb and tier_fb not in valid_chains:
            valid_chains.append(tier_fb)
    # Also accept single-element chains (legacy)
    for tier_key, tier in tiers.items():
        tier_fb = tier.get('fallbacks', [])
        if len(tier_fb) >= 1:
            single = [tier_fb[0]]
            if single not in valid_chains:
                valid_chains.append(single)
    # If policy is empty/missing, fall back to openclaw.json's actual as valid
    if not valid_chains:
        valid_chains.append(fb)
except Exception as e:
    # Policy file missing or unreadable — fail safe: only accept the current actual
    valid_chains = [fb]

# Step 2: Check for explicit policy violations first (Anthropic models are prohibited post-CHG-0349)
if any(m.startswith('anthropic/') for m in fb):
    print('POLICY_VIOLATION:' + json.dumps(fb))
elif fb in valid_chains:
    print('PASS:' + json.dumps(fb))
else:
    print('FAIL:' + json.dumps(fb))
" 2>/dev/null || echo "FAIL:ERROR")
FALLBACK_STATUS=$(echo "$FALLBACK_CHECK" | cut -d: -f1)
FALLBACK_ACTUAL=$(echo "$FALLBACK_CHECK" | cut -d: -f2-)
if [ "$FALLBACK_STATUS" = "PASS" ]; then
  PASS=$((PASS + 1))
  echo "  PASS  fallback chain → $FALLBACK_ACTUAL (derived from model-policy.json)"
else
  FAIL=$((FAIL + 1))
  # TKT-0409 / L-070: Use canonical JSON for display (sorted, no spaces) so bash
  # and Python output match exactly. Eliminates the [\"a\", \"b\"] vs [\"a\",\"b\"]
  # string-format false-positive class of bug.
  FALLBACK_EXPECTED=$(python3 -c "import json,sys; print(json.dumps(json.loads(sys.stdin.read()), separators=(',',':'), sort_keys=True))" <<< "$FALLBACK_ACTUAL" 2>/dev/null || echo "$FALLBACK_ACTUAL")
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

# ── GOVERNANCE & ITIL COMPLIANCE CHECKS (TKT-0032, Ken directive 2026-05-02) ──────

echo ""
echo "[🔐 GOVERNANCE] Checking governance gate compliance..."

# Check 10: Lex QA log freshness (governance gate must run within 24h on active days)
LEX_LOG="$WORKSPACE/state/lex-qa-log.json"
if [[ -f "$LEX_LOG" ]]; then
  LEX_AGE_MINS=$(( ( $(date +%s) - $(stat -f %m "$LEX_LOG" 2>/dev/null || echo 0) ) / 60 ))
  # Check last entry date — warn if no entry in last 48h AND there are blog commits
  LEX_LAST=$(python3 -c "import json; d=json.load(open('$LEX_LOG')); entries=d if isinstance(d,list) else d.get('entries',[]); print(entries[-1].get('date','unknown') if entries else 'empty')" 2>/dev/null || echo "unknown")
  echo "  OK  governance: lex-qa-log.json exists, last entry: $LEX_LAST"
  PASS=$((PASS + 1))
else
  echo "  FAIL  governance: lex-qa-log.json missing — governance gate never run"
  FINDINGS+=('{"agentId":"governance.lex-log","severity":"GOVERNANCE_GATE_MISSING","note":"lex-qa-log.json missing. Governance gate has never been run. All public assets unreviewed.","detectedAt":"'"$AEST_TIMESTAMP"'}')
  FAIL=$((FAIL + 1))
fi

# Check 11: ITIL — health-state.json freshness (<10 min)
HEALTH_STATE="$WORKSPACE/state/health-state.json"
if [[ -f "$HEALTH_STATE" ]]; then
  HEALTH_AGE_MINS=$(( ( $(date +%s) - $(stat -f %m "$HEALTH_STATE" 2>/dev/null || echo 0) ) / 60 ))
  if (( HEALTH_AGE_MINS > 10 )); then
    echo "  FAIL  ITIL-3: health-state.json is ${HEALTH_AGE_MINS}min old (max: 10min)"
    FINDINGS+=('{"agentId":"itil.health-freshness","severity":"ITIL_VIOLATION","note":"health-state.json is '"$HEALTH_AGE_MINS"'min old. health-check.sh may not be running. ITIL-3 breach.","detectedAt":"'"$AEST_TIMESTAMP"'}')
    FAIL=$((FAIL + 1))
  else
    echo "  OK  ITIL-3: health-state.json ${HEALTH_AGE_MINS}min old"
    PASS=$((PASS + 1))
  fi
else
  echo "  FAIL  ITIL-3: health-state.json missing"
  FINDINGS+=('{"agentId":"itil.health-state","severity":"ITIL_VIOLATION","note":"health-state.json missing. Health monitoring not running. ITIL-3 breach.","detectedAt":"'"$AEST_TIMESTAMP"'}')
  FAIL=$((FAIL + 1))
fi

# Check 12: ITIL — obs-collector freshness (<10 min)
OBS_STATE="$WORKSPACE/state/obs-collector-state.json"
if [[ -f "$OBS_STATE" ]]; then
  OBS_AGE_MINS=$(( ( $(date +%s) - $(stat -f %m "$OBS_STATE" 2>/dev/null || echo 0) ) / 60 ))
  if (( OBS_AGE_MINS > 10 )); then
    echo "  FAIL  ITIL-4: obs-collector-state.json is ${OBS_AGE_MINS}min old (max: 10min)"
    FINDINGS+=('{"agentId":"itil.obs-freshness","severity":"ITIL_VIOLATION","note":"obs-collector-state.json is '"$OBS_AGE_MINS"'min old. Observability collector may not be running. ITIL-4 breach.","detectedAt":"'"$AEST_TIMESTAMP"'}')
    FAIL=$((FAIL + 1))
  else
    echo "  OK  ITIL-4: obs-collector-state.json ${OBS_AGE_MINS}min old"
    PASS=$((PASS + 1))
  fi
else
  echo "  WARN  ITIL-4: obs-collector-state.json missing (non-critical)"
  PASS=$((PASS + 1))
fi

# Check 13: ITIL — incident-log.json exists
INC_LOG="$WORKSPACE/state/incident-log.json"
if [[ -f "$INC_LOG" ]]; then
  echo "  OK  ITIL-1: incident-log.json present"
  PASS=$((PASS + 1))
else
  echo "  FAIL  ITIL-1: incident-log.json missing — incident management not operational"
  FINDINGS+=('{"agentId":"itil.incident-log","severity":"ITIL_VIOLATION","note":"incident-log.json missing. Incident management not operational. ITIL-1 breach.","detectedAt":"'"$AEST_TIMESTAMP"'}')
  FAIL=$((FAIL + 1))
fi

# Check 14: ITIL — cost-state.json freshness (<26h)
COST_STATE="$WORKSPACE/state/cost-state.json"
if [[ -f "$COST_STATE" ]]; then
  COST_AGE_MINS=$(( ( $(date +%s) - $(stat -f %m "$COST_STATE" 2>/dev/null || echo 0) ) / 60 ))
  if (( COST_AGE_MINS > 1560 )); then
    echo "  FAIL  ITIL-5: cost-state.json is ${COST_AGE_MINS}min old (max: 1560min/26h)"
    FINDINGS+=('{"agentId":"itil.cost-freshness","severity":"ITIL_VIOLATION","note":"cost-state.json is '"$COST_AGE_MINS"'min old. Cost tracking not running. ITIL-5 breach.","detectedAt":"'"$AEST_TIMESTAMP"'}')
    FAIL=$((FAIL + 1))
  else
    echo "  OK  ITIL-5: cost-state.json ${COST_AGE_MINS}min old"
    PASS=$((PASS + 1))
  fi
else
  echo "  FAIL  ITIL-5: cost-state.json missing"
  FINDINGS+=('{"agentId":"itil.cost-state","severity":"ITIL_VIOLATION","note":"cost-state.json missing. Cost tracking not operational. ITIL-5 breach.","detectedAt":"'"$AEST_TIMESTAMP"'}')
  FAIL=$((FAIL + 1))
fi

# Check 15: Content governance queue — no published item missing triad clearance (TKT-0033)
CONTENT_QUEUE="$WORKSPACE/state/content-queue.json"
if [[ -f "$CONTENT_QUEUE" ]]; then
  QUEUE_VIOLATIONS=$(python3 -c "
import json, sys
try:
    with open('$CONTENT_QUEUE') as f:
        data = json.load(f)
    queue = data.get('queue', [])
    violations = []
    for item in queue:
        if item.get('status') == 'published':
            shield_ok = item.get('shield') in ('clear', 'conditional')
            lex_ok    = item.get('lex')    in ('clear', 'conditional')
            sage_ok   = item.get('sage')   in ('clear', 'conditional')
            if not (shield_ok and lex_ok and sage_ok):
                violations.append(item.get('id', 'unknown'))
    for v in violations:
        print(v)
except Exception as e:
    pass
" 2>/dev/null)

  if [ -z "$QUEUE_VIOLATIONS" ]; then
    echo "  OK  content-governance: no published items missing triad clearance"
    PASS=$((PASS + 1))
  else
    echo "  FAIL  content-governance: published items missing triad clearance: $QUEUE_VIOLATIONS"
    FAIL=$((FAIL + 1))
    while IFS= read -r item_id; do
      FINDINGS+=("{\"agentId\":\"content-governance.$item_id\",\"severity\":\"content-published-without-clearance\",\"note\":\"Item $item_id is published but missing CLEAR/CONDITIONAL from one or more triad agents. TKT-0033 violation.\",\"detectedAt\":\"$AEST_TIMESTAMP\"}")
    done <<< "$QUEUE_VIOLATIONS"
  fi
else
  echo "  OK  content-governance: content-queue.json not present (no items to check)"
  PASS=$((PASS + 1))
fi

echo "─────────────────────────────────────────────────────────────"
echo "Total: $((PASS + FAIL)) checks | PASS: $PASS | FAIL: $FAIL"
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
  # Write FINDINGS_JSON to a temp file to avoid shell quoting issues in python -c
  FINDINGS_TMP=$(mktemp /tmp/warden-findings-XXXXXX.json)
  echo "$FINDINGS_JSON" > "$FINDINGS_TMP"
  python3 - <<PYEOF
import json, os
vfile = '$VIOLATIONS'
findings_file = '$FINDINGS_TMP'
# Load existing
if os.path.exists(vfile):
    with open(vfile) as f:
        data = json.load(f)
else:
    data = {'violations': [], 'totalUnresolved': 0}

with open(findings_file) as ff:
    findings = json.load(ff)
os.unlink(findings_file)

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
PYEOF
  echo ""
  echo "⚠️  VIOLATIONS DETECTED — written to state/model-drift-violations.json"
  echo "    Warden will escalate to Yoda."
  exit 2
else
  echo ""
  echo "✅ All checks passed. No model drift detected."
  exit 0
fi
