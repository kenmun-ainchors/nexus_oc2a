#!/usr/bin/env python3
"""Process Notion tickets and rebuild tickets.json - CORRECTED."""
import json
import re
from datetime import datetime

# Load fetched data
with open('/tmp/notion-all-tickets.json') as f:
    pages = json.load(f)

print(f"Processing {len(pages)} Notion pages...")

tickets = []
chg_records = []
max_tkt_seq = 0
max_chg_seq = 0

for page in pages:
    props = page.get('properties', {})
    
    # Find the title property (it's the one with type='title')
    title = ''
    for prop_name, prop_val in props.items():
        if prop_val.get('type') == 'title':
            title_parts = prop_val.get('title', [])
            if title_parts:
                title = title_parts[0].get('plain_text', '')
            break
    
    if not title:
        continue
    
    # Extract TKT or CHG number
    tkt_match = re.search(r'\[TKT-(\d{4})\]', title)
    chg_match = re.search(r'\[CHG-(\d{4})\]', title)
    
    # Get status from Status property
    status = 'unknown'
    status_prop = props.get('Status', {})
    if status_prop.get('status'):
        status = status_prop['status'].get('name', 'unknown').lower().replace(' ', '-')
    elif status_prop.get('select'):
        status = status_prop['select'].get('name', 'unknown').lower().replace(' ', '-')
    
    # Get priority
    priority = 'unknown'
    priority_prop = props.get('Priority', {})
    if priority_prop.get('select'):
        priority = priority_prop['select'].get('name', 'unknown').lower()
    
    # Get type
    ticket_type = 'unknown'
    type_prop = props.get('Type', {})
    if type_prop.get('select'):
        ticket_type = type_prop['select'].get('name', 'unknown').lower()
    
    # Get created time
    created = page.get('created_time', datetime.now().isoformat())
    
    if tkt_match:
        tkt_num = int(tkt_match.group(1))
        if tkt_num > max_tkt_seq:
            max_tkt_seq = tkt_num
        
        tickets.append({
            'id': f'TKT-{tkt_num:04d}',
            'sequence': tkt_num,
            'title': title,
            'status': status,
            'priority': priority,
            'type': ticket_type,
            'createdAt': created,
            'notionPageId': page.get('id', ''),
            'url': page.get('url', '')
        })
    
    elif chg_match:
        chg_num = int(chg_match.group(1))
        if chg_num > max_chg_seq:
            max_chg_seq = chg_num
        
        chg_records.append({
            'id': f'CHG-{chg_num:04d}',
            'sequence': chg_num,
            'title': title,
            'status': status,
            'priority': priority,
            'type': 'change',
            'createdAt': created,
            'notionPageId': page.get('id', ''),
            'url': page.get('url', '')
        })

# Sort by sequence
tickets.sort(key=lambda x: x['sequence'])
chg_records.sort(key=lambda x: x['sequence'])

print(f"\n=== PROCESSING RESULTS ===")
print(f"Tickets (TKT-): {len(tickets)}")
print(f"Changes (CHG-): {len(chg_records)}")
print(f"Highest TKT: {max_tkt_seq}")
print(f"Highest CHG: {max_chg_seq}")

if tickets:
    print(f"\nRange: {tickets[0]['id']} to {tickets[-1]['id']}")
    
    print(f"\n=== LAST 10 TICKETS ===")
    for t in tickets[-10:]:
        print(f"  {t['id']}: {t['title'][:70]}")
        print(f"    Status: {t['status']}, Priority: {t['priority']}")

if chg_records:
    print(f"\n=== LAST 5 CHANGES ===")
    for c in chg_records[-5:]:
        print(f"  {c['id']}: {c['title'][:70]}")

# Build the output structure
output = {
    'schema_version': '1.0',
    'sequence': max_tkt_seq,
    'lastUpdated': datetime.now().isoformat(),
    'source': 'notion-akb-backlog-rebuild',
    'ticketCount': len(tickets),
    'changeCount': len(chg_records),
    'tickets': tickets,
    'changes': chg_records
}

# Save
with open('/tmp/rebuilt-tickets.json', 'w') as f:
    json.dump(output, f, indent=2)

print(f"\n✅ Saved to /tmp/rebuilt-tickets.json")
print(f"File size: {len(json.dumps(output))} bytes")

# Verify by loading it back
with open('/tmp/rebuilt-tickets.json') as f:
    verify = json.load(f)
print(f"✅ JSON valid: {len(verify['tickets'])} tickets, {len(verify['changes'])} changes, seq={verify['sequence']}")
