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

python3 << PYEOF
import sys, os, re, json
from datetime import datetime, timezone, timedelta

tasks_raw = """$TASKS"""
now = datetime.now(timezone.utc)
cutoff = now - timedelta(hours=26)  # look back 26h — catches missed daily crons

failures = []
warnings = []
seen_crons = set()

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
        print(f"  ❌ [{item['cronId']}] {item['name']} — {item['status']}")
    for item in warnings:
        print(f"  ⚠️  [{item['cronId']}] {item['name']} — {item.get('detail','')}")
    sys.exit(1)
else:
    print(f"OK: cron health clean")
    sys.exit(0)
PYEOF
