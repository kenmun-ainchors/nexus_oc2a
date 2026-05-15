#!/usr/bin/env python3
"""Task 2: Field sync Sprint/Type/Priority for TKT-0104 to TKT-0157"""

import json
import urllib.request
import time

NOTION_KEY = "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"
TICKETS_PATH = "/Users/ainchorsangiefpl/.openclaw/workspace/state/tickets.json"

HEADERS = {
    "Authorization": f"Bearer {NOTION_KEY}",
    "Notion-Version": "2025-09-03",
    "Content-Type": "application/json"
}

PRIORITY_MAP = {
    "high": "High",
    "medium": "Medium",
    "low": "Low"
}

SPRINT_MAP = {
    1: "Sprint 1", 2: "Sprint 2", 3: "Sprint 3",
    4: "Sprint 4", 5: "Sprint 5", 6: "Sprint 6", 7: "Sprint 7"
}

def patch_page(page_id, properties):
    url = f"https://api.notion.com/v1/pages/{page_id}"
    payload = json.dumps({"properties": properties}).encode()
    req = urllib.request.Request(url, data=payload, headers=HEADERS, method="PATCH")
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return json.loads(resp.read())
    except urllib.error.HTTPError as e:
        err = e.read().decode()
        print(f"  HTTP Error {e.code}: {err[:200]}")
        return None

def main():
    with open(TICKETS_PATH) as f:
        data = json.load(f)
    
    tickets = data["tickets"]
    
    # Filter TKT-0104 to TKT-0157 with notionPageId
    target_ids = {f"TKT-{i:04d}" for i in range(104, 158)}
    targets = [t for t in tickets if t["id"] in target_ids and t.get("notionPageId")]
    
    print(f"Found {len(targets)} tickets to sync fields for")
    
    synced = []
    failed = []
    skipped = []
    
    for ticket in sorted(targets, key=lambda t: t["id"]):
        page_id = ticket["notionPageId"]
        priority = ticket.get("priority")
        sprint_num = ticket.get("sprint")
        ticket_type = ticket.get("type")
        
        properties = {}
        
        # Always set Type=TKT and Priority
        properties["Type"] = {"select": {"name": "TKT"}}
        
        if priority and priority in PRIORITY_MAP:
            properties["Priority"] = {"select": {"name": PRIORITY_MAP[priority]}}
        
        if sprint_num and sprint_num in SPRINT_MAP:
            properties["Sprint"] = {"select": {"name": SPRINT_MAP[sprint_num]}}
        
        sprint_info = f"Sprint {sprint_num}" if sprint_num else "no sprint"
        print(f"Syncing {ticket['id']} (priority={priority}, {sprint_info})...")
        
        result = patch_page(page_id, properties)
        
        if result and result.get("id"):
            print(f"  ✅ Synced")
            synced.append(ticket["id"])
        else:
            print(f"  ❌ FAILED")
            failed.append(ticket["id"])
        
        time.sleep(0.35)  # Rate limit
    
    print(f"\n=== Task 2 Summary ===")
    print(f"Synced: {len(synced)}")
    print(f"Failed: {len(failed)}")
    if failed:
        print(f"Failed IDs: {failed}")

if __name__ == "__main__":
    main()
