#!/bin/zsh
# cron-timeout-scaler.sh — Adaptive timeout calculation for all active crons (TKT-0339 AC1)
# Phase 1 of 4: Reads cron API, computes recommended timeouts, writes baseline JSON.
#
# CONSERVATIVE MODE (CHG-0349): FLAG/RECOMMEND only — never auto-apply timeouts.
# All writes through cron-write.sh for state files.
#
# Formula: timeout = max(sliding_avg * 1.5, floor_timeout_ms)
# Sliding window: last 10 runs (best effort from cron state + task history)
# Task classes: shell(30s), light-agent(120s), heavy-agent(300s), blog/standup(600s)
#
# Output: state/cron-timeout-baseline.json
# Exit: 0 = success, 1 = computation failed

set -u
WORKSPACE="/Users/ainchorsangiefpl/.openclaw/workspace"
STATE_DIR="$WORKSPACE/state"
BASELINE_FILE="$STATE_DIR/cron-timeout-baseline.json"
CRON_WRITE="$WORKSPACE/scripts/cron-write.sh"
NOW=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

# ── Pull cron list from API, write to temp file ────────────────────────────
CRON_TMP=$(mktemp /tmp/cron-timeout-scaler-XXXXXX.json)
/opt/homebrew/bin/openclaw cron list --json > "$CRON_TMP" 2>/dev/null || echo '[]' > "$CRON_TMP"

# ── Compute + write baseline in a single Python process ─────────────────────
# This avoids shell escaping problems with control characters in cron names.
python3 << PYEOF
import json, sys, math, re, subprocess, os

cron_file = '$CRON_TMP'
now_ts = '$NOW'
baseline_file = os.path.expanduser('$BASELINE_FILE')

# Read raw cron data
with open(cron_file) as f:
    cron_raw = f.read()

try:
    if cron_raw.strip().startswith('['):
        jobs = json.loads(cron_raw)
    else:
        data = json.loads(cron_raw)
        jobs = data.get('jobs', [])
except Exception:
    jobs = []

FLOORS = {
    'shell': 30000,
    'light-agent': 120000,
    'heavy-agent': 300000,
    'blog-standup': 600000,
}
SCALE = 1.5
WINDOW = 10

def sanitize_name(name):
    if not name:
        return 'unknown'
    # Collapse all whitespace (including embedded newlines) to single space
    name = re.sub(r'\s+', ' ', name).strip()
    return name[:80]

def classify_cron(name, full_id):
    name_lower = name.lower() if name else ''
    # Blog/standup (600s floor)
    if any(p in name_lower for p in ['blog', 'stand-up', 'standup', 'daily close', 'daily summary']):
        return 'blog-standup'
    # Heavy agent (300s floor)
    heavy = ['model', 'strategy review', 'compliance', 'weekly report', 'monthly report',
             'quarterly', 'roi summary', 'asset review', 'sla report', 'legal review',
             'security review', 'qa review', 'glm-', 'no-think mode', 'cost tracker',
             'budget', 'burn alert']
    if any(p in name_lower for p in heavy):
        return 'heavy-agent'
    # Shell (30s floor)
    shell = ['backup', 'restart', 'gateway health', 'tz drift', 'cleanup',
             'drive sync', 'context sync', 'holocron', 'mission control',
             'task monitor', 'task queue', 'observability', 'post-deliverable',
             'context-brief']
    if any(p in name_lower for p in shell):
        return 'shell'
    return 'light-agent'

results = []

for job in jobs:
    job_id = job.get('id', '')
    name = sanitize_name(job.get('name', 'unknown'))
    state = job.get('state', {})
    enabled = state.get('enabled', True)
    timeout_set = job.get('timeoutSeconds', None)
    last_dur_ms = state.get('lastDurationMs', None)
    consecutive_errors = state.get('consecutiveErrors', 0)
    last_status = state.get('lastStatus', 'unknown')

    class_name = classify_cron(name, job_id)

    durations = []
    if last_dur_ms is not None and isinstance(last_dur_ms, (int, float)) and last_dur_ms > 0:
        durations.append(last_dur_ms)

    if not durations:
        avg_duration_ms = FLOORS.get(class_name, 120000)
        data_points = 0
    else:
        avg_duration_ms = sum(durations) / len(durations)
        data_points = len(durations)

    floor_ms = FLOORS.get(class_name, 120000)
    computed = max(avg_duration_ms * SCALE, floor_ms)
    computed_sec = math.ceil(computed / 1000)

    cur_to = timeout_set if timeout_set else 0
    deviation = None
    recommendation = None

    if cur_to > 0:
        deviation_pct = abs(computed_sec - cur_to) / max(computed_sec, 1) * 100
        deviation = round(deviation_pct, 1)
        if deviation_pct > 50:
            recommendation = "INCREASE" if computed_sec > cur_to else "DECREASE"
        elif computed_sec > cur_to:
            recommendation = "REVIEW"
    else:
        recommendation = "SET"

    is_victim = False
    victim_detail = None
    if timeout_set is not None and last_dur_ms is not None:
        timeout_ms = timeout_set * 1000
        if last_dur_ms > timeout_ms:
            is_victim = True
            victim_detail = "{}ms > {}ms".format(last_dur_ms, timeout_ms)

    results.append({
        'cronId': job_id[:8],
        'fullCronId': job_id,
        'name': name,
        'enabled': enabled,
        'taskClass': class_name,
        'floorTimeoutSec': floor_ms // 1000,
        'avgDurationMs': round(avg_duration_ms),
        'dataPoints': data_points,
        'computedTimeoutSec': computed_sec,
        'currentTimeoutSec': cur_to if cur_to else None,
        'deviationPct': deviation,
        'recommendation': recommendation,
        'lastStatus': last_status,
        'consecutiveErrors': consecutive_errors,
        'isTimeoutVictim': is_victim,
        'victimDetail': victim_detail
    })

