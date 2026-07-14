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
        # CHG-0814: skip disabled crons — they are intentionally decommissioned
        if job.get('enabled') is False:
            continue
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

    # CHG-0591 (2026-06-15): Preserve acknowledged flag from prior alert
    # - If new alert has NO failures: keep existing ack (sticky)
    # - If new alert has failures: reset acknowledged=False (new failure invalidates prior ack)
    # - If no existing file: default acknowledged=False
    ack = False
    ack_at = None
    ack_reason = None
    if not failures:
        # No new failures — preserve prior ack if it exists
        ack = existing.get('acknowledged', False)
        ack_at = existing.get('acknowledgedAt')
        ack_reason = existing.get('acknowledgedReason')
    # else: failures exist → reset to False (default)

    alert = {
        'generatedAt': now.isoformat(),
        'failures': failures,
        'warnings': warnings,
        'acknowledged': ack
    }
    if ack_at:
        alert['acknowledgedAt'] = ack_at
    if ack_reason:
        alert['acknowledgedReason'] = ack_reason
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


# ── Retry State Tracking (TKT-0339 AC2) ────────────────────────────────────
# Track timeout failures per cron — 2 retries with 2x/4x backoff
RETRY_STATE_FILE="$WORKSPACE/state/cron-retry-state.json"
python3 - "$STATE_FILE" "$RETRY_STATE_FILE" << 'RETRY_PYEOF'
import json, sys, os
from datetime import datetime, timezone

health_file = sys.argv[1]
retry_file = sys.argv[2]
now = datetime.now(timezone.utc).isoformat()

# Load current failures from health state
failures = []
try:
    with open(health_file) as f:
        hs = json.load(f)
    failures = hs.get('failures', [])
except:
    pass

# Load existing retry state
retry_state = {'updatedAt': now, 'crons': {}}
try:
    with open(retry_file) as f:
        retry_state = json.load(f)
except:
    pass

retry_crons = retry_state.get('crons', {})

# Process each failed cron
for f_item in failures:
    cid = f_item.get('cronId', '')
    if not cid:
        continue
    
    entry = retry_crons.get(cid, {
        'cronId': cid,
        'name': f_item.get('name', ''),
        'consecutiveTimeouts': 0,
        'totalTimeouts': 0,
        'retriesUsed': 0,
        'lastTimeoutAt': None,
        'nextRetryBackoffMs': 0,
        'deadLetter': False
    })
    
    # Increment counters
    entry['consecutiveTimeouts'] = entry.get('consecutiveTimeouts', 0) + 1
    entry['totalTimeouts'] = entry.get('totalTimeouts', 0) + 1
    entry['lastTimeoutAt'] = now
    
    # Compute backoff
    con = entry['consecutiveTimeouts']
    retries_used = min(con, 2)  # cap at 2 retries
    entry['retriesUsed'] = retries_used
    
    if retries_used == 1:
        entry['nextRetryBackoffMs'] = 2 * 60 * 1000  # 2x = 2 min
    elif retries_used == 2:
        entry['nextRetryBackoffMs'] = 4 * 60 * 1000  # 4x = 4 min
    elif con >= 3:
        entry['deadLetter'] = True
        entry['nextRetryBackoffMs'] = 0  # dead — no more retries
    
    retry_crons[cid] = entry

retry_state['crons'] = retry_crons

os.makedirs(os.path.dirname(retry_file), exist_ok=True)
with open(retry_file, 'w') as f:
    json.dump(retry_state, f, indent=2, default=str)

dead_letters = [e for e in retry_crons.values() if e.get('deadLetter')]
if dead_letters:
    print("DEAD_LETTER_ALERT: {} cron(s) have 3+ consecutive failures:".format(len(dead_letters)))
    for dl in dead_letters:
        print("  DEAD: [{}] {} — {} timeouts total".format(dl['cronId'], dl.get('name', '?')[:50], dl['totalTimeouts']))
RETRY_PYEOF

# ── TKT-0319 Atom 3: Retryable cron failures -> resumable registry ───────
# Crons killed by gateway restart or rate-limited by the provider are
# transient and should be retried. Write them to a registry so a later
# resume executor can re-run them without waiting for the next schedule.
python3 - "$STATE_FILE" << 'RESUMABLE_PYEOF'
import json, sys, os
from datetime import datetime, timezone

health_file = sys.argv[1]
now = datetime.now(timezone.utc)

RETRYABLE_PATTERNS = [
    'interrupted by gateway restart',
    'job interrupted by gateway restart',
    'reached your weekly usage limit',  # Ollama 429 rate-limit
    'rate_limit',
    'All models failed',
]

resumable = []
try:
    with open(health_file) as f:
        hs = json.load(f)
    for failure in hs.get('failures', []):
        reason = failure.get('lastError', '') or failure.get('status', '') or ''
        if any(p in reason for p in RETRYABLE_PATTERNS):
            resumable.append({
                'cronId': failure.get('cronId', failure.get('fullCronId', '')),
                'name': failure.get('name', ''),
                'failure_reason': reason,
                'detected_at': now.isoformat()
            })
