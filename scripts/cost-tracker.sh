#!/bin/zsh
# AInchors Cost Tracker
# Calculates daily token costs from OpenClaw session logs.
# Run daily via cron or on demand.

SESSIONS_DIR="$HOME/.openclaw/agents/main/sessions"
STATE_FILE="$HOME/.openclaw/workspace/state/cost-state.json"
COST_LOG="$HOME/.openclaw/workspace/memory/shared/cost-history.md"
STATE_WRITER="$HOME/.openclaw/workspace/scripts/state-write.py"
DATE="${1:-$(date +%Y-%m-%d)}"

mkdir -p "$(dirname $STATE_FILE)" "$(dirname $COST_LOG)"

echo "Calculating costs for $DATE..."

# Extract and sum costs from session logs
python3 << PYEOF
import json, os, glob, sys, tempfile
from datetime import datetime

agents_dir = os.path.expanduser("~/.openclaw/agents")
date = "$DATE"
state_file = os.path.expanduser("$STATE_FILE")
cost_log = os.path.expanduser("$COST_LOG")

STREAM_MAP = {"main":"technical","business":"business","security":"governance","governance":"governance","legal":"governance","qa":"governance","architect":"technical","platform-arch":"technical","infra":"technical","biz-process":"business","change-mgt":"business","ahsoka":"consulting"}

# TKT-0175: Calculated cost fallback for ephemeral sessions
# Derived from sampling 20-30 sessions per model tier (2026-05-15)
# Average total tokens (input + output + cacheRead + cacheWrite) per turn
TURN_RATES = {
    "claude-sonnet-4-6": 18884,
    "claude-haiku-4-5": 10409,
    "kimi-k2.6:cloud": 54000,
    "deepseek-v4-pro:cloud": 33847,
    "gemma4:31b-cloud": 14146,
    "gemma4:e2b": 11164,
    "claude-opus-4-7": 25000,
}

# Per-token rates ($/token) — Anthropic API + Ollama Cloud fair-value
# Ollama Cloud: subscription-aligned rates derived from market comparables,
# scaled to $100 USD/month at current usage. See cost-state.json for methodology.
# Approved by Ken 2026-05-28. CHG-0443.
MODEL_RATES = {
    # Anthropic API — actual per-token costs
    "claude-sonnet-4-6": 0.000003,   # blended input/output/cache rate
    "claude-haiku-4-5": 0.0000008,
    "claude-opus-4-7": 0.000015,
    # Ollama Cloud — subscription-aligned fair-value (per 1M tokens: see cost-state.json)
    # Rates are per single token here (cost-state.json stores per 1M for readability)
    "deepseek-v4-pro:cloud": 0.0000000425,
    "kimi-k2.6:cloud": 0.0000000309,
    "gemma4:31b-cloud": 0.0000000155,
    "deepseek-v4-flash:cloud": 0.0000000108,
    "gemma4:26b": 0.0000000093,
    "gemma4:e2b": 0.0000000046,
    # Non-billable
    "gateway-injected": 0.0,
    "delivery-mirror": 0.0,
}

by_model  = {}
by_stream = {"technical":{"cost":0.0,"turns":0},"business":{"cost":0.0,"turns":0},"governance":{"cost":0.0,"turns":0},"consulting":{"cost":0.0,"turns":0}}
total_cost = 0.0
total_input = 0
total_output = 0
total_cache_read = 0
total_cache_write = 0
total_turns = 0
total_calculated_cost = 0.0  # TKT-0175: track calculated vs actual
total_calculated_turns = 0

