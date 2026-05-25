#!/bin/zsh
# AInchors Notion Sync Fix — Automated drift remediation
# CHG-0420: Fixes drift between PG state_tickets (SSOT) and Notion AKB Backlog
# Updated: TKT-0296 — Switch data source from tickets.json to PG
# Output: Remediation logs and final audit verification

set -uo pipefail

WORKSPACE="/Users/ainchorsangiefpl/.openclaw/workspace"
STATE="$WORKSPACE/state"
AUDIT_FILE="$STATE/notion-audit-report.json"
NOTION_KEY_FILE="/Users/ainchorsangiefpl/.config/notion/api_key"
NOTION_DB_ID="34dc1829-53ff-814b-8257-d3a3bf351d44"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"; }

if [[ ! -f "$NOTION_KEY_FILE" ]]; then
  log "ERROR: $NOTION_KEY_FILE not found"
  exit 1
fi

if [[ ! -f "$AUDIT_FILE" ]]; then
  log "ERROR: $AUDIT_FILE not found. Run audit script first."
  exit 1
fi

log "Starting Notion sync remediation (PG SSOT)..."

export NOTION_KEY_FILE NOTION_DB_ID AUDIT_FILE WORKSPACE

/opt/homebrew/bin/python3 - << 'PYEOF'
import json, os, sys, time, urllib.request, subprocess

key_file = os.environ['NOTION_KEY_FILE']
with open(key_file) as f:
    key = f.read().strip()

headers = {
    "Authorization": f"Bearer {key}",
    "Notion-Version": "2022-06-28",
    "Content-Type": "application/json",
}

db_id = os.environ['NOTION_DB_ID']
audit_file = os.environ['AUDIT_FILE']
workspace = os.environ['WORKSPACE']

# ── Load tickets from PG (SSOT) ──────────────────────────────────────────
env = os.environ.copy()
env.update({"PGHOST": "/tmp", "PGPORT": "5432", "PGUSER": "ainchorsangiefpl", "PGDATABASE": "ainchors_nexus"})
try:
    result = subprocess.run(
        ["/opt/homebrew/bin/psql", "-t", "-A", "-c", 
         "SELECT jsonb_agg(row_to_json(t)) FROM state_tickets t"],
        capture_output=True, text=True, timeout=10, env=env
    )
    ticket_list = json.loads(result.stdout) if result.stdout and result.stdout != 'null' else []
except Exception:
    # Fallback to JSON
    with open(f"{workspace}/state/tickets.json") as f:
        data = json.load(f)
        ticket_list = data.get('tickets', [])

# Build lookup
tickets_by_id = {}
for t in ticket_list:
    tid = t.get('id')
    if not tid:
        continue
    if tid not in tickets_by_id:
        tickets_by_id[tid] = []
    tickets_by_id[tid].append(t)

# ── Load audit report ────────────────────────────────────────────────────
with open(audit_file) as f:
    audit_report = json.load(f)

issues = audit_report.get('issues', {})
missing_tickets = issues.get('missing', [])
extra_tickets = issues.get('extra', [])

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

# ── Part 1: Fix Missing Tickets (Create in Notion) ────────────────────────
for tkt_id in missing_tickets:
    tkt_list = tickets_by_id.get(tkt_id, [])
    if not tkt_list:
        print(f"Skipping {tkt_id}: Not found in PG", file=sys.stderr)
        continue
    
    tkt = tkt_list[-1]
    title = tkt.get('title', f'[{tkt_id}] Untitled')
    # PG title may not have [TKT-NNNN] prefix — add it
    if not title.startswith('[TKT-'):
        title = f'[{tkt_id}] {title}'
    
    status_name = tkt.get('status', 'open').capitalize()
    print(f"Fixing missing ticket: {tkt_id}...", file=sys.stderr)
    
    payload = {
        "parent": {"database_id": db_id},
        "properties": {
            "US Title": {
                "title": [{"text": {"content": title}}]
            },
            "Status": {
                "select": {"name": status_name}
            }
        }
    }
    
    res = notion_api("pages", data=payload)
    if res and 'id' in res:
        new_page_id = res['id']
        print(f"Successfully created {tkt_id} (Page ID: {new_page_id})", file=sys.stderr)
        # Update PG with notionPageId
        slug = title.replace(' ', '-').replace('[', '').replace(']', '')
        url = f"https://www.notion.so/{slug}-{new_page_id.replace('-', '')}"
        subprocess.run(
            ["/opt/homebrew/bin/psql", "-t", "-A", "-c",
             f"UPDATE state_tickets SET notionpageid='{new_page_id}', url='{url}' WHERE id='{tkt_id}'"],
            capture_output=True, env=env
        )
        time.sleep(0.35)
    else:
        print(f"Failed to create {tkt_id}", file=sys.stderr)

# ── Part 2: Fix Extra (Add to PG if genuinely missing) ────────────────────
for tkt_id in extra_tickets:
    if tkt_id in tickets_by_id:
        continue  # Already in PG

    print(f"Processing extra ticket: {tkt_id}...", file=sys.stderr)
    query_payload = {
        "filter": {
            "property": "US Title",
            "title": {"contains": tkt_id}
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

        # Insert into PG
        seq = tkt_id.replace('TKT-', '') if tkt_id.startswith('TKT-') else '0'
        created = page.get('created_time', '2026-01-01T00:00:00Z')
        subprocess.run(
            ["/opt/homebrew/bin/psql", "-t", "-A", "-c",
             f"INSERT INTO state_tickets (id, title, status, type, priority, sequence, createdat, notionpageid, url) VALUES ('{tkt_id}', '{title}', '{status}', 'task', 'medium', '{seq}', '{created}', '{pid}', 'https://www.notion.so/{title[:50].replace(chr(39), chr(39)+chr(39))}-{pid[:8]}') ON CONFLICT (id) DO UPDATE SET notionpageid=EXCLUDED.notionpageid, url=EXCLUDED.url"],
            capture_output=True, env=env
        )
        print(f"Added extra ticket {tkt_id} to PG", file=sys.stderr)
        time.sleep(0.2)

print("SYNC_COMPLETE")
PYEOF

if [[ $? -eq 0 ]]; then
  log "Remediation complete. Verifying with audit script..."
  bash "$WORKSPACE/scripts/notion-sync-audit.sh"
else
  log "ERROR: Remediation script failed."
  exit 1
fi
