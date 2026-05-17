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
        'kimi_confidence_mapping': f'{len(confidence_data.get("tickets", {}))} tickets assessed',
        'tickets_json_sprint4_tag': '18 tickets tagged Sprint 4'
    },
    'unified_items': []
}

# Helper: Get ticket details
def get_ticket(tkt_id):
    for t in tickets_data.get('tickets', []):
        if t.get('id') == tkt_id:
            return t
    return None

# Helper: Get confidence level
def get_confidence(tkt_id):
    return confidence_data.get('tickets', {}).get(tkt_id)

# Helper: Get confidence label
def get_confidence_label(level):
    levels = confidence_data.get('levels', {})
    if level in levels:
        return levels[level].get('label', level)
    return level

# 1. From sprint-current.json (confirmed items)
for item in sprint_current.get('items', []):
    tkt_id = item.get('ticket')
    t = get_ticket(tkt_id)
    conf = get_confidence(tkt_id)
    sprint4_scope['unified_items'].append({
        'ticket': tkt_id,
        'title': item.get('title'),
        'owner': item.get('owner'),
        'type': item.get('type'),
        'source': 'sprint-current.json',
        'status': item.get('status'),
        'kimi_confidence': get_confidence_label(conf) if conf else None,
        'execution_order': 1,
        'rationale': 'Committed in sprint-current.json'
    })

# 2. From Ken's 2026-05-16 directive (TKT-0137)
tkt = get_ticket('TKT-0137')
conf = get_confidence('TKT-0137')
sprint4_scope['unified_items'].append({
    'ticket': 'TKT-0137',
    'title': 'AInchors Policy Register — formal policy library',
    'owner': 'Atlas/Thrawn',
    'type': 'policy',
    'source': 'Ken directive 2026-05-16',
    'status': 'confirmed',
    'kimi_confidence': get_confidence_label(conf) if conf else 'Unknown',
    'execution_order': 2,
    'rationale': 'Ken confirmed + sub-tickets AC2-AC9',
    'sub_tickets': 'AC2-AC9 to be created'
})

# 3. From kimi confidence mapping — Sprint 4 execution order
for phase, info in confidence_data.get('executionOrder', {}).items():
    for tkt_id in info.get('tickets', []):
        # Skip if already in list
        existing = [i for i in sprint4_scope['unified_items'] if i['ticket'] == tkt_id]
        if existing:
            continue
        
        t = get_ticket(tkt_id)
        if t and t.get('status') in ['open', 'in-progress', 'pending']:
            conf = get_confidence(tkt_id)
            sprint4_scope['unified_items'].append({
                'ticket': tkt_id,
                'title': t.get('title'),
                'owner': t.get('assignee', 'TBD'),
                'type': t.get('type', 'task'),
                'source': 'kimi-confidence-mapping',
                'status': t.get('status'),
                'kimi_confidence': get_confidence_label(conf) if conf else 'Unknown',
                'execution_order': 3,
                'rationale': f'{phase}: {info.get("focus", "unknown")} confidence'
            })

# 4. From tickets.json Sprint 4 tagged (remaining items not in above)
for t in tickets_data.get('tickets', []):
    tkt_id = t.get('id')
    if t.get('sprint') in ['Sprint 4', 'S4'] or 'Sprint 4' in str(t.get('notes', '')):
        existing = [i for i in sprint4_scope['unified_items'] if i['ticket'] == tkt_id]
        if not existing and t.get('status') in ['open', 'in-progress', 'pending']:
            conf = get_confidence(tkt_id)
            sprint4_scope['unified_items'].append({
                'ticket': tkt_id,
                'title': t.get('title'),
                'owner': t.get('assignee', 'TBD'),
                'type': t.get('type', 'task'),
                'source': 'tickets.json Sprint 4 tag',
                'status': t.get('status'),
                'kimi_confidence': get_confidence_label(conf) if conf else 'Unknown',
                'execution_order': 4,
                'rationale': 'Historical Sprint 4 tag'
            })

# Sort by execution order then by confidence
confidence_order = {'Full Confidence': 0, 'Fairly Confident': 1, 'Low Confidence': 2, 'Blocked': 3, 'Unknown': 4}
sorted_items = sorted(sprint4_scope['unified_items'], 
                      key=lambda x: (x['execution_order'], confidence_order.get(x.get('kimi_confidence', 'Unknown'), 4)))

# Print comprehensive scope
print("=" * 80)
print("SPRINT 4 UNIFIED SCOPE - All Data Sources Merged (CORRECTED)")
print("=" * 80)
print()
print("DATA SOURCES:")
for source, desc in sprint4_scope['data_sources'].items():
    print(f"  * {source}: {desc}")
print()
print(f"Kimi confidence mapping: {len(confidence_data.get('tickets', {}))} tickets with confidence levels")
print()
print("-" * 80)
print("UNIFIED SCOPE (by priority: sprint-current > Ken directive > confidence > historical)")
print("-" * 80)
print()

for i, item in enumerate(sorted_items, 1):
    conf_str = f" | Confidence: {item.get('kimi_confidence', 'Unknown')}" if item.get('kimi_confidence') else ""
    print(f"{i}. {item['ticket']}: {item['title'][:50]}...")
    print(f"   Owner: {item['owner']} | Source: {item['source']} | Status: {item['status']}{conf_str}")
    print(f"   Rationale: {item.get('rationale', '')}")
    if item.get('sub_tickets'):
        print(f"   Note: {item['sub_tickets']}")
    print()

# Count by confidence
from collections import Counter
conf_counts = Counter([i.get('kimi_confidence', 'Unknown') for i in sorted_items])
print("-" * 80)
print("CONFIDENCE DISTRIBUTION:")
for conf, count in sorted(conf_counts.items(), key=lambda x: confidence_order.get(x[0], 99)):
    print(f"  {conf}: {count} tickets")

print()
print("=" * 80)
print(f"TOTAL ITEMS: {len(sorted_items)}")
print("=" * 80)

# Save to state
with open('/Users/ainchorsangiefpl/.openclaw/workspace/state/sprint-4-unified-scope.json', 'w') as f:
    json.dump(sprint4_scope, f, indent=2)

print()
print("Saved to: state/sprint-4-unified-scope.json")
