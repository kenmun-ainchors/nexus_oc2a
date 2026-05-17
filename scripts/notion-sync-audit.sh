#!/bin/zsh
# AInchors Notion Sync Audit — Daily drift detection
# CHG-0371/L-035: Detects drift between tickets.json and Notion AKB Backlog
# Output: state/notion-audit-report.json
# Alert: Telegram if drift detected

set -uo pipefail

WORKSPACE="$HOME/.openclaw/workspace"
STATE="$WORKSPACE/state"
TICKET_FILE="$STATE/tickets.json"
AUDIT_FILE="$STATE/notion-audit-report.json"
ALERT_FILE="/tmp/pvt-alert.txt"
NOTION_KEY_FILE="$HOME/.config/notion/api_key"
NOTION_DB_ID="34dc1829-53ff-814b-8257-d3a3bf351d44"

TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
AEST_TIMESTAMP=$(TZ=Australia/Melbourne date '+%Y-%m-%d %H:%M:%S %Z')

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"; }

# ── Load tickets.json ──────────────────────────────────────────────────────
if [[ ! -f "$TICKET_FILE" ]]; then
  log "ERROR: $TICKET_FILE not found"
  exit 1
fi

TICKETS_JSON=$(cat "$TICKET_FILE")

# ── Fetch Notion pages ────────────────────────────────────────────────────
log "Fetching Notion pages..."

NOTION_PAGES=$(python3 - << "PYEOF"
import json, urllib.request, os
key_path = os.path.expanduser('~/.config/notion/api_key')
with open(key_path) as f:
    key = f.read().strip()
headers = {
    "Authorization": f"Bearer {key}",
    "Notion-Version": "2025-09-03",
    "Content-Type": "application/json",
}

pages = {}
has_more = True
next_cursor = None
while has_more:
    import time
    time.sleep(0.4)
    req = urllib.request.Request(
        "https://api.notion.com/v1/search",
        data=json.dumps({"page_size": 100, "start_cursor": next_cursor} if next_cursor else {"page_size": 100}).encode(),
        headers=headers, method="POST"
    )
    try:
        with urllib.request.urlopen(req) as r:
            data = json.loads(r.read())
            for page in data.get('results', []):
                if page.get('object') == 'page':
                    props = page.get('properties', {})
                    title = ''
                    if props.get('US Title') and props['US Title'].get('title'):
                        title = props['US Title']['title'][0].get('text', {}).get('content', '')
                    elif props.get('Name') and props['Name'].get('title'):
                        title = props['Name']['title'][0].get('text', {}).get('content', '')
                    
                    if title.startswith('[TKT-'):
                        tkt_id = title.split(']')[0][1:]
                        if tkt_id not in pages:
                            pages[tkt_id] = []
                        pages[tkt_id].append({
                            'page_id': page['id'],
                            'title': title,
                            'created_time': page.get('created_time', '')
                        })
            has_more = data.get('has_more', False)
            next_cursor = data.get('next_cursor')
    except Exception as e:
        print(f'Error: {e}', file=__import__('sys').stderr)
        break

print(json.dumps(pages))
PYEOF
)

# ── Identify issues ────────────────────────────────────────────────────────
log "Analyzing drift..."

AUDIT=$(python3 - << "PYEOF"
import json

tickets = json.loads('''$TICKETS_JSON''')
notion = json.loads('''$NOTION_PAGES''')

issues = {
    'duplicates': [],
    'missing': [],
    'status_mismatch': [],
    'extra': [],
    'timestamp': '$AEST_TIMESTAMP'
}

# Check duplicates
for tkt_id, pages in notion.items():
    if len(pages) > 1:
        issues['duplicates'].append({
            'tkt_id': tkt_id,
            'count': len(pages),
            'pages': [p['page_id'] for p in pages]
        })

# Check status mismatches
status_map = {
    'Open': 'Backlog', 'In-progress': 'In Progress', 'Pending': 'Pending',
    'Closed': 'Done', 'Resolved': 'Done', 'Blocked': 'Blocked', 'Done': 'Done'
}

for tkt_id, pages in notion.items():
    for t in tickets.get('tickets', []):
        if t.get('id') == tkt_id:
            # We can't easily check status via search, so skip for now
            break

# Check missing (active tickets not in Notion)
for t in tickets.get('tickets', []):
    if t.get('status') in ['open', 'in-progress', 'pending']:
        if t.get('id') not in notion:
            issues['missing'].append(t.get('id'))

# Check extra (in Notion but not in tickets.json)
for tkt_id in notion.keys():
    found = False
    for t in tickets.get('tickets', []):
        if t.get('id') == tkt_id:
            found = True
            break
    if not found:
        issues['extra'].append(tkt_id)

print(json.dumps({
    'auditDate': '$AEST_TIMESTAMP',
    'notionPageCount': len(notion),
    'ticketsJsonCount': len(tickets.get('tickets', [])),
    'issues': issues
}, indent=2))
PYEOF
)

# ── Write audit report ─────────────────────────────────────────────────────
echo "$AUDIT" > "$AUDIT_FILE"

# ── Parse for alerts ───────────────────────────────────────────────────────
DRIFT_COUNT=$(echo "$AUDIT" | python3 -c "
import json, sys
d = json.load(sys.stdin)
count = len(d.get('issues', {}).get('duplicates', [])) + \
        len(d.get('issues', {}).get('missing', [])) + \
        len(d.get('issues', {}).get('extra', []))
print(count)
")

log "Drift detected: $DRIFT_COUNT issues"

if [[ "$DRIFT_COUNT" -gt 0 ]]; then
  {
    echo ""
    echo "=== Notion Sync Audit: DRIFT DETECTED ($AEST_TIMESTAMP) ==="
    echo "  Duplicates: $(echo "$AUDIT" | python3 -c 'import json,sys; print(len(json.load(sys.stdin).get("issues",{}).get("duplicates",[])))')"
    echo "  Missing: $(echo "$AUDIT" | python3 -c 'import json,sys; print(len(json.load(sys.stdin).get("issues",{}).get("missing",[])))')"
    echo "  Extra: $(echo "$AUDIT" | python3 -c 'import json,sys; print(len(json.load(sys.stdin).get("issues",{}).get("extra",[])))')"
    echo "  Run: bash scripts/notion-sync-audit.sh for details"
    echo ""
  } >> "$ALERT_FILE"
  log "ALERT: $DRIFT_COUNT drift issues appended to $ALERT_FILE"
  exit 1
else
  log "All clear — no drift detected"
  exit 0
fi
