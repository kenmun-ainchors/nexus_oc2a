#!/bin/bash
# nother-dedup-sync.sh — Deduplicate Notion pages and backfill notionpageid in PG
# TKT-0392-B
set -euo pipefail

# --- SKILL GATE: notion ---
source "${SCRIPT_DIR:-$(dirname "$0")}/skill-gate.sh" "notion" || exit $?

NOTION_KEY="$(cat ~/.config/notion/api_key)"
BACKLOG_DB="34dc1829-53ff-814b-8257-d3a3bf351d44"
ARCHIVE_DB="364c1829-53ff-818e-a783-ebafcb6a9880"
WORKSPACE="/Users/ainchorsangiefpl/.openclaw/workspace"
OUTFILE="$WORKSPACE/state/notion-dedup-2026-06-10.json"
REPORT=$(mktemp)

echo "{" > "$REPORT"
echo '  "timestamp": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'",' >> "$REPORT"
echo '  "database_id": "'$BACKLOG_DB'",' >> "$REPORT"

echo "=== Step 1: Dump all Notion pages (paginated) ===" >&2

ALL_PAGES="[]"
HAS_MORE=true
START_NEXT=""

while [ "$HAS_MORE" = "true" ]; do
  if [ -z "$START_NEXT" ]; then
    RESP=$(curl -s -X POST "https://api.notion.com/v1/databases/${BACKLOG_DB}/query" \
      -H "Authorization: Bearer ${NOTION_KEY}" \
      -H "Notion-Version: 2022-06-28" \
      -H "Content-Type: application/json" \
      -d '{"page_size": 100}')
  else
    RESP=$(curl -s -X POST "https://api.notion.com/v1/databases/${BACKLOG_DB}/query" \
      -H "Authorization: Bearer ${NOTION_KEY}" \
      -H "Notion-Version: 2022-06-28" \
      -H "Content-Type: application/json" \
      -d '{"page_size": 100, "start_cursor": "'${START_NEXT}'"}')
  fi

  RESULTS=$(echo "$RESP" | python3 -c "import json,sys; d=json.load(sys.stdin); print(json.dumps(d.get('results',[])))" 2>/dev/null)
  ALL_PAGES=$(echo "$ALL_PAGES" | python3 -c "import json,sys; a=json.loads(sys.stdin.read().strip()); b=json.loads('''$RESULTS'''); a.extend(b); print(json.dumps(a))" 2>/dev/null)

  HAS_MORE=$(echo "$RESP" | python3 -c "import json,sys; d=json.load(sys.stdin); print(str(d.get('has_more',False)).lower())" 2>/dev/null)
  START_NEXT=$(echo "$RESP" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('next_cursor','') or '')" 2>/dev/null)

  echo "  Fetched batch... total=$(echo "$ALL_PAGES" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))" 2>/dev/null)" >&2
  sleep 0.35
done

PAGE_COUNT=$(echo "$ALL_PAGES" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))" 2>/dev/null)
echo "  Total pages fetched: $PAGE_COUNT" >&2
echo '  "total_pages_in_notion": '$PAGE_COUNT',' >> "$REPORT"

echo "=== Step 2: Analyze duplicates and build action plan ===" >&2

DUMP_FILE=$(mktemp)
echo "$ALL_PAGES" > "$DUMP_FILE"

