#!/bin/zsh
# obs-collector.sh — AInchors Observability Collector
# Runs every 5 minutes via Haiku cron sub-agent.
# Checks state files, logs events to obs.db, outputs exactly one summary line.
# Usage: bash scripts/obs-collector.sh
set -euo pipefail

WORKSPACE="${WORKSPACE:-$HOME/.openclaw/workspace}"
SCRIPTS="$WORKSPACE/scripts"
STATE="$WORKSPACE/state"
OBS_DB="$STATE/obs.db"
COLLECTOR_STATE="$STATE/obs-collector-state.json"
OBS_LOG_CMD="$SCRIPTS/obs-log.sh"
TODAY=$(date '+%Y-%m-%d')
NOW_UTC=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
NOW_EPOCH=$(date +%s)

# ── Ensure DB exists ──────────────────────────────────────────────────────────
if [[ ! -f "$OBS_DB" ]]; then
  bash "$SCRIPTS/obs-init.sh" >/dev/null 2>&1
fi

NEW_EVENTS=0

_obs_log() {
  # Wrapper: increments NEW_EVENTS on success
  # TKT-0140: dedup check — skip if identical event already in obs.db (same ts_epoch+event_type+source)
  # Prevents re-logging on state reset
  local _msg="" _type="" _source="" _ts=""
  local _args=("$@")
  for ((i=0; i<${#_args[@]}; i++)); do
    case "${_args[$i]}" in
      --message) _msg="${_args[$((i+1))]}" ;;
      --type)    _type="${_args[$((i+1))]}" ;;
      --source)  _source="${_args[$((i+1))]}" ;;
    esac
  done
  if [[ -n "$_type" && -n "$_source" && -f "$OBS_DB" ]]; then
    local _exists
    _exists=$(sqlite3 "$OBS_DB" \
      "SELECT COUNT(*) FROM obs_log WHERE event_type='$_type' AND source='$_source' AND ts_epoch > $(( NOW_EPOCH - 300 )) AND message='${_msg//\'/\'\'}'" \
      2>/dev/null || echo 0)
    if [[ "$_exists" -gt 0 ]]; then
      return 0  # already logged in last 5 min, skip
    fi
  fi
  if bash "$OBS_LOG_CMD" "$@" >/dev/null 2>&1; then
    NEW_EVENTS=$((NEW_EVENTS + 1))
  fi
}

