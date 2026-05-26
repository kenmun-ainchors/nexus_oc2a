#!/usr/bin/env python3
# latency-tracker.sh — AInchors Model Latency Tracker (TKT-0031)
# Reads cron run JSONL history, writes latency samples to obs.db latency_log.
# Generates state/latency-summary.json for dashboard + model switching decisions.
#
# Usage: python3 scripts/latency-tracker.sh

import json, sqlite3, os, sys, time, glob
from datetime import datetime, timezone
from collections import defaultdict

WORKSPACE   = os.environ.get('WORKSPACE', os.path.expanduser('~/.openclaw/workspace'))
CRON_RUNS   = os.path.expanduser('~/.openclaw/cron/runs')
OBS_DB      = os.path.join(WORKSPACE, 'state', 'obs.db')
STATE_FILE  = os.path.join(WORKSPACE, 'state', 'latency-tracker-state.json')
SUMMARY     = os.path.join(WORKSPACE, 'state', 'latency-summary.json')

# ── Load state ────────────────────────────────────────────────────────────────
try:
    state = json.load(open(STATE_FILE))
except Exception:
    state = {'lastTracked': {}}

last_tracked = state.get('lastTracked', {})  # {jobId: lastTs (epoch seconds)}
now_epoch    = int(time.time())
new_samples  = 0

# ── Load cron job metadata for names/labels ───────────────────────────────────
def classify_task(job_name):
    n = job_name.lower()
    if 'warden'   in n: return 'governance-check'
    if 'standup'  in n: return 'standup'
    if 'journal'  in n: return 'journal'
    if 'blog'     in n: return 'blog'
    if 'backup'   in n: return 'backup'
    if 'cost'     in n: return 'cost-tracking'
    if 'burn'     in n: return 'burn-check'
    if 'relay'    in n: return 'relay'
    if 'fallback' in n or 'chain' in n: return 'fallback-check'
    if 'heal'     in n: return 'auto-heal'
    if 'asset'    in n: return 'asset-review'
    if 'akb'      in n or 'obsidian' in n: return 'akb-sync'
    if 'sla'      in n: return 'sla-report'
    if 'shield'   in n: return 'security-review'
    if 'lex'      in n: return 'legal-review'
    if 'sage'     in n: return 'qa-review'
    if 'stand'    in n: return 'standup'
    if 'mission'  in n: return 'dashboard'
    if 'health'   in n: return 'health-check'
    if 'close'    in n: return 'daily-close'
    if 'aria'     in n: return 'aria-task'
    return 'other'

def normalise_model(raw):
    if not raw: return 'claude-sonnet-4-6'
    r = raw.lower()
    if 'haiku'      in r: return 'claude-haiku-4-5'
    if 'sonnet'     in r: return 'claude-sonnet-4-6'
    if 'opus'       in r: return 'claude-opus-4-7'
    if 'gemma4:e2b' in r: return 'gemma4:e2b'
    if 'gemma4'     in r: return 'gemma4:26b'
    if 'qwen'       in r: return 'qwen3.5:cloud'
    if 'kimi'       in r: return 'kimi-k2.6:cloud'
    return raw.split('/')[-1]

con = sqlite3.connect(OBS_DB)

# ── Process each cron job's JSONL run file ────────────────────────────────────
for jsonl_path in glob.glob(os.path.join(CRON_RUNS, '*.jsonl')):
    job_id = os.path.basename(jsonl_path).replace('.jsonl', '')
    last_ts = last_tracked.get(job_id, 0)
    max_ts  = last_ts

    try:
        lines = open(jsonl_path).readlines()
    except Exception:
        continue

    for line in lines:
        try:
            run = json.loads(line.strip())
        except Exception:
            continue

        if run.get('action') != 'finished':
            continue

        run_ts_ms = run.get('ts', 0)
        run_ts    = run_ts_ms / 1000.0
        if run_ts <= last_ts:
            continue

        duration_ms = run.get('durationMs', 0)
        if not duration_ms:
            continue

        model_raw = run.get('model', '')
        model     = normalise_model(model_raw)
        status    = run.get('status', 'ok')

        # Derive job name from sessionKey if possible
        session_key = run.get('sessionKey', '')
        # e.g. agent:main:cron:{jobId}:run:{sessionId}
        job_name = job_id[:20]  # fallback

        usage   = run.get('usage') or {}
        in_tok  = usage.get('input_tokens', 0)
        out_tok = usage.get('output_tokens', 0)
        tot_tok = usage.get('total_tokens', in_tok + out_tok)

        ts_str = datetime.fromtimestamp(run_ts, tz=timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')

        con.execute(
            '''INSERT INTO latency_log
               (ts, ts_epoch, model, task_type, job_id, job_name, duration_ms,
                input_tokens, output_tokens, total_tokens, status)
               VALUES (?,?,?,?,?,?,?,?,?,?,?)''',
            (ts_str, int(run_ts), model, 'cron-job', job_id, job_name,
             duration_ms, in_tok, out_tok, tot_tok, status)
        )
        new_samples += 1
        max_ts = max(max_ts, run_ts)

    if max_ts > last_ts:
        last_tracked[job_id] = max_ts

con.commit()

# ── Generate latency-summary.json ─────────────────────────────────────────────
window = now_epoch - 7 * 86400

rows = con.execute('''
    SELECT model, COUNT(*) as n,
           AVG(duration_ms) as avg_ms,
           MIN(duration_ms) as min_ms,
           MAX(duration_ms) as max_ms,
           AVG(total_tokens) as avg_tokens
    FROM latency_log
    WHERE ts_epoch > ? AND status = 'ok'
    GROUP BY model
    ORDER BY avg_ms DESC
''', (window,)).fetchall()

all_rows = con.execute(
    'SELECT model, duration_ms FROM latency_log WHERE ts_epoch > ? AND status = "ok" ORDER BY model, duration_ms',
    (window,)
).fetchall()

overall = con.execute(
    'SELECT COUNT(*), AVG(duration_ms), MAX(duration_ms), MIN(duration_ms) FROM latency_log WHERE ts_epoch > ? AND status = "ok"',
    (window,)
).fetchone()

# P50 / P95 per model
model_durs = defaultdict(list)
for m, d in all_rows:
    model_durs[m].append(d)

def percentile(lst, p):
    if not lst: return 0
    idx = max(0, int(len(lst) * p / 100) - 1)
    return lst[idx]

summary = {
    'generatedAt': datetime.now(timezone.utc).isoformat(),
    'windowDays': 7,
    'note': 'Duration = end-to-end cron task time (includes LLM call + tool use). TTFT instrumentation pending gateway-level hooks.',
    'overall': {
        'sampleCount': overall[0] or 0,
        'avgMs':  round(overall[1] or 0),
        'peakMs': overall[2] or 0,
        'minMs':  overall[3] or 0,
    },
    'byModel': {}
}

for model, n, avg, mn, mx, avg_tok in rows:
    durs = model_durs.get(model, [])
    summary['byModel'][model] = {
        'sampleCount': n,
        'avgMs':    round(avg),
        'minMs':    mn,
        'maxMs':    mx,
        'p50Ms':    percentile(durs, 50),
        'p95Ms':    percentile(durs, 95),
        'avgTokens': round(avg_tok or 0),
    }

con.close()

json.dump(summary, open(SUMMARY, 'w'), indent=2)

# ── Persist state ─────────────────────────────────────────────────────────────
state['lastTracked'] = last_tracked
state['lastRun'] = datetime.now(timezone.utc).isoformat()
json.dump(state, open(STATE_FILE, 'w'), indent=2)

# Dual-write lastTracked timestamps to PG (TKT-0304)
import subprocess as _sp
_pge = os.environ.copy()
_pge.update({'PGHOST': '/tmp', 'PGPORT': '5432', 'PGUSER': 'ainchorsangiefpl', 'PGDATABASE': 'ainchors_nexus'})
for _jid, _ts in last_tracked.items():
    _dt = datetime.fromtimestamp(_ts, tz=timezone.utc)
    _sp.run(['/opt/homebrew/bin/psql', '-c',
        "INSERT INTO state_latency (cron_id, duration_ms, status, recorded_at, metadata) VALUES ("
        + "'" + _jid + "', 0, 'tracked', '" + _dt.isoformat() + "', "
        + "'{\"source\": \"latency-tracker.sh\", \"epoch\": " + str(_ts) + "}')"],
        env=_pge, capture_output=True)

print(f"LATENCY: {new_samples} new samples logged | summary → state/latency-summary.json")
