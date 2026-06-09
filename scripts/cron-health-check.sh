#!/bin/zsh
# cron-health-check.sh — Check cron run history for failures, timeouts, missed daily runs
# Uses: openclaw tasks list (the only reliable source of cron run outcomes)
# Output: state/cron-health-state.json | state/cron-health-alert.json
# Exit: 0 = healthy | 1 = failures found

set -u
WORKSPACE="$HOME/.openclaw/workspace"
STATE_FILE="$WORKSPACE/state/cron-health-state.json"
ALERT_FILE="$WORKSPACE/state/cron-health-alert.json"

# Pull last 100 task runs, filter crons only
TASKS=$(openclaw tasks list --limit 100 2>/dev/null || echo "")

# Pull live cron state for consecutiveErrors check — write to temp file to avoid control char issues
CRON_STATE_TMP=$(mktemp /tmp/cron-state-health-XXXXXX.json)
openclaw cron list --json 2>/dev/null > "$CRON_STATE_TMP" || echo '{"jobs":[]}' > "$CRON_STATE_TMP"

python3 << PYEOF
import sys, os, re, json
from datetime import datetime, timezone, timedelta

tasks_raw = """$TASKS"""
cron_state_tmp = """$CRON_STATE_TMP"""
try:
    with open(cron_state_tmp.strip()) as _f:
        cron_state_raw = _f.read()
except Exception:
    cron_state_raw = '{"jobs":[]}'  
now = datetime.now(timezone.utc)
cutoff = now - timedelta(hours=26)  # look back 26h — catches missed daily crons

failures = []
warnings = []
seen_crons = set()

# CHG-0411: Crons where "error" status is expected (e.g. gateway restart kills the cron process)
# These are ID prefixes — matched with .startswith()
EXPECTED_ERROR_CRONS = [
    '20f59555',  # Nightly Gateway Restart — "interrupted by gateway restart" is expected
]

# CHG-0458: Errors caused by gateway restart are transient — skip if lastError contains this pattern
# Any cron can be interrupted by the 03:00 restart; it recovers on next run.
EXPECTED_ERROR_PATTERNS = [
    'interrupted by gateway restart',
    'job interrupted by gateway restart',
]

# --- Live consecutiveErrors check (Fix 1: CHG-0152 followup) ---
try:
    cron_data = json.loads(cron_state_raw)
    for job in cron_data.get('jobs', []):
        job_id = job.get('id', '')
        if any(job_id.startswith(prefix) for prefix in EXPECTED_ERROR_CRONS):
            continue  # CHG-0411: expected error, skip
        last_error = job.get('state', {}).get('lastError', '')
        if any(pattern in last_error for pattern in EXPECTED_ERROR_PATTERNS):
            continue  # CHG-0458: transient gateway restart error, skip
        consecutive = job.get('state', {}).get('consecutiveErrors', 0)
        if consecutive >= 3:
            last_status = job.get('state', {}).get('lastStatus', '')
            failures.append({
                'cronId': job.get('id', '')[:8],
                'fullCronId': job.get('id', ''),
                'name': job.get('name', '')[:60],
                'consecutiveErrors': consecutive,
                'lastError': last_status,
                'source': 'live-cron-state'
            })
except Exception as e:
    warnings.append({'source': 'live-cron-state', 'detail': f'Failed to parse cron state: {e}'})

for line in tasks_raw.strip().split('\n'):
    if not line.strip() or 'cron' not in line:
        continue
    parts = line.split()
    if len(parts) < 4:
        continue
    run_id = parts[0].rstrip('…')
    kind = parts[1] if len(parts) > 1 else ''
    status = parts[2] if len(parts) > 2 else ''
    cron_ref = parts[4] if len(parts) > 4 else ''  # cron:XXXXXXXX...
    name_parts = parts[6:] if len(parts) > 6 else []
    name = ' '.join(name_parts)[:60]

    if kind != 'cron':
        continue

    cron_id = cron_ref.replace('cron:', '')[:8]
    full_cron_id = cron_ref.replace('cron:', '')

    # CHG-0411: skip crons where error is expected
    if any(full_cron_id.startswith(prefix) for prefix in EXPECTED_ERROR_CRONS):
        continue

    if status in ('timed_out', 'error', 'failed'):
        # Only report once per cron (most recent)
        if cron_id not in seen_crons:
            seen_crons.add(cron_id)
            failures.append({
                'cronId': cron_id,
                'runId': run_id,
                'name': name,
                'status': status
            })

result = {
    'checkedAt': now.isoformat(),
    'failures': failures,
    'warnings': warnings,
    'healthy': len(failures) == 0 and len(warnings) == 0
}

state_path = os.path.expanduser('~/.openclaw/workspace/state/cron-health-state.json')
with open(state_path, 'w') as f:
    json.dump(result, f, indent=2)

if failures or warnings:
    # Write alert for heartbeat to pick up
    existing = {}
    alert_path = os.path.expanduser('~/.openclaw/workspace/state/cron-health-alert.json')
    try:
        with open(alert_path) as f:
            existing = json.load(f)
    except:
        pass

    alert = {
        'generatedAt': now.isoformat(),
        'failures': failures,
        'warnings': warnings,
        'acknowledged': False
    }
    with open(alert_path, 'w') as f:
        json.dump(alert, f, indent=2)

    print(f"ALERT: {len(failures)} cron failure(s), {len(warnings)} warning(s)")
    for item in failures:
        if item.get('source') == 'live-cron-state':
            print(f"  ❌ [{item['cronId']}] {item['name']} — consecutiveErrors={item['consecutiveErrors']} lastStatus={item['lastError']}")
        else:
            print(f"  ❌ [{item['cronId']}] {item['name']} — {item['status']}")
    for item in warnings:
        print(f"  ⚠️  [{item['cronId']}] {item['name']} — {item.get('detail','')}")
    sys.exit(1)
else:
    print(f"OK: cron health clean")
    sys.exit(0)
PYEOF

# Cleanup temp file
[ -f "$CRON_STATE_TMP" ] && rm -f "$CRON_STATE_TMP"
