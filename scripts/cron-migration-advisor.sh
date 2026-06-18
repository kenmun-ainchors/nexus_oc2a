#!/bin/zsh
# cron-migration-advisor.sh — Per-cron multi-vendor migration advisor (L-130, P2 #2).
# Reads state/cron-ollama-usage.json (L-128) + state/cron-list-snapshot.json.
# Computes a migration score per cron: 40% cliff_risk + 30% model_load + 20% (1-criticality) + 10% rate_limited_streak.
# Tier 1 (>=0.5): migrate now. Tier 2 (0.3-0.5): monitor. Tier 3 (<0.3): keep.
# Writes state/cron-migration-suggestions.json.
# 6h cooldown via state/cron-migration-advisor-last-run.json.

set -euo pipefail

WORKSPACE="${WORKSPACE_ROOT:-$HOME/.openclaw/workspace}"
USAGE_FILE="$WORKSPACE/state/cron-ollama-usage.json"
CRON_LIST="$WORKSPACE/state/cron-list-snapshot.json"
OUTPUT="$WORKSPACE/state/cron-migration-suggestions.json"
COOLDOWN_FILE="$WORKSPACE/state/cron-migration-advisor-last-run.json"
COOLDOWN_S=21600  # 6h

# Shared atomic-write helper (TKT-0529 B2.5)
source "${WORKSPACE}/scripts/lib/atomic-write.sh"

