#!/bin/bash
# pg-json-reconcile.sh — Reconcile tickets.json from PG (SSOT → JSON fallback sync)
# TKT-0268: Periodic reconciliation job
# Usage: bash scripts/pg-json-reconcile.sh [--dry-run]
# Exit codes: 0=OK (no changes or sync applied), 1=ERROR

set -euo pipefail

WORKSPACE="/Users/ainchorsangiefpl/.openclaw/workspace"
TICKETS_FILE="$WORKSPACE/state/tickets.json"
BACKUP_DIR="$WORKSPACE/state/archive/reconcile-backups"
LOG_FILE="$WORKSPACE/state/reconcile-log.json"
DRY_RUN=false

[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

mkdir -p "$BACKUP_DIR"

# --- Helper: query PG for all tickets ---
dump_pg_tickets() {
  /opt/homebrew/bin/psql -h localhost -p 5432 -d ainchors_nexus -t -A -F '|' <<'SQL'
SELECT 
  id,
  sequence,
  title,
  status,
  priority,
  type,
  created_at,
  notionpageid,
  url,
  COALESCE(tags::text, '[]'),
  COALESCE(metadata::text, '{}')
FROM state_tickets
ORDER BY sequence::int ASC;
SQL
}

# --- Counts ---
PG_COUNT=$(/opt/homebrew/bin/psql -h localhost -p 5432 -d ainchors_nexus -t -c "SELECT count(*) FROM state_tickets;" 2>/dev/null | tr -d '[:space:]')
PG_COUNT=${PG_COUNT:-0}

if [[ -f "$TICKETS_FILE" ]]; then
  FILE_COUNT=$(python3 -c "
import json
with open('$TICKETS_FILE') as f:
    data = json.load(f)
if isinstance(data, list) and len(data) == 1 and 'tickets' in data[0]:
    print(len(data[0]['tickets']))
elif isinstance(data, dict) and 'tickets' in data:
    print(len(data['tickets']))
else:
    print(0)
" 2>/dev/null | tr -d '[:space:]')
  FILE_COUNT=${FILE_COUNT:-0}
else
  FILE_COUNT=0
fi

GAP=$((PG_COUNT - FILE_COUNT))

echo "=== PG→JSON Reconcile $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
echo "PG: $PG_COUNT | FILE: $FILE_COUNT | GAP: $GAP"

if [[ "$GAP" -eq 0 ]]; then
  echo "RESULT: in_sync — no reconciliation needed"
  exit 0
fi

if [[ "$GAP" -lt 0 ]]; then
  echo "WARNING: FILE has MORE records than PG ($((-GAP)) extra). This is unexpected — PG is SSOT."
  echo "RESULT: file_ahead — manual investigation recommended, not auto-reconciling"
  exit 1
fi

echo "GAP: $GAP records in PG not in JSON file. Reconciling..."

# --- Back up current JSON before overwriting ---
if [[ -f "$TICKETS_FILE" ]]; then
  BACKUP_PATH="$BACKUP_DIR/tickets-$(date +%Y%m%d-%H%M%S).json"
  cp "$TICKETS_FILE" "$BACKUP_PATH"
  echo "Backup: $BACKUP_PATH"
fi

# --- Parse PG output into JSON ---
if $DRY_RUN; then
  echo "DRY RUN — would reconcile $GAP records. Not modifying files."
  
  # Show which tickets are PG-only
  echo ""
  echo "=== PG-Only Tickets (not in JSON) ==="
  # Get PG IDs
  PG_IDS=$(/opt/homebrew/bin/psql -h localhost -p 5432 -d ainchors_nexus -t -A -c "SELECT id FROM state_tickets ORDER BY sequence::int ASC;" 2>/dev/null)
  # Get JSON IDs
  JSON_IDS=$(python3 -c "
import json
with open('$TICKETS_FILE') as f:
    data = json.load(f)
tickets = data[0]['tickets'] if isinstance(data, list) else data.get('tickets', [])
for t in tickets:
    print(t.get('id', ''))
" 2>/dev/null)
  
  while IFS= read -r pg_id; do
    [[ -z "$pg_id" ]] && continue
    if ! echo "$JSON_IDS" | grep -qF "$pg_id"; then
      echo "  + $pg_id (PG only)"
    fi
  done <<< "$PG_IDS"
  
  exit 0
fi

# --- Full rebuild: dump PG → JSON file ---
TMPFILE=$(mktemp)
DUMPFILE=$(mktemp)
trap 'rm -f "$TMPFILE" "$DUMPFILE"' EXIT

# Dump PG to temp file first (avoid pipe SIGPIPE issues)
dump_pg_tickets > "$DUMPFILE"

python3 <<PYEOF > "$TMPFILE"
import json

tickets = []
seen_ids = set()

with open('$DUMPFILE') as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        parts = line.split('|')
        if len(parts) < 10:
            continue
        
        tid = parts[0].strip()
        # Skip rows with empty ID or duplicate IDs
        if not tid:
            continue
        if tid in seen_ids:
            continue
        seen_ids.add(tid)
        
        try:
            tags = json.loads(parts[9]) if parts[9] and parts[9] != '[]' else []
        except:
            tags = []
        try:
            metadata = json.loads(parts[10]) if len(parts) > 10 and parts[10] and parts[10] != '{}' else {}
        except:
            metadata = {}
        
        ticket = {
            "id": tid,
            "sequence": parts[1],
            "title": parts[2],
            "status": parts[3],
            "priority": parts[4],
            "type": parts[5],
            "created_at": parts[6],
            "notionpageid": parts[7],
            "url": parts[8],
            "tags": tags,
            "metadata": metadata
        }
        tickets.append(ticket)

print(json.dumps([{"tickets": tickets}], indent=2))
PYEOF

# Validate the temp file has valid JSON and correct count
NEW_COUNT=$(python3 -c "
import json
with open('$TMPFILE') as f:
    data = json.load(f)
print(len(data[0]['tickets']))
" 2>/dev/null | tr -d '[:space:]')

if [[ -z "$NEW_COUNT" ]] || [[ "$NEW_COUNT" -eq 0 ]]; then
  echo "ERROR: Generated JSON is empty or invalid. Aborting — original file preserved."
  exit 1
fi

if [[ "$NEW_COUNT" -ne "$PG_COUNT" ]]; then
  echo "ERROR: Generated JSON has $NEW_COUNT tickets but PG has $PG_COUNT. Aborting — original file preserved."
  exit 1
fi

# Atomic replacement
cp "$TICKETS_FILE" "$TICKETS_FILE.bak" 2>/dev/null || true
mv "$TMPFILE" "$TICKETS_FILE"
rm -f "$TMPFILE"

# --- Log ---
cat > "$LOG_FILE" <<LOF
{
  "lastReconcile": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "pgCount": $PG_COUNT,
  "fileCountBefore": $FILE_COUNT,
  "fileCountAfter": $NEW_COUNT,
  "gapResolved": $GAP,
  "backupPath": "$BACKUP_PATH"
}
LOF

echo "RESULT: reconciled — $GAP records synced. PG=$PG_COUNT FILE=$NEW_COUNT ✅"
echo "Backup: $BACKUP_PATH"
echo "Log: $LOG_FILE"
