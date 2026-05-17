import json
import urllib.request
import time
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

tickets = {t.get('id'): t for t in tickets_data.get('tickets', [])}
status_map = {
    'Open': 'Backlog', 'In-progress': 'In Progress', 'Pending': 'Pending',
    'Closed': 'Done', 'Resolved': 'Done', 'Blocked': 'Blocked', 'Done': 'Done'
}

actions = {'archived': 0, 'updated': 0, 'created': 0, 'orphaned': 0}
errors = []

print("Notion Full Sync — Efficient Mode")
print("=" * 60)

# Fetch all Notion pages once
print("\nFetching all Notion pages...")
notion_pages = {}
has_more = True
next_cursor = None
while has_more:
    time.sleep(0.4)
    req = urllib.request.Request(
        "https://api.notion.com/v1/search",
        data=json.dumps({"page_size": 100, "start_cursor": next_cursor} if next_cursor else {"page_size": 100}).encode(),
        headers=HEADERS, method="POST"
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
                        if tkt_id not in notion_pages:
                            notion_pages[tkt_id] = []
                        notion_pages[tkt_id].append({
                            'page_id': page['id'],
                            'title': title,
                            'created_time': page.get('created_time', ''),
                            'properties': props
                        })
            has_more = data.get('has_more', False)
            next_cursor = data.get('next_cursor')
    except Exception as e:
        errors.append(f"Fetch error: {e}")
        break

print(f"Found {len(notion_pages)} unique [TKT] IDs")

# Helper for API calls with rate limiting
def notion_call(method, path, body=None):
    time.sleep(0.35)  # Rate limit
    url = f"https://api.notion.com/v1/{path}"
    data = json.dumps(body).encode() if body else None
    req = urllib.request.Request(url, data=data, headers=HEADERS, method=method)
    try:
        with urllib.request.urlopen(req) as r:
            return json.loads(r.read())
    except Exception as e:
        return None

# Phase 1: Fix duplicates (keep newest, archive rest)
print("\n[Phase 1] Fixing duplicates...")
for dup in audit['issues']['duplicates']:
    tkt_id = dup['tkt_id']
    pages = notion_pages.get(tkt_id, [])
    if len(pages) > 1:
        pages.sort(key=lambda x: x['created_time'], reverse=True)
        for p in pages[1:]:
            result = notion_call("PATCH", f"pages/{p['page_id']}", {
                "properties": {
                    "US Title": {"title": [{"text": {"content": f"[ARCHIVED] Duplicate of [TKT-{tkt_id}]"}}]},
                    "Status": {"select": {"name": "Done"}}
                }
            })
            if result:
                actions['archived'] += 1
        print(f"  [TKT-{tkt_id}] Archived {len(pages)-1} duplicates")

# Phase 2: Fix status mismatches
print("\n[Phase 2] Fixing status mismatches...")
for mismatch in audit['issues']['status_mismatch']:
    tkt_id = mismatch['tkt_id']
    tkt = tickets.get(tkt_id)
    if tkt:
        expected = status_map.get(tkt['status'].capitalize(), tkt['status'].capitalize())
        pages = notion_pages.get(tkt_id, [])
        if pages:
            result = notion_call("PATCH", f"pages/{pages[0]['page_id']}", {
                "properties": {"Status": {"select": {"name": expected}}}
            })
            if result:
                actions['updated'] += 1
                print(f"  [TKT-{tkt_id}] Status -> {expected}")

# Phase 3: Create missing tickets
print("\n[Phase 3] Creating missing tickets...")
for tkt_id in audit['issues']['missing']:
    tkt = tickets.get(tkt_id)
    if tkt:
        n_status = status_map.get(tkt['status'].capitalize(), tkt['status'].capitalize())
        n_priority = tkt.get('priority', 'Medium').capitalize()
        
        result = notion_call("POST", "pages", {
            "parent": {"database_id": "34dc1829-53ff-814b-8257-d3a3bf351d44"},
            "properties": {
                "US Title": {"title": [{"text": {"content": f"[TKT-{tkt_id}] {tkt['title']}"}}]},
                "Status": {"select": {"name": n_status}},
                "Type": {"select": {"name": "TKT"}},
                "Priority": {"select": {"name": n_priority}}
            }
        })
        if result and result.get('id'):
            actions['created'] += 1
            print(f"  [TKT-{tkt_id}] Created")

# Phase 4: Orphan extra pages
print("\n[Phase 4] Orphaning extra pages...")
for tkt_id in audit['issues']['extra']:
    pages = notion_pages.get(tkt_id, [])
    for p in pages:
        result = notion_call("PATCH", f"pages/{p['page_id']}", {
            "properties": {
                "US Title": {"title": [{"text": {"content": f"[ORPHAN] {p['title']}"}}]},
                "Status": {"select": {"name": "Done"}}
            }
        })
        if result:
            actions['orphaned'] += 1
    if pages:
        print(f"  [TKT-{tkt_id}] Orphaned {len(pages)} pages")

print(f"\n{'='*60}")
print("NOTION AKB BACKLOG SYNC COMPLETE")
print(f"{'='*60}")
print(f"Archived:  {actions['archived']} duplicates")
print(f"Updated:   {actions['updated']} status fixes")
print(f"Created:   {actions['created']} missing tickets")
print(f"Orphaned:  {actions['orphaned']} extra pages")
if errors:
    print(f"Errors:    {len(errors)}")
    for e in errors[:5]:
        print(f"  {e}")
print(f"{'='*60}")
