#!/usr/bin/env zsh
# drive-sync.sh — Sync key OC1 assets to Google Drive (Ken interim personal repo)
# Tracks synced files via state/drive-sync-state.json — only uploads new/modified files
# Run daily via EOD close cron. Manual: bash scripts/drive-sync.sh [--force] [--section all|journal|memory|docs]

set -uo pipefail

WORKSPACE="/Users/ainchorsoc2a/.openclaw/workspace"
CANVAS="/Users/ainchorsoc2a/.openclaw/canvas/documents"
GOG="$(command -v gog 2>/dev/null || brew --prefix 2>/dev/null)/bin/gog"
GOG_ACCT="kenmun@ainchors.com"
STATE_FILE="$WORKSPACE/state/drive-sync-state.json"

JOURNAL_FOLDER="1WUcG6cdT95FYzSu-bh9S9Jaux4rWRR3z"
MEMORY_FOLDER="1qn7pZaw4akt8a7DDsSoGS55KMsevLFgu"
DOCS_FOLDER="1WsvbM7RbUXBRGKk_izbtWSlQ_z3kjx0t"  # Docs (was Platform Docs)
MARKETING_FOLDER="1rFUZ6-3xRrGK7EKV7CPg7ISQCNRsu8Wo"  # AInchors/Marketing
CANVAS_FOLDER="1sY9qkXiAv8vy3m6E_W2eH73TCOreZKge"  # Docs/Canvas
REVIEW_QUEUE_FOLDER="1w8WhcaoPAXzsgU2epycoIoBag-JWWnKN"  # Review Queue (was Drafts for Ken Review DoD)
SOCIAL_FOLDER="1ATWhL4lRWB1Rf0Y4Y7YVYgeP_CiveK4A"  # Social

FORCE=false
SECTION="all"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --force) FORCE=true; shift ;;
    --section) SECTION="$2"; shift 2 ;;
    *) echo "Unknown: $1" >&2; exit 1 ;;
  esac
done

[[ ! -f "$STATE_FILE" ]] && echo '{"synced":{}}' > "$STATE_FILE"

UPLOADED=0
SKIPPED=0
FAILED=0

# Returns: 0=uploaded, 2=skipped(up-to-date), 1=failed
sync_file() {
  local src="$1" folder="$2" dest_name="${3:-$(basename $1)}"
  [[ ! -f "$src" ]] && return 2

  local key="${src}:${folder}"
  local mtime
  mtime=$(python3 -c "import os; print(int(os.stat('$src').st_mtime))" 2>/dev/null || echo "0")

  local last_mtime
  last_mtime=$(python3 -c "
import json, sys
try:
    d=json.load(open('$STATE_FILE'))
    print(d.get('synced',{}).get(sys.argv[1],'0'))
except: print('0')
" "$key" 2>/dev/null || echo "0")

  if [[ "$FORCE" == "false" && "$last_mtime" == "$mtime" && "$last_mtime" != "0" ]]; then
    return 2  # up to date, skip
  fi

  # Upload (copy to temp with dest_name if renaming)
  local upload_src="$src"
  local tmp=""
  if [[ "$dest_name" != "$(basename $src)" ]]; then
    tmp="/tmp/dsync_$$_${dest_name}"
    cp "$src" "$tmp"
    upload_src="$tmp"
  fi

  local result
  result=$(GOG_ACCOUNT="$GOG_ACCT" "$GOG" drive upload "$upload_src" --parent "$folder" 2>&1)
  [[ -n "$tmp" ]] && rm -f "$tmp"

  if echo "$result" | grep -q "^id"; then
    python3 -c "
import json, datetime
f='$STATE_FILE'
d=json.load(open(f))
d.setdefault('synced','{}')
d['synced']['$key']='$mtime'
d['lastSync']=datetime.datetime.now().astimezone().isoformat()
json.dump(d,open(f,'w'),indent=2)
" 2>/dev/null
    echo "  ✅ $dest_name"
    return 0
  else
    echo "  ❌ FAILED: $dest_name" >&2
    return 1
  fi
}

do_sync() {
  local src="$1" folder="$2" name="${3:-}"
  sync_file "$src" "$folder" "$name"
  local rc=$?
  case $rc in
    0) UPLOADED=$((UPLOADED+1)) ;;
    2) SKIPPED=$((SKIPPED+1)) ;;
    *) FAILED=$((FAILED+1)) ;;
  esac
}

# ── Journals + Blogs ──────────────────────────────────────────────────────────
if [[ "$SECTION" == "journal" || "$SECTION" == "all" ]]; then
  echo "── Journals + Blogs ──"
  for f in "$WORKSPACE/memory/journal-"*.md; do
    [[ -f "$f" ]] && do_sync "$f" "$JOURNAL_FOLDER"
  done
  for dir in "$CANVAS"/ainchors-20[0-9][0-9]-[0-9][0-9]-[0-9][0-9]; do
    [[ -d "$dir" && -f "$dir/index.html" ]] || continue
    date_str=$(basename "$dir" | sed 's/ainchors-//')
    do_sync "$dir/index.html" "$JOURNAL_FOLDER" "blog-${date_str}.html"
  done
fi

