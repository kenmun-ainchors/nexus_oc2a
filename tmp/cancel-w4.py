import json

with open('/Users/ainchorsangiefpl/.openclaw/workspace/state/linkedin-campaign.json') as f:
    data = json.load(f)

slots = data['drafts']['thisWeek']['slots']
removed = []

# Cancel P2 and P3 (remove from slots, keep P1 as posted for record)
# Actually, cancel ALL remaining — mark P2 and P3 as removed
data['drafts']['thisWeek']['slots'] = [s for s in slots if s['id'] == 'LI-W4-P1-Confidence']
for s in slots:
    if s['id'] != 'LI-W4-P1-Confidence':
        removed.append(s['id'])

# Mark P1 as cancelled-too (Ken wants a full break)
for s in data['drafts']['thisWeek']['slots']:
    if s['id'] == 'LI-W4-P1-Confidence':
        s['cancelledAt'] = '2026-05-26T13:32:00+10:00'
        s['cancelledBy'] = 'Ken Mun'
        s['cancelReason'] = 'Full week cancellation — content quality reset. Contents feeling wishy-washy/no material essence. Fresh restart at Sunday sprint planning.'

data['drafts']['thisWeek']['status'] = 'cancelled'
data['drafts']['thisWeek']['cancelNote'] = 'Ken: Contents starting to feel wishy-washy and consulting-like, no material essence or takeaway. Taking a break this week. Fresh restart at Sunday sprint planning.'
data['lastUpdated'] = '2026-05-26T13:32:00+10:00'

with open('/Users/ainchorsangiefpl/.openclaw/workspace/state/linkedin-campaign.json', 'w') as f:
    json.dump(data, f, indent=2)

print(f"Cancelled: {removed}")
PYEOF
