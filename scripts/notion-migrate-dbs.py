#!/usr/bin/env python3 -u
"""Migrate Notion pages from AKB Backlog (A) → B (Auto-Heal) and C (Completed-Archived)"""
import json, time, sys, os

NOTION_KEY = open(os.path.expanduser("~/.config/notion/api_key")).read().strip()
API_VER = "2022-06-28"
DB_A = "34dc1829-53ff-814b-8257-d3a3bf351d44"
DB_B = "364c1829-53ff-81c0-9dbd-ff2c907d1a6b"
DB_C = "364c1829-53ff-818e-a783-ebafcb6a9880"

HEADERS = {
    "Authorization": f"Bearer {NOTION_KEY}",
    "Notion-Version": API_VER,
    "Content-Type": "application/json"
}

import urllib.request

def api(method, url, data=None):
    req = urllib.request.Request(url, data=json.dumps(data).encode() if data else None,
                                  headers=HEADERS, method=method)
    try:
        resp = urllib.request.urlopen(req)
        return json.loads(resp.read())
    except urllib.error.HTTPError as e:
        return json.loads(e.read())

def query_pages(db_id, filter_obj, page_size=100):
    """Get all pages matching filter"""
    all_pages = []
    cursor = None
    while True:
        body = {"filter": filter_obj, "page_size": page_size}
        if cursor:
            body["start_cursor"] = cursor
        resp = api("POST", f"https://api.notion.com/v1/databases/{db_id}/query", body)
        pages = resp.get("results", [])
        all_pages.extend(pages)
        cursor = resp.get("next_cursor")
        if not cursor or not pages:
            break
    return all_pages

def move_to_db(pages, target_db, status_map=None):
    """Move pages to target DB by recreating them. Returns count moved."""
    moved = 0
    for page in pages:
        props = page.get("properties", {})
        title_prop = props.get("US Title", props.get("Title", {}))
        title = ""
        if title_prop.get("title"):
            title = title_prop["title"][0]["text"]["content"]
        elif title_prop.get("rich_text"):
            title = title_prop["rich_text"][0]["text"]["content"]
        
        original_status = (props.get("Status") or {}).get("select") or {}
        original_status = original_status.get("name", "unknown") if original_status else "unknown"
        original_type = (props.get("Type") or {}).get("select") or {}
        original_type = original_type.get("name", "unknown") if original_type else "unknown"
        original_priority = (props.get("Priority") or {}).get("select") or {}
        original_priority = original_priority.get("name", "Medium") if original_priority else "Medium"
        
        # Determine new properties based on target DB
        new_title = title
        
        if target_db == DB_B:
            # Auto-Heal DB
            new_props = {
                "Title": {"title": [{"text": {"content": new_title[:2000]}}]},
                "Status": {"select": {"name": "Open"}},
                "Date": {"date": {"start": page.get("created_time", "")[:10]}},
                "Category": {"select": {"name": "Other"}},
                "Description": {"rich_text": [{"text": {"content": f"Migrated from AKB Backlog. Original status: {original_status}"[:2000]}}]}
            }
        else:
            # Archived DB
            new_props = {
                "Title": {"title": [{"text": {"content": new_title[:2000]}}]},
                "Original ID": {"rich_text": [{"text": {"content": new_title[:2000]}}]},
                "Type": {"select": {"name": "AUTO-HEAL" if "[AUTO-HEAL]" in title else (original_type if original_type else "TKT")}},
                "Status": {"select": {"name": "Archived"}},
                "Priority": {"select": {"name": original_priority if original_priority in ("High","Medium","Low") else "Medium"}},
                "Completed Date": {"date": {"start": page.get("last_edited_time", "")[:10]}},
                "Description": {"rich_text": [{"text": {"content": f"Archived from AKB Backlog. Original status: {original_status}, Type: {original_type}"[:2000]}}]}
            }
        
        # Create in target DB
        create_body = {
            "parent": {"database_id": target_db},
            "properties": new_props
        }
        
        resp = api("POST", "https://api.notion.com/v1/pages", create_body)
        if resp.get("id"):
            moved += 1
            if moved % 10 == 0:
                print(f"  Moved {moved} pages so far...")
        else:
            print(f"  FAILED: {new_title[:60]} — {resp.get('message', 'unknown error')}")
        
        time.sleep(0.25)  # Rate limit: ~4 req/sec
    
    return moved

# ── PHASE 1: Move AUTO-HEAL pages → B ──
print("=== PHASE 1: Moving [AUTO-HEAL] pages from A → B ===")
autoheal_pages = query_pages(DB_A, {"property": "US Title", "title": {"contains": "[AUTO-HEAL]"}})
print(f"Found {len(autoheal_pages)} AUTO-HEAL pages in DB A")
moved_b = move_to_db(autoheal_pages, DB_B)
print(f"Moved {moved_b} AUTO-HEAL pages to DB B")

# ── PHASE 2: Move ALL Done pages → C ──
print("\n=== PHASE 2: Moving Done pages from A → C ===")
done_pages = query_pages(DB_A, {"property": "Status", "select": {"equals": "Done"}})
print(f"Found {len(done_pages)} Done pages in DB A")
moved_c = move_to_db(done_pages, DB_C)
print(f"Moved {moved_c} Done pages to DB C")

# ── SUMMARY ──
print(f"\n=== MIGRATION COMPLETE ===")
print(f"DB B (Auto-Heal): {moved_b} pages migrated")
print(f"DB C (Archived):  {moved_c} pages migrated")
print(f"Total migrated:   {moved_b + moved_c}")
