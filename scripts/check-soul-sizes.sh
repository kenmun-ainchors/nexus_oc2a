#!/usr/bin/env bash
# check-soul-sizes.sh — Weekly SOUL.md size audit
# Alerts if any SOUL.md exceeds warning (6,000) or hard limit (10,000)
# CHG-0362 — created 2026-05-17

set -uo pipefail

WORKSPACE="/Users/ainchorsangiefpl/.openclaw"
WARN_LIMIT=6000
HARD_LIMIT=10000
ALERT_FILE="/Users/ainchorsangiefpl/.openclaw/workspace/state/soul-size-alert.json"
STATE_FILE="/Users/ainchorsangiefpl/.openclaw/workspace/state/soul-sizes.json"

# Temporary file for results
TMP_RESULTS=$(mktemp)
trap 'rm -f "$TMP_RESULTS"' EXIT

# Find all SOUL.md files
find "$WORKSPACE" -maxdepth 4 -name "SOUL.md" -print0 2>/dev/null | while IFS= read -r -d '' file; do
    size=$(wc -c < "$file")
    agent=$(echo "$file" | sed 's|.*workspace-||; s|.*workspace/||; s|/SOUL.md||; s|agents/||')
    st="OK"
    if [ "$size" -gt "$HARD_LIMIT" ]; then
        st="HARD_LIMIT_EXCEEDED"
    elif [ "$size" -gt "$WARN_LIMIT" ]; then
        st="WARNING"
    fi
    printf '%s\t%s\t%s\t%s\n' "$agent" "$size" "$st" "$file"
done > "$TMP_RESULTS"

# Build JSON using Python
timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

export TMP_RESULTS timestamp WARN_LIMIT HARD_LIMIT ALERT_FILE STATE_FILE

/usr/bin/python3 << 'PYEOF'
import json, os, sys

timestamp = os.environ['timestamp']
warn_limit = int(os.environ['WARN_LIMIT'])
hard_limit = int(os.environ['HARD_LIMIT'])
state_file = os.environ['STATE_FILE']
alert_file = os.environ['ALERT_FILE']
tmp_results = os.environ['TMP_RESULTS']

# Read results from temp file
entries = []
with open(tmp_results) as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        parts = line.split('\t')
        entries.append({
            "agent": parts[0],
            "size": int(parts[1]),
            "status": parts[2],
            "path": parts[3]
        })

warn_count = len([e for e in entries if e["status"] == "WARNING"])
hard_count = len([e for e in entries if e["status"] == "HARD_LIMIT_EXCEEDED"])

state = {
    "checkedAt": timestamp,
    "warningLimit": warn_limit,
    "hardLimit": hard_limit,
    "totalAgents": len(entries),
    "warnings": warn_count,
    "hardLimitBreaches": hard_count,
    "agents": entries
}

with open(state_file, "w") as f:
    json.dump(state, f, indent=2)

if warn_count > 0 or hard_count > 0:
    alert = {
        "alertedAt": timestamp,
        "severity": "HARD" if hard_count > 0 else "WARN",
        "message": f"SOUL.md size check: {hard_count} hard limit, {warn_count} warnings",
        "details": [e for e in entries if e["status"] != "OK"]
    }
    with open(alert_file, "w") as f:
        json.dump(alert, f, indent=2)
    print(f"ALERT: {alert['message']}", file=sys.stderr)
    sys.exit(1)
else:
    print("All SOUL.md files within limits.")
    if os.path.exists(alert_file):
        os.remove(alert_file)
    sys.exit(0)
PYEOF
