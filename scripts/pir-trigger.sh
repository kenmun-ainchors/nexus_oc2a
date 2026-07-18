#!/usr/bin/env bash
# pir-trigger.sh — Post-Incident Review (PIR) Trigger
# Automatically schedules a PIR for any P1 or P2 incident.
# Called by incident-log.sh or manually.
# ITSM-US-006 / 2026-04-28

export PATH="$PATH:/usr/local/bin:/opt/homebrew/bin"

WORKSPACE="$HOME/.openclaw/workspace"
PIR_DIR="$WORKSPACE/state/pir"
TIMESTAMP=$(date +"%Y-%m-%dT%H:%M:%S+08:00")
LOCAL=$(date +"%Y-%m-%d %H:%M MYT")

INC_ID="${1:-}"
SEVERITY="${2:-P3}"
TITLE="${3:-Unknown incident}"

mkdir -p "$PIR_DIR"

# Only trigger for P1 or P2
if [[ "$SEVERITY" != "P1" && "$SEVERITY" != "P2" ]]; then
  echo "PIR not required for $SEVERITY incidents (P1/P2 only). Skipping."
  exit 0
fi

PIR_ID="PIR-$(date +%Y%m%d)-${INC_ID##INC-}"
PIR_FILE="$PIR_DIR/$PIR_ID.json"

# Create PIR record
python3 -c "
import json
pir = {
    'id': '$PIR_ID',
    'incidentId': '$INC_ID',
    'severity': '$SEVERITY',
    'title': 'PIR: $TITLE',
    'scheduledFor': 'Within 48hrs of incident close',
    'createdAt': '$TIMESTAMP',
    'status': 'scheduled',
    'requiredAttendees': ['Ken Mun (CTO)'],
    'agenda': [
        '1. Timeline: what happened, when, in what order',
        '2. Root cause: why did it happen (5 Whys)',
        '3. Impact: what was affected, for how long',
        '4. Detection: how was it detected, was alerting adequate',
        '5. Response: what worked, what didnt, response time',
        '6. Prevention: what changes prevent recurrence',
        '7. Action items: owner, due date, verification method'
    ],
    'outputRequired': [
        'PIR document filed to Notion Incident Log',
        'Action items as US in Backlog',
        'CHANGELOG entry for any changes made'
    ]
}
with open('$PIR_FILE', 'w') as f:
    json.dump(pir, f, indent=2)
print(f'PIR scheduled: $PIR_ID for $INC_ID [$SEVERITY]')
"

# Alert Ken via system banner
python3 -c "
import json, os
banner_file = '$WORKSPACE/state/system-banner.json'
existing = json.load(open(banner_file)) if os.path.exists(banner_file) else {}
banner = {
    'active': True,
    'type': 'info',
    'message': f'📋 PIR Required: $PIR_ID for $INC_ID [$SEVERITY] — schedule within 48hrs. File: state/pir/$PIR_ID.json',
    'since': '$TIMESTAMP',
    'dismissable': True
}
with open(banner_file, 'w') as f:
    json.dump(banner, f, indent=2)
"

echo "✅ PIR triggered: $PIR_ID"
echo "   Incident: $INC_ID [$SEVERITY] — $TITLE"
echo "   Action: Schedule PIR review within 48hrs with Ken"
