import json

with open('/Users/ainchorsangiefpl/.openclaw/workspace/state/linkedin-campaign.json') as f:
    data = json.load(f)

slots = data['drafts']['thisWeek']['slots']
for slot in slots:
    if slot['id'] == 'LI-W4-P1-Confidence':
        slot['status'] = 'approved'
        slot['imageAssetUrn'] = 'urn:li:image:D5610AQFSf-hlh3m_Zg'
        slot['imageMinioUrl'] = 'http://ainchorss-mac-mini.tail5e2567.ts.net:9000/ainchors-generated-media/social/linkedin/LI-W4-P1/image.jpg'
        slot['imageLocalPath'] = '/Users/ainchorsangiefpl/.openclaw/workspace/workspace-social/images/linkedin/LI-W4-P1/image.jpg'
        slot['imageReceivedAt'] = '2026-05-26T12:57:00+10:00'
        slot['approvedAt'] = '2026-05-26T12:57:00+10:00'
        slot['approvedBy'] = 'Ken Mun (Telegram image approval)'
        slot['slot'] = 'Wed 27 May 12:00 AEST'
        slot['slotNote'] = 'Pushed from Tue 07:30 (missed) → Wed 12:00 per missed-slot rule'
        break

data['lastUpdated'] = '2026-05-26T12:57:00+10:00'

with open('/Users/ainchorsangiefpl/.openclaw/workspace/state/linkedin-campaign.json', 'w') as f:
    json.dump(data, f, indent=2)

print("Done")
