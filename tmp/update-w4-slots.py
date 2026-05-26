import json

with open('/Users/ainchorsangiefpl/.openclaw/workspace/state/linkedin-campaign.json') as f:
    data = json.load(f)

slots = data['drafts']['thisWeek']['slots']

# Add P2
slots.append({
    "id": "LI-W4-P2",
    "slot": "Wed 27 May 12:00 AEST",
    "title": "The Quiet Failures That Kill AI Projects",
    "angle": "Silent degradation, observability gap, operational failures vs. model failures",
    "status": "triad-cleared",
    "draftPath": "/Users/ainchorsangiefpl/.openclaw/workspace/social-drafts/LI-W4-P2.md",
    "createdAt": "2026-05-26T13:27:00+10:00",
    "createdBy": "Spark (kimi)",
    "governance": "Shield CLEAR | Lex CONDITIONAL | Sage CONDITIONAL",
    "note": "Generated via manual trigger after cron fixes"
})

# Add P3
slots.append({
    "id": "LI-W4-P3",
    "slot": "Thu 28 May 07:30 AEST",
    "title": "Why Your AI Rollout Will Stall at 3 Months",
    "angle": "Org adoption, maintenance burden, long-term operational reality vs. demo hype",
    "status": "triad-cleared",
    "draftPath": "/Users/ainchorsangiefpl/.openclaw/workspace/social-drafts/LI-W4-P3.md",
    "createdAt": "2026-05-26T13:27:00+10:00",
    "createdBy": "Spark (kimi)",
    "governance": "Shield CLEAR | Lex CONDITIONAL | Sage CONDITIONAL",
    "note": "Generated via manual trigger after cron fixes"
})

data['lastUpdated'] = '2026-05-26T13:28:00+10:00'

with open('/Users/ainchorsangiefpl/.openclaw/workspace/state/linkedin-campaign.json', 'w') as f:
    json.dump(data, f, indent=2)

print("Slots added: LI-W4-P2 + LI-W4-P3")
