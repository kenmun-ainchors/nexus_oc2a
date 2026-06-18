#!/bin/zsh
# ollama-quota-track.sh — Per-cron Ollama Cloud quota tracking (L-128, Rec #1)
# Pairs with CHECK 30 (L-118, aggregate) for full cliff prediction.
# Reads state/cron-list-snapshot.json, computes per-cron estimated weekly usage,
# cliff risk score, status. Writes state/cron-ollama-usage.json.
# 6h cooldown via state/ollama-quota-track-last-run.json.

set -euo pipefail

WORKSPACE="${WORKSPACE_ROOT:-$HOME/.openclaw/workspace}"
CRON_LIST="$WORKSPACE/state/cron-list-snapshot.json"
OUTPUT="$WORKSPACE/state/cron-ollama-usage.json"
COOLDOWN_FILE="$WORKSPACE/state/ollama-quota-track-last-run.json"
COOLDOWN_S=21600  # 6h

# TKT-0529 B2.4: shared atomic-write helper
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

# Refresh cron list if stale (>30 min)
if [[ ! -f "$CRON_LIST" ]] || [[ $(find "$CRON_LIST" -mmin +30 2>/dev/null) ]]; then
  openclaw cron list --json > "$CRON_LIST" 2>/dev/null || {
    echo "FAIL: openclaw cron list failed"
    exit 1
  }
fi

python3 <<'PYEOF'
import json, datetime, sys, os, tempfile

d = json.load(open('/Users/ainchorsangiefpl/.openclaw/workspace/state/cron-list-snapshot.json'))
now = datetime.datetime.now(datetime.timezone.utc).astimezone(datetime.timezone(datetime.timedelta(hours=10)))

# Per-model rate estimates (tokens/sec, rough heuristic)
# Calibrated against typical cron output (200-500 tokens for ~3-5s response)
MODEL_RATES = {
    'ollama/gemma4:31b-cloud': 120,
    'ollama/deepseek-v4-pro:cloud': 200,
    'ollama/kimi-k2.6:cloud': 150,
    'ollama/minimax-m3:cloud': 100,
    'ollama/deepseek-v4-flash:cloud': 250,
}
WEEKLY_CAP_TOKENS = 5_000_000  # rough estimate for $100/wk Ollama Cloud subscription

per_cron = {}
ollama_count = 0
rate_limited_count = 0
warning_count = 0
critical_count = 0
top_consumers = []

for j in d.get('jobs', []):
    model = j.get('payload', {}).get('model', '')
    if not model.startswith('ollama/'):
        continue
    ollama_count += 1
    
    state = j.get('state', {})
    last_run_ms = state.get('lastRunAtMs', 0)
    last_duration_ms = state.get('lastDurationMs', 0)
    consecutive_errors = state.get('consecutiveErrors', 0)
    last_error_reason = state.get('lastErrorReason', '')
    
    # Estimated tokens for last run
    rate = MODEL_RATES.get(model, 100)
    estimated_tokens_last_run = int((last_duration_ms / 1000) * rate)
    
    # Rough weekly estimate: assume cron runs ~7x/week (daily), so 7 × last run
    # Could be refined with actual schedule parsing, but this is a heuristic
    week_estimated = estimated_tokens_last_run * 7
    
    # Cliff risk score (0-1)
    # 50% weight on rate-limit hits (consecutive_errors normalized, cap at 5)
    # 50% weight on estimated % of weekly cap per cron
    rl_component = min(consecutive_errors, 5) / 5 * 0.5
    cap_component = min(week_estimated / WEEKLY_CAP_TOKENS, 1.0) * 0.5
    cliff_risk = round(rl_component + cap_component, 3)
    
    # Status
    if cliff_risk >= 0.7:
        status = 'critical'
        critical_count += 1
    elif cliff_risk >= 0.4:
        status = 'warning'
        warning_count += 1
    else:
        status = 'safe'
    
    if last_error_reason == 'rate_limit':
        rate_limited_count += 1
    
    cron_id = j.get('id', '')
    cron_id_short = cron_id[:8] if cron_id else ''
    
    per_cron[cron_id] = {
        'name': j.get('name', ''),
        'model': model,
        'lastRunAtMs': last_run_ms,
        'lastRunAtLocal': datetime.datetime.fromtimestamp(last_run_ms/1000, tz=datetime.timezone(datetime.timedelta(hours=10))).strftime('%Y-%m-%dT%H:%M:%S%z') if last_run_ms else None,
        'lastDurationMs': last_duration_ms,
        'estimatedTokensLastRun': estimated_tokens_last_run,
        'weekEstimatedTotal': week_estimated,
        'consecutiveErrors': consecutive_errors,
        'lastErrorReason': last_error_reason,
        'cliffRiskScore': cliff_risk,
        'status': status,
    }
    
    top_consumers.append((cron_id, week_estimated, cliff_risk, j.get('name', '')))

# Sort top consumers by week_estimated desc
top_consumers.sort(key=lambda x: x[1], reverse=True)
top_consumer_ids = [tc[0] for tc in top_consumers[:5]]

output = {
    'generatedAt': now.strftime('%Y-%m-%dT%H:%M:%S%z'),
    'weekOfYear': now.strftime('%Y-W%V'),
    'schemaVersion': 1,
    'per_cron': per_cron,
    'summary': {
        'total_ollama_crons': ollama_count,
        'rate_limited': rate_limited_count,
        'warning': warning_count,
        'critical': critical_count,
        'top_consumers': top_consumer_ids,
        'cliff_pattern_note': 'Ollama Cloud weekly cap hits Sun/Mon, recovers Tue. 0 critical = no per-cron cliff detected.'
    }
}

# TKT-0529 B2.4: atomic write via tempfile + os.replace
_target = '/Users/ainchorsangiefpl/.openclaw/workspace/state/cron-ollama-usage.json'
_dir = os.path.dirname(_target)
_tmp = tempfile.NamedTemporaryFile('w', dir=_dir, prefix='.cron-ollama-usage.', suffix='.json.tmp', delete=False)
try:
    json.dump(output, _tmp, indent=2)
    _tmp.flush()
    os.fsync(_tmp.fileno())
    _tmp.close()
    os.replace(_tmp.name, _target)
except Exception:
    try:
        _tmp.close()
    except Exception:
        pass
    try:
        os.unlink(_tmp.name)
    except Exception:
        pass
    raise

print(f'TRACKED: {ollama_count} ollama/* crons')
print(f'RATE_LIMITED: {rate_limited_count}')
print(f'WARNING: {warning_count}')
print(f'CRITICAL: {critical_count}')
print(f'TOP_CONSUMER: {top_consumers[0][3] if top_consumers else "none"} ({top_consumers[0][1] if top_consumers else 0} tokens/wk est.)')
PYEOF

# Update cooldown
python3 -c "
import json, time, os, tempfile
_target = '$COOLDOWN_FILE'
_dir = os.path.dirname(_target) or '.'
_tmp = tempfile.NamedTemporaryFile('w', dir=_dir, prefix='.ollama-quota-track-last-run.', suffix='.json.tmp', delete=False)
try:
    json.dump({'epoch': int(time.time())}, _tmp)
    _tmp.flush()
    os.fsync(_tmp.fileno())
    _tmp.close()
    os.replace(_tmp.name, _target)
except Exception:
    try:
        _tmp.close()
    except Exception:
        pass
    try:
        os.unlink(_tmp.name)
    except Exception:
        pass
    raise
"

exit 0
