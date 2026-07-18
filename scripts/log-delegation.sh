#!/usr/bin/env bash
# log-delegation.sh — Log model routing outcomes to the 3-tier delegation tracker
# Usage: bash log-delegation.sh --tier TIER --task-type TYPE --model MODEL --status STATUS [--latency-ms N] [--notes "..."]
# TKT-0015

export PATH="$PATH:/usr/local/bin"

LOG_FILE="$HOME/.openclaw/workspace/state/delegation-log.json"
TIMESTAMP=$(date +"%Y-%m-%dT%H:%M:%S+08:00")
DATE=$(date +"%Y-%m-%d")

TIER=""; TASK_TYPE=""; MODEL=""; STATUS=""; LATENCY_MS="0"; NOTES=""

while (( $# > 0 )); do
  case "$1" in
    --tier)       TIER="$2"; shift 2 ;;
    --task-type)  TASK_TYPE="$2"; shift 2 ;;
    --model)      MODEL="$2"; shift 2 ;;
    --status)     STATUS="$2"; shift 2 ;;
    --latency-ms) LATENCY_MS="$2"; shift 2 ;;
    --notes)      NOTES="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

if [ -z "$TIER" ] || [ -z "$TASK_TYPE" ] || [ -z "$MODEL" ] || [ -z "$STATUS" ]; then
  echo "Usage: log-delegation.sh --tier T1|T2|T3 --task-type TYPE --model MODEL --status pass|fail|timeout [--latency-ms N] [--notes '...']" >&2
  exit 1
fi

python3 << PYEOF
import json, os
from datetime import datetime

log_file = os.path.expanduser("$LOG_FILE")

# Load or create
if os.path.exists(log_file):
    with open(log_file) as f:
        data = json.load(f)
else:
    data = {
        "schema_version": "2.0",
        "description": "3-tier model routing delegation outcomes. Updated by log-delegation.sh.",
        "trackingStarted": "$DATE",
        "entries": [],
        "summary": {
            "total": 0,
            "byTier": {"T1": {"pass":0,"fail":0,"timeout":0}, "T2": {"pass":0,"fail":0,"timeout":0}, "T3": {"pass":0,"fail":0,"timeout":0}},
            "byTaskType": {},
            "estimatedSavingsUSD": 0.0
        }
    }

entry = {
    "ts": "$TIMESTAMP",
    "date": "$DATE",
    "tier": "$TIER",
    "taskType": "$TASK_TYPE",
    "model": "$MODEL",
    "status": "$STATUS",
    "latencyMs": int("$LATENCY_MS"),
    "notes": "$NOTES"
}

data["entries"].append(entry)

# Update summary
s = data["summary"]
s["total"] = len(data["entries"])
tier = "$TIER"
status = "$STATUS"
if tier in s["byTier"]:
    if status in s["byTier"][tier]:
        s["byTier"][tier][status] += 1

task = "$TASK_TYPE"
if task not in s["byTaskType"]:
    s["byTaskType"][task] = {"pass":0,"fail":0,"timeout":0,"tier":"$TIER"}
if status in s["byTaskType"][task]:
    s["byTaskType"][task][status] += 1

# Rough savings estimate: T2 saves (Sonnet - Haiku) cost, T3 saves full Sonnet cost
# Sonnet ≈ $0.015/1k output, Haiku ≈ $0.005/1k output. Avg turn ~500 output tokens.
if tier == "T2" and status == "pass":
    s["estimatedSavingsUSD"] = round(s.get("estimatedSavingsUSD", 0) + 0.005, 4)  # ~$0.005/turn saved
elif tier == "T3" and status == "pass":
    s["estimatedSavingsUSD"] = round(s.get("estimatedSavingsUSD", 0) + 0.0075, 4)  # ~$0.0075/turn saved

with open(log_file, "w") as f:
    json.dump(data, f, indent=2)

print(f"Logged: tier={tier} task={task} model=$MODEL status={status} latency={entry['latencyMs']}ms")
PYEOF
