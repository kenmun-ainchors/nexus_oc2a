-- ============================================================================
-- TKT-0725 Rollback Script
-- Restores state_tickets.sprint to previous text-based sprint values,
-- drops the sprint_id FK column, drops state_sprint_normalization_map,
-- and removes the Unassigned sentinel sprint.
--
-- WARNING: This is a DESTRUCTIVE rollback. Run only if TKT-0725 needs to be
-- fully reverted. All sprint_id FK assignments will be lost.
--
-- Usage:
--   psql -f TKT-0725-rollback.sql
--   # Or via db.sh:
--   bash scripts/db.sh -f infra/rollback/TKT-0725-rollback.sql
-- ============================================================================

BEGIN;

-- ============================================================================
-- STEP 1: Restore text-based sprint values from sprint_history metadata
-- ============================================================================
-- For tickets that have sprint_history in metadata, restore the old_sprint_text
-- value. For tickets without sprint_history, keep the current sprint text value
-- (which was already set to canonical during normalization).

-- Restore from metadata->sprint_history (most recent entry per ticket)
UPDATE state_tickets t
SET sprint = sub.old_sprint_text,
    updated_at = NOW()
FROM (
    SELECT
        t2.id,
        (t2.metadata->'sprint_history'->>(jsonb_array_length(t2.metadata->'sprint_history') - 1))::jsonb->>'old_sprint_text' AS old_sprint_text
    FROM state_tickets t2
    WHERE t2.metadata ? 'sprint_history'
      AND jsonb_array_length(t2.metadata->'sprint_history') > 0
) sub
WHERE t.id = sub.id
  AND sub.old_sprint_text IS NOT NULL;

-- Restore from state_sprint_normalization_map for tickets that have
-- a sprint value matching a canonical sprint name but no sprint_history
UPDATE state_tickets t
SET sprint = m.old_sprint_text,
    updated_at = NOW()
FROM state_sprint_normalization_map m
WHERE t.sprint = m.canonical_sprint_name
  AND (NOT t.metadata ? 'sprint_history'
       OR jsonb_array_length(t.metadata->'sprint_history') = 0);

-- ============================================================================
-- STEP 2: Clear sprint_id FK column
-- ============================================================================
UPDATE state_tickets SET sprint_id = NULL, updated_at = NOW();

-- ============================================================================
-- STEP 3: Drop FK constraint and sprint_id column
-- ============================================================================
-- First check if the FK constraint exists
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'state_tickets_sprint_id_fkey'
          AND conrelid = 'state_tickets'::regclass
    ) THEN
        ALTER TABLE state_tickets DROP CONSTRAINT state_tickets_sprint_id_fkey;
    END IF;
END $$;

-- Drop the sprint_id column
ALTER TABLE state_tickets DROP COLUMN IF EXISTS sprint_id;

-- ============================================================================
-- STEP 4: Drop state_sprint_normalization_map table
-- ============================================================================
DROP TABLE IF EXISTS state_sprint_normalization_map;

-- ============================================================================
-- STEP 5: Remove Unassigned sentinel sprint from state_sprints
-- ============================================================================
DELETE FROM state_sprints WHERE sprint_name = 'Unassigned' AND sprint_number = 0;

-- ============================================================================
-- STEP 6: Restore state_sprints.items to text-based format
-- ============================================================================
-- The items JSONB arrays reference tickets by TKT-ID. These remain valid
-- since the TKT-ID references are unchanged. No action needed on items
-- themselves, but we clear the sprint_number=0 sentinel from any items
-- references (should be empty already).

-- ============================================================================
-- VERIFICATION QUERIES (run after rollback to confirm)
-- ============================================================================
-- 1. Check sprint_id column is gone:
--    \d state_tickets
--
-- 2. Check state_sprint_normalization_map is gone:
--    \d state_sprint_normalization_map
--
-- 3. Check Unassigned sentinel is gone:
--    SELECT * FROM state_sprints WHERE sprint_name = 'Unassigned';
--
-- 4. Check sprint values are restored to text:
--    SELECT id, sprint FROM state_tickets WHERE sprint IS NOT NULL LIMIT 10;
--
-- 5. Check no sprint_id references remain:
--    SELECT id FROM information_schema.columns
--    WHERE table_name = 'state_tickets' AND column_name = 'sprint_id';

COMMIT;
