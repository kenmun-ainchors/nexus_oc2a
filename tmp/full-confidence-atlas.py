import json

# Load data
with open('/Users/ainchorsangiefpl/.openclaw/workspace/state/tickets.json') as f:
    tickets_data = json.load(f)

with open('/Users/ainchorsangiefpl/.openclaw/workspace/state/kimi-confidence-mapping.json') as f:
    confidence_data = json.load(f)

# Get Full Confidence items
full_conf = []
for tkt_id, conf_level in confidence_data.get('tickets', {}).items():
    if conf_level == 'full':
        t = None
        for ticket in tickets_data.get('tickets', []):
            if ticket.get('id') == tkt_id:
                t = ticket
                break
        if t and t.get('status') in ['open', 'in-progress', 'pending', 'confirmed']:
            full_conf.append({
                'id': tkt_id,
                'title': t.get('title'),
                'type': t.get('type', 'task'),
                'priority': t.get('priority', 'medium'),
                'status': t.get('status'),
                'assignee': t.get('assignee', 'TBD'),
                'sprint': t.get('sprint', 'None'),
                'notes': t.get('notes', '')[:100]
            })

# Atlas priority categories
def atlas_category(title):
    t = title.lower()
    if any(word in t for word in ['architecture', 'schema', 'design', 'register', 'work type', 'routing', 'sources of truth']):
        return 'Architecture'
    elif any(word in t for word in ['data', 'migration', 'postgres', 'json', 'sources']):
        return 'Data'
    elif any(word in t for word in ['integration', 'cloudflare', 'tunnel', 'api', 'webhook']):
        return 'Integration'
    elif any(word in t for word in ['security', 'policy', 'access', 'compliance', 'audit', 'guard', 'warden']):
        return 'Security'
    elif any(word in t for word in ['infra', 'backup', 'restore', 'monitoring', 'health', 'cron']):
        return 'Infra'
    else:
        return 'Other'

for item in full_conf:
    item['atlas_category'] = atlas_category(item['title'])

# Sort by Atlas priority order
category_order = {'Architecture': 0, 'Data': 1, 'Integration': 2, 'Security': 3, 'Infra': 4, 'Other': 5}
full_conf.sort(key=lambda x: (category_order.get(x['atlas_category'], 99), x['priority'] != 'high', x['id']))

print("=" * 80)
print("FULL CONFIDENCE ITEMS — Prioritized by Atlas Sequence")
print("=" * 80)
print()
print("Atlas Priority: Architecture → Data → Integration → Security → Infra")
print()

current_cat = None
for item in full_conf:
    if item['atlas_category'] != current_cat:
        current_cat = item['atlas_category']
        print()
        print(f"--- {current_cat.upper()} ---")
    
    sprint_marker = f" [Sprint: {item['sprint']}]" if item['sprint'] != 'None' else ""
    print(f"  {item['id']}: {item['title'][:50]}...")
    print(f"    Priority: {item['priority']} | Status: {item['status']} | Assignee: {item['assignee']}{sprint_marker}")

print()
print("=" * 80)
print(f"TOTAL Full Confidence: {len(full_conf)} tickets")
print("=" * 80)

print()
print("ALIGNMENT WITH SPRINT-CURRENT.JSON:")
sprint_current_ids = ['TKT-0196', 'TKT-0197', 'TKT-0187']
for tkt_id in sprint_current_ids:
    conf = confidence_data.get('tickets', {}).get(tkt_id, 'unknown')
    print(f"  {tkt_id}: {conf} confidence")
