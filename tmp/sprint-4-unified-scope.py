import json
from datetime import datetime

# Load all data sources
with open('/Users/ainchorsangiefpl/.openclaw/workspace/state/tickets.json') as f:
    tickets_data = json.load(f)

with open('/Users/ainchorsangiefpl/.openclaw/workspace/state/sprint-current.json') as f:
    sprint_current = json.load(f)

with open('/Users/ainchorsangiefpl/.openclaw/workspace/state/kimi-confidence-mapping.json') as f:
    confidence_data = json.load(f)

with open('/Users/ainchorsangiefpl/.openclaw/workspace/state/sprint-4-planning-notes.json') as f:
    planning_notes = json.load(f)

# Build unified Sprint 4 scope
sprint4_scope = {
    'data_sources': {
        'sprint_current_json': '3 items from sprint-current.json',
        'ken_directive_2026_05_16': 'TKT-0137 + sub-tickets confirmed',
        'kimi_confidence_mapping': f'{len(confidence_data.get("mapping", []))} tickets assessed',
        'tickets_json_sprint4_tag': '18 tickets tagged Sprint 4'
    },
    'unified_items': []
}

# 1. From sprint-current.json (confirmed items)
for item in sprint_current.get('items', []):
    sprint4_scope['unified_items'].append({
        'ticket': item.get('ticket'),
        'title': item.get('title'),
        'owner': item.get('owner'),
        'type': item.get('type'),
        'source': 'sprint-current.json',
        'status': item.get('status'),
        'kimi_confidence': None,
        'execution_order': 1
    })

# 2. From Ken's 2026-05-16 directive
sprint4_scope['unified_items'].append({
    'ticket': 'TKT-0137',
    'title': 'AInchors Policy Register — formal policy library',
    'owner': 'Atlas/Thrawn',
    'type': 'policy',
    'source': 'Ken directive 2026-05-16',
    'status': 'confirmed',
    'kimi_confidence': None,
    'execution_order': 2,
    'sub_tickets': 'AC2-AC9 to be created'
})

# 3. From kimi confidence mapping
for conf in confidence_data.get('mapping', []):
    tkt_id = conf.get('ticket_id')
    for t in tickets_data.get('tickets', []):
        if t.get('id') == tkt_id:
            if t.get('status') in ['open', 'in-progress', 'pending'] and t.get('priority') in ['high', 'critical']:
                existing = [i for i in sprint4_scope['unified_items'] if i['ticket'] == tkt_id]
                if not existing:
                    sprint4_scope['unified_items'].append({
                        'ticket': tkt_id,
                        'title': t.get('title'),
                        'owner': 'TBD',
                        'type': t.get('type', 'task'),
                        'source': 'kimi-confidence-mapping',
                        'status': t.get('status'),
                        'kimi_confidence': conf.get('confidence'),
                        'execution_order': 3 if conf.get('confidence') == 'Full Confidence' else 4
                    })
            break

# 4. From tickets.json Sprint 4 tagged
for t in tickets_data.get('tickets', []):
    if t.get('sprint') in ['Sprint 4', 'S4'] or 'Sprint 4' in str(t.get('notes', '')):
        existing = [i for i in sprint4_scope['unified_items'] if i['ticket'] == t.get('id')]
        if not existing and t.get('status') in ['open', 'in-progress', 'pending']:
            sprint4_scope['unified_items'].append({
                'ticket': t.get('id'),
                'title': t.get('title'),
                'owner': t.get('assignee', 'TBD'),
                'type': t.get('type', 'task'),
                'source': 'tickets.json Sprint 4 tag',
                'status': t.get('status'),
                'kimi_confidence': None,
                'execution_order': 5
            })

# Print comprehensive scope
print("=" * 80)
print("SPRINT 4 UNIFIED SCOPE - All Data Sources Merged")
print("=" * 80)
print()
print("DATA SOURCES:")
for source, desc in sprint4_scope['data_sources'].items():
    print(f"  * {source}: {desc}")
print()
print("-" * 80)
print("UNIFIED SCOPE (by execution order)")
print("-" * 80)
print()

sorted_items = sorted(sprint4_scope['unified_items'], key=lambda x: x['execution_order'])

for i, item in enumerate(sorted_items, 1):
    conf_str = f" | Confidence: {item['kimi_confidence']}" if item['kimi_confidence'] else ""
    print(f"{i}. {item['ticket']}: {item['title'][:50]}...")
    print(f"   Owner: {item['owner']} | Source: {item['source']} | Status: {item['status']}{conf_str}")
    if item.get('sub_tickets'):
        print(f"   Note: {item['sub_tickets']}")
    print()

print("=" * 80)
print(f"TOTAL ITEMS: {len(sorted_items)}")
print("=" * 80)

# Save to state
with open('/Users/ainchorsangiefpl/.openclaw/workspace/state/sprint-4-unified-scope.json', 'w') as f:
    json.dump(sprint4_scope, f, indent=2)

print()
print("Saved to: state/sprint-4-unified-scope.json")