ANALYSIS=$(python3 -c "
import json, re, sys

pages = json.load(open('$DUMP_FILE'))
tkt_pattern = re.compile(r'\[(TKT-\d+)\]')

# Group pages by TKT ID
groups = {}
for p in pages:
    title = ''
    props = p.get('properties', {})
    for k, v in props.items():
        if v.get('type') == 'title':
            t = v.get('title', [])
            if t:
                title = t[0].get('plain_text', '')
            break
    
    match = tkt_pattern.search(title)
    if not match:
        continue
    
    tkt_id = match.group(1)
    page_id = p['id']
    archived = p.get('archived', p.get('is_archived', False))
    last_edited = p.get('last_edited_time', '')
    created_time = p.get('created_time', '')
    
    if tkt_id not in groups:
        groups[tkt_id] = []
    groups[tkt_id].append({
        'page_id': page_id,
        'title': title,
        'archived': archived,
        'last_edited': last_edited,
        'created_time': created_time
    })

# Find duplicates
actions = {'archive': [], 'keep': [], 'backfill': [], 'skip': []}

for tkt_id, g in groups.items():
    # Active (non-archived) pages
    active = [p for p in g if not p['archived']]
    
    if len(active) > 1:
        # Sort by last_edited descending
        active.sort(key=lambda x: x['last_edited'], reverse=True)
        winner = active[0]
        dupes = active[1:]
        
        winner['action'] = 'KEEP'
        winner['reason'] = 'latest_edited'
        actions['keep'].append(winner)
        
        for d in dupes:
            d['action'] = 'ARCHIVE'
            d['reason'] = 'duplicate_older'
            actions['archive'].append(d)
    
    elif len(active) == 1:
        # Single active page — check if PG has notionpageid
        actions['backfill'].append({
            'tkt_id': tkt_id,
            'page_id': active[0]['page_id'],
            'title': active[0]['title'],
            'action': 'PENDING_CHECK',
            'reason': 'potential_backfill'
        })
    
    # Archived pages — skip
    for p in g:
        if p['archived']:
            actions['skip'].append(p)

print(json.dumps(actions, indent=2))
" 2>&1)

echo "$ANALYSIS" >&2

echo '  "duplicates_found": '$(echo "$ANALYSIS" | python3 -c "import json,sys; d=json.load(sys.stdin); print(len(d['archive']))" 2>/dev/null)',' >> "$REPORT"
echo '  "unique_tkts_affected": '$(echo "$ANALYSIS" | python3 -c "import json,sys; d=json.load(sys.stdin); s=set(x.get('tkt_id','') for x in d['archive']); print(len(s))" 2>/dev/null)',' >> "$REPORT"
echo '  "potential_backfills": '$(echo "$ANALYSIS" | python3 -c "import json,sys; d=json.load(sys.stdin); print(len(d['backfill']))" 2>/dev/null)',' >> "$REPORT"

echo "=== Step 3: Execute archiving + backfill ===" >&2

ARCHIVED=0
BACKFILLED=0
FAILED_ARCHIVE=0
FAILED_BACKFILL=0
ARCHIVE_DETAILS="[]"

# Archive duplicates
echo "$ANALYSIS" | python3 -c "import json,sys; d=json.load(sys.stdin); [print(x['page_id'],x['tkt_id']) for x in d['archive']]" 2>/dev/null | while read -r PID TKT; do
  sleep 0.35
  RES=$(curl -s -X PATCH "https://api.notion.com/v1/pages/${PID}" \
    -H "Authorization: Bearer ${NOTION_KEY}" \
    -H "Notion-Version: 2022-06-28" \
    -H "Content-Type: application/json" \
    -d '{"archived": true}')
  
  STATUS=$(echo "$RES" | python3 -c "import json,sys; d=json.load(sys.stdin); print('OK' if not d.get('archived') is False else 'FAIL')" 2>/dev/null)
  echo "  ARCHIVE $TKT $PID => $STATUS" >&2
done

# Actually run archiving properly — we need to collect results
echo "$ANALYSIS" | python3 -c "
import json, sys, subprocess, time

data = json.load(sys.stdin)
archive_pages = data['archive']
backfill_candidates = data['backfill']
notion_key = '${NOTION_KEY}'

print(f'ARCHIVE_COUNT={len(archive_pages)}')
print(f'BACKFILL_COUNT={len(backfill_candidates)}')

# Archive duplicates
results = {'archived': [], 'failed_archive': [], 'backfilled': [], 'failed_backfill': [], 'pg_updates': []}

for p in archive_pages:
    pid = p['page_id']
    tkt = p.get('tkt_id', '?')
    time.sleep(0.35)
    
    r = subprocess.run([
        'curl', '-s', '-X', 'PATCH',
        f'https://api.notion.com/v1/pages/{pid}',
        '-H', f'Authorization: Bearer {notion_key}',
        '-H', 'Notion-Version: 2022-06-28',
        '-H', 'Content-Type: application/json',
        '-d', '{\"archived\": true}'
    ], capture_output=True, text=True)
    
    try:
        resp = json.loads(r.stdout)
        if resp.get('archived') is not False:
            results['archived'].append({'page_id': pid, 'tkt_id': tkt, 'title': p.get('title','')})
            print(f'  OK ARCHIVE {tkt} {pid}')
        else:
            results['failed_archive'].append({'page_id': pid, 'tkt_id': tkt})
            print(f'  FAIL ARCHIVE {tkt} {pid}: {r.stdout[:200]}')
    except:
        results['failed_archive'].append({'page_id': pid, 'tkt_id': tkt})
        print(f'  FAIL ARCHIVE {tkt} {pid}: {r.stdout[:200]}')

# Now for backfill: check PG and update
import subprocess as sp
for p in backfill_candidates:
    tkt = p['tkt_id']
    pid = p['page_id']
    time.sleep(0.1)
    
    # Check if PG already has notionpageid
    r = sp.run([
        'bash', '${WORKSPACE}/scripts/db.sh', '-c',
        f\"SELECT COUNT(*) FROM state_tickets WHERE id = '{tkt}' AND notionpageid IS NOT NULL AND notionpageid != '';\"
    ], capture_output=True, text=True)
    
    already_has = r.stdout.strip().split('\n')[-1].strip() if r.stdout else '0'
    
    if already_has == '0':
        # Backfill: update PG
        r2 = sp.run([
            'bash', '${WORKSPACE}/scripts/db.sh', '-c',
            f\"UPDATE state_tickets SET notionpageid = '{pid}' WHERE id = '{tkt}';\"
        ], capture_output=True, text=True)
        
        if r2.returncode == 0:
            results['backfilled'].append({'tkt_id': tkt, 'page_id': pid})
            print(f'  OK BACKFILL {tkt} -> {pid}')
        else:
            results['failed_backfill'].append({'tkt_id': tkt, 'page_id': pid})
            print(f'  FAIL BACKFILL {tkt}: {r2.stderr}')
    else:
        print(f'  SKIP BACKFILL {tkt} — already has notionpageid')
        results['pg_updates'].append({'tkt_id': tkt, 'page_id': pid, 'action': 'skip_already_has_id'})

print('=== RESULTS JSON ===')
print(json.dumps(results, indent=2))
" 2>&1

echo ""
echo "=== Step 4: Verify ===" >&2

# Count remaining duplicates in Notion
VERIFY_RESP=$(curl -s -X POST "https://api.notion.com/v1/databases/${BACKLOG_DB}/query" \
  -H "Authorization: Bearer ${NOTION_KEY}" \
  -H "Notion-Version: 2022-06-28" \
  -H "Content-Type: application/json" \
  -d '{"page_size": 100}')

VERIFY_DUPES=$(echo "$VERIFY_RESP" | python3 -c "
import json, sys, re
d = json.load(sys.stdin)
results = d.get('results', [])
tkt_pat = re.compile(r'\[(TKT-\d+)\]')
page_by_tkt = {}
for p in results:
    title = ''
    for k, v in p.get('properties', {}).items():
        if v.get('type') == 'title' and v.get('title'):
            title = v['title'][0].get('plain_text', '')
            break
    m = tkt_pat.search(title)
    if not m:
        continue
    tkt = m.group(1)
    archived = p.get('archived', p.get('is_archived', False))
    if not archived:
        pos = p.get('last_edited_time', '')
        if tkt not in page_by_tkt:
            page_by_tkt[tkt] = []
        page_by_tkt[tkt].append({'id': p['id'], 'title': title, 'edited': pos})
dups = {k: v for k, v in page_by_tkt.items() if len(v) > 1}
print(f'REMAINING_DUPLICATE_TKTS={len(dups)}')
print(json.dumps(dups, indent=2))
" 2>/dev/null)

echo "$VERIFY_DUPES" >&2

echo ""
echo "=== Step 5: Check PG backfill counts ===" >&2
bash "${WORKSPACE}/scripts/db.sh" -c "SELECT COUNT(*) FROM state_tickets WHERE notionpageid IS NOT NULL AND notionpageid != '';"
bash "${WORKSPACE}/scripts/db.sh" -c "SELECT COUNT(*) FROM state_tickets WHERE notionpageid IS NULL OR notionpageid = '';"

echo ""
echo "=== DONE ===" >&2