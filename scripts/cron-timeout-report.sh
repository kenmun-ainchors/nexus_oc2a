#!/bin/zsh
# cron-timeout-report.sh — CSV report of all crons with timeout data (TKT-0339 AC4)
# Outputs CSV to stdout: cron_id,name,class,computed_timeout_s,recommended_timeout_s,
#   last_5_avg_ms,timeout_incidents_7d,recommendation,last_status
#
# Usage:
#   cron-timeout-report.sh            # stdout CSV
#   cron-timeout-report.sh --json     # JSON output
#   cron-timeout-report.sh --summary  # Summary only

set -u
WORKSPACE="/Users/ainchorsangiefpl/.openclaw/workspace"
STATE_DIR="$WORKSPACE/state"
BASELINE_FILE="$STATE_DIR/cron-timeout-baseline.json"
HEALTH_STATE="$STATE_DIR/cron-health-state.json"
REAP_LOG="$STATE_DIR/cron-reap-log.json"
NOW=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

MODE="csv"
case "${1:-csv}" in
  --json) MODE="json" ;;
  --summary) MODE="summary" ;;
esac

# ── Generate baseline if missing/stale ──────────────────────────────────────
if [[ ! -f "$BASELINE_FILE" ]]; then
  echo "WARN: baseline missing, generating..." >&2
  "$WORKSPACE/scripts/cron-timeout-scaler.sh" > /dev/null 2>&1
fi

# ── Compute report via Python ───────────────────────────────────────────────
python3 << PYEOF
import json, sys, os, math
from datetime import datetime, timezone, timedelta

baseline_file = '$BASELINE_FILE'
health_file = '$HEALTH_STATE'
reap_log_file = '$REAP_LOG'
mode = '$MODE'
now = datetime.now(timezone.utc)
cutoff_7d = now - timedelta(days=7)

# Load baseline
try:
    with open(baseline_file) as f:
        baseline = json.load(f)
except:
    print("ERROR: baseline file unreadable", file=sys.stderr)
    sys.exit(1)

crons = baseline.get('crons', [])

# Load health state for incident data
health_failures = {}
try:
    with open(health_file) as f:
        hs = json.load(f)
    for f_item in hs.get('failures', []):
        cid = f_item.get('cronId', '')
        if cid:
            health_failures[cid] = health_failures.get(cid, 0) + 1
except:
    pass

# Load reap log for reaping incidents
reap_incidents = {}
try:
    with open(reap_log_file) as f:
        rl = json.load(f)
    for entry in rl.get('entries', []):
        cid = entry.get('cronId', '')
        reap_incidents[cid] = reap_incidents.get(cid, 0) + 1
except:
    pass

# ── Build report rows ─────────────────────────────────────────────────────
rows = []
for r in crons:
    cid = r['cronId']
    name = r['name']
    task_class = r['taskClass']
    computed = r['computedTimeoutSec']
    current = r['currentTimeoutSec']
    recommended = computed if not current or r['recommendation'] in ('SET', 'INCREASE') else current
    avg_dur = r.get('avgDurationMs', 0)
    data_pts = r.get('dataPoints', 0)
    rec = r.get('recommendation', '')
    deviation = r.get('deviationPct', '')
    last_status = r.get('lastStatus', 'unknown')
    consecutive_errs = r.get('consecutiveErrors', 0)
    is_victim = r.get('isTimeoutVictim', False)

    # Timeout incidents in last 7d = health failures + reap incidents
    incidents_7d = health_failures.get(cid, 0) + reap_incidents.get(cid, 0)

    rows.append({
        'cronId': cid,
        'name': name,
        'taskClass': task_class,
        'computedTimeoutS': computed,
        'currentTimeoutS': current,
        'recommendedTimeoutS': recommended,
        'last5AvgMs': avg_dur,  # TKT-0339 note: single data point until sliding window fully implemented
        'dataPoints': data_pts,
        'timeoutIncidents7d': incidents_7d,
        'recommendation': rec,
        'deviationPct': deviation,
        'lastStatus': last_status,
        'consecutiveErrors': consecutive_errs,
        'isTimeoutVictim': is_victim,
        'reapIncidents': reap_incidents.get(cid, 0)
    })

