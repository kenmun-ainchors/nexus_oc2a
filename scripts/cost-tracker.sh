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
import json, os, glob, sys
from datetime import datetime

sessions_dir = os.path.expanduser("~/.openclaw/agents/main/sessions")
date = "$DATE"
state_file = os.path.expanduser("$STATE_FILE")
cost_log = os.path.expanduser("$COST_LOG")

by_model = {}
total_cost = 0.0
total_input = 0
total_output = 0
total_cache_read = 0
total_cache_write = 0
total_turns = 0

# Parse all session files
for jsonl_file in glob.glob(f"{sessions_dir}/*.jsonl"):
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
                cr = usage.get("cacheRead", 0) or 0
                cw = usage.get("cacheWrite", 0) or 0

                if model not in by_model:
                    by_model[model] = {"input":0,"output":0,"cacheRead":0,"cacheWrite":0,"cost":0.0,"turns":0}

                by_model[model]["input"] += inp
                by_model[model]["output"] += out
                by_model[model]["cacheRead"] += cr
                by_model[model]["cacheWrite"] += cw
                by_model[model]["cost"] += cost
                by_model[model]["turns"] += 1
                total_cost += cost
                total_input += inp
                total_output += out
                total_cache_read += cr
                total_cache_write += cw
                total_turns += 1
    except Exception as e:
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
    lines.append("")
    lines.append("### By Model")
    for model, d in sorted(by_model.items(), key=lambda x: -x[1]["cost"]):
        lines.append(f"- **{model}**: {d['turns']} turns | {d['input']:,} in / {d['output']:,} out | \${d['cost']:.4f}")
    lines.append("")

    if not existing:
        header = "# AInchors Cost History\n_Token costs by day. Source: OpenClaw session logs._\n\nGemma4 (Ollama) = \$0.00 always (local). Cloud costs = Anthropic API.\n"
        with open(cost_log, "w") as f:
            f.write(header + "\n".join(lines))
    else:
        with open(cost_log, "a") as f:
            f.write("\n".join(lines))

# Balance alert check
# IMPORTANT: only count spend AFTER the top-up timestamp to avoid double-counting
# pre-top-up spend that already exhausted the previous balance.
api = state.get('apiBalance', {})
alerts = state.get('spendAlerts', {})

# Use confirmedAt balance if available (set by Ken) — most accurate source of truth
# Otherwise fall back to calculated estimate
confirmed_balance = api.get('confirmedBalance')
if confirmed_balance is not None:
    # Confirmed balance is mid-day ground truth — don't subtract all-day spend
    remaining = confirmed_balance  # use confirmed balance as current floor
    api['spentSinceTopUp'] = 0  # reset anchor to confirmed balance point
else:
    # Only add today's cost to spentSinceTopUp if today >= topUpDate
    topup_date = api.get('topUpDate', '1970-01-01')
    if date >= topup_date:
        spent_since_topup = api.get('spentSinceTopUp', 0) + total_cost
    else:
        spent_since_topup = api.get('spentSinceTopUp', 0)
    starting_balance = api.get('balance', 0)
    remaining = round(starting_balance - spent_since_topup, 4)
    api['spentSinceTopUp'] = round(spent_since_topup, 4)

api['remainingEstimate'] = max(0, remaining)
state['apiBalance'] = api

alert_75 = alerts.get('alert75pct', {})
alert_10 = alerts.get('alert10pct', {})

if remaining <= alert_10.get('threshold', 5.0) and not alert_10.get('triggered'):
    alerts['alert10pct']['triggered'] = True
    print(f"ALERT_CRITICAL: Balance at 10% or below. Remaining: \${remaining:.2f}")
elif remaining <= alert_75.get('threshold', 12.51) and not alert_75.get('triggered'):
    alerts['alert75pct']['triggered'] = True
    print(f"ALERT_75PCT: 75% of balance consumed. Remaining: \${remaining:.2f}")

state['spendAlerts'] = alerts
# Safe atomic write
import sys as _sys
_sys.path.insert(0, os.path.dirname(os.path.abspath('$STATE_WRITER')))
try:
    from state_write import safe_write
    safe_write(state_file, state)
except Exception as _e:
    # Fallback to direct write if locking unavailable
    dir_path = os.path.dirname(os.path.abspath(state_file))
    import tempfile
    with tempfile.NamedTemporaryFile(mode='w', dir=dir_path, suffix='.tmp', delete=False) as tmp:
        json.dump(state, tmp, indent=2)
        tmp_path = tmp.name
    os.rename(tmp_path, state_file)

# Print summary
print(f"Date: {date}")
print(f"Total cost today: \${total_cost:.4f}")
print(f"Total turns: {total_turns}")
print(f"Balance remaining: \${remaining:.2f} USD")
print(f"All-time total: \${state['allTimeTotalCost']:.4f} over {state['daysTracked']} day(s)")
for model, d in sorted(by_model.items(), key=lambda x: -x[1]["cost"]):
    print(f"  {model}: {d['turns']} turns | \${d['cost']:.4f}")
PYEOF