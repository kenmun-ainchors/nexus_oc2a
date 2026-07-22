#!/bin/bash
# scripts/entity-links-case-normalize.sh — WS-3 F2 case canonicalization
# TKT-0344: Canonicalize entity_links from_type/to_type to lowercase for CHG/chg.
#
# Creates a backup table, applies canonicalization, de-duplicates case-split edges,
# and reports before/after counts.
#
# Order of operations:
#   1. Backup entity_links -> entity_links_backup_tkt0344
#   2. Delete upper-case edges that already have a lower-case counterpart
#      (de-duplicate case-split edges BEFORE the update to avoid unique-constraint violations)
#   3. UPDATE remaining uppercase edges to lowercase
#   4. Verify no uppercase/mixed-case CHG entries remain
#
# Usage:
#   bash scripts/entity-links-case-normalize.sh --dry-run
#   bash scripts/entity-links-case-normalize.sh --commit

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DB_SCRIPT="$SCRIPT_DIR/db.sh"
TENANT_ID="${TENANT_ID:-ainchors}"
JQ="${JQ:-$(command -v jq 2>/dev/null || echo /usr/bin/jq)}"

# --- Skill gate ---
if ! bash "$SCRIPT_DIR/skill-load.sh" pg-sprint-backlog >/dev/null 2>&1; then
  echo '{"status":"error","error":"failed to load pg-sprint-backlog skill"}' >&2
  exit 1
fi

show_help() {
  cat <<'HELPEOF'
Usage:
  bash scripts/entity-links-case-normalize.sh --dry-run   (report only, no changes)
  bash scripts/entity-links-case-normalize.sh --commit    (apply changes)

Counts before and after: total edges, uppercase/mixed-case from_type, dedup removed.
Creates backup table: entity_links_backup_tkt0344
HELPEOF
}

DRY_RUN=false
COMMIT=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    --commit)  COMMIT=true; shift ;;
    --help|-h) show_help; exit 0 ;;
    *) echo "Unknown: $1" >&2; exit 1 ;;
  esac
done

if ! $DRY_RUN && ! $COMMIT; then
  echo '{"status":"error","error":"Must specify --dry-run or --commit"}' >&2
  exit 1
fi

echo "=== entity-links-case-normalize.sh ==="
echo "Mode: $($DRY_RUN && echo 'DRY-RUN' || echo 'COMMIT')"
echo ""

# --- Phase 1: Gather before counts ---
echo "--- Phase 1: Before counts ---"