# ── Build by-class summary ───────────────────────────────────────────────
by_class = {}
for cls in FLOORS:
    crons_in_class = [r for r in results if r['taskClass'] == cls]
    if crons_in_class:
        by_class[cls] = {
            'count': len(crons_in_class),
            'avgComputedTimeoutSec': round(sum(r['computedTimeoutSec'] for r in crons_in_class) / len(crons_in_class), 1),
            'maxComputedTimeoutSec': max((r['computedTimeoutSec'] for r in crons_in_class), default=0)
        }

baseline = {
    'generatedAt': now_ts,
    'version': '1.0.0',
    'schema': 'TKT-0339',
    'scalerMode': 'FLAG_RECOMMEND_ONLY',
    'formula': {
        'scaleFactor': SCALE,
        'slidingWindow': WINDOW,
        'description': 'timeout = max(avg_duration_ms * 1.5, floor_timeout_ms_seconds)'
    },
    'taskClasses': {
        'shell': {'floorSec': 30, 'description': 'Shell-level ops: backups, restarts, health checks'},
        'light-agent': {'floorSec': 120, 'description': 'Standard agent tasks: monitoring, syncs, daily reports'},
        'heavy-agent': {'floorSec': 300, 'description': 'Complex analysis: model review, compliance, legal, strategy'},
        'blog-standup': {'floorSec': 600, 'description': 'Content generation: blog posts, daily standups'}
    },
    'summary': {
        'totalCrons': len(jobs),
        'enabledCrons': sum(1 for r in results if r['enabled']),
        'timeoutsSet': sum(1 for r in results if r['currentTimeoutSec'] is not None),
        'timeoutsRecommended': sum(1 for r in results if r['recommendation'] in ('SET', 'INCREASE', 'DECREASE', 'REVIEW')),
        'needsIncrease': sum(1 for r in results if r['recommendation'] == 'INCREASE'),
        'needsSet': sum(1 for r in results if r['recommendation'] == 'SET'),
        'needsDecrease': sum(1 for r in results if r['recommendation'] == 'DECREASE'),
        'needsReview': sum(1 for r in results if r['recommendation'] == 'REVIEW'),
        'timeoutVictims': sum(1 for r in results if r['isTimeoutVictim']),
        'byClass': by_class
    },
    'crons': results
}

# ── Write directly from Python (no shell echo/pipe) ─────────────────────────
output = json.dumps(baseline, indent=2, ensure_ascii=False)
os.makedirs(os.path.dirname(baseline_file), exist_ok=True)
with open(baseline_file, 'w') as f:
    f.write(output)

# ── Print summary ──────────────────────────────────────────────────────────
s = baseline['summary']
print("OK: {} bytes -> {}".format(len(output), baseline_file))
print("")
print("=== cron-timeout-scaler.sh complete ===")
print("Crons scanned: {} (enabled: {})".format(s['totalCrons'], s['enabledCrons']))
print("Timeouts currently set: {}".format(s['timeoutsSet']))
print("Recommended actions: {} total".format(s['timeoutsRecommended']))
print("  SET (no timeout): {}".format(s['needsSet']))
print("  INCREASE (>50% deviation): {}".format(s['needsIncrease']))
print("  DECREASE (>50% deviation): {}".format(s['needsDecrease']))
print("  REVIEW (minor deviation): {}".format(s['needsReview']))
print("Timeout victims (last run exceeded set timeout): {}".format(s['timeoutVictims']))
print("")
print("By class:")
for cls, info in sorted(s['byClass'].items()):
    print("  {}: {} crons, avg computed={}s, max={}s".format(cls, info['count'], info['avgComputedTimeoutSec'], info['maxComputedTimeoutSec']))
print("")
print("Top recommendations (by computed timeout):")
needs_action = [r for r in results if r['recommendation'] in ('SET', 'INCREASE', 'DECREASE')]
needs_action.sort(key=lambda x: x['computedTimeoutSec'], reverse=True)
for r in needs_action[:12]:
    cur = r['currentTimeoutSec'] if r['currentTimeoutSec'] else 'NONE'
    print("  [{}] {:50s} | class={:15s} | computed={:>5d}s | cur={:>5s} | rec={}".format(
        r['cronId'], r['name'][:50], r['taskClass'], r['computedTimeoutSec'], str(cur), r['recommendation']))
print("")
print("Timeout victims (would have timed out if timeout was set):")
victims = [r for r in results if r['isTimeoutVictim']]
if victims:
    for r in victims:
        print("  VICTIM [{}] {} — {}".format(r['cronId'], r['name'][:55], r.get('victimDetail', '?')))
else:
    print("  (none — no crons have set timeouts, so no comparison possible)")
PYEOF

# Cleanup temp file
rm -f "$CRON_TMP"
exit 0