# Cooldown check
if [[ -f "$COOLDOWN_FILE" ]]; then
  LAST_RUN_EPOCH=$(python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print(d.get('epoch',0))" "$COOLDOWN_FILE" 2>/dev/null || echo 0)
  NOW_EPOCH=$(date "+%s")
  if (( NOW_EPOCH - LAST_RUN_EPOCH < COOLDOWN_S )); then
    echo "SKIP: cooldown active, last run $(( NOW_EPOCH - LAST_RUN_EPOCH ))s ago"
    exit 0
  fi
fi

# Required input
if [[ ! -f "$USAGE_FILE" ]]; then
  echo "FAIL: $USAGE_FILE not found (run ollama-quota-track.sh first)"
  exit 1
fi
if [[ ! -f "$CRON_LIST" ]]; then
  echo "FAIL: $CRON_LIST not found"
  exit 1
fi

python3 - "$USAGE_FILE" "$CRON_LIST" "$OUTPUT" <<'PYEOF'
import json, datetime, sys, os, tempfile

# Load L-128 data
usage_path = sys.argv[1]
cron_list_path = sys.argv[2]
output_path = sys.argv[3]
usage = json.load(open(usage_path))
crons_list = json.load(open(cron_list_path))
now = datetime.datetime.now(datetime.timezone.utc).astimezone(datetime.timezone(datetime.timedelta(hours=10)))

# Critical cron patterns (should NOT migrate unless last resort)
CRITICAL_PATTERNS = ['TQP', 'Auto-Heal', 'Task Monitor', 'sovereign-alert', 'Journal Cron', 'Blog Cron', 'Drive Cron', 'Sprint']

# Compute total errors per model (for model_load)
model_errors = {}
for cid, c in usage.get('per_cron', {}).items():
    m = c.get('model', '')
    if m:
        model_errors.setdefault(m, 0)
        model_errors[m] += c.get('consecutiveErrors', 0)
total_errors = sum(model_errors.values()) or 1

# Build cron list lookup for full cron data
cron_lookup = {j['id']: j for j in crons_list.get('jobs', []) if j.get('id')}

# Score each cron
suggestions = []
for cid, c in usage.get('per_cron', {}).items():
    name = c.get('name', '')
    model = c.get('model', '')
    cliff_risk = c.get('cliffRiskScore', 0)
    consecutive_errors = c.get('consecutiveErrors', 0)
    rate_limited_streak = min(consecutive_errors, 5) / 5
    
    # Model load = this model's share of total errors
    model_load = model_errors.get(model, 0) / total_errors
    
    # Criticality: 1 if name matches critical pattern
    is_critical = any(p.lower() in name.lower() for p in CRITICAL_PATTERNS)
    criticality = 1.0 if is_critical else 0.0
    
    # Migration score: 40% cliff_risk + 30% model_load + 20% (1-criticality) + 10% rate_limited_streak
    migration_score = round(0.4 * cliff_risk + 0.3 * model_load + 0.2 * (1 - criticality) + 0.1 * rate_limited_streak, 3)
    
    # Tier
    if migration_score >= 0.5:
        tier = 1
        tier_name = 'migrate_now'
    elif migration_score >= 0.3:
        tier = 2
        tier_name = 'monitor'
    else:
        tier = 3
        tier_name = 'keep'
    
    # Suggested target model: prefer kimi (clean cap, 0 rate-limited)
    # If kimi is already used, suggest deepseek-v4-flash:cloud
    if model == 'ollama/kimi-k2.6:cloud':
        suggested_target = 'ollama/deepseek-v4-flash:cloud'
    elif model.startswith('ollama/'):
        suggested_target = 'ollama/kimi-k2.6:cloud'
    else:
        suggested_target = 'ollama/kimi-k2.6:cloud'
    
    suggestions.append({
        'cronId': cid,
        'name': name,
        'currentModel': model,
        'cliffRisk': cliff_risk,
        'modelLoad': round(model_load, 3),
        'isCritical': is_critical,
        'consecutiveErrors': consecutive_errors,
        'rateLimitedStreak': round(rate_limited_streak, 3),
        'migrationScore': migration_score,
        'tier': tier,
        'tierName': tier_name,
        'suggestedTargetModel': suggested_target,
    })

# Sort by score desc
suggestions.sort(key=lambda x: x['migrationScore'], reverse=True)

# Summary
tier_1 = [s for s in suggestions if s['tier'] == 1]
tier_2 = [s for s in suggestions if s['tier'] == 2]
tier_3 = [s for s in suggestions if s['tier'] == 3]

output = {
    'generatedAt': now.strftime('%Y-%m-%dT%H:%M:%S%z'),
    'schemaVersion': 1,
    'scoreFormula': '0.4*cliff_risk + 0.3*model_load + 0.2*(1-criticality) + 0.1*rate_limited_streak',
    'tierThresholds': {'1': 0.5, '2': 0.3, '3': 0.0},
    'suggestions': suggestions,
    'summary': {
        'total_crons_evaluated': len(suggestions),
        'tier_1_migrate_now': len(tier_1),
        'tier_2_monitor': len(tier_2),
        'tier_3_keep': len(tier_3),
        'top_3_migration_candidates': [s['cronId'] for s in suggestions[:3]],
        'note': 'Tier 1 = migrate now candidates. Review state/cron-ollama-usage.json for context. Apply via openclaw cron update or similar.'
    }
}

# Atomic write (TKT-0529 B2.5): write to temp file in same dir, then os.replace
_target = output_path
_target_dir = os.path.dirname(_target)
_fd, _tmp = tempfile.mkstemp(prefix='.cron-migration-suggestions.', suffix='.json.tmp', dir=_target_dir)
try:
    with os.fdopen(_fd, 'w') as _f:
        json.dump(output, _f, indent=2)
        _f.flush()
        os.fsync(_f.fileno())
    os.replace(_tmp, _target)
except Exception:
    try:
        os.unlink(_tmp)
    except OSError:
        pass
    raise

print(f'EVALUATED: {len(suggestions)} ollama/* crons')
print(f'TIER_1: {len(tier_1)} (migrate now)')
print(f'TIER_2: {len(tier_2)} (monitor)')
print(f'TIER_3: {len(tier_3)} (keep)')
if suggestions:
    top = suggestions[0]
    print(f'TOP_CANDIDATE: {top["name"]} (score={top["migrationScore"]}, current={top["currentModel"]}, suggested={top["suggestedTargetModel"]})')
PYEOF

# Update cooldown — atomic write (TKT-0529 B2.5)
python3 -c "
import json, time, os, tempfile
_target = '$COOLDOWN_FILE'
_dir = os.path.dirname(_target) or '.'
_fd, _tmp = tempfile.mkstemp(prefix='.cron-migration-advisor-last-run.', suffix='.json.tmp', dir=_dir)
try:
    with os.fdopen(_fd, 'w') as _f:
        json.dump({'epoch': int(time.time())}, _f)
        _f.flush()
        os.fsync(_f.fileno())
    os.replace(_tmp, _target)
except Exception:
    try:
        os.unlink(_tmp)
    except OSError:
        pass
    raise
"

exit 0