# Parse ALL agent session directories (technical + business + governance)
for agent_sessions in glob.glob(f"{agents_dir}/*/sessions"):
    agent_name = os.path.basename(os.path.dirname(agent_sessions))
    stream = STREAM_MAP.get(agent_name, "technical")
    for jsonl_file in glob.glob(f"{agent_sessions}/*.jsonl"):
        if ".trajectory." in jsonl_file:
            continue
        try:
            with open(jsonl_file, 'r') as f:
                for line in f:
                    line = line.strip()
                    if not line:
                        continue
                    try:
                        record = json.loads(line)
                    except:
                        continue

                    ts = record.get("timestamp", "")
                    if not ts.startswith(date):
                        continue
                    msg = record.get("message", {})
                    if record.get("type") != "message" or msg.get("role") != "assistant":
                        continue
                    usage = msg.get("usage")
                    if not usage:
                        continue

                    model = msg.get("model", "unknown")
                    cost = (usage.get("cost") or {}).get("total") or 0
                    inp = usage.get("input", 0) or 0
                    out = usage.get("output", 0) or 0
                    cr  = usage.get("cacheRead", 0) or 0
                    cw  = usage.get("cacheWrite", 0) or 0

                    # TKT-0175: Calculated fallback for missing cost data
                    # Ephemeral sessions (isolated crons, subagents, Forge runs)
                    # often lack usage.cost.total. Use: turns × avg_tokens_per_model × price_per_token
                    calculated = False
                    if cost == 0 and model in TURN_RATES:
                        turn_rate = TURN_RATES[model]
                        model_rate = MODEL_RATES.get(model, 0)
                        if model_rate > 0:
                            cost = turn_rate * model_rate
                            calculated = True
                            total_calculated_cost += cost
                            total_calculated_turns += 1

                    if model not in by_model:
                        by_model[model] = {"input":0,"output":0,"cacheRead":0,"cacheWrite":0,"cost":0.0,"turns":0,"calculatedCost":0.0,"calculatedTurns":0}
                    by_model[model]["input"]      += inp
                    by_model[model]["output"]     += out
                    by_model[model]["cacheRead"]  += cr
                    by_model[model]["cacheWrite"] += cw
                    by_model[model]["cost"]       += cost
                    by_model[model]["turns"]      += 1
                    if calculated:
                        by_model[model]["calculatedCost"] += cost
                        by_model[model]["calculatedTurns"] += 1
                    by_stream[stream]["cost"]     += cost
                    by_stream[stream]["turns"]    += 1
                    total_cost      += cost
                    total_input     += inp
                    total_output    += out
                    total_cache_read += cr
                    total_cache_write += cw
                    total_turns     += 1
        except Exception:
            pass

# Build day summary
day_summary = {
    "date": date,
    "totalCost": round(total_cost, 4),
    "totalTurns": total_turns,
    "totalInputTokens": total_input,
    "totalOutputTokens": total_output,
    "totalCacheReadTokens": total_cache_read,
    "totalCacheWriteTokens": total_cache_write,
    "source": "session-log-estimate",
    "note": "Session log estimate. usage.cost.total includes cacheWrite charges. CHG-0097: confirmed cost includes cache writes. CHG-0175: calculated fallback for ephemeral sessions.",
    "calculatedCost": round(total_calculated_cost, 4),
    "calculatedTurns": total_calculated_turns,
    "byModel": {m: {k: round(v, 4) if isinstance(v, float) else v for k,v in d.items()} for m, d in by_model.items()}
}

# Update state file
state = {}
if os.path.exists(state_file):
    try:
        with open(state_file) as f:
            state = json.load(f)
    except:
        pass

if "history" not in state:
    state["history"] = {}
# Only write day summary if there were actual turns (avoid polluting averages with empty days)
if total_turns > 0:
    state["history"][date] = day_summary
state["lastUpdated"] = datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")

# Running totals
all_costs = [d["totalCost"] for d in state["history"].values()]
state["allTimeTotalCost"] = round(sum(all_costs), 4)
state["daysTracked"] = len(all_costs)
state["avgDailyCost"] = round(sum(all_costs) / len(all_costs), 4) if all_costs else 0

with open(state_file, "w") as f:
    json.dump(state, f, indent=2)

# Append to cost-history.md if date not already there
existing = ""
if os.path.exists(cost_log):
    with open(cost_log) as f:
        existing = f.read()