except Exception as e:
    print(f"RESUMABLE_CRONS: failed to read health state: {e}")

if resumable:
    ws = "/Users/ainchorsoc2a/.openclaw/workspace"
    resume_file = os.path.join(ws, "state", "resumable-crons.json")
    with open(resume_file, "w") as f:
        json.dump({
            "detectedAt": now.isoformat(),
            "count": len(resumable),
            "resumable": resumable
        }, f, indent=2)
    print(f"RESUMABLE_CRONS: {len(resumable)} retryable cron failure(s) written -> {resume_file}")
else:
    print("RESUMABLE_CRONS: no retryable cron failures")
RESUMABLE_PYEOF

# ── Process Group Reaping (TKT-0339 AC3) ───────────────────────────────────
# Detect running-but-stale cron sessions (> 2x computed timeout)
REAP_LOG_FILE="$WORKSPACE/state/cron-reap-log.json"
BASELINE_FILE="$WORKSPACE/state/cron-timeout-baseline.json"

if [[ -f "$BASELINE_FILE" ]]; then
  python3 - "$BASELINE_FILE" "$REAP_LOG_FILE" << 'REAP_PYEOF'
import json, sys, os, subprocess, time
from datetime import datetime, timezone

baseline_file = sys.argv[1]
reap_file = sys.argv[2]
now = datetime.now(timezone.utc).isoformat()

# Load baseline
try:
    with open(baseline_file) as f:
        baseline = json.load(f)
except:
    sys.exit(0)

# Build computed timeout map
timeout_map = {}
for r in baseline.get('crons', []):
    timeout_map[r['cronId']] = r['computedTimeoutSec']

# Load existing reap log
reap_log = {'updatedAt': now, 'entries': []}
try:
    with open(reap_file) as f:
        reap_log = json.load(f)
except:
    pass

# Find stale cron processes
# Look for processes that appear to be cron runs (openclaw tasks with cron patterns)
# and have been running longer than 2x computed timeout
try:
    ps_out = subprocess.run(['ps', '-eo', 'pid,ppid,etime,command'], 
                           capture_output=True, text=True, timeout=5).stdout
except:
    ps_out = ''

stale_found = []
for line in ps_out.strip().split('\n'):
    if 'openclaw' not in line or 'cron' not in line.lower():
        continue
    parts = line.split(None, 3)
    if len(parts) < 4:
        continue
    pid = parts[0]
    etime = parts[2]  # format: DD-HH:MM:SS or HH:MM:SS
    
    # Parse elapsed time to seconds
    elapsed_s = 0
    try:
        if '-' in etime:
            days, rest = etime.split('-')
            h, m, s = rest.split(':')
            elapsed_s = int(days)*86400 + int(h)*3600 + int(m)*60 + int(s)
        else:
            parts_t = etime.split(':')
            if len(parts_t) == 3:
                h, m, s = parts_t
                elapsed_s = int(h)*3600 + int(m)*60 + int(s)
            elif len(parts_t) == 2:
                m, s = parts_t
                elapsed_s = int(m)*60 + int(s)
    except:
        continue
    
    if elapsed_s <= 0:
        continue
    
    # Check against all crons — if any cron has computed timeout, and elapsed > 2x, reap
    for cron_id, computed_s in timeout_map.items():
        if computed_s <= 0:
            continue
        if elapsed_s > (computed_s * 2):
            stale_found.append({
                'pid': int(pid),
                'cronId': cron_id,
                'elapsedSec': elapsed_s,
                'computedTimeoutSec': computed_s,
                'thresholdSec': computed_s * 2,
                'command': parts[3][:120],
                'reapedAt': now
            })
            break  # one cron match is enough

if stale_found:
    # Kill each stale process + its process group
    for entry in stale_found:
        pid = entry['pid']
        try:
            # Kill process group (negative PID)
            os.killpg(pid, 9)
            entry['reaped'] = True
            print('REAPED: PID {} (cron {}) — elapsed {}s > threshold {}s (2x computed {})'.format(
                pid, entry['cronId'], entry['elapsedSec'], entry['thresholdSec'], entry['computedTimeoutSec']))
        except Exception as e:
            entry['reaped'] = False
            entry['reapError'] = str(e)
            print('REAP_FAILED: PID {} — {}'.format(pid, e))
    
    # Log to reap file
    for entry in stale_found:
        if entry.get('reaped'):
            reap_log['entries'].append(entry)
    
    # Keep last 100 reap entries
    if len(reap_log['entries']) > 100:
        reap_log['entries'] = reap_log['entries'][-100:]
    
    os.makedirs(os.path.dirname(reap_file), exist_ok=True)
    with open(reap_file, 'w') as f:
        json.dump(reap_log, f, indent=2, default=str)
else:
    print('REAP: No stale cron processes detected')
REAP_PYEOF
else
  echo "REAP: SKIP — cron-timeout-baseline.json not found" >&2
fi
# Cleanup temp file
[ -f "$CRON_STATE_TMP" ] && rm -f "$CRON_STATE_TMP"
