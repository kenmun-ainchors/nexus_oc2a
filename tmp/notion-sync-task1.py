#!/usr/bin/env python3
"""Task 1: Create Notion pages for TKT-0186 to TKT-0199"""

import json
import urllib.request
import urllib.parse
import time

NOTION_KEY = "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"
DB_ID = "34dc1829-53ff-814b-8257-d3a3bf351d44"
TICKETS_PATH = "/Users/ainchorsangiefpl/.openclaw/workspace/state/tickets.json"

HEADERS = {
    "Authorization": f"Bearer {NOTION_KEY}",
    "Notion-Version": "2025-09-03",
    "Content-Type": "application/json"
}

# Status mapping
STATUS_MAP = {
    "open": "Backlog",
    "pending": "Backlog",
    "closed": "Done",
    "done": "Done",
    "resolved": "Done",
    "in-progress": "In Progress",
    "deferred": "Deferred"
}

# Priority mapping
PRIORITY_MAP = {
    "high": "High",
    "medium": "Medium",
    "low": "Low"
}

# Sprint mapping
SPRINT_MAP = {
    1: "Sprint 1",
    2: "Sprint 2",
    3: "Sprint 3",
    4: "Sprint 4",
    5: "Sprint 5",
    6: "Sprint 6",
    7: "Sprint 7"
}

def notion_request(method, path, data=None):
    url = f"https://api.notion.com/v1/{path}"
    body = json.dumps(data).encode() if data else None
    req = urllib.request.Request(url, data=body, headers=HEADERS, method=method)
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return json.loads(resp.read())
    except urllib.error.HTTPError as e:
        err = e.read().decode()
        print(f"HTTP Error {e.code}: {err}")
        return None

def create_page(ticket):
    status_name = STATUS_MAP.get(ticket.get("status", "open"), "Backlog")
    priority_name = PRIORITY_MAP.get(ticket.get("priority", "medium"), "Medium")
    sprint_num = ticket.get("sprint")
    ticket_type = ticket.get("type", "task")
    
    title = f"{ticket['id']}: {ticket['title']}"
    
    properties = {
        "US Title": {
            "title": [{"text": {"content": title[:2000]}}]
        },
        "Status": {
            "select": {"name": status_name}
        },
        "Type": {
            "select": {"name": "TKT"}
        },
        "Priority": {
            "select": {"name": priority_name}
        }
    }
    
    if sprint_num and sprint_num in SPRINT_MAP:
        properties["Sprint"] = {"select": {"name": SPRINT_MAP[sprint_num]}}
    
    payload = {
        "parent": {"database_id": DB_ID},
        "properties": properties
    }
    
    result = notion_request("POST", "pages", payload)
    return result

def main():
    with open(TICKETS_PATH) as f:
        data = json.load(f)
    
    tickets = data["tickets"]
    
    # Filter TKT-0186 to TKT-0199 with null notionPageId
    target_ids = {f"TKT-{i:04d}" for i in range(186, 200)}
    targets = [t for t in tickets if t["id"] in target_ids and not t.get("notionPageId")]
    
    print(f"Found {len(targets)} tickets to create pages for")
    
    created = []
    failed = []
    
    for ticket in sorted(targets, key=lambda t: t["id"]):
        print(f"Creating page for {ticket['id']}: {ticket['title'][:60]}...")
        result = notion_request("POST", "pages", {
            "parent": {"database_id": DB_ID},
            "properties": {
                "US Title": {
                    "title": [{"text": {"content": f"{ticket['id']}: {ticket['title'][:1990]}"}}]
                },
                "Status": {
                    "select": {"name": STATUS_MAP.get(ticket.get("status", "open"), "Backlog")}
                },
                "Type": {
                    "select": {"name": "TKT"}
                },
                "Priority": {
                    "select": {"name": PRIORITY_MAP.get(ticket.get("priority", "medium"), "Medium")}
                },
                **({"Sprint": {"select": {"name": SPRINT_MAP[ticket["sprint"]]}}} if ticket.get("sprint") and ticket["sprint"] in SPRINT_MAP else {})
            }
        })
        
        if result and result.get("id"):
            page_id = result["id"]
            print(f"  ✅ Created: {page_id}")
            created.append({"id": ticket["id"], "pageId": page_id})
            # Update in-memory ticket
            ticket["notionPageId"] = page_id
        else:
            print(f"  ❌ FAILED")
            failed.append(ticket["id"])
        
        time.sleep(0.4)  # Rate limit respect
    
    # Save updated tickets.json
    if created:
        with open(TICKETS_PATH, "w") as f:
            json.dump(data, f, indent=2)
        print(f"\n✅ Saved {len(created)} page IDs to tickets.json")
    
    print(f"\n=== Task 1 Summary ===")
    print(f"Created: {len(created)}")
    print(f"Failed: {len(failed)}")
    if failed:
        print(f"Failed IDs: {failed}")
    for c in created:
        print(f"  {c['id']} → {c['pageId']}")

if __name__ == "__main__":
    main()
