#!/usr/bin/env python3
import json
import time
import subprocess
import os
from datetime import datetime, timezone

NOTION_KEY = subprocess.check_output(['cat', os.path.expanduser('~/.config/notion/api_key')]).decode().strip()

# Page ID -> Date mapping
DATE_MAP = {
    "35bc1829-53ff-8163-8486-efa1377f52f5": "2026-05-08",
    "35bc1829-53ff-8180-9ee4-ed01228c9d51": "2026-05-08",
    "35bc1829-53ff-81d6-a8d2-c960a3452adf": "2026-05-08",
    "35bc1829-53ff-81ba-8bef-f6fc93c366e2": "2026-05-08",
    "35bc1829-53ff-81ff-8367-ea1c2932ca1d": "2026-05-08",
    "35bc1829-53ff-8156-8e76-ca35271967a6": "2026-05-08",
    "35bc1829-53ff-81ec-928c-ea14c880b310": "2026-05-04",
    "35ec1829-53ff-81ce-aa96-c3f90a2ef05f": "2026-05-14",
    "360c1829-53ff-815c-8556-d603f5860bbf": "2026-05-14",
    "360c1829-53ff-81f3-8dd6-c614aa87143a": "2026-05-14",
    "360c1829-53ff-81ed-8f8a-eb4c4f6e6408": "2026-05-14",
    "360c1829-53ff-816f-a04c-c4eca21bddfa": "2026-05-14",
    "35ec1829-53ff-8116-af02-e92a45102282": "2026-05-13",
    "35ec1829-53ff-8167-a055-ebeb213cc419": "2026-05-13",
    "35ec1829-53ff-81c7-b3e4-ef0cebbbaf35": "2026-05-13",
    "35ec1829-53ff-8198-958a-c9465afaa551": "2026-05-13",
    "35ec1829-53ff-8129-afac-d913b3e98e8e": "2026-05-13",
    "35ec1829-53ff-819d-a211-dc38f94e1c72": "2026-05-13",
    "35ec1829-53ff-811f-929c-cfcffcff4198": "2026-05-13",
    "35ec1829-53ff-8165-a58a-f4b2bb11f757": "2026-05-13",
    "35ec1829-53ff-8125-afa2-ef468dc6011a": "2026-05-13",
    "35ec1829-53ff-8055-8912-e8de1aa5b763": "2026-05-12",
    "35ec1829-53ff-804b-8cca-d34303cc414e": "2026-05-12",
    "35cc1829-53ff-812c-97fb-c230ffeccda4": "2026-05-11",
    "35cc1829-53ff-81ec-ad33-e4d4a52923b3": "2026-05-11",
    "35bc1829-53ff-81bd-adc4-de163d0e694f": "2026-05-10",
    "35bc1829-53ff-8195-989e-d06f4e046886": "2026-05-09",
    "35bc1829-53ff-81dc-9f0d-d031509513c4": "2026-05-09",
    "35bc1829-53ff-814d-b09e-d1d0ffd04e20": "2026-05-09",
    "359c1829-53ff-8105-892a-cbc9cc473fbb": "2026-05-07",
    "359c1829-53ff-81b4-a134-e796aac3a8a2": "2026-05-07",
    "359c1829-53ff-816f-b5bb-c29fca526584": "2026-05-07",
    "359c1829-53ff-815a-8c06-c60d2e0344ef": "2026-05-07",
    "359c1829-53ff-8177-a011-e81ea0a45d37": "2026-05-07",
    "357c1829-53ff-8107-9a79-e4a7a9e6d7e7": "2026-05-06",
    "356c1829-53ff-8104-a01e-d3617bff59e5": "2026-05-05",
    "355c1829-53ff-8131-a200-c4eafd4dcd12": "2026-05-04",
    "363c1829-53ff-807b-8cfe-ce3ff6656ed2": "2026-05-17",
    "363c1829-53ff-80db-8e97-e45b8bf9e01a": "2026-05-17",
}

REPORT = "/Users/ainchorsangiefpl/.openclaw/workspace/state/notion-created-date-fix.json"
total = len(DATE_MAP)
report = {
    "started": datetime.now(timezone.utc).isoformat(),
    "total": total,
    "success": [],
    "failed": []
}

success_count = 0
failed_count = 0

import urllib.request
import urllib.error

for idx, (page_id, date_val) in enumerate(DATE_MAP.items(), 1):
    print(f"[{idx}/{total}] Updating {page_id} -> {date_val}")
    
    payload = json.dumps({
        "properties": {
            "Created Date": {
                "date": {"start": date_val}
            }
        }
    }).encode()
    
    req = urllib.request.Request(
        f"https://api.notion.com/v1/pages/{page_id}",
        data=payload,
        headers={
            "Authorization": f"Bearer {NOTION_KEY}",
            "Notion-Version": "2025-09-03",
            "Content-Type": "application/json"
        },
        method="PATCH"
    )
    
    try:
        with urllib.request.urlopen(req) as resp:
            resp_body = resp.read().decode()
            status = json.loads(resp_body).get("object")
            if status == "page" or status == "error":
                print(f"  ✓ Success")
                success_count += 1
                report["success"].append({"page_id": page_id, "date": date_val})
            else:
                print(f"  ? Unexpected response: {status}")
    except urllib.error.HTTPError as e:
        err_body = e.read().decode()
        print(f"  ✗ HTTP {e.code}: {err_body[:100]}")
        failed_count += 1
        report["failed"].append({"page_id": page_id, "date": date_val, "error": f"HTTP {e.code}: {err_body[:200]}"})
    except Exception as e:
        print(f"  ✗ Error: {str(e)[:100]}")
        failed_count += 1
        report["failed"].append({"page_id": page_id, "date": date_val, "error": str(e)[:200]})
    
    time.sleep(0.4)

report["completed"] = datetime.now(timezone.utc).isoformat()
report["success_count"] = success_count
report["failed_count"] = failed_count

with open(REPORT, "w") as f:
    json.dump(report, f, indent=2)

print(f"\nDone: {success_count}/{total} succeeded, {failed_count} failed")
print(f"Report: {REPORT}")
