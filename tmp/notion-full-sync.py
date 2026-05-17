import json
import urllib.request
from datetime import datetime

# Load data
with open('/Users/ainchorsangiefpl/.openclaw/workspace/state/tickets.json') as f:
    tickets_data = json.load(f)

with open('/Users/ainchorsangiefpl/.openclaw/workspace/state/notion-audit-report.json') as f:
    audit = json.load(f)

NOTION_KEY = open('/Users/ainchorsangiefpl/.config/notion/api_key').read().strip()
HEADERS = {
    "Authorization": f"Bearer {NOTION_KEY}",
    "Notion-Version": "2025-09-03",
    "Content-Type": "application/json",
}

def notion_api(method, path, body=None):
    url = f"https://api.notion.com/v1/{path}"
    data = json.dumps(body).encode() if body else None
    req = urllib.request.Request(url, data=data, headers=HEADERS, method=method)
    try:
        with urllib.request.urlopen(req) as r:
            return json.loads(r.read())
    except urllib.error.HTTPError as e:
        err = e.read().decode()
        print(f"  HTTP {e.code}: {err[:200]}")
        return None
    except Exception as ex:
        print(f"  Error: {ex}")
        return None

# Fetch all Notion pages for TKT IDs
print("Fetching all Notion pages...")
notion_pages = {}
has_more = True
next_cursor = None
while has_more:
    body = {"page_size": 100}
    if next_cursor:
        body["start_cursor"] = next_cursor
    
    req = urllib.request.Request(
        "https://api.notion.com/v1/search",
        data=json.dumps(body).encode(),
        headers=HEADERS,
        method="POST"
    )
    
    try:
        with urllib.request.urlopen(req) as r:
            data = json.loads(r.read())
            for page in data.get('results', []):
                if page.get('object') == 'page':
                    props = page.get('properties', {})
                    title = 'Untitled'
                    if props.get('US Title') and props['US Title'].get('title'):
                        title = props['US Title']['title'][0].get('text', {}).get('content', '')
                    elif props.get('Name') and props['Name'].get('title'):
                        title = props['Name']['title'][0].get('text', {}).get('content', '')
                    
                    if title.startswith('[TKT-'):
                        tkt_id = title.split(']')[0][1:]
                        if tkt_id not in notion_pages:
                            notion_pages[tkt_id] = []
                        notion_pages[tkt_id].append({
                            'page_id': page.get('id'),
                            'title': title,
                            'created_time': page.get('created_time', ''),
                            'properties': props
                        })
            
            has_more = data.get('has_more', False)
            next_cursor = data.get('next_cursor')
    except Exception as e:
        print(f"Error: {e}")
        break

print(f"Found {len(notion_pages)} unique [TKT] IDs in Notion")

# Build tickets lookup
tickets = {t.get('id'): t for t in tickets_data.get('tickets', [])}

actions = {'deleted': 0, 'updated': 0, 'created': 0, 'archived': 0}

# 1. FIX DUPLICATES: Keep newest, archive others
print(f"\n[1/4] Fixing {len(audit['issues']['duplicates'])} duplicates...")
for dup in audit['issues']['duplicates']:
    tkt_id = dup['tkt_id']
    pages = notion_pages.get(tkt_id, [])
    if len(pages) > 1:
        # Sort by created_time, keep newest
        pages.sort(key=lambda x: x['created_time'], reverse=True)
        keep = pages[0]
        archive = pages[1:]
        
        for p in archive:
            # Archive by updating title to [ARCHIVED]
            result = notion_api("PATCH", f"pages/{p['page_id']}", {
                "properties": {
                    "US Title": {"title": [{"text": {"content": f"[ARCHIVED] {p['title']}"}}]},
                    "Status": {"select": {"name": "Done"}}
                }
            })
            if result:
                actions['archived'] += 1
                print(f"  [TKT-{tkt_id}] Archived duplicate: {p['page_id']}")

# 2. FIX STATUS MISMATCHES
print(f"\n[2/4] Fixing {len(audit['issues']['status_mismatch'])} status mismatches...")
status_map = {
    'Open': 'Backlog',
    'In-progress': 'In Progress',
    'Pending': 'Pending',
    'Closed': 'Done',
    'Resolved': 'Done',
    'Blocked': 'Blocked',
    'Done': 'Done'
}
for mismatch in audit['issues']['status_mismatch']:
    tkt_id = mismatch['tkt_id']
    tkt = tickets.get(tkt_id)
    if tkt:
        pages = notion_pages.get(tkt_id, [])
        if pages:
            expected = status_map.get(tkt['status'].capitalize(), tkt['status'].capitalize())
            result = notion_api("PATCH", f"pages/{pages[0]['page_id']}", {
                "properties": {
                    "Status": {"select": {"name": expected}}
                }
            })
            if result:
                actions['updated'] += 1
                print(f"  [TKT-{tkt_id}] Status: {mismatch['notion_status']} -> {expected}")

# 3. CREATE MISSING TICKETS
print(f"\n[3/4] Creating {len(audit['issues']['missing'])} missing tickets...")
for tkt_id in audit['issues']['missing']:
    tkt = tickets.get(tkt_id)
    if tkt:
        n_status = status_map.get(tkt['status'].capitalize(), tkt['status'].capitalize())
        n_priority = tkt.get('priority', 'Medium').capitalize()
        
        result = notion_api("POST", "pages", {
            "parent": {"database_id": "34dc1829-53ff-814b-8257-d3a3bf351d44"},
            "properties": {
                "US Title": {"title": [{"text": {"content": f"[TKT-{tkt_id}] {tkt['title']}"}}]},
                "Status": {"select": {"name": n_status}},
                "Type": {"select": {"name": "TKT"}},
                "Priority": {"select": {"name": n_priority}},
                "Notes": {"rich_text": [{"text": {"content": tkt.get('notes', '')[:2000]}}]}
            }
        })
        if result and result.get('id'):
            actions['created'] += 1
            # Update tickets.json with notionPageId
            for i, t in enumerate(tickets_data.get('tickets', [])):
                if t.get('id') == tkt_id:
                    tickets_data['tickets'][i]['notionPageId'] = result['id']
                    break
            print(f"  [TKT-{tkt_id}] Created in Notion")

# 4. REMOVE EXTRA PAGES
print(f"\n[4/4] Removing {len(audit['issues']['extra'])} extra pages...")
for tkt_id in audit['issues']['extra']:
    pages = notion_pages.get(tkt_id, [])
    for p in pages:
        result = notion_api("PATCH", f"pages/{p['page_id']}", {
            "properties": {
                "US Title": {"title": [{"text": {"content": f"[ORPHAN] {p['title']}"}}]},
                "Status": {"select": {"name": "Done"}}
            }
        })
        if result:
            actions['deleted'] += 1
            print(f"  [TKT-{tkt_id}] Marked orphan: {p['page_id']}")

# Save updated tickets.json
with open('/Users/ainchorsangiefpl/.openclaw/workspace/state/tickets.json', 'w') as f:
    json.dump(tickets_data, f, indent=2)

print(f"\n{'='*60}")
print("NOTION AKB BACKLOG SYNC COMPLETE")
print(f"{'='*60}")
print(f"Archived:  {actions['archived']} duplicates")
print(f"Updated:   {actions['updated']} status fixes")
print(f"Created:   {actions['created']} missing tickets")
print(f"Orphaned:  {actions['deleted']} extra pages")
print(f"{'='*60}")
