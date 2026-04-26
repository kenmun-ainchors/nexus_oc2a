#!/bin/zsh
# AInchors Gemma4 Delegation Helper
# Logs delegation attempts and outcomes to gemma4-delegation-log.json
#
# Usage: delegate-gemma4.sh log <task_type> <tier> <status> [notes]
# Status: success | failure | escalated
# Example: delegate-gemma4.sh log "file_ops" "A" "success" "Updated cost-state.json"

ACTION=$1
TASK_TYPE=$2
TIER=$3
STATUS=$4
NOTES="${5:-}"
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
LOG_FILE="$HOME/.openclaw/workspace/state/gemma4-delegation-log.json"
STATE_WRITER="$HOME/.openclaw/workspace/scripts/state_write.py"

if [[ "$ACTION" != "log" ]]; then
    echo "Usage: delegate-gemma4.sh log <task_type> <tier> <status> [notes]"
    exit 1
fi

# Estimate cost saved (rough Sonnet equivalent per turn)
SONNET_COST_PER_TURN=0.062  # ~avg from Day 1 ($25.75 / 416 turns)

python3 << PYEOF
import json, os, sys
sys.path.insert(0, os.path.expanduser('~/.openclaw/workspace/scripts'))
try:
    from state_write import safe_read, safe_write
except:
    def safe_read(p, d=None):
        try: return json.load(open(p))
        except: return d or {}
    def safe_write(p, d):
        import tempfile
        with tempfile.NamedTemporaryFile(mode='w', dir=os.path.dirname(os.path.abspath(p)), suffix='.tmp', delete=False) as f:
            json.dump(d, f, indent=2); n = f.name
        os.rename(n, p)

state = safe_read('$LOG_FILE', {})
entry = {
    "timestamp": "$TIMESTAMP",
    "taskType": "$TASK_TYPE",
    "tier": "$TIER",
    "status": "$STATUS",
    "notes": "$NOTES"
}
if 'entries' not in state: state['entries'] = []
state['entries'].append(entry)

# Update summary
s = state.get('summary', {})
s['totalDelegations'] = s.get('totalDelegations', 0) + 1
if '$STATUS' == 'success':
    s['successCount'] = s.get('successCount', 0) + 1
    s['estimatedSonnetSaved'] = round(s.get('estimatedSonnetSaved', 0) + $SONNET_COST_PER_TURN, 4)
elif '$STATUS' == 'failure':
    s['failureCount'] = s.get('failureCount', 0) + 1
elif '$STATUS' == 'escalated':
    s['escalationCount'] = s.get('escalationCount', 0) + 1

by_type = s.get('byTaskType', {})
if '$TASK_TYPE' not in by_type:
    by_type['$TASK_TYPE'] = {'success': 0, 'failure': 0, 'escalated': 0}
by_type['$TASK_TYPE']['$STATUS'] = by_type['$TASK_TYPE'].get('$STATUS', 0) + 1
s['byTaskType'] = by_type
state['summary'] = s
state['lastUpdated'] = '$TIMESTAMP'
state['successRate'] = round(s['successCount'] / s['totalDelegations'] * 100, 1) if s['totalDelegations'] else 0

safe_write('$LOG_FILE', state)
print(f"Logged: {entry['taskType']} ({entry['tier']}) — {entry['status']}")
print(f"Total delegations: {s['totalDelegations']} | Success rate: {state['successRate']}% | Est. saved: \${s['estimatedSonnetSaved']:.4f}")
PYEOF