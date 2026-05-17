import json
import urllib.request
from datetime import datetime

with open('/Users/ainchorsangiefpl/.openclaw/workspace/state/tickets.json') as f:
    tickets_data = json.load(f)

NOTION_KEY = open('/Users/ainchorsangiefpl/.config/notion/api_key').read().strip()
HEADERS = {
    "Authorization": f"Bearer {NOTION_KEY}",
    "Notion-Version": "2025-09-03",
    "Content-Type": "application/json",
}

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
                            'properties': props
                        })
            
            has_more = data.get('has_more', False)
            next_cursor = data.get('next_cursor')
    except Exception as e:
        print(f"Error: {e}")
        break

print(f"Found {len(notion_pages)} unique TKT IDs in Notion")

issues = {'duplicates': [], 'missing': [], 'status_mismatch': [], 'extra': []}

for tkt_id, pages in notion_pages.items():
    if len(pages) > 1:
        issues['duplicates'].append({'tkt_id': tkt_id, 'count': len(pages)})
    
    tkt = None
    for t in tickets_data.get('tickets', []):
        if t.get('id') == tkt_id:
            tkt = t
            break
    
    if tkt:
        notion_status = pages[0]['properties'].get('Status', {}).get('select', {}).get('name', 'Unknown')
        ticket_status = tkt.get('status', 'Unknown').capitalize()
        status_map = {'Open': 'Backlog', 'In-progress': 'In Progress', 'Pending': 'Pending', 
                      'Closed': 'Done', 'Resolved': 'Done', 'Blocked': 'Blocked', 'Done': 'Done'}
        expected_status = status_map.get(ticket_status, ticket_status)
        
        if notion_status != expected_status and notion_status != ticket_status:
            issues['status_mismatch'].append({
                'tkt_id': tkt_id,
                'notion_status': notion_status,
                'ticket_status': ticket_status
            })
    else:
        issues['extra'].append(tkt_id)

for t in tickets_data.get('tickets', []):
    if t.get('status') in ['open', 'in-progress', 'pending']:
        if t.get('id') not in notion_pages:
            issues['missing'].append(t.get('id'))

print("\n" + "=" * 80)
print("NOTION AKB BACKLOG AUDIT REPORT")
print("=" * 80)
print(f"\ntickets.json: {len(tickets_data.get('tickets', []))} tickets")
print(f"Notion pages: {len(notion_pages)} unique TKTs")
print(f"\nDUPLICATES: {len(issues['duplicates'])}")
for d in issues['duplicates'][:5]:
    print(f"  {d['tkt_id']}: {d['count']} pages")

print(f"\nSTATUS MISMATCHES: {len(issues['status_mismatch'])}")
for m in issues['status_mismatch'][:10]:
    print(f"  {m['tkt_id']}: Notion='{m['notion_status']}' | tickets.json='{m['ticket_status']}'")

print(f"\nMISSING: {len(issues['missing'])}")
for m in issues['missing'][:10]:
    print(f"  {m}")

print(f"\nEXTRA: {len(issues['extra'])}")
for e in issues['extra'][:5]:
    print(f"  {e}")

with open('/Users/ainchorsangiefpl/.openclaw/workspace/state/notion-audit-report.json', 'w') as f:
    json.dump({
        'auditDate': datetime.now().astimezone().isoformat(),
        'ticketsJsonCount': len(tickets_data.get('tickets', [])),
        'notionPageCount': len(notion_pages),
        'issues': issues
    }, f, indent=2)

print("\nSaved to: state/notion-audit-report.json")
