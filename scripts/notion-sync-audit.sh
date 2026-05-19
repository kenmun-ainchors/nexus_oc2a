#!/bin/zsh
# AInchors Notion Sync Audit — Daily drift detection
# CHG-0371/L-035: Detects drift between tickets.json and Notion AKB Backlog
# Output: state/notion-audit-report.json
# Alert: Telegram if drift detected
# FIXED: 2026-05-19 — heredoc variable passing, DB-filtered search, absolute paths

set -uo pipefail

WORKSPACE="/Users/ainchorsangiefpl/.openclaw/workspace"
STATE="$WORKSPACE/state"
TICKET_FILE="$STATE/tickets.json"
AUDIT_FILE="$STATE/notion-audit-report.json"
ALERT_FILE="/tmp/pvt-alert.txt"
NOTION_KEY_FILE="/Users/ainchorsangiefpl/.config/notion/api_key"
NOTION_DB_ID="34dc1829-53ff-814b-8257-d3a3bf351d44"

AEST_TIMESTAMP=$(TZ=Australia/Melbourne date '+%Y-%m-%d %H:%M:%S %Z')

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"; }

# ── Validate inputs ────────────────────────────────────────────────────────
if [[ ! -f "$TICKET_FILE" ]]; then
  log "ERROR: $TICKET_FILE not found"
  exit 1
fi

if [[ ! -f "$NOTION_KEY_FILE" ]]; then
  log "ERROR: $NOTION_KEY_FILE not found"
  exit 1
fi

# ── Single Python script: fetch Notion + analyze drift ─────────────────────
# Pass data via files (tickets.json) and env vars to avoid heredoc interpolation bugs
log "Fetching Notion pages and analyzing drift..."

export NOTION_KEY_FILE NOTION_DB_ID TICKET_FILE AUDIT_FILE AEST_TIMESTAMP

/opt/homebrew/bin/python3 - << 'PYEOF'
import json, os, sys, time, urllib.request

# ── Load API key ───────────────────────────────────────────────────────────
key_file = os.environ['NOTION_KEY_FILE']
with open(key_file) as f:
    key = f.read().strip()

headers = {
    "Authorization": f"Bearer {key}",
    "Notion-Version": "2022-06-28",
    "Content-Type": "application/json",
}

db_id = os.environ['NOTION_DB_ID']
ticket_file = os.environ['TICKET_FILE']
audit_file = os.environ['AUDIT_FILE']
aest_ts = os.environ['AEST_TIMESTAMP']

# ── Load tickets.json ──────────────────────────────────────────────────────
with open(ticket_file) as f:
    tickets = json.load(f)

ticket_list = tickets.get('tickets', [])
ticket_ids = {t['id'] for t in ticket_list}
active_ticket_ids = {t['id'] for t in ticket_list if t.get('status') in ('open', 'in-progress', 'pending')}

# ── Fetch all pages from Backlog DB ────────────────────────────────────────
# Use database query to filter to the correct DB, paginated
notion_pages = {}
has_more = True
start_cursor = None

while has_more:
    time.sleep(0.35)  # rate limit courtesy
    body = {"page_size": 100}
    if start_cursor:
        body["start_cursor"] = start_cursor

    req = urllib.request.Request(
        f"https://api.notion.com/v1/databases/{db_id}/query",
        data=json.dumps(body).encode(),
        headers=headers,
        method="POST"
    )

    try:
        with urllib.request.urlopen(req) as r:
            data = json.loads(r.read())
            for page in data.get('results', []):
                props = page.get('properties', {})
                # US Title is the title property in AKB Backlog
                title = ''
                if props.get('US Title') and props['US Title'].get('title'):
                    title_parts = props['US Title']['title']
                    if title_parts:
                        title = title_parts[0].get('text', {}).get('content', '')

                if title.startswith('[TKT-'):
                    tkt_id = title.split(']')[0][1:]
                    if tkt_id not in notion_pages:
                        notion_pages[tkt_id] = []
                    notion_pages[tkt_id].append({
                        'page_id': page['id'],
                        'title': title,
                        'created_time': page.get('created_time', '')
                    })

            has_more = data.get('has_more', False)
            start_cursor = data.get('next_cursor')
            print(f"[{time.strftime('%H:%M:%S')}] Fetched page batch, total pages so far: {len(notion_pages)}", file=sys.stderr)

    except Exception as e:
        print(f"ERROR fetching Notion: {e}", file=sys.stderr)
        break

print(f"[{time.strftime('%H:%M:%S')}] Total Notion pages with TKT prefix: {len(notion_pages)}", file=sys.stderr)

# ── Analyze drift ──────────────────────────────────────────────────────────
issues = {
    'duplicates': [],
    'missing': [],
    'extra': [],
    'timestamp': aest_ts
}

# Duplicates: same TKT appears multiple times in Notion
for tkt_id, pages in notion_pages.items():
    if len(pages) > 1:
        issues['duplicates'].append({
            'tkt_id': tkt_id,
            'count': len(pages),
            'pages': [p['page_id'] for p in pages]
        })

# Missing: active tickets in JSON but not in Notion
for tkt_id in sorted(active_ticket_ids):
    if tkt_id not in notion_pages:
        issues['missing'].append(tkt_id)

# Extra: in Notion but not in tickets.json
for tkt_id in sorted(notion_pages.keys()):
    if tkt_id not in ticket_ids:
        issues['extra'].append(tkt_id)

# ── Write audit report ─────────────────────────────────────────────────────
report = {
    'auditDate': aest_ts,
    'notionPageCount': len(notion_pages),
    'ticketsJsonCount': len(ticket_list),
    'activeTicketCount': len(active_ticket_ids),
    'issues': issues
}

with open(audit_file, 'w') as f:
    json.dump(report, f, indent=2)

# ── Output summary for shell ───────────────────────────────────────────────
drift_count = len(issues['duplicates']) + len(issues['missing']) + len(issues['extra'])
print(f"DRIFT_COUNT={drift_count}")
print(f"DUPLICATES={len(issues['duplicates'])}")
print(f"MISSING={len(issues['missing'])}")
print(f"EXTRA={len(issues['extra'])}")

# Print details to stderr for logging
if drift_count > 0:
    print(f"DRIFT DETECTED: {drift_count} issues", file=sys.stderr)
    if issues['duplicates']:
        print(f"  Duplicates: {[d['tkt_id'] for d in issues['duplicates']]}", file=sys.stderr)
    if issues['missing']:
        print(f"  Missing: {issues['missing']}", file=sys.stderr)
    if issues['extra']:
        print(f"  Extra: {issues['extra']}", file=sys.stderr)
else:
    print("All clear — no drift detected", file=sys.stderr)

sys.exit(0 if drift_count == 0 else 1)
PYEOF

EXIT_CODE=$?

# ── Alert if drift detected ────────────────────────────────────────────────
if [[ $EXIT_CODE -ne 0 ]]; then
  # Parse the audit file for alert
  if [[ -f "$AUDIT_FILE" ]]; then
    ISSUES=$(/opt/homebrew/bin/python3 -c "
import json
with open('$AUDIT_FILE') as f:
    d = json.load(f)
i = d.get('issues', {})
dup = len(i.get('duplicates', []))
miss = len(i.get('missing', []))
extra = len(i.get('extra', []))
print(f'Duplicates: {dup}, Missing: {miss}, Extra: {extra}')
" 2>&1)

    {
      echo ""
      echo "=== Notion Sync Audit: DRIFT DETECTED ($AEST_TIMESTAMP) ==="
      echo "  $ISSUES"
      echo "  Report: $AUDIT_FILE"
      echo "  Run: bash scripts/notion-sync-audit.sh for details"
      echo ""
    } >> "$ALERT_FILE"
    log "ALERT: Drift detected — $ISSUES"
  fi
  exit 1
else
  log "All clear — no drift detected"
  exit 0
fi