# ── Output ────────────────────────────────────────────────────────────────
if mode == 'csv':
    print('cron_id,name,class,computed_timeout_s,current_timeout_s,recommended_timeout_s,last_5_avg_ms,data_points,timeout_incidents_7d,recommendation,deviation_pct,last_status,consecutive_errors,is_timeout_victim,reap_incidents')
    for r in rows:
        print('{},{},{},{},{},{},{},{},{},{},{},{},{},{},{}'.format(
            r['cronId'],
            '"' + r['name'].replace('"', '""') + '"',
            r['taskClass'],
            r['computedTimeoutS'],
            r['currentTimeoutS'] if r['currentTimeoutS'] else '',
            r['recommendedTimeoutS'],
            r['last5AvgMs'],
            r['dataPoints'],
            r['timeoutIncidents7d'],
            r['recommendation'],
            r['deviationPct'] if r['deviationPct'] else '',
            r['lastStatus'],
            r['consecutiveErrors'],
            'YES' if r['isTimeoutVictim'] else 'NO',
            r['reapIncidents']
        ))

elif mode == 'json':
    report = {
        'generatedAt': '$NOW',
        'schema': 'TKT-0339-AC4',
        'totalCrons': len(rows),
        'rows': rows
    }
    print(json.dumps(report, indent=2))

elif mode == 'summary':
    by_class = {}
    for r in rows:
        cls = r['taskClass']
        if cls not in by_class:
            by_class[cls] = {'count': 0, 'needsSet': 0, 'needsIncrease': 0, 'needsDecrease': 0, 'victims': 0, 'incidents': 0}
        by_class[cls]['count'] += 1
        if r['recommendation'] == 'SET':
            by_class[cls]['needsSet'] += 1
        elif r['recommendation'] == 'INCREASE':
            by_class[cls]['needsIncrease'] += 1
        elif r['recommendation'] == 'DECREASE':
            by_class[cls]['needsDecrease'] += 1
        if r['isTimeoutVictim']:
            by_class[cls]['victims'] += 1
        by_class[cls]['incidents'] += r['timeoutIncidents7d']

    total_set = sum(c['needsSet'] for c in by_class.values())
    total_inc = sum(c['needsIncrease'] for c in by_class.values())
    total_victims = sum(c['victims'] for c in by_class.values())
    total_incidents = sum(c['incidents'] for c in by_class.values())

    print("=== Cron Timeout Report Summary ===")
    print("Generated: $NOW")
    print("Total crons: {} | Needs timeout SET: {} | Needs INCREASE: {} | Victims: {} | Incidents 7d: {}".format(
        len(rows), total_set, total_inc, total_victims, total_incidents))
    print()
    print("{:20s} {:>6s} {:>6s} {:>8s} {:>8s} {:>10s}".format("Class", "Count", "SET", "INCREASE", "Victims", "Incidents"))
    print("-" * 62)
    for cls in ['shell', 'light-agent', 'heavy-agent', 'blog-standup']:
        if cls in by_class:
            c = by_class[cls]
            print("{:20s} {:>6d} {:>6d} {:>8d} {:>8d} {:>10d}".format(
                cls, c['count'], c['needsSet'], c['needsIncrease'], c['victims'], c['incidents']))
    print()
    print("Top 10 highest computed timeouts (flag for review):")
    top = sorted(rows, key=lambda x: x['computedTimeoutS'], reverse=True)[:10]
    print("{:10s} {:40s} {:15s} {:>8s} {:>8s} {}".format("ID", "Name", "Class", "Computed", "Current", "Rec"))
    print("-" * 95)
    for r in top:
        cur = str(r['currentTimeoutS']) if r['currentTimeoutS'] else 'NONE'
        print("{:10s} {:40s} {:15s} {:>8d}s {:>8s} {}".format(r['cronId'], r['name'][:40], r['taskClass'], r['computedTimeoutS'], cur, r['recommendation']))
PYEOF
