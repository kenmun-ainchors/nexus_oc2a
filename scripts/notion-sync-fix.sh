#!/bin/zsh
# AInchors Notion Sync Fix — Automated drift remediation
# CHG-0420: Fixes drift between tickets.json and Notion AKB Backlog
# Output: Remediation logs and final audit verification
# References: L-035

set -uo pipefail

WORKSPACE="/Users/ainchorsangiefpl/.openclaw/workspace"
STATE="$WORKSPACE/state"
TICKET_FILE="$STATE/tickets.json"
AUDIT_FILE="$STATE/notion-audit-report.json"
NOTION_KEY_FILE="/Users/ainchorsangiefpl/.config/notion/api_key"
# Notion DB ID (Create)
NOTION_DB_ID="34dc1829-53ff-814b-8257-d3a3bf351d44"

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

if [[ ! -f "$AUDIT_FILE" ]]; then
  log "ERROR: $AUDIT_FILE not found. Run audit script first."
  exit 1
fi

log "Starting Notion sync remediation..."

export NOTION_KEY_FILE NOTION_DB_ID TICKET_FILE AUDIT_FILE

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

# ── Load data ──────────────────────────────────────────────────────────────
with open(ticket_file) as f:
    tickets_data = json.load(f)

with open(audit_file) as f:
    audit_report = json.load(f)

issues = audit_report.get('issues', {})
missing_tickets = issues.get('missing', [])
duplicate_issues = issues.get('duplicates', [])
extra_tickets = issues.get('extra', [])

# To handle duplicate IDs in tickets.json, we map IDs to lists of tickets
tickets_by_id = {}
for t in tickets_data.get('tickets', []):
    tid = t['id']
    if tid not in tickets_by_id:
        tickets_by_id[tid] = []
    tickets_by_id[tid].append(t)

def notion_api(endpoint, method="POST", data=None):
    url = f"https://api.notion.com/v1/{endpoint}"
    req_data = json.dumps(data).encode() if data else None
    req = urllib.request.Request(url, data=req_data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req) as r:
            return json.loads(r.read())
    except Exception as e:
        print(f"API Error: {e}", file=sys.stderr)
        return None

# ── Part 1: Fix Missing Tickets (Create in Notion) ──────────────────────────
for tkt_id in missing_tickets:
    tkt_list = tickets_by_id.get(tkt_id, [])
    if not tkt_list:
        print(f"Skipping {tkt_id}: Not found in tickets.json", file=sys.stderr)
        continue
    
    # If multiple exist, we only create one for the most recent/relevant (last in list)
    tkt = tkt_list[-1]
    print(f"Fixing missing ticket: {tkt_id}...", file=sys.stderr)
    
    payload = {
        "parent": {"database_id": db_id},
        "properties": {
            "US Title": {
                "title": [
                    {"text": {"content": tkt.get('title', f"[{tkt_id}] Untitled")}}
                ]
            },
            "Status": {
                "select": {"name": tkt.get('status', 'backlog').capitalize()}
            }
        }
    }
    
    res = notion_api("pages", data=payload)
    if res and 'id' in res:
        new_page_id = res['id']
        print(f"Successfully created {tkt_id} (Page ID: {new_page_id})", file=sys.stderr)
        tkt['notionPageId'] = new_page_id
        slug = tkt['title'].replace(' ', '-').replace('[', '').replace(']', '')
        tkt['url'] = f"https://www.notion.so/{slug}-{new_page_id.replace('-', '')}"
    else:
        print(f"Failed to create {tkt_id}", file=sys.stderr)

# ── Part 2: Fix Duplicates (Archive/Delete) ─────────────────────────────────
for dup in duplicate_issues:
    tkt_id = dup['tkt_id']
    pages = dup['pages']
    
    # Find the current active page id for this ticket from local state
    target_page_id = None
    tkt_list = tickets_by_id.get(tkt_id, [])
    for t in tkt_list:
        if t.get('notionPageId'):
            target_page_id = t['notionPageId']
            break
    
    for pid in pages:
        if pid == target_page_id:
            continue
        print(f"Archiving duplicate page {pid} for {tkt_id}...", file=sys.stderr)
        notion_api(f"pages/{pid}", method="PATCH", data={"archived": True})

# ── Part 3: Fix Extra (Add to tickets.json) ─────────────────────────────────
for tkt_id in extra_tickets:
    print(f"Processing extra ticket: {tkt_id}...", file=sys.stderr)
    query_payload = {
        "filter": {
            "property": "US Title",
            "title": { "contains": tkt_id }
        }
    }
    res = notion_api(f"databases/{db_id}/query", data=query_payload)
    if res and res.get('results'):
        page = res['results'][0]
        pid = page['id']
        props = page.get('properties', {})
        title = ""
        if props.get('US Title') and props['US Title'].get('title'):
            title = props['US Title']['title'][0].get('text', {}).get('content', '')
        
        status = "backlog"
        if props.get('Status') and props['Status'].get('select'):
            status = props['Status']['select']['name'].lower()

        new_tkt = {
            "id": tkt_id,
            "sequence": 0,
            "title": title,
            "status": status,
            "priority": "medium",
            "type": "tkt",
            "createdAt": page.get('created_time', '2026-01-01T00:00:00Z'),
            "notionPageId": pid,
            "url": f"https://www.notion.so/{title.replace(' ', '-').replace('[', '').replace(']', '')}-{pid.replace('-', '')}"
        }
        tickets_data['tickets'].append(new_tkt)
        print(f"Added extra ticket {tkt_id} to local state", file=sys.stderr)

# Save updated tickets.json
with open(ticket_file, 'w') as f:
    json.dump(tickets_data, f, indent=2)

PYEOF

if [[ $? -eq 0 ]]; then
  log "Remediation complete. Verifying with audit script..."
  /Users/ainchorsangiefpl/.openclaw/workspace/scripts/notion-sync-audit.sh
  if [[ $? -eq 0 ]]; then
    log "VERIFIED: Notion sync is now clean (0 drift)."
  else
    log "WARNING: Audit still reports drift after fix."
  fi
else
  log "ERROR: Remediation script failed."
  exit 1
fi