# ── Canvas Deliverables (all non-dated canvas folders) ─────────────────────────
if [[ "$SECTION" == "canvas" || "$SECTION" == "all" ]]; then
  echo "── Canvas Deliverables ──"
  # Resolve or create AInchors/Canvas folder in Drive
  CANVAS_FOLDER_ID=$(GOG_ACCOUNT=kenmun@ainchors.com "$GOG" drive ls \
    --query "name='Canvas' and mimeType='application/vnd.google-apps.folder' and '12pzxe8VJXm0L3cppNAZlB-pNdkcfZVtB' in parents" \
    --no-input 2>/dev/null | grep -oE '[A-Za-z0-9_-]{33}' | head -1)
  if [[ -z "$CANVAS_FOLDER_ID" ]]; then
    CANVAS_FOLDER_ID=$(GOG_ACCOUNT=kenmun@ainchors.com "$GOG" drive mkdir "Canvas" \
      --parent "12pzxe8VJXm0L3cppNAZlB-pNdkcfZVtB" --no-input 2>/dev/null | grep -oE '[A-Za-z0-9_-]{33}' | head -1)
  fi
  # Sync all non-dated canvas subfolders (excludes ainchors-YYYY-MM-DD which goes to journal)
  for dir in "$CANVAS"/*/; do
    dirname=$(basename "$dir")
    [[ "$dirname" =~ ^ainchors-20[0-9]{2}-[0-9]{2}-[0-9]{2}$ ]] && continue  # skip dated blogs
    [[ -f "$dir/index.html" ]] || continue
    [[ -n "$CANVAS_FOLDER_ID" ]] && do_sync "$dir/index.html" "$CANVAS_FOLDER_ID" "${dirname}.html"
  done
fi

# ── Marketing Collaterals (TKT-0027) ─────────────────────────────────
if [[ "$SECTION" == "marketing" || "$SECTION" == "all" ]]; then
  echo "── Marketing Collaterals ──"
  MKTG_FOLDER_ID=$(GOG_ACCOUNT=kenmun@ainchors.com "$GOG" drive ls \
    --query "name='Marketing' and mimeType='application/vnd.google-apps.folder' and '12pzxe8VJXm0L3cppNAZlB-pNdkcfZVtB' in parents" \
    --no-input 2>/dev/null | grep -oE '[A-Za-z0-9_-]{33}' | head -1)
  if [[ -z "$MKTG_FOLDER_ID" ]]; then
    MKTG_FOLDER_ID=$(GOG_ACCOUNT=kenmun@ainchors.com "$GOG" drive mkdir "Marketing" \
      --parent "12pzxe8VJXm0L3cppNAZlB-pNdkcfZVtB" --no-input 2>/dev/null | grep -oE '[A-Za-z0-9_-]{33}' | head -1)
  fi
  for f in "$CANVAS/ainchors-marketing/"*.html; do
    [[ -f "$f" && -n "$MKTG_FOLDER_ID" ]] && do_sync "$f" "$MKTG_FOLDER_ID"
  done
fi

# ── Memory + Context ─────────────────────────────────────────────────────────
if [[ "$SECTION" == "memory" || "$SECTION" == "all" ]]; then
  echo "── Memory + Context ──"
  do_sync "$WORKSPACE/MEMORY.md" "$MEMORY_FOLDER"
  for f in "$WORKSPACE/memory/20"[0-9][0-9]-[0-9][0-9]-[0-9][0-9].md; do
    [[ -f "$f" ]] && do_sync "$f" "$MEMORY_FOLDER"
  done
fi

# ── Platform Docs ─────────────────────────────────────────────────────────────
if [[ "$SECTION" == "docs" || "$SECTION" == "all" ]]; then
  echo "── Platform Docs ──"
  for f in \
    "$WORKSPACE/docs/AI_CHARTER_v1.0.md" \
    "$WORKSPACE/docs/AI_GOVERNANCE_FRAMEWORK_v1.0.md" \
    "$WORKSPACE/docs/Agent_Governance_Framework_v1.md" \
    "$WORKSPACE/docs/Model3-Policy.md" \
    "$WORKSPACE/docs/Agent_TOM_Review_2026-05-10.md" \
    "$WORKSPACE/docs/Strategy_to_Backlog_Pipeline_v0.1.md" \
    "$WORKSPACE/docs/DataMemory_P1P4_Roadmap.md" \
    "$WORKSPACE/docs/ainchors-agile-framework-v1.md" \
    "$WORKSPACE/docs/Luthen_Marketing_Intelligence_Agent_v1.md" \
    "$WORKSPACE/docs/Aria_Marketing_Mandate_Addendum_v1.md" \
    "$WORKSPACE/docs/postmortem-INC-20260509-001.md" \
    "$WORKSPACE/docs/TKT-0124-Hybrid-Storage-Amendment.md" \
    "$WORKSPACE/docs/EA-Addendum-Storage-Access-Architecture-v0.1.md" \
    "$WORKSPACE/docs/File-Routing-Policy-v1.0.md" \
    "$WORKSPACE/state/minio-routing-policy.json"; do
    [[ -f "$f" ]] && do_sync "$f" "$DOCS_FOLDER"
  done
fi

echo ""
echo "Drive sync complete — uploaded: $UPLOADED | skipped (up-to-date): $SKIPPED | failed: $FAILED"
