#!/usr/bin/env bash
# asset-review.sh — AInchors Weekly Asset Review
# Reads asset-registry.json, checks file mtimes, flags stale assets,
# updates Notion, and writes a review log.
#
# Usage: bash asset-review.sh
# Schedule: Sunday 17:00 Melbourne time (via OpenClaw cron)
# Owner: Infra Agent / Yoda

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- SKILL GATE: notion ---
source "$SCRIPT_DIR/skill-gate.sh" "notion" || exit $?

WORKSPACE="/Users/ainchorsangiefpl/.openclaw/workspace"
REGISTRY="$WORKSPACE/state/asset-registry.json"
LOG_DIR="$HOME/Backups/ainchors/logs"
LOG_FILE="$LOG_DIR/asset-review.log"
NOTION_KEY_FILE="$HOME/.config/notion/api_key"
TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
DATE_TAG="$(date '+%Y-%m-%d %H:%M %Z')"

# Ensure log dir exists
mkdir -p "$LOG_DIR"

# Load Notion API key
if [[ ! -f "$NOTION_KEY_FILE" ]]; then
  echo "[$TIMESTAMP] ERROR: Notion API key not found at $NOTION_KEY_FILE" | tee -a "$LOG_FILE"
  exit 1
fi
NOTION_KEY="$(cat "$NOTION_KEY_FILE")"

echo "" >> "$LOG_FILE"
echo "========================================" >> "$LOG_FILE"
echo "ASSET REVIEW RUN: $DATE_TAG" >> "$LOG_FILE"
echo "========================================" >> "$LOG_FILE"

# Python script for the heavy lifting
python3 - "$REGISTRY" "$NOTION_KEY" "$TIMESTAMP" "$LOG_FILE" << 'PYEOF'
import json, sys, os, urllib.request, urllib.error, time, subprocess
from datetime import datetime, timezone

registry_path, notion_key, timestamp, log_file = sys.argv[1:]

def log(msg):
    print(msg)
    with open(log_file, "a") as f:
        f.write(msg + "\n")

def get_file_mtime(path):
    """Return file mtime as YYYY-MM-DD string, or None if file not found."""
    try:
        mtime = os.path.getmtime(path)
        return datetime.fromtimestamp(mtime, tz=timezone.utc).strftime("%Y-%m-%d")
    except (OSError, FileNotFoundError):
        return None

def update_notion_page(page_id, status, last_updated, notion_key):
    """Update a Notion page's Status and Last Updated fields."""
    payload = json.dumps({
        "properties": {
            "Status": {"select": {"name": status}},
            "Last Updated": {"date": {"start": last_updated}}
        }
    }).encode()
    
    req = urllib.request.Request(
        f"https://api.notion.com/v1/pages/{page_id}",
        data=payload,
        headers={
            "Authorization": f"Bearer {notion_key}",
            "Notion-Version": "2022-06-28",
            "Content-Type": "application/json"
        },
        method="PATCH"
    )
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            return True
    except urllib.error.HTTPError as e:
        log(f"  Notion update error for {page_id}: HTTP {e.code}")
        return False

# Load registry
with open(registry_path) as f:
    data = json.load(f)

assets = data["assets"]
log(f"Checking {len(assets)} assets...")
log("")

needs_review = []
stale = []
current = []
missing = []

today = datetime.now(tz=timezone.utc).strftime("%Y-%m-%d")

for asset in assets:
    name = asset["name"]
    path = asset["location"]
    last_updated = asset.get("last_updated", "")
    status = asset.get("status", "Current")
    
    mtime = get_file_mtime(path)
    
    if mtime is None:
        log(f"  ⚠  MISSING: {name} (path not found: {path})")
        missing.append(asset)
        continue
    
    # Compare mtime vs last_updated in registry
    if mtime > last_updated:
        log(f"  🔄 NEEDS REVIEW: {name} (file mtime={mtime}, registry last_updated={last_updated})")
        asset["status"] = "Needs Review"
        asset["last_updated"] = mtime
        needs_review.append(asset)
        
        # Update Notion
        if asset.get("notion_page_id"):
            success = update_notion_page(asset["notion_page_id"], "Needs Review", mtime, notion_key)
            if success:
                log(f"     → Notion updated: Status=Needs Review, Last Updated={mtime}")
            time.sleep(0.35)  # rate limit
    else:
        # Check if already stale (status was Stale before run)
        if status == "Stale":
            log(f"  🔴 STALE: {name} (status unchanged)")
            stale.append(asset)
        else:
            current.append(asset)

log("")
log("=== SUMMARY ===")
log(f"  Total assets:    {len(assets)}")
log(f"  Current:         {len(current)}")
log(f"  Needs Review:    {len(needs_review)}")
log(f"  Stale:           {len(stale)}")
log(f"  Missing (path):  {len(missing)}")
log("")

if needs_review:
    log("Assets Needing Review:")
    for a in needs_review:
        log(f"  - {a['name']} ({a['type']}) — Owner: {a['owner']}")
    log("")

if stale:
    log("Stale Assets (escalate to Ken if >2 weeks):")
    for a in stale:
        log(f"  - {a['name']} ({a['type']}) — Owner: {a['owner']}")
    log("")

# Update registry last_reviewed timestamp
data["last_reviewed"] = timestamp

# Write updated registry
tmp = registry_path + ".tmp"
with open(tmp, "w") as f:
    json.dump(data, f, indent=2)
os.rename(tmp, registry_path)

log(f"Registry updated: {registry_path}")
log(f"Review complete: {timestamp}")

# Exit with count of items needing attention for caller
sys.exit(0)
PYEOF

echo "" >> "$LOG_FILE"
echo "Asset review complete. Log: $LOG_FILE"