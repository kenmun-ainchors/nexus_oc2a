#!/usr/bin/env python3
"""Fetch all tickets from Notion AKB Backlog database."""
import json
import requests

NOTION_KEY = open('/Users/ainchorsangiefpl/.config/notion/api_key').read().strip()
DB_ID = "34dc1829-53ff-814b-8257-d3a3bf351d44"

headers = {
    "Authorization": f"Bearer {NOTION_KEY}",
    "Notion-Version": "2022-06-28",
    "Content-Type": "application/json"
}

all_results = []
has_more = True
next_cursor = None
page = 0

while has_more and page < 10:  # Safety limit
    page += 1
    payload = {"page_size": 100}
    if next_cursor:
        payload["start_cursor"] = next_cursor
    
    resp = requests.post(
        f"https://api.notion.com/v1/databases/{DB_ID}/query",
        headers=headers,
        json=payload
    )
    data = resp.json()
    
    results = data.get('results', [])
    all_results.extend(results)
    
    has_more = data.get('has_more', False)
    next_cursor = data.get('next_cursor')
    
    print(f"Page {page}: {len(results)} results (total: {len(all_results)})")
    
    if not has_more:
        break

# Save all results
with open('/tmp/notion-all-tickets.json', 'w') as f:
    json.dump(all_results, f)

print(f"\n✅ Total tickets fetched: {len(all_results)}")
