#!/usr/bin/env bash
# state-health-assert.sh — EOD Health Assert Gate (TKT-REC5)
# Runs 5 health checks before EOD finalizer proceeds.
# exit 0 = pass, exit 1 = fail (block file + Telegram alert written)
set -euo pipefail

WORKSPACE="${WORKSPACE_ROOT:-$HOME/.openclaw/workspace}"
source "${WORKSPACE}/scripts/lib/atomic-write.sh"
DATE=$(date +%Y-%m-%d)
ASSERT_FILE="${WORKSPACE}/state/eod-assert-${DATE}.json"
BLOCK_FILE="${WORKSPACE}/state/eod-blocked-${DATE}.json"
TMP_CHECK="${WORKSPACE}/state/.health-check-tmp.json"

log() { echo "[STATE-HEALTH] $*" >&2; }

# ─── CHECK 1: CRON_HEALTH ───
check_cron_health() {
  log "CHECK 1: CRON_HEALTH"
  local bad_json
  bad_json=$(openclaw cron list --json 2>/dev/null | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    bad = []
    for j in d.get('jobs', []):
        m = j.get('payload', {}).get('model', '')
        s = j.get('state', {})
        err = s.get('consecutiveErrors', 0)
        reason = s.get('lastErrorReason') or ''
        if m.startswith('ollama/') and err >= 3 and reason not in [None, '']:
            bad.append({'name': j.get('name','?'), 'errors': err, 'reason': reason})
    print(json.dumps(bad))
except Exception as e:
    print(json.dumps({'error': str(e)}))
" 2>&1)

  local count
  count=$(echo "$bad_json" | python3 -c "
import json,sys
d=json.load(sys.stdin)
print(len(d) if isinstance(d,list) else 1 if isinstance(d,dict) else 0
" 2>/dev/null || echo 0)

  if [ "$count" -gt 0 ]; then
    local summary
    summary=$(echo "$bad_json" | python3 -c "
import json,sys
d=json.load(sys.stdin)
if isinstance(d,dict):
    print(f'parse error: {d.get(\"error\",\"\")}')
else:
    parts=[f\"{c['name']}({c['errors']}errs: {c['reason']})\" for c in d]
    print(', '.join(parts))
" 2>/dev/null)
    echo "{\"name\":\"CRON_HEALTH\",\"status\":\"fail\",\"detail\":\"${summary}\"}"
    return 1
  fi
  echo "{\"name\":\"CRON_HEALTH\",\"status\":\"pass\",\"detail\":\"all ollama crons healthy\"}"
}

# ─── CHECK 2: COST_STATE_FRESH ───
check_cost_state_fresh() {
  log "CHECK 2: COST_STATE_FRESH"
  local cost_file="${WORKSPACE}/state/cost-state.json"
  if [ ! -f "$cost_file" ]; then
    echo "{\"name\":\"COST_STATE_FRESH\",\"status\":\"fail\",\"detail\":\"cost-state.json missing\"}"
    return 1
  fi
  local mtime now diff
  mtime=$(stat -f %m "$cost_file" 2>/dev/null) || mtime=0
  now=$(date +%s)
  diff=$((now - mtime))
  if [ "$diff" -gt 50400 ]; then
    echo "{\"name\":\"COST_STATE_FRESH\",\"status\":\"fail\",\"detail\":\"cost-state.json age=${diff}s > 50400s (14h)\"}"
    return 1
  fi
  echo "{\"name\":\"COST_STATE_FRESH\",\"status\":\"pass\",\"detail\":\"cost-state.json age=${diff}s <= 50400s\"}"
}

# ─── CHECK 3: WARDEN ───
check_warden() {
  log "CHECK 3: WARDEN"
  local warden_file="${WORKSPACE}/state/warden-violations.json"
  if [ ! -f "$warden_file" ]; then
    echo "{\"name\":\"WARDEN\",\"status\":\"pass\",\"detail\":\"no warden-violations.json file\"}"
    return 0
  fi
  local violations ack
  violations=$(python3 -c "import json; d=json.load(open('${warden_file}')); print(len(d.get('violations',[])))" 2>/dev/null || echo 0)
  ack=$(python3 -c "import json; d=json.load(open('${warden_file}')); print(d.get('lastAcknowledgedAt','none'))" 2>/dev/null || echo "none")
  if [ "$violations" -gt 0 ] && [ "$ack" = "none" ]; then
    echo "{\"name\":\"WARDEN\",\"status\":\"fail\",\"detail\":\"${violations} violations unacknowledged (lastAcknowledgedAt=${ack})\"}"
    return 1
  fi
  echo "{\"name\":\"WARDEN\",\"status\":\"pass\",\"detail\":\"violations=${violations}, ack=${ack}\"}"
}

# ─── CHECK 4: CRITICAL_CRONS_ALIVE ───
check_critical_crons_alive() {
  log "CHECK 4: CRITICAL_CRONS_ALIVE"
  local cids=("a89d00ef-6d96-4aaf-8759-504c4ac72a3c" "e269d620-bf99-4515-b1a8-93ef8c0579b1" "637ecb12-eae2-4c16-b174-8acdaa2729cc")
  local cnames=("Task-Queue" "Auto-Heal" "Task-Monitor")
  local failures=""
  local idx=0
  for id in "${cids[@]}"; do
    local cname="${cnames[$idx]}"
    local cj
    cj=$(openclaw cron get "$id" 2>/dev/null) || {
      failures="${failures}${cname}(get-failed) "
      idx=$((idx+1))
      continue
    }
    local lst_st lst_er
    lst_st=$(echo "$cj" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('state',{}).get('lastStatus','unknown'))" 2>/dev/null || echo "unknown")
    lst_er=$(echo "$cj" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('state',{}).get('consecutiveErrors',0))" 2>/dev/null || echo "99")
    if [ "$lst_st" != "ok" ] && [ "$lst_er" -ge 3 ]; then
      failures="${failures}${cname}(status=${lst_st},errs=${lst_er}) "
    fi
    idx=$((idx+1))
  done
  if [ -n "$failures" ]; then
    echo "{\"name\":\"CRITICAL_CRONS_ALIVE\",\"status\":\"fail\",\"detail\":\"${failures}\"}"
    return 1
  fi
  echo "{\"name\":\"CRITICAL_CRONS_ALIVE\",\"status\":\"pass\",\"detail\":\"all 3 critical crons healthy\"}"
}

# ─── CHECK 5: CHECK30_QUIET ───
check_check30_quiet() {
  log "CHECK 5: CHECK30_QUIET"
  local fire_file="${WORKSPACE}/state/check30-last-fire.json"
  if [ -f "$fire_file" ]; then
    local ts
    ts=$(python3 -c "import json; d=json.load(open('${fire_file}')); print(d['ts'])" 2>/dev/null || echo "")
    if [ -n "$ts" ]; then
      local fire_epoch now age
      fire_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%S" "$ts" "+%s" 2>/dev/null || echo 0)
      now=$(date +%s)
      age=$((now - fire_epoch))
      if [ "$age" -lt 21600 ] && [ "$age" -ge 0 ]; then
        log "CHECK30 fired recently: ${ts} (age=${age}s < 21600s)"
        echo "{\"name\":\"CHECK30_QUIET\",\"status\":\"fail\",\"detail\":\"check30-last-fire.json ts=${ts} (age=${age}s < 6h)\"}"
        return 1
      fi
    fi
  fi

  # Also check for any current rate_limit errors in cron list
  local rate_limited
  rate_limited=$(openclaw cron list --json 2>/dev/null | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    bad = [j.get('name','?') for j in d.get('jobs',[]) if j.get('state',{}).get('lastErrorReason','') == 'rate_limit']
    print(json.dumps(bad))
except:
    print('[]')
" 2>/dev/null) || rate_limited="[]"
  local rl_count
  rl_count=$(echo "$rate_limited" | python3 -c "import json,sys; d=json.load(sys.stdin); print(len(d))" 2>/dev/null || echo 0)
  if [ "$rl_count" -gt 0 ]; then
    local rl_names
    rl_names=$(echo "$rate_limited" | python3 -c "import json,sys; print(', '.join(json.load(sys.stdin)))" 2>/dev/null || echo "unknown")
    echo "{\"name\":\"CHECK30_QUIET\",\"status\":\"fail\",\"detail\":\"${rl_count} crons currently rate-limited: ${rl_names}\"}"
    return 1
  fi
  echo "{\"name\":\"CHECK30_QUIET\",\"status\":\"pass\",\"detail\":\"no recent fire and no rate-limited crons\"}"
}

send_telegram_alert() {
  log "Sending Telegram alert for blocked EOD..."
  # TKT-1004 (CHG-0898) + CHG-0799: route to BOTH Ken + Angie.
  bash "${WORKSPACE}/scripts/telegram-alert.sh" --recipients "8574109706,8141152780" --message "TKT-REC5 EOD BLOCKED - ${DATE}
State-Health-Assert FAILED: ${FAILED_NAMES}
Block file: ${BLOCK_FILE}
EOD finalizer will skip journal, blog, and drive sync."
}

# ─── Main ───
log "Starting EOD health assert for ${DATE}..."

FAILED_NAMES=""
CHECKS_LIST="["
SEP=""
for check_fn in check_cron_health check_cost_state_fresh check_warden check_critical_crons_alive check_check30_quiet; do
  # Run check - capture JSON output, detect failure from exit code
  json_result=$(eval "$check_fn" 2>/dev/null)
  rc=$?
  CHECKS_LIST="${CHECKS_LIST}${SEP}${json_result}"
  SEP=","
  if [ "$rc" -ne 0 ]; then
    # Extract the check name from the JSON
    cname=$(echo "$json_result" | python3 -c "import json,sys; print(json.load(sys.stdin).get('name','?'))" 2>/dev/null || echo "?")
    [ -n "$FAILED_NAMES" ] && FAILED_NAMES="${FAILED_NAMES}, "
    FAILED_NAMES="${FAILED_NAMES}${cname}"
  fi
done
CHECKS_LIST="${CHECKS_LIST}]"

if [ -n "$FAILED_NAMES" ]; then
  # Build JSON array of failed check names
  FAILED_JSON=$(echo "$FAILED_NAMES" | python3 -c "import json,sys; items=[x.strip() for x in sys.stdin.read().split(',') if x.strip()]; print(json.dumps(items))" 2>/dev/null || echo "[]")
  atomic_write "$BLOCK_FILE" <<EOF
{"date":"${DATE}","checks":${CHECKS_LIST},"status":"fail","failedChecks":${FAILED_JSON}}
EOF
  log "Wrote block file: ${BLOCK_FILE}"
  send_telegram_alert
  echo "STATE-HEALTH-ASSERT: FAIL: ${FAILED_NAMES}"
  exit 1
fi

atomic_write "$ASSERT_FILE" <<EOF
{"date":"${DATE}","checks":${CHECKS_LIST},"status":"pass","failedChecks":[]}
EOF
log "Wrote assert file: ${ASSERT_FILE}"
echo "STATE-HEALTH-ASSERT: PASS"
exit 0