# ── Read lastRun epoch from state ─────────────────────────────────────────────
LAST_RUN=$(python3 -c "
import json, sys, time
try:
    d = json.load(open('$COLLECTOR_STATE'))
    epoch = int(d.get('lastRunEpoch', 0))
    # TKT-0140: cap lookback to 24h on state reset (epoch=0 or missing)
    # Prevents re-logging all historical entries after state wipe (INC-20260509-001 root cause)
    if epoch == 0:
        epoch = int(time.time()) - 86400
    print(epoch)
except Exception:
    # State file missing entirely — cap to 24h ago
    print(int(time.time()) - 86400)
" 2>/dev/null || echo $(($(date +%s) - 86400)))

# ── CHECK A: health-state.json ────────────────────────────────────────────────
HEALTH_FILE="$STATE/health-state.json"
if [[ -f "$HEALTH_FILE" ]]; then
  _HC_RESULT=$(python3 -c "
import json, sys
try:
    d = json.load(open('$HEALTH_FILE'))
    status   = d.get('status', 'unknown')
    failures = int(d.get('consecutiveFailures', 0))
    issues   = d.get('issues', [])
    if status != 'ok' or failures > 0:
        detail = json.dumps({'status': status, 'consecutiveFailures': failures, 'issues': issues[:5]})
        print('FAIL|' + status + '|' + detail)
    else:
        print('OK')
except Exception as e:
    print('OK')
" 2>/dev/null || echo "OK")

  if [[ "$_HC_RESULT" == FAIL* ]]; then
    _STATUS=$(echo "$_HC_RESULT" | cut -d'|' -f2)
    _DETAIL=$(echo "$_HC_RESULT" | cut -d'|' -f3-)
    _obs_log --source health-check --level ERROR --type health_failure \
      --message "Health check failure: status=${_STATUS}" --detail "$_DETAIL"
  fi
fi

# ── CHECK B: warden-escalation-pending.json ───────────────────────────────────
WARDEN_FILE="$STATE/warden-escalation-pending.json"
if [[ -f "$WARDEN_FILE" ]]; then
  _WD_RESULT=$(python3 -c "
import json
try:
    d = json.load(open('$WARDEN_FILE'))
    status = d.get('status', '')
    if status == 'pending-yoda-action':
        detail = json.dumps({'status': status, 'violation': str(d.get('violation',''))[:200], 'agent': d.get('agent','')})
        print('PENDING|' + detail)
    else:
        print('OK')
except Exception:
    print('OK')
" 2>/dev/null || echo "OK")

  if [[ "$_WD_RESULT" == PENDING* ]]; then
    _DETAIL=$(echo "$_WD_RESULT" | cut -d'|' -f2-)
    _obs_log --source warden --level ERROR --type warden_violation \
      --message "Warden escalation pending Yoda action" --detail "$_DETAIL"
  fi
fi

# ── CHECK C: auto-heal-YYYY-MM-DD.json (today) ────────────────────────────────
HEAL_FILE="$STATE/auto-heal-${TODAY}.json"
if [[ -f "$HEAL_FILE" ]]; then
  # Get auto_fixed and needs_ken items from today's run if newer than last collector run
  _HEAL_DATA=$(python3 -c "
import json, sys
from datetime import datetime, timezone
try:
    d = json.load(open('$HEAL_FILE'))
    run_at = d.get('runAt', '')
    try:
        dt = datetime.fromisoformat(run_at.replace('Z','+00:00'))
        run_epoch = int(dt.timestamp())
    except Exception:
        run_epoch = 0

    if run_epoch <= $LAST_RUN:
        print('SKIP')
        sys.exit(0)

    auto_fixed = d.get('auto_fixed', [])
    needs_ken  = d.get('needs_ken', [])

    # Output: one line per event, format TYPE|MESSAGE|DETAIL
    for fix in auto_fixed:
        detail = json.dumps({'item': fix, 'runAt': run_at})
        msg = ('Auto-heal fixed: ' + fix)[:120]
        print('FIX|' + msg + '|' + detail)
    for item in needs_ken:
        detail = json.dumps({'item': item[:200], 'runAt': run_at})
        msg = ('Needs Ken: ' + item)[:120]
        print('KEN|' + msg + '|' + detail)
except Exception as e:
    print('SKIP')
" 2>/dev/null || echo "SKIP")

  if [[ "$_HEAL_DATA" != "SKIP" && -n "$_HEAL_DATA" ]]; then
    while IFS= read -r _line; do
      [[ -z "$_line" || "$_line" == "SKIP" ]] && continue
      _KIND=$(echo "$_line" | cut -d'|' -f1)
      _MSG=$(echo  "$_line" | cut -d'|' -f2)
      _DET=$(echo  "$_line" | cut -d'|' -f3-)
      case "$_KIND" in
        FIX) _obs_log --source auto-heal --level INFO --type auto_heal_fix    --message "$_MSG" --detail "$_DET" ;;
        KEN) _obs_log --source auto-heal --level WARN --type auto_heal_needs_ken --message "$_MSG" --detail "$_DET" ;;
      esac
    done <<< "$_HEAL_DATA"
  fi
fi

# ── CHECK D: task-stall-alert.json ────────────────────────────────────────────
STALL_FILE="$STATE/task-stall-alert.json"
if [[ -f "$STALL_FILE" ]]; then
  _STALL_DETAIL=$(python3 -c "
import json
try:
    d = json.load(open('$STALL_FILE'))
    print(json.dumps({'task': d.get('task',''), 'stalledAt': d.get('stalledAt',''), 'raw': str(d)[:300]}))
except Exception:
    print('{}')
" 2>/dev/null || echo "{}")
  _obs_log --source task-monitor --level WARN --type task_stall \
    --message "Task stall alert detected" --detail "$_STALL_DETAIL"
fi

# ── CHECK E: stability/ — unhandled Node.js rejections ──────────────────
STABILITY_DIR="$HOME/.openclaw/logs/stability"
if [[ -d "$STABILITY_DIR" ]]; then
  _STAB_NEW=$(find "$STABILITY_DIR" -name '*.json' -newer "$COLLECTOR_STATE" 2>/dev/null | wc -l | tr -d ' ')
  if [[ "$_STAB_NEW" -gt 0 ]]; then
    _STAB_SAMPLE=$(find "$STABILITY_DIR" -name '*.json' -newer "$COLLECTOR_STATE" 2>/dev/null | head -1)
    _STAB_REASON=$(python3 -c "import json; d=json.load(open('$_STAB_SAMPLE')); print(d.get('reason','unknown'))" 2>/dev/null || echo "unknown")
    _obs_log --source gateway --level WARN --type unhandled_rejection \
      --message "Node.js unhandled rejection(s): ${_STAB_NEW} new stability file(s) — reason: ${_STAB_REASON}" \
      --detail "{\"count\":${_STAB_NEW},\"reason\":\"${_STAB_REASON}\"}"
  fi
fi

# ── CHECK F: pending-alert.json — undelivered platform alerts ───────────────
PENDING_ALERT="$STATE/pending-alert.json"
if [[ -f "$PENDING_ALERT" ]]; then
  _PA=$(python3 -c "
import json
d=json.load(open('$PENDING_ALERT'))
if not d.get('delivered', True):
    import json as j
    det=j.dumps({'type':d.get('type','?'),'balance':d.get('balance','?'),'triggeredAt':d.get('triggeredAt','?')})
    print('UNDELIVERED|' + d.get('message','Undelivered alert')[:150] + '|' + det)
else:
    print('OK')
" 2>/dev/null || echo 'OK')
  if [[ "$_PA" == UNDELIVERED* ]]; then
    _MSG=$(echo "$_PA" | cut -d'|' -f2)
    _DET=$(echo "$_PA" | cut -d'|' -f3-)
    _obs_log --source platform --level ERROR --type undelivered_alert \
      --message "Undelivered platform alert: $_MSG" --detail "$_DET"
  fi
fi

# ── CHECK G: standby-mode.json — platform in degraded/outage state ───────────
STANDBY="$STATE/standby-mode.json"
if [[ -f "$STANDBY" ]]; then
  _SB=$(python3 -c "
import json
d=json.load(open('$STANDBY'))
if d.get('active'):
    import json as j
    print('ACTIVE|Standby mode active: ' + d.get('reason','?') + ' since ' + d.get('since','?') + '|' + j.dumps({'since':d.get('since'),'fallback':d.get('fallback'),'reason':d.get('reason')}))
else:
    print('OK')
" 2>/dev/null || echo 'OK')
  if [[ "$_SB" == ACTIVE* ]]; then
    _MSG=$(echo "$_SB" | cut -d'|' -f2)
    _DET=$(echo "$_SB" | cut -d'|' -f3-)
    _obs_log --source platform --level ERROR --type standby_active \
      --message "$_MSG" --detail "$_DET"
  fi
fi

# ── CHECK H: system-banner.json — active platform banner ──────────────────
BANNER="$STATE/system-banner.json"
if [[ -f "$BANNER" ]]; then
  _BN=$(python3 -c "
import json
d=json.load(open('$BANNER'))
if d.get('active'):
    print('ACTIVE|System banner active: ' + d.get('message','?')[:100] + '|{}')
else:
    print('OK')
" 2>/dev/null || echo 'OK')
  if [[ "$_BN" == ACTIVE* ]]; then
    _MSG=$(echo "$_BN" | cut -d'|' -f2)
    _obs_log --source platform --level WARN --type system_banner_active \
      --message "$_MSG" --detail '{}'
  fi
fi

# ── CHECK I: shield-escalation-pending.json — security escalation ──────────
SHIELD_ESC="$STATE/shield-escalation-pending.json"
if [[ -f "$SHIELD_ESC" ]]; then
  _SE=$(python3 -c "
import json
d=json.load(open('$SHIELD_ESC'))
if d.get('status') in ('pending','pending-review'):
    import json as j
    det=j.dumps({'asset':d.get('asset','?'),'verdict':d.get('verdict','?'),'rule':d.get('rule','?')})
    print('PENDING|Shield escalation pending: ' + d.get('asset','unknown asset')[:80] + '|' + det)
else:
    print('OK')
" 2>/dev/null || echo 'OK')
  if [[ "$_SE" == PENDING* ]]; then
    _MSG=$(echo "$_SE" | cut -d'|' -f2)
    _DET=$(echo "$_SE" | cut -d'|' -f3-)
    _obs_log --source shield --level ERROR --type shield_escalation \
      --message "$_MSG" --detail "$_DET"
  fi
fi

# ── CHECK J: task-verification-alert.json — task completion failures ────────
TASK_VERIFY_ALERT="$STATE/task-verification-alert.json"
if [[ -f "$TASK_VERIFY_ALERT" ]]; then
  _TVA=$(python3 -c "
import json
d=json.load(open('$TASK_VERIFY_ALERT'))
alerts=[a for a in d.get('alerts',[]) if not a.get('resolved')]
if alerts:
    import json as j
    det=j.dumps({'count':len(alerts),'ids':[a.get('task_id','?') for a in alerts[:3]]})
    titles=', '.join(a.get('title','?') for a in alerts[:2])
    print(f'FAIL|Task verification failed ({len(alerts)} tasks): {titles[:100]}|'+det)
else:
    print('OK')
" 2>/dev/null || echo 'OK')
  if [[ "$_TVA" == FAIL* ]]; then
    _MSG=$(echo "$_TVA" | cut -d'|' -f2)
    _DET=$(echo "$_TVA" | cut -d'|' -f3-)
    _obs_log --source task-monitor --level ERROR --type task_verification_failed \
      --message "$_MSG" --detail "$_DET"
  fi
fi

# ── CHECK K: fallback-chain-status.json — chain broken ────────────────────
FB_STATUS="$STATE/fallback-chain-status.json"
if [[ -f "$FB_STATUS" ]]; then
  _FBS=$(python3 -c "
import json
d=json.load(open('$FB_STATUS'))
if d.get('overall') != 'ok':
    broken=d.get('brokenLinks',[])
    import json as j
    print('BROKEN|Fallback chain broken: ' + str(broken)[:80] + '|' + j.dumps({'overall':d.get('overall'),'broken':broken}))
else:
    print('OK')
" 2>/dev/null || echo 'OK')
  if [[ "$_FBS" == BROKEN* ]]; then
    _MSG=$(echo "$_FBS" | cut -d'|' -f2)
    _DET=$(echo "$_FBS" | cut -d'|' -f3-)
    _obs_log --source platform --level ERROR --type fallback_chain_broken \
      --message "$_MSG" --detail "$_DET"
  fi
fi

# ── CHECK L: cost-alert-state.json — Tier 3 emergency ──────────────────────
COST_ALERT="$STATE/cost-alert-state.json"
if [[ -f "$COST_ALERT" ]]; then
  _CA=$(python3 -c "
import json
d=json.load(open('$COST_ALERT'))
tier=int(d.get('activeTier',0))
bal=d.get('currentBalance',999)
if tier >= 3 or d.get('tier3',{}).get('active'):
    det=json.dumps({'tier':tier,'balance':bal})
    print('T3|API credit CRITICAL (Tier 3 active) - balance: USD '+str(bal)+'|'+det)
elif tier == 2:
    det=json.dumps({'tier':tier,'balance':bal})
    print('T2|API credit LOW (Tier 2 active) - balance: USD '+str(bal)+'|'+det)
else:
    print('OK')
" 2>/dev/null || echo 'OK')
  if [[ "$_CA" == T3* ]]; then
    _MSG=$(echo "$_CA" | cut -d'|' -f2)
    _DET=$(echo "$_CA" | cut -d'|' -f3-)
    _obs_log --source platform --level ERROR --type credit_critical \
      --message "$_MSG" --detail "$_DET"
  elif [[ "$_CA" == T2* ]]; then
    _MSG=$(echo "$_CA" | cut -d'|' -f2)
    _DET=$(echo "$_CA" | cut -d'|' -f3-)
    _obs_log --source platform --level WARN --type credit_low \
      --message "$_MSG" --detail "$_DET"
  fi
fi

# ── CHECK M: backup.log — backup failures ───────────────────────────────────
BACKUP_LOG="$HOME/Backups/ainchors/logs/backup.log"
if [[ -f "$BACKUP_LOG" ]]; then
  _BK_RESULT=$(python3 -c "
import re, sys
from datetime import datetime, timezone
last_run = $LAST_RUN
TS = re.compile(r'\\[(\\d{4}-\\d{2}-\\d{2} \\d{2}:\\d{2}:\\d{2})\\]')
current_epoch = 0
for line in open('$BACKUP_LOG'):
    m = TS.search(line)
    if m:
        try: current_epoch = int(datetime.strptime(m.group(1),'%Y-%m-%d %H:%M:%S').replace(tzinfo=timezone.utc).timestamp())
        except: pass
    if current_epoch > last_run and re.search(r'error|fail', line, re.IGNORECASE):
        print('FAIL|' + line.strip()[:120])
        sys.exit(0)
print('OK')
" 2>/dev/null || echo 'OK')
  if [[ "$_BK_RESULT" == FAIL* ]]; then
    _BK_MSG=$(echo "$_BK_RESULT" | cut -d'|' -f2)
    _obs_log --source backup --level ERROR --type backup_failure \
      --message "Backup failure detected: $_BK_MSG" --detail '{}'
  fi
fi

# ── CHECK N: config-health.json — suspicious config signature ──────────────
CFG_HEALTH="$HOME/.openclaw/logs/config-health.json"
if [[ -f "$CFG_HEALTH" ]]; then
  _CFG=$(python3 -c "
import json
d=json.load(open('$CFG_HEALTH'))
for path,info in d.get('entries',{}).items():
    sig=info.get('lastObservedSuspiciousSignature')
    if sig:
        print('SUSPICIOUS|Config suspicious signature detected in: ' + path[:80] + '|{\"path\":\"'+path[:80]+'\",\"signature\":\"'+str(sig)[:80]+'\"}') 
        break
print('OK')
" 2>/dev/null || echo 'OK')
  # Only process first non-OK line
  _CFG_LINE=$(echo "$_CFG" | grep -v '^OK$' | head -1 || true)
  if [[ -n "$_CFG_LINE" ]]; then
    _MSG=$(echo "$_CFG_LINE" | cut -d'|' -f2)
    _DET=$(echo "$_CFG_LINE" | cut -d'|' -f3-)
    _obs_log --source gateway --level ERROR --type config_suspicious \
      --message "$_MSG" --detail "$_DET"
  fi
fi

# ── CHECK O: gateway.err.log — scan for new errors since last run ───────────
GATEWAY_ERR="$HOME/.openclaw/logs/gateway.err.log"
if [[ -f "$GATEWAY_ERR" ]]; then
  _GW_NEW=$(python3 - "$GATEWAY_ERR" "$OBS_LOG_CMD" "$LAST_RUN" "$COLLECTOR_STATE" << 'PYEOF'
import re, json, subprocess, sys, os, time
from datetime import datetime, timezone

err_log_path, obs_log, last_run_str, state_path = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
last_run = int(last_run_str)
new = 0

# Load cross-run stuck-session dedup state
STUCK_COOLDOWN = 600  # 10 min — only re-alert for same session after this
try:
    _state = json.load(open(state_path))
    stuck_sessions = _state.get('stuckSessions', {})  # {sessionId: lastLoggedEpoch}
except Exception:
    stuck_sessions = {}

SID_RE = re.compile(r'sessionId=(\S+)')

PATTERNS = [
    ('gateway_oom',       'ERROR', r'FATAL ERROR.*(heap|Allocation failed)',
     'Gateway OOM crash — Node.js heap limit hit'),
    ('gateway_restart',   'WARN',  r'main-session-restart-recovery.*interrupted',
     'Gateway restart — main session interrupted'),
    ('session_stuck',     'WARN',  r'\[diagnostic\] stuck session',
     'Stuck agent session detected'),
    ('telegram_fail',     'ERROR', r'\[tools\] message failed.*Unknown target',
     'Telegram send failed — unknown target (wrong chatId format)'),
    ('soul_truncated',    'WARN',  r'bootstrap file SOUL\.md is \d+ chars.*truncating',
     'SOUL.md exceeds bootstrap limit and is being truncated'),
    ('incomplete_turn',   'WARN',  r'incomplete turn detected',
     'Agent incomplete turn — no output generated (silent-output bug)'),
    ('context_too_small', 'ERROR', r'Model context window too small',
     'Model context window too small — Gemma4 incompatible with agentTurn'),
    ('cron_fail',         'ERROR', r'\[tools\] cron failed',
     'Cron job creation failed — check schedule or payload'),
    ('lane_error',        'WARN',  r'\[diagnostic\] lane task error',
     'Lane task error detected'),
    ('notion_api_fail',   'ERROR', r'notion.*error|notion.*failed|notion.*4\d\d|notion.*5\d\d',
     'Notion API failure detected'),
    ('google_api_fail',   'ERROR', r'google.*error|gog.*failed|gmail.*error|calendar.*error|drive.*error|oauth.*error',
     'Google Workspace API failure detected'),
    ('anthropic_api_fail','ERROR', r'anthropic.*529|anthropic.*overload|anthropic.*5\d\d|API.*unavailable',
     'Anthropic API failure or overload detected'),
    ('tool_fail',         'WARN',  r'\[tools\].*failed|\[tools\].*error',
     'Tool execution failure detected'),
]

# Regex captures datetime + optional fractional seconds + optional timezone offset
TS_RE = re.compile(r'^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})(?:\.\d+)?([+-]\d{2}:\d{2}|Z)?')

def line_epoch(line):
    m = TS_RE.match(line)
    if not m: return 0
    try:
        from datetime import timedelta
        dt_s, tz_s = m.group(1), m.group(2)
        dt = datetime.fromisoformat(dt_s)  # naive datetime
        if tz_s and tz_s != 'Z':
            sign = 1 if tz_s[0] == '+' else -1
            hh, mm = int(tz_s[1:3]), int(tz_s[4:6])
            tz = timezone(timedelta(hours=sign*hh, minutes=sign*mm))
            dt = dt.replace(tzinfo=tz)
        else:
            dt = dt.replace(tzinfo=timezone.utc)
        return int(dt.astimezone(timezone.utc).timestamp())
    except Exception:
        return 0

try:
    lines = open(err_log_path).readlines()
except Exception:
    print(0); sys.exit(0)

for event_type, level, pattern, template in PATTERNS:
    seen = False
    for line in lines:
        epoch = line_epoch(line)
        if epoch <= last_run: continue
        if not re.search(pattern, line, re.IGNORECASE): continue

        # Cross-run dedup for session_stuck: only alert once per session per 10 min
        if event_type == 'session_stuck':
            sid_m = SID_RE.search(line)
            sid = sid_m.group(1) if sid_m else '__unknown__'
            last_alert = stuck_sessions.get(sid, 0)
            if epoch - last_alert < STUCK_COOLDOWN:
                continue  # suppress: same session alerted recently
            stuck_sessions[sid] = epoch

        if seen: continue  # dedupe: 1 event per type per run
        seen = True
        detail = json.dumps({'line': line.strip()[:300], 'epoch': epoch})
        rc = subprocess.run(
            ['bash', obs_log, '--source', 'gateway', '--level', level,
             '--type', event_type, '--message', template, '--detail', detail],
            capture_output=True
        ).returncode
        if rc == 0: new += 1

# Persist updated stuck-sessions state (prune entries older than 1h)
now_epoch = int(time.time())
stuck_sessions = {k: v for k, v in stuck_sessions.items() if now_epoch - v < 3600}
try:
    _state_out = json.load(open(state_path)) if os.path.exists(state_path) else {}
    _state_out['stuckSessions'] = stuck_sessions
    json.dump(_state_out, open(state_path, 'w'), indent=2)
except Exception:
    pass

print(new)
PYEOF
  )
  NEW_EVENTS=$((NEW_EVENTS + ${_GW_NEW:-0}))
fi

# ── CHECK P: Latency tracker — collect cron run durations per model ───────────
_LATENCY_OUT=$(python3 "$SCRIPTS/latency-tracker.sh" 2>/dev/null || echo "LATENCY: skipped")
# Latency tracker runs silently; only log if it errors
if echo "$_LATENCY_OUT" | grep -qi "error"; then
  _obs_log --source platform --level WARN --type tool_fail \
    --message "Latency tracker error" --detail "$(echo $_LATENCY_OUT | head -c200)"
fi

# ── CHECK E: Purge obs.db entries older than 7 days ──────────────────────────
python3 -c "
import sqlite3, time
cutoff  = int(time.time()) - (7 * 86400)
con     = sqlite3.connect('$OBS_DB')
deleted = con.execute('DELETE FROM obs_log WHERE ts_epoch < ?', (cutoff,)).rowcount
con.commit()
con.close()
" 2>/dev/null || true

# ── Update collector state (preserve stuckSessions across writes) ────────────
python3 -c "
import json, os
existing = {}
try:
    existing = json.load(open('$COLLECTOR_STATE'))
except Exception:
    pass
existing['lastRun'] = '$NOW_UTC'
existing['lastRunEpoch'] = $NOW_EPOCH
json.dump(existing, open('$COLLECTOR_STATE', 'w'), indent=2)
" 2>/dev/null || true

# ── CHECK Q: cron-health-state.json — cron run failures ─────────────────────────────
CRON_HEALTH_FILE="$STATE/cron-health-state.json"
if [[ -f "$CRON_HEALTH_FILE" ]]; then
  python3 - <<'PYEOF'
import json, subprocess, sys, os

state_dir  = os.environ.get('WORKSPACE', os.path.expanduser('~/.openclaw/workspace'))
state_file = os.path.join(state_dir, 'state', 'cron-health-state.json')
obs_log    = os.path.join(state_dir, 'scripts', 'obs-log.sh')
coll_state = os.path.join(state_dir, 'state', 'obs-collector-state.json')
try:
    d = json.load(open(state_file))
except Exception:
    sys.exit(0)

# TKT-0112: deduplicate — only log failures newer than last obs run
try:
    cs = json.load(open(coll_state))
    last_run = int(cs.get('lastRunEpoch', 0))
except Exception:
    last_run = 0

import datetime
failures = d.get('failures', [])
for f in failures:
    # Dedup: skip if failure was detected before last collector run
    detected = f.get('detectedAt', f.get('failedAt', f.get('ts', '')))
    if detected:
        try:
            dt = datetime.datetime.fromisoformat(str(detected).replace('Z', '+00:00'))
            if int(dt.timestamp()) <= last_run: continue
        except Exception:
            pass  # can't parse timestamp — log it to be safe
    cron_id  = f.get('cronId', 'unknown')[:8]
    name     = f.get('name', 'unknown cron')[:80]
    err      = f.get('error', '')[:200]
    detail   = json.dumps({'cronId': cron_id, 'name': name, 'error': err})
    msg      = f'Cron run failure: {name} ({cron_id}) — {err[:100]}'
    subprocess.run(
        ['bash', obs_log,
         '--source', 'cron-health',
         '--level', 'ERROR',
         '--type', 'cron_run_fail',
         '--message', msg,
         '--detail', detail],
        capture_output=True
    )
PYEOF
fi


# ── CHECK R: incident-log.json — open (unresolved) incidents ─────────────────
INCIDENT_LOG="$STATE/incident-log.json"
if [[ -f "$INCIDENT_LOG" ]]; then
  python3 - <<'PYEOF2'
import json, subprocess, os

state = os.environ.get('WORKSPACE', os.path.expanduser('~/.openclaw/workspace'))
obs_log = os.path.join(state, 'scripts', 'obs-log.sh')
f = os.path.join(state, 'state', 'incident-log.json')
try:
    d = json.load(open(f))
    incs = d if isinstance(d, list) else d.get('incidents', [])
    open_incs = [i for i in incs if isinstance(i, dict)
                 and i.get('status', '') not in ('resolved', 'closed')
                 and not i.get('resolvedAt')]
    for i in open_incs:
        msg = f"Open incident: {i.get('id','?')} [{i.get('severity','?')}] — {i.get('title','?')[:100]}"
        subprocess.run(['bash', obs_log, '--source', 'incident-log',
                        '--level', 'WARN', '--type', 'open_incident',
                        '--message', msg,
                        '--detail', json.dumps({'id': i.get('id'), 'severity': i.get('severity'), 'detectedAt': i.get('detectedAt', '')})],
                       capture_output=True)
except Exception:
    pass
PYEOF2
fi

# ── CHECK S: model-drift-violations.json — unescalated active violations ──────
MDV_FILE="$STATE/model-drift-violations.json"
if [[ -f "$MDV_FILE" ]]; then
  python3 - <<'PYEOF2'
import json, subprocess, os

state = os.environ.get('WORKSPACE', os.path.expanduser('~/.openclaw/workspace'))
obs_log = os.path.join(state, 'scripts', 'obs-log.sh')
f = os.path.join(state, 'state', 'model-drift-violations.json')
try:
    d = json.load(open(f))
    viols = d if isinstance(d, list) else d.get('violations', [])
    # Suppression rules (TKT-0144, CHG-0273, 2026-05-11):
    # 1. NOT_SET actual = agent uses default model routing, not a true drift violation -> INFO only
    # 2. Skip violations already logged in obs.db in the last 60 minutes (dedup)
    import subprocess as sp
    try:
        import sqlite3
        db_path = os.path.join(state, 'state', 'obs.db')
        conn = sqlite3.connect(db_path)
        _rows = conn.execute(
            "SELECT json_extract(details,'$.id') FROM obs_log WHERE event_type='warden_violation_unescalated' AND ts_epoch > strftime('%s','now','-60 minutes')"
        ).fetchall() if os.path.exists(db_path) else []
        recent_ids = set(row[0] for row in _rows)
        conn.close()
    except Exception:
        recent_ids = set()

    # CHG-0279: Auto-resolve stale violations when Warden is consecutively clean
    # If consecutiveClean > 0, all unresolved violations are from a prior era — mark superseded
    drift_state_path = os.path.join(state, 'state', 'model-drift-state.json')
    consecutive_clean = 0
    try:
        ds = json.load(open(drift_state_path))
        consecutive_clean = ds.get('consecutiveClean', 0)
    except Exception:
        pass

    if consecutive_clean > 0:
        # Auto-supersede any unresolved violations — Warden has already cleared them
        changed = False
        for v in viols:
            if isinstance(v, dict) and v.get('status') not in ('resolved', 'superseded', 'cleared'):
                v['status'] = 'superseded'
                v['supersededReason'] = f'Auto-superseded: Warden consecutiveClean={consecutive_clean} (CHG-0279)'
                changed = True
        if changed:
            d['violations'] = viols
            d['totalUnresolved'] = 0
            with open(f, 'w') as fw:
                json.dump(d, fw, indent=2)
        # No obs log needed — Warden is clean
    else:
        active = [v for v in viols if isinstance(v, dict)
                  and not v.get('escalatedToYoda', True)
                  and v.get('status', '') not in ('superseded', 'resolved', 'cleared')
                  and v.get('id') not in recent_ids]  # dedup: skip if logged < 60 min ago

        # CHG-0279: Aggregate into ONE summary event instead of one ERROR per agent
        gap_agents = [v.get('agentId','?') for v in active if v.get('actual','') == 'NOT_SET']
        viol_agents = [v.get('agentId','?') for v in active if v.get('actual','') != 'NOT_SET']

        if gap_agents:
            subprocess.run(['bash', obs_log, '--source', 'warden',
                            '--level', 'INFO', '--type', 'warden_gap_noted',
                            '--message', f"Warden gap ({len(gap_agents)} agents use default routing): {', '.join(gap_agents)}",
                            '--detail', json.dumps({'agents': gap_agents, 'note': 'NOT_SET=default routing, not drift'})],
                           capture_output=True)
        if viol_agents:
            # Single summary ERROR — not one per agent (CHG-0279)
            msg = f"Warden: {len(viol_agents)} unescalated violation(s) — {', '.join(viol_agents)}"
            subprocess.run(['bash', obs_log, '--source', 'warden',
                            '--level', 'ERROR', '--type', 'warden_violation_unescalated',
                            '--message', msg,
                            '--detail', json.dumps({'agents': viol_agents, 'count': len(viol_agents)})],
                           capture_output=True)
except Exception:
    pass
PYEOF2
fi

# ── CHECK T: budget-alert-state.json — unacknowledged budget exceeded ─────────
BUDGET_ALERT="$STATE/budget-alert-state.json"
if [[ -f "$BUDGET_ALERT" ]]; then
  python3 - <<'PYEOF2'
import json, subprocess, os

state = os.environ.get('WORKSPACE', os.path.expanduser('~/.openclaw/workspace'))
obs_log = os.path.join(state, 'scripts', 'obs-log.sh')
f = os.path.join(state, 'state', 'budget-alert-state.json')
try:
    d = json.load(open(f))
    alerts = d if isinstance(d, list) else d.get('alerts', [])
    unack = [a for a in alerts if isinstance(a, dict) and not a.get('acknowledged', True)]
    for a in unack:
        agent = a.get('agent', a.get('agentId', '?'))
        spent = a.get('spent', a.get('amount', '?'))
        cap = a.get('cap', a.get('budget', '?'))
        msg = f"Budget exceeded (unacknowledged): agent={agent} spent={spent} cap={cap}"
        subprocess.run(['bash', obs_log, '--source', 'budget',
                        '--level', 'ERROR', '--type', 'budget_exceeded',
                        '--message', msg,
                        '--detail', json.dumps(a)],
                       capture_output=True)
except Exception:
    pass
PYEOF2
fi

# ── CHECK U: delegation-log.json — task delegation failures ───────────────────
DELEG_LOG="$STATE/delegation-log.json"
if [[ -f "$DELEG_LOG" ]]; then
  python3 - <<'PYEOF2'
import json, subprocess, os, time

state = os.environ.get('WORKSPACE', os.path.expanduser('~/.openclaw/workspace'))
obs_log = os.path.join(state, 'scripts', 'obs-log.sh')
collector_state = os.path.join(state, 'state', 'obs-collector-state.json')
f = os.path.join(state, 'state', 'delegation-log.json')
try:
    cs = json.load(open(collector_state))
    last_run = int(cs.get('lastRunEpoch', 0))
except Exception:
    last_run = 0
try:
    d = json.load(open(f))
    entries = d if isinstance(d, list) else d.get('entries', [])
    for e in entries:
        if not isinstance(e, dict): continue
        if e.get('status') != 'fail': continue
        # TKT-0112: skip phantom entries — latency records with no real task data
        task_val  = str(e.get('task',   e.get('taskId', '')) or '').strip()
        agent_val = str(e.get('agent',  '') or '').strip()
        error_val = str(e.get('error',  '') or '').strip()
        if not task_val and not agent_val and not error_val: continue  # phantom — skip
        # Only new since last obs run
        import datetime
        ts_str = e.get('timestamp', e.get('at', e.get('ts', '')))
        try:
            from datetime import timezone
            dt = datetime.datetime.fromisoformat(ts_str.replace('Z', '+00:00'))
            if int(dt.timestamp()) <= last_run: continue
        except Exception:
            continue  # skip if timestamp unparseable — avoids re-logging every run
        msg = f"Delegation failure: task={task_val[:60]} agent={agent_val}"
        subprocess.run(['bash', obs_log, '--source', 'delegation',
                        '--level', 'ERROR', '--type', 'delegation_fail',
                        '--message', msg,
                        '--detail', json.dumps({'task': e.get('task', e.get('taskId', '')), 'agent': e.get('agent', ''), 'error': str(e.get('error', ''))[:200]})],
                       capture_output=True)
except Exception:
    pass
PYEOF2
fi

# ── CHECK V: pvt-last-result.json — PVT failure ────────────────────────────────
PVT_FILE="$STATE/pvt-last-result.json"
if [[ -f "$PVT_FILE" ]]; then
  python3 - <<'PYEOF2'
import json, subprocess, os

state = os.environ.get('WORKSPACE', os.path.expanduser('~/.openclaw/workspace'))
obs_log = os.path.join(state, 'scripts', 'obs-log.sh')
f = os.path.join(state, 'state', 'pvt-last-result.json')
try:
    d = json.load(open(f))
    passed = int(d.get('passed', d.get('score', 9)))
    total  = int(d.get('total', 9))
    if passed < total:
        msg = f"PVT failed: {passed}/{total} checks passed"
        failed = d.get('failed', d.get('failures', []))
        subprocess.run(['bash', obs_log, '--source', 'pvt',
                        '--level', 'ERROR', '--type', 'pvt_fail',
                        '--message', msg,
                        '--detail', json.dumps({'passed': passed, 'total': total, 'failed': failed})],
                       capture_output=True)
except Exception:
    pass
PYEOF2
fi

# ── CHECK W: relay-to-ken.json — messages stuck unsent >30 min ───────────────
RELAY_FILE="$STATE/relay-to-ken.json"
if [[ -f "$RELAY_FILE" ]]; then
  python3 - <<'PYEOF2'
import json, subprocess, os, datetime

state = os.environ.get('WORKSPACE', os.path.expanduser('~/.openclaw/workspace'))
obs_log = os.path.join(state, 'scripts', 'obs-log.sh')
f = os.path.join(state, 'state', 'relay-to-ken.json')
STALE_SECS = 1800  # 30 min
now = datetime.datetime.now(datetime.timezone.utc)
try:
    d = json.load(open(f))
    msgs = d if isinstance(d, list) else d.get('messages', [])
    for m in msgs:
        if not isinstance(m, dict): continue
        if m.get('sent', True): continue
        created = m.get('createdAt', m.get('timestamp', ''))
        try:
            dt = datetime.datetime.fromisoformat(created.replace('Z', '+00:00'))
            age = (now - dt).total_seconds()
            if age > STALE_SECS:
                msg = f"Relay message stuck unsent: id={m.get('id','?')} age={int(age/60)}min"
                subprocess.run(['bash', obs_log, '--source', 'relay',
                                '--level', 'WARN', '--type', 'relay_stuck',
                                '--message', msg,
                                '--detail', json.dumps({'id': m.get('id', ''), 'createdAt': created, 'ageMinutes': int(age/60)})],
                               capture_output=True)
        except Exception:
            pass
except Exception:
    pass
PYEOF2
fi

# ── CHECK X: overnight-task-status.json — overnight task failures ─────────────
OVERNIGHT_FILE="$STATE/overnight-task-status.json"
if [[ -f "$OVERNIGHT_FILE" ]]; then
  python3 - <<'PYEOF2'
import json, subprocess, os

state = os.environ.get('WORKSPACE', os.path.expanduser('~/.openclaw/workspace'))
obs_log = os.path.join(state, 'scripts', 'obs-log.sh')
f = os.path.join(state, 'state', 'overnight-task-status.json')
try:
    d = json.load(open(f))
    tasks = d if isinstance(d, list) else d.get('tasks', [])
    for t in tasks:
        if not isinstance(t, dict): continue
        if t.get('status') in ('failed', 'error', 'stalled'):
            msg = f"Overnight task {t.get('status','failed')}: {t.get('name', t.get('id','?'))[:80]}"
            subprocess.run(['bash', obs_log, '--source', 'overnight-task',
                            '--level', 'ERROR', '--type', 'overnight_task_fail',
                            '--message', msg,
                            '--detail', json.dumps({'id': t.get('id', ''), 'name': t.get('name', ''), 'error': str(t.get('error', ''))[:200]})],
                           capture_output=True)
except Exception:
    pass
PYEOF2
fi

# ── CHECK Y: governance triad QA logs — shield/lex/sage failures ──────────────
for QA_AGENT in shield lex sage; do
  QA_FILE="$STATE/${QA_AGENT}-qa-log.json"
  if [[ -f "$QA_FILE" ]]; then
    python3 - "$QA_FILE" "$QA_AGENT" <<'PYEOF2'
import json, subprocess, os, sys

state = os.environ.get('WORKSPACE', os.path.expanduser('~/.openclaw/workspace'))
obs_log = os.path.join(state, 'scripts', 'obs-log.sh')
collector_state = os.path.join(state, 'state', 'obs-collector-state.json')
qa_file, agent = sys.argv[1], sys.argv[2]
try:
    cs = json.load(open(collector_state))
    last_run = int(cs.get('lastRunEpoch', 0))
except Exception:
    last_run = 0
try:
    d = json.load(open(qa_file))
    entries = d if isinstance(d, list) else d.get('entries', [])
    for e in entries[-20:]:
        if not isinstance(e, dict): continue
        if e.get('verdict', e.get('result', '')) != 'fail': continue
        import datetime
        ts_str = e.get('timestamp', e.get('at', ''))
        try:
            from datetime import timezone
            dt = datetime.datetime.fromisoformat(ts_str.replace('Z', '+00:00'))
            if int(dt.timestamp()) <= last_run: continue
        except Exception:
            pass
        msg = f"{agent.capitalize()} QA failure: {e.get('task', e.get('check', '?'))[:80]}"
        subprocess.run(['bash', obs_log, '--source', f'{agent}-qa',
                        '--level', 'ERROR', '--type', 'governance_qa_fail',
                        '--message', msg,
                        '--detail', json.dumps({'agent': agent, 'task': e.get('task', e.get('check', '')), 'reason': str(e.get('reason', e.get('error', '')))[:200]})],
                       capture_output=True)
except Exception:
    pass
PYEOF2
  fi
done

# ── CHECK Z: sanctum-sla-log.json — SLA breaches ─────────────────────────────
SANCTUM_FILE="$STATE/sanctum-sla-log.json"
if [[ -f "$SANCTUM_FILE" ]]; then
  python3 - <<'PYEOF2'
import json, subprocess, os

state = os.environ.get('WORKSPACE', os.path.expanduser('~/.openclaw/workspace'))
obs_log = os.path.join(state, 'scripts', 'obs-log.sh')
collector_state = os.path.join(state, 'state', 'obs-collector-state.json')
f = os.path.join(state, 'state', 'sanctum-sla-log.json')
try:
    cs = json.load(open(collector_state))
    last_run = int(cs.get('lastRunEpoch', 0))
except Exception:
    last_run = 0
try:
    d = json.load(open(f))
    breaches = d.get('breaches', [])
    for b in breaches:
        if not isinstance(b, dict): continue
        import datetime
        ts_str = b.get('detectedAt', b.get('timestamp', ''))
        try:
            from datetime import timezone
            dt = datetime.datetime.fromisoformat(ts_str.replace('Z', '+00:00'))
            if int(dt.timestamp()) <= last_run: continue
        except Exception:
            pass
        msg = f"Sanctum SLA breach: {b.get('sla','?')} — {b.get('agent','?')} exceeded {b.get('thresholdMs','?')}ms"
        subprocess.run(['bash', obs_log, '--source', 'sanctum',
                        '--level', 'WARN', '--type', 'sla_breach',
                        '--message', msg,
                        '--detail', json.dumps(b)],
                       capture_output=True)
except Exception:
    pass
PYEOF2
fi

# ── Final output (exactly one line) ──────────────────────────────────────────
echo "OBS: $NEW_EVENTS new events logged"
