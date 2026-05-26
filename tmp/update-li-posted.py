import json

with open('/Users/ainchorsangiefpl/.openclaw/workspace/state/linkedin-campaign.json') as f:
    data = json.load(f)

slots = data['drafts']['thisWeek']['slots']
for slot in slots:
    if slot['id'] == 'LI-W4-P1-Confidence':
        slot['status'] = 'posted'
        slot['postedAt'] = '2026-05-26T13:10:00+10:00'
        slot['postedBy'] = 'Yoda (manual fix — Spark posted wrong content+broken formatting, deleted, reposted correctly)'
        slot['note'] = 'Broken post (old draft + literal \\n escapes) deleted via UGC API. Correct draft (social-drafts/LI-W4-P1-Confidence.md) reposted with correct image. URN capture failed — linkedin-post.sh bug (headers not captured). Script fixed in this same session.'
        break

data['lastUpdated'] = '2026-05-26T13:12:00+10:00'

with open('/Users/ainchorsangiefpl/.openclaw/workspace/state/linkedin-campaign.json', 'w') as f:
    json.dump(data, f, indent=2)

print("Campaign state updated → posted")