if f"## {date}" not in existing:
    lines = [f"\n## {date}\n"]
    lines.append(f"| Metric | Value |")
    lines.append(f"|--------|-------|")
    lines.append(f"| Total Cost | \${total_cost:.4f} |")
    lines.append(f"| Turns | {total_turns} |")
    lines.append(f"| Input Tokens | {total_input:,} |")
    lines.append(f"| Output Tokens | {total_output:,} |")
    lines.append(f"| Cache Read | {total_cache_read:,} |")
    lines.append(f"| Calculated Cost (ephemeral) | \${total_calculated_cost:.4f} |")
    lines.append(f"| Calculated Turns | {total_calculated_turns} |")
    lines.append("")
    lines.append("### By Stream")
    for stream, d in sorted(by_stream.items(), key=lambda x: -x[1]["cost"]):
        if d["turns"] > 0:
            lines.append(f"- **{stream}**: {d['turns']} turns | \${d['cost']:.4f}")
    lines.append("")
    lines.append("### By Model")
    for model, d in sorted(by_model.items(), key=lambda x: -x[1]["cost"]):
        calc_note = ""
        if d.get("calculatedTurns", 0) > 0:
            calc_note = f" (calc: {d['calculatedTurns']} turns @ \${d['calculatedCost']:.4f})"
        lines.append(f"- **{model}**: {d['turns']} turns | {d['input']:,} in / {d['output']:,} out | \${d['cost']:.4f}{calc_note}")
    lines.append("")

    if not existing:
        header = "# AInchors Cost History\n_Token costs by day. Source: OpenClaw session logs._\n\nGemma4 (Ollama) = \$0.00 always (local). Cloud costs = Anthropic API.\n"
        with open(cost_log, "w") as f:
            f.write(header + "\n".join(lines))
    else:
        with open(cost_log, "a") as f:
            f.write("\n".join(lines))

# Balance tracking — accurate remaining estimate
# Logic: confirmedBalance is the balance AT the moment Ken confirmed it.
# Spend on days AFTER the confirmedAt date reduces it.
# The confirmedAt day itself is NOT subtracted (balance was confirmed mid-day,
# already net of any pre-confirmation spend).
api = state.get('apiBalance', {})
alerts = state.get('spendAlerts', {})

confirmed_balance = api.get('confirmedBalance')
confirmed_at = api.get('confirmedAt', '')
confirmed_date = confirmed_at[:10] if confirmed_at else api.get('topUpDate', '1970-01-01')

if confirmed_balance is not None:
    # Sum all daily costs for days STRICTLY AFTER the confirmed date.
    # The confirmed date itself is excluded — the confirmed balance already
    # accounts for any spend up to that point in the day.
    spent_after_confirm = sum(
        d.get('totalCost', 0)
        for day, d in state.get('history', {}).items()
        if day > confirmed_date
    )
    remaining = max(0, round(confirmed_balance - spent_after_confirm, 4))
    api['spentSinceTopUp'] = round(spent_after_confirm, 4)
else:
    # Legacy path — no confirmed balance, use topUpDate
    topup_date = api.get('topUpDate', '1970-01-01')
    spent_since_topup = sum(
        d.get('totalCost', 0)
        for day, d in state.get('history', {}).items()
        if day >= topup_date
    )
    starting_balance = api.get('balance', 0)
    remaining = max(0, round(starting_balance - spent_since_topup, 4))
    api['spentSinceTopUp'] = round(spent_since_topup, 4)

api['remainingEstimate'] = remaining
api['remainingNote'] = "confirmedBalance=" + str(confirmed_balance) + " at " + confirmed_date + "; spentAfter=" + str(round(api['spentSinceTopUp'], 4))
state['apiBalance'] = api

# Load cost-alert-state.json for confirmed balance + tier thresholds
alert_state_file = os.path.expanduser('~/.openclaw/workspace/state/cost-alert-state.json')
alert_state = {}
if os.path.exists(alert_state_file):
    try:
        with open(alert_state_file) as f:
            alert_state = json.load(f)
    except:
        pass

# Prefer confirmed balance from cost-alert-state.json; fall back to computed remaining
current_balance = alert_state.get('currentBalance') or remaining

# Tier thresholds — cost-alert-state.json is authoritative, spendAlerts as fallback
t1_thresh = alert_state.get('tier1', {}).get('threshold', alerts.get('tier1', {}).get('threshold', 80.0))
t2_thresh = alert_state.get('tier2', {}).get('threshold', alerts.get('tier2', {}).get('threshold', 40.0))
t3_thresh = alert_state.get('tier3', {}).get('threshold', alerts.get('tier3', {}).get('threshold', 15.0))

if current_balance <= t3_thresh and not alerts.get('tier3', {}).get('triggered'):
    alerts.setdefault('tier3', {})['triggered'] = True
    print(f"WARNING_TIER3_CRITICAL: Balance \${current_balance:.2f} <= \${t3_thresh:.2f}. CRITICAL — pause before every request.")
