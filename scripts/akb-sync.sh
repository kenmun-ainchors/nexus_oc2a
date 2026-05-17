#!/usr/bin/env bash
# akb-sync.sh — Sync new/changed Notion AKB pages to local markdown files
# Reads state/akb-sync-state.json for lastSync cursor
# Queries Notion AInchors Backlog for pages edited after lastSync
# Writes markdown files to state/akb-pages/
# Outputs: "changes=N updated=M new=K" on stdout (parsable)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE="$(cd "$SCRIPT_DIR/.." && pwd)"
STATE_FILE="$WORKSPACE/state/akb-sync-state.json"
OUTPUT_DIR="$WORKSPACE/state/akb-pages"
NOTION_KEY="$(cat ~/.config/notion/api_key 2>/dev/null || echo "")"
DATA_SOURCE_ID="34dc1829-53ff-812d-8e43-000b83eb0e7e"

if [ -z "$NOTION_KEY" ]; then
  echo "ERROR: Notion API key not found" >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

# Read last sync time, default to 24h ago
LAST_SYNC="2026-05-17T17:03:00.000Z"
if [ -f "$STATE_FILE" ]; then
  ts=$(python3 -c "import json; d=json.load(open('$STATE_FILE')); print(d.get('lastSync',''))" 2>/dev/null || echo "")
  if [ -n "$ts" ]; then
    LAST_SYNC="$ts"
  fi
fi

# Query Notion for recently edited pages (descending by last_edited_time)
RESP=$(curl -s -X POST "https://api.notion.com/v1/data_sources/$DATA_SOURCE_ID/query" \
  -H "Authorization: Bearer $NOTION_KEY" \
  -H "Notion-Version: 2025-09-03" \
  -H "Content-Type: application/json" \
  -d '{
    "sorts": [{"timestamp": "last_edited_time", "direction": "descending"}],
    "page_size": 50
  }')

# Process response: extract pages edited after LAST_SYNC, write markdown
NEW_COUNT=0
UPDATED_COUNT=0
NOW_UTC=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")
LAST_SYNC_EPOCH=$(date -j -f "%Y-%m-%dT%H:%M:%S" "$(echo "$LAST_SYNC" | sed 's/\..*//')" "+%s" 2>/dev/null || echo 0)

python3 - "$RESP" "$LAST_SYNC" "$OUTPUT_DIR" "$LAST_SYNC_EPOCH" "$NOW_UTC" "$STATE_FILE" << 'PYEOF'
import json, sys, os, re

resp_raw = sys.argv[1]
last_sync = sys.argv[2]
output_dir = sys.argv[3]
last_sync_epoch = int(sys.argv[4])
now_utc = sys.argv[5]
state_file = sys.argv[6]

data = json.loads(resp_raw)
results = data.get('results', [])

new_count = 0
updated_count = 0

for page in results:
    pid = page.get('id', '').replace('-', '')
    edited_time = page.get('last_edited_time', '')
    created_time = page.get('created_time', '')
    
    # Parse edited time epoch for comparison
    edit_ts = edited_time.replace('Z', '').replace('+00:00', '')
    try:
        # Handle possible formats
        edit_clean = edit_ts.split('.')[0] if '.' in edit_ts else edit_ts
        edit_epoch = 0
        import subprocess
        r = subprocess.run(['date', '-j', '-f', '%Y-%m-%dT%H:%M:%S', edit_clean, '+%s'],
                         capture_output=True, text=True)
        if r.returncode == 0:
            edit_epoch = int(r.stdout.strip())
    except:
        edit_epoch = 0
    
    if edit_epoch <= last_sync_epoch:
        continue
    
    # Extract properties
    props = page.get('properties', {})
    title = ''
    title_arr = props.get('US Title', {}).get('title', []) or props.get('Name', {}).get('title', [])
    if isinstance(title_arr, list):
        title = ''.join(t.get('plain_text', '') for t in title_arr)
    
    status = props.get('Status', {}).get('select', {})
    status_name = status.get('name', '') if status else ''
    
    typ = props.get('Type', {}).get('select', {})
    type_name = typ.get('name', '') if typ else ''
    
    priority = props.get('Priority', {}).get('select', {})
    priority_name = priority.get('name', '') if priority else ''
    
    category = props.get('Category', {}).get('select', {})
    category_name = category.get('name', '') if category else ''
    
    sprint = props.get('Sprint', {}).get('select', {})
    sprint_name = sprint.get('name', '') if sprint else ''
    
    created_date = props.get('Created Date', {}).get('date', {})
    created_date_str = created_date.get('start', '') if created_date else ''
    
    notes = props.get('Notes', {}).get('rich_text', [])
    notes_text = ''.join(t.get('plain_text', '') for t in notes) if notes else ''
    
    # Determine if new or updated
    is_new = False
    created_ts = created_time.replace('Z', '').replace('+00:00', '')
    try:
        created_clean = created_ts.split('.')[0] if '.' in created_ts else created_ts
        import subprocess
        r = subprocess.run(['date', '-j', '-f', '%Y-%m-%dT%H:%M:%S', created_clean, '+%s'],
                         capture_output=True, text=True)
        if r.returncode == 0:
            created_epoch = int(r.stdout.strip())
            if created_epoch > last_sync_epoch:
                is_new = True
    except:
        pass
    
    # Sanitize filename
    safe_title = re.sub(r'[^a-zA-Z0-9_-]', '_', title[:60])
    filename = f"{pid[:8]}_{safe_title}.md"
    filepath = os.path.join(output_dir, filename)
    
    # Build markdown content
    md_lines = [
        f"# {title}",
        "",
        f"- **Notion ID:** `{pid}`",
        f"- **Status:** {status_name}",
        f"- **Type:** {type_name}",
        f"- **Priority:** {priority_name}",
        f"- **Category:** {category_name}",
        f"- **Sprint:** {sprint_name}",
        f"- **Created:** {created_date_str}",
        f"- **Last Edited:** {edited_time}",
    ]
    if notes_text:
        md_lines.append("")
        md_lines.append("## Notes")
        md_lines.append("")
        md_lines.append(notes_text)
    md_lines.append("")
    
    # Check if file already exists (for update vs new tracking)
    existed = os.path.exists(filepath)
    
    with open(filepath, 'w') as f:
        f.write('\n'.join(md_lines))
    
    if is_new and not existed:
        new_count += 1
    else:
        updated_count += 1

# Update state file
state = {}
if os.path.exists(state_file):
    with open(state_file) as f:
        state = json.load(f)

state['lastSync'] = now_utc
state['stats'] = state.get('stats', {})
state['stats']['lastRunUpdated'] = updated_count
state['stats']['lastRunNew'] = new_count
state['stats']['totalSynced'] = state['stats'].get('totalSynced', 0) + updated_count + new_count

with open(state_file, 'w') as f:
    json.dump(state, f, indent=2)

# Output parsable result
print(f"changes={updated_count + new_count} updated={updated_count} new={new_count}")
PYEOF

exit 0
