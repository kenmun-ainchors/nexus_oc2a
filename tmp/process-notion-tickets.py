#!/usr/bin/env python3
"""Process Notion tickets and rebuild tickets.json."""
import json
import re
from datetime import datetime

# Load fetched data
with open('/tmp/notion-all-tickets.json') as f:
    pages = json.load(f)

print(f"Processing {len(pages)} Notion pages...")

tickets = []
max_seq = 0
missing_tkt_num = []

for page in pages:
    props = page.get('properties', {})
    
    # Get title from Name property
    name_prop = props.get('Name', {})
    title_parts = name_prop.get('title', [])
    title = title_parts[0].get('plain_text', '') if title_parts else 'Untitled'
    
    # Extract TKT number from title
    tkt_match = re.search(r'TKT-(\d{4})', title)
    tkt_num = int(tkt_match.group(1)) if tkt_match else 0
    
    if tkt_num > 0:
        if tkt_num > max_seq:
            max_seq = tkt_num
    else:
        # Try to extract any number
        num_match = re.search(r'\d{4,}', title)
        if num_match:
            tkt_num = int(num_match.group())
            if tkt_num > max_seq:
                max_seq = tkt_num
        else:
            missing_tkt_num.append(title[:60])
    
    # Get status
    status = 'unknown'
    status_prop = props.get('Status', {})
    if status_prop.get('select'):
        status = status_prop['select'].get('name', 'unknown').lower().replace(' ', '-')
    elif status_prop.get('status'):
        status = status_prop['status'].get('name', 'unknown').lower().replace(' ', '-')
    
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

# Sort by sequence
valid_tickets = [t for t in tickets if t['sequence'] > 0]
valid_tickets.sort(key=lambda x: x['sequence'])

print(f"\n=== PROCESSING RESULTS ===")
print(f"Valid tickets with TKT numbers: {len(valid_tickets)}")
print(f"Highest sequence: {max_seq}")
print(f"Missing TKT numbers: {len(missing_tkt_num)}")

if missing_tkt_num:
    print(f"\nSample titles without TKT numbers:")
    for t in missing_tkt_num[:5]:
        print(f"  - {t}")

# Show range
if valid_tickets:
    print(f"\nRange: {valid_tickets[0]['id']} to {valid_tickets[-1]['id']}")
    
    print(f"\n=== LAST 10 TICKETS ===")
    for t in valid_tickets[-10:]:
        print(f"  {t['id']}: {t['title'][:60]}")
        print(f"    Status: {t['status']}, Priority: {t['priority']}, Type: {t['type']}")

# Build the output structure
output = {
    'schema_version': '1.0',
    'sequence': max_seq,
    'lastUpdated': datetime.now().isoformat(),
    'source': 'notion-akb-backlog-rebuild',
    'ticketCount': len(valid_tickets),
    'tickets': valid_tickets
}

# Save
with open('/tmp/rebuilt-tickets.json', 'w') as f:
    json.dump(output, f, indent=2)

print(f"\n✅ Saved to /tmp/rebuilt-tickets.json")
print(f"File size: {len(json.dumps(output))} bytes")

# Verify by loading it back
with open('/tmp/rebuilt-tickets.json') as f:
    verify = json.load(f)
print(f"✅ JSON valid: {len(verify['tickets'])} tickets, seq={verify['sequence']}")