elif current_balance <= t2_thresh and not alerts.get('tier2', {}).get('triggered'):
    alerts.setdefault('tier2', {})['triggered'] = True
    print(f"WARNING_TIER2: Balance \${current_balance:.2f} <= \${t2_thresh:.2f}. Alert every 3rd response. Top up urgently.")
elif current_balance <= t1_thresh and not alerts.get('tier1', {}).get('triggered'):
    alerts.setdefault('tier1', {})['triggered'] = True
    print(f"WARNING_TIER1: Balance \${current_balance:.2f} <= \${t1_thresh:.2f}. Top up soon. ~19hrs runway.")
else:
    print(f"Balance OK: \${current_balance:.2f} USD (T1=\${t1_thresh:.0f} / T2=\${t2_thresh:.0f} / T3=\${t3_thresh:.0f})")

state['spendAlerts'] = alerts

# TRIGGER-08: Daily spend thresholds (archive/YODA_OC1_OC2_OPERATIONAL_BRIEF.md)
# T1=$60/day alert | T2=$80/day escalate | T3=$100/day pause
daily_t1 = 60.0
daily_t2 = 80.0
daily_t3 = 100.0
trigger_state_file = os.path.expanduser('~/.openclaw/workspace/state/chg-triggers.json')
trigger_state = {}
if os.path.exists(trigger_state_file):
    try:
        with open(trigger_state_file) as f:
            trigger_state = json.load(f)
    except: pass

t08 = trigger_state.get('triggers', {}).get('TRIGGER-08', {})
t08_fired_today = t08.get('lastFiredDate') == date

if total_cost >= daily_t3 and not t08_fired_today:
    print("TRIGGER-08-T3: Daily spend \${:.2f} >= \${:.0f}. PAUSE - notify Ken immediately.".format(total_cost, daily_t3))
    trigger_state.setdefault('triggers', {}).setdefault('TRIGGER-08', {})['lastFired'] = datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ')
    trigger_state['triggers']['TRIGGER-08']['lastFiredDate'] = date
    trigger_state['triggers']['TRIGGER-08']['lastFiredLevel'] = 'T3'
elif total_cost >= daily_t2 and not t08_fired_today:
    print("TRIGGER-08-T2: Daily spend \${:.2f} >= \${:.0f}. Escalate to Ken.".format(total_cost, daily_t2))
    trigger_state.setdefault('triggers', {}).setdefault('TRIGGER-08', {})['lastFired'] = datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ')
    trigger_state['triggers']['TRIGGER-08']['lastFiredDate'] = date
    trigger_state['triggers']['TRIGGER-08']['lastFiredLevel'] = 'T2'
elif total_cost >= daily_t1 and not t08_fired_today:
    print("TRIGGER-08-T1: Daily spend \${:.2f} >= \${:.0f}. Alert Ken.".format(total_cost, daily_t1))
    trigger_state.setdefault('triggers', {}).setdefault('TRIGGER-08', {})['lastFired'] = datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ')
    trigger_state['triggers']['TRIGGER-08']['lastFiredDate'] = date
    trigger_state['triggers']['TRIGGER-08']['lastFiredLevel'] = 'T1'
else:
    print("TRIGGER-08: Daily spend \${:.2f} OK (T1=\${:.0f} / T2=\${:.0f} / T3=\${:.0f})".format(total_cost, daily_t1, daily_t2, daily_t3))

if trigger_state:
    try:
        with open(trigger_state_file, 'w') as f2:
            import json as _json
            _json.dump(trigger_state, f2, indent=2)
    except: pass

# Safe atomic write (inline — state-write.py has a dash, not importable as a module)
dir_path = os.path.dirname(os.path.abspath(state_file))
with tempfile.NamedTemporaryFile(mode='w', dir=dir_path, suffix='.tmp', delete=False) as tmp:
    json.dump(state, tmp, indent=2)
    tmp_path = tmp.name
os.rename(tmp_path, state_file)

# Print summary
print(f"Date: {date}")
print(f"Total cost today: \${total_cost:.4f}")
print(f"Total turns: {total_turns}")
if total_calculated_turns > 0:
    print(f"Calculated cost (ephemeral): \${total_calculated_cost:.4f} ({total_calculated_turns} turns)")
