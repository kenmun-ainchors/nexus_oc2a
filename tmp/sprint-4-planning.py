import json
from datetime import datetime, timedelta

# Load tickets
with open('/Users/ainchorsangiefpl/.openclaw/workspace/state/tickets.json') as f:
    tickets_data = json.load(f)

# Load sprint current
with open('/Users/ainchorsangiefpl/.openclaw/workspace/state/sprint-current.json') as f:
    sprint_current = json.load(f)

# Load kimi confidence mapping
with open('/Users/ainchorsangiefpl/.openclaw/workspace/state/kimi-confidence-mapping.json') as f:
    confidence = json.load(f)

# Find Sprint 4 confirmed items
sprint4_tickets = []

# From sprint-current.json
for item in sprint_current.get('items', []):
    sprint4_tickets.append({
        'id': item.get('ticket'),
        'title': item.get('title'),
        'owner': item.get('owner'),
        'type': item.get('type'),
        'status': item.get('status'),
        'source': 'sprint-current.json'
    })

# From TKT-0137 + sub-tickets (Ken confirmed)
tkt0137 = None
for t in tickets_data.get('tickets', []):
    if t.get('id') == 'TKT-0137':
        tkt0137 = t
        break

if tkt0137:
    sprint4_tickets.append({
        'id': 'TKT-0137',
        'title': tkt0137.get('title'),
        'owner': 'Atlas/Thrawn',
        'type': 'policy',
        'status': 'confirmed',
        'source': 'Ken confirmed 2026-05-16'
    })

print("=" * 70)
print("SPRINT 4 PLANNING - May 19-25, 2026")
print("=" * 70)
print()
print(f"Sprint Dates: May 19-25, 2026 (Mon-Sun)")
print(f"Planning: May 17, 2026 (NOW)")
print(f"Theme: {sprint_current.get('theme', 'TBD')}")
print()
print("-" * 70)
print("CONFIRMED SCOPE (Ken approved)")
print("-" * 70)
print()

for i, t in enumerate(sprint4_tickets, 1):
    print(f"{i}. {t['id']}: {t['title'][:55]}")
    print(f"   Owner: {t['owner']} | Type: {t['type']} | Status: {t['status']}")
    print()

print("-" * 70)
print("TKT-0137 SUB-TICKETS (to be created)")
print("-" * 70)
print()
print("Ken confirmed AC2-AC9 sub-tickets under TKT-0137 for Sprint 4.")
print("Policy Register formalization - 7.5 days total across Sprint 4+5.")
print()
print("-" * 70)
print("EXECUTION MODEL (kimi = standup only)")
print("-" * 70)
print()
print("WARNING: Conservative Mode ACTIVE - All agents on kimi interim models")
print("WARNING: Sonnet FALLBACK ONLY - No complex orchestration on kimi")
print()
print("Sprint 4 execution strategy:")
print("- Week 1: Script-heavy tasks (Forge execution, config, infra)")
print("- Week 2: Policy work (Atlas/Thrawn with explicit checkpoints)")
print("- All multi-step work: state-snapshot.sh + diff validation")
print()
print("-" * 70)
print("CEREMONY GATE (NON-NEGOTIABLE)")
print("-" * 70)
print()
print("Sprint 3 ceremonies:")
print("- Friday Sprint Review - COMPLETE (CHG-0356, auto-heal, journal, blog)")
print("- Sunday Sprint Planning - COMPLETE (NOW)")
print()
print("Sprint 4 ceremonies required:")
print("- Friday May 23: Sprint Review")
print("- Sunday May 25: Sprint Planning (Sprint 5)")
print()
print("-" * 70)
print("CAPACITY")
print("-" * 70)
print()
print("Pre-OC2 capacity: 5 tickets/sprint")
print("Current kimi constraint: Script/low-risk work only")
print("P2 hard gates (POL-001-008): DEFERRED to Sprint 4 kickoff")
print()
print("=" * 70)
print("READY TO COMMIT")
print("=" * 70)