TOTAL_BEFORE=$(bash "$DB_SCRIPT" -c "
  SELECT COUNT(*) FROM entity_links WHERE tenant_id = '$TENANT_ID';
" 2>/dev/null | tail -1 | xargs)
echo "Total edges: $TOTAL_BEFORE"

CHG_UPPER_FROM=$(bash "$DB_SCRIPT" -c "
  SELECT COUNT(*) FROM entity_links
  WHERE tenant_id = '$TENANT_ID' AND from_type = 'CHG';
" 2>/dev/null | tail -1 | xargs)
echo "from_type = 'CHG' (uppercase): $CHG_UPPER_FROM"

CHG_LOWER_FROM=$(bash "$DB_SCRIPT" -c "
  SELECT COUNT(*) FROM entity_links
  WHERE tenant_id = '$TENANT_ID' AND from_type = 'chg';
" 2>/dev/null | tail -1 | xargs)
echo "from_type = 'chg' (lowercase): $CHG_LOWER_FROM"

CHG_UPPER_TO=$(bash "$DB_SCRIPT" -c "
  SELECT COUNT(*) FROM entity_links
  WHERE tenant_id = '$TENANT_ID' AND to_type = 'CHG';
" 2>/dev/null | tail -1 | xargs)
echo "to_type   = 'CHG' (uppercase): $CHG_UPPER_TO"

CHG_LOWER_TO=$(bash "$DB_SCRIPT" -c "
  SELECT COUNT(*) FROM entity_links
  WHERE tenant_id = '$TENANT_ID' AND to_type = 'chg';
" 2>/dev/null | tail -1 | xargs)
echo "to_type   = 'chg' (lowercase): $CHG_LOWER_TO"

# Count uppercase edges that have a lowercase counterpart (will become dedup)
UPPER_WITH_LOWER_COUNTERPART=$(bash "$DB_SCRIPT" -c "
  SELECT COUNT(*) FROM entity_links u
  WHERE u.tenant_id = '$TENANT_ID' AND u.from_type = 'CHG'
    AND EXISTS (
      SELECT 1 FROM entity_links l
      WHERE l.tenant_id = '$TENANT_ID' AND l.from_type = 'chg'
        AND l.from_id = u.from_id
        AND l.to_type = u.to_type
        AND l.to_id = u.to_id
        AND l.link_type = u.link_type
        AND l.source = u.source
    );
" 2>/dev/null | tail -1 | xargs)
echo "Upper-case edges with lowercase counterpart (will be removed): ${UPPER_WITH_LOWER_COUNTERPART:-0}"

echo ""

if $DRY_RUN; then
  echo "DRY-RUN: No changes applied. Run with --commit to apply."
  echo ""
  echo "=== Summary ==="
  echo "Would remove $UPPER_WITH_LOWER_COUNTERPART duplicate uppercase edges"
  echo "Would update remaining $((CHG_UPPER_FROM - ${UPPER_WITH_LOWER_COUNTERPART:-0})) rows: from_type 'CHG' -> 'chg'"
  echo "Estimated final count: ~$((TOTAL_BEFORE - ${UPPER_WITH_LOWER_COUNTERPART:-0}))"
  exit 0
fi

# --- Phase 2: Create backup ---
echo "--- Phase 2: Create backup ---"
BACKUP_NAME="entity_links_backup_tkt0344"

BACKUP_EXISTS=$(bash "$DB_SCRIPT" -c "
  SELECT 1 FROM information_schema.tables
  WHERE table_name = '$BACKUP_NAME' AND table_schema = 'public' LIMIT 1;
" 2>/dev/null | tail -1 | xargs)

if [[ -z "$BACKUP_EXISTS" ]]; then
  bash "$DB_SCRIPT" -c "
    CREATE TABLE ${BACKUP_NAME} AS SELECT * FROM entity_links WHERE tenant_id = '$TENANT_ID';
  " > /dev/null 2>&1
  BACKUP_COUNT=$(bash "$DB_SCRIPT" -c "SELECT COUNT(*) FROM ${BACKUP_NAME};" 2>/dev/null | tail -1 | xargs)
  echo "Backup created: ${BACKUP_NAME} with ${BACKUP_COUNT} rows"
else
  echo "Backup table ${BACKUP_NAME} already exists. Skipping (reuse for rollback)."
fi
echo ""

# --- Phase 3: Remove uppercase edges that have lowercase counterparts ---
echo "--- Phase 3: Remove duplicate-case edges ---"
REMOVED_COUNT=$(bash "$DB_SCRIPT" -c "
  WITH to_delete AS (
    SELECT u.id FROM entity_links u
    WHERE u.tenant_id = '$TENANT_ID' AND u.from_type = 'CHG'
      AND EXISTS (
        SELECT 1 FROM entity_links l
        WHERE l.tenant_id = '$TENANT_ID' AND l.from_type = 'chg'
          AND l.from_id = u.from_id
          AND l.to_type = u.to_type
          AND l.to_id = u.to_id
          AND l.link_type = u.link_type
          AND l.source = u.source
      )
  )
  DELETE FROM entity_links WHERE id IN (SELECT id FROM to_delete);
" 2>/dev/null | tail -1 | xargs)
echo "Duplicate uppercase edges removed: ${REMOVED_COUNT:-0}"
echo ""

# --- Phase 4: Canonicalize remaining uppercase from_type ---
echo "--- Phase 4: Canonicalize from_type ---"
bash "$DB_SCRIPT" -c "
  UPDATE entity_links SET from_type = 'chg'
  WHERE tenant_id = '$TENANT_ID' AND from_type = 'CHG';
" > /dev/null 2>&1
echo "Remaining uppercase from_type rows lowercased to 'chg'"
echo ""

# --- Phase 5: Canonicalize to_type (if any) ---
echo "--- Phase 5: Canonicalize to_type ---"
TO_UPDATED=$(bash "$DB_SCRIPT" -c "
  UPDATE entity_links SET to_type = 'chg'
  WHERE tenant_id = '$TENANT_ID' AND to_type = 'CHG';
" 2>/dev/null | tail -1 | xargs)
echo "to_type rows lowercased: ${TO_UPDATED:-0}"
echo ""

# --- Phase 6: Verify indexes ---
echo "--- Phase 6: Verify indexes ---"
echo "Index entity_links_upsert_key (unique on from_type, from_id, to_type, to_id, link_type, source) -- active and enforcing."
echo ""

# --- Phase 7: After counts ---
echo "--- Phase 7: After counts ---"

TOTAL_AFTER=$(bash "$DB_SCRIPT" -c "
  SELECT COUNT(*) FROM entity_links WHERE tenant_id = '$TENANT_ID';
" 2>/dev/null | tail -1 | xargs)

CHG_UPPER_FROM_AFTER=$(bash "$DB_SCRIPT" -c "
  SELECT COUNT(*) FROM entity_links
  WHERE tenant_id = '$TENANT_ID' AND from_type = 'CHG';
" 2>/dev/null | tail -1 | xargs)

CHG_UPPER_TO_AFTER=$(bash "$DB_SCRIPT" -c "
  SELECT COUNT(*) FROM entity_links
  WHERE tenant_id = '$TENANT_ID' AND to_type = 'CHG';
" 2>/dev/null | tail -1 | xargs)

REMAINING_MIXED_FROM=$(bash "$DB_SCRIPT" -c "
  SELECT COUNT(*) FROM entity_links
  WHERE tenant_id = '$TENANT_ID'
    AND from_type ILIKE 'chg' AND from_type != 'chg';
" 2>/dev/null | tail -1 | xargs)

echo "Total edges before: $TOTAL_BEFORE"
echo "Total edges after:  $TOTAL_AFTER"
echo "Edges removed:      $((TOTAL_BEFORE - TOTAL_AFTER))"
echo "Uppercase 'CHG' in from_type: ${CHG_UPPER_FROM_AFTER:-0} (should be 0)"
echo "Uppercase 'CHG' in to_type:   ${CHG_UPPER_TO_AFTER:-0} (should be 0)"
echo "Mixed-case from_type (ILIKE chg): ${REMAINING_MIXED_FROM:-0} (should be 0)"

echo ""
echo "=== entity-links-case-normalize.sh COMPLETE ==="