print(f"Balance remaining: \${remaining:.2f} USD")
print(f"All-time total: \${state['allTimeTotalCost']:.4f} over {state['daysTracked']} day(s)")
print("By stream:")
for stream, d in sorted(by_stream.items(), key=lambda x: -x[1]["cost"]):
    if d["turns"] > 0:
        print(f"  {stream}: {d['turns']} turns | \${d['cost']:.4f}")
for model, d in sorted(by_model.items(), key=lambda x: -x[1]["cost"]):
    calc_note = ""
    if d.get("calculatedTurns", 0) > 0:
        calc_note = f" [calc: {d['calculatedTurns']}t @ \${d['calculatedCost']:.4f}]"
    print(f"  {model}: {d['turns']} turns | \${d['cost']:.4f}{calc_note}")
PYEOF
# ---------------------------------------------------------------------------
# extract_session_turns JSONL_FILE
# TKT-0175: Count assistant turns in a session file for calculated cost fallback.
# Returns integer turn count.
# ---------------------------------------------------------------------------
extract_session_turns() {
  local file="${1:-}"
  if [[ ! -f "$file" ]]; then
    echo "0"
    return 1
  fi
  python3 -c "
import json, sys
count = 0
with open('$file') as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            record = json.loads(line)
        except:
            continue
        msg = record.get('message', {})
        if record.get('type') == 'message' and msg.get('role') == 'assistant':
            count += 1
print(count)
"
}

# ---------------------------------------------------------------------------
# calculate_ephemeral_cost AGENT_NAME DATE
# TKT-0175: For ephemeral sessions (isolated crons, subagents, Forge runs)
# that lack usage.cost data, estimate cost from turn count × model rate.
# ---------------------------------------------------------------------------
calculate_ephemeral_cost() {
  local agent_name="${1:-}"
  local target_date="${2:-$(date +%Y-%m-%d)}"
  local agent_sessions="$HOME/.openclaw/agents/$agent_name/sessions"
  
  if [[ ! -d "$agent_sessions" ]]; then
    return 0
  fi

  python3 << EPY
import json, os, glob
from datetime import datetime

agent_name = "$agent_name"
date = "$target_date"
agent_sessions = os.path.expanduser(f"~/.openclaw/agents/{agent_name}/sessions")

TURN_RATES = {
    "claude-sonnet-4-6": 18884,
    "claude-haiku-4-5": 10409,
    "kimi-k2.6:cloud": 54000,
    "deepseek-v4-pro:cloud": 33847,
    "gemma4:31b-cloud": 14146,
    "gemma4:e2b": 11164,
    "claude-opus-4-7": 25000,
}

MODEL_RATES = {
    # Anthropic API — actual per-token costs
    "claude-sonnet-4-6": 0.000003,
    "claude-haiku-4-5": 0.0000008,
    "claude-opus-4-7": 0.000015,
    # Ollama Cloud — subscription-aligned fair-value
    "deepseek-v4-pro:cloud": 0.0000000425,
    "kimi-k2.6:cloud": 0.0000000309,
    "gemma4:31b-cloud": 0.0000000155,
    "deepseek-v4-flash:cloud": 0.0000000108,
    "gemma4:26b": 0.0000000093,
    "gemma4:e2b": 0.0000000046,
}

total_cost = 0.0
total_turns = 0
by_model = {}

for jsonl_file in glob.glob(f"{agent_sessions}/*.jsonl"):
    if ".trajectory." in jsonl_file:
        continue
    try:
        with open(jsonl_file, 'r') as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    record = json.loads(line)
                except:
                    continue
                ts = record.get("timestamp", "")
                if not ts.startswith(date):
                    continue
                msg = record.get("message", {})
                if record.get("type") != "message" or msg.get("role") != "assistant":
                    continue
                usage = msg.get("usage")
                if usage and (usage.get("cost") or {}).get("total"):
                    continue  # Skip — already has real cost data
                model = msg.get("model", "unknown")
                if model in TURN_RATES and MODEL_RATES.get(model, 0) > 0:
                    turn_rate = TURN_RATES[model]
                    model_rate = MODEL_RATES[model]
                    cost = turn_rate * model_rate
                    total_cost += cost
                    total_turns += 1
                    if model not in by_model:
                        by_model[model] = {"cost": 0.0, "turns": 0}
                    by_model[model]["cost"] += cost
                    by_model[model]["turns"] += 1
    except Exception:
        pass

print(f"EPHEMERAL_COST: agent={agent_name} date={date} cost=${total_cost:.4f} turns={total_turns}")
for model, d in sorted(by_model.items(), key=lambda x: -x[1]["cost"]):
    print(f"  {model}: {d['turns']} turns | ${d['cost']:.4f}")
EPY
}

# ---------------------------------------------------------------------------
# estimate_workflow_cost WORKFLOW_NAME
# TKT-0092: Estimates p50/p90 cost for a named workflow and compares to cap.
# Reads last 7 days of cost-state.json history; uses daily avg as proxy until
# per-workflow session tagging is implemented.
# ---------------------------------------------------------------------------
estimate_workflow_cost() {
  local workflow_name="${1:-}"
  if [[ -z "$workflow_name" ]]; then
    echo "Usage: estimate_workflow_cost WORKFLOW_NAME"
    return 1
  fi

  local budget_file="$HOME/.openclaw/workspace/state/agent-budgets.json"
  local JQ_BIN="/opt/homebrew/bin/jq"

  if [[ ! -f "$budget_file" ]]; then
    echo "ERROR: agent-budgets.json not found — run TKT-0092 setup first"
    return 1
  fi

  local cap
  cap=$("$JQ_BIN" -r --arg w "$workflow_name" '.workflows[$w].perRunCapUsd // empty' "$budget_file" 2>/dev/null)
  if [[ -z "$cap" ]]; then
    echo "ERROR: Workflow '$workflow_name' not in agent-budgets.json"
    return 1
  fi

  local STATE_FILE_LOC="$HOME/.openclaw/workspace/state/cost-state.json"
  python3 << ESTIMATOR_EOF
import json, os, statistics
from datetime import datetime, timedelta

state_file = os.path.expanduser("$HOME/.openclaw/workspace/state/cost-state.json")
budget_file = os.path.expanduser("$HOME/.openclaw/workspace/state/agent-budgets.json")
workflow = "$workflow_name"

with open(state_file) as f:
    state = json.load(f)

with open(budget_file) as f:
    budgets = json.load(f)

cap = budgets.get('workflows', {}).get(workflow, {}).get('perRunCapUsd', 0)

# Last 7 days of total daily costs as proxy (no per-workflow data yet)
today = datetime.utcnow().date()
daily_costs = []
for i in range(1, 8):
    day = (today - timedelta(days=i)).isoformat()
    c = state.get('history', {}).get(day, {}).get('totalCost')
    if c is not None:
        daily_costs.append(c)

if len(daily_costs) >= 2:
    p50 = statistics.median(daily_costs)
    p90 = sorted(daily_costs)[max(0, int(len(daily_costs)*0.9)-1)] if len(daily_costs) >= 5 else max(daily_costs)
    status = "OK" if p90 <= float(cap) * 50 else "WARN_HIGH_PLATFORM_COST"
    print(f"WORKFLOW {workflow}: p50=\${p50:.2f}/day p90=\${p90:.2f}/day cap=\${float(cap):.2f}/run STATUS={status}")
    print(f"Note: Platform-level daily costs shown — per-workflow isolation pending session tagging (US future).")
else:
    print(f"WORKFLOW {workflow}: p50=N/A p90=N/A cap=\${float(cap):.2f}/run STATUS=INSUFFICIENT_DATA")
ESTIMATOR_EOF
}

# If called with --estimate-workflow flag, run estimator
if [[ "${1:-}" == "--estimate-workflow" && -n "${2:-}" ]]; then
  estimate_workflow_cost "$2"
fi

# If called with --ephemeral flag, run ephemeral cost calculator
if [[ "${1:-}" == "--ephemeral" && -n "${2:-}" ]]; then
  calculate_ephemeral_cost "$2" "${3:-$(date +%Y-%m-%d)}"
fi

# If called with --turns flag, extract turn count from session file
if [[ "${1:-}" == "--turns" && -n "${2:-}" ]]; then
  extract_session_turns "$2"
fi
