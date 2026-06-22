-- ============================================================================
-- TKT-0330 Rollback Script
-- Reverses A2-A5: drops state_changes table, sequences, changelog_view,
-- and the ticket_number column from state_tickets.
--
-- WARNING: This script COMMITS on run. For dry-run, copy this file and
-- replace COMMIT; with ROLLBACK;. Never run the production script for
-- syntax checking — always use the copy+ROLLBACK method.
--
-- Script file changes (db-ticket.sh, changelog-append.sh) are reverted
-- via git revert, not by this SQL script.
--
-- Usage (dry-run only):
--   cp infra/rollback/TKT-0330-rollback.sql /tmp/TKT-0330-dry-run.sql
--   # Edit /tmp/TKT-0330-dry-run.sql: replace COMMIT; with ROLLBACK;
--   bash scripts/db.sh -f /tmp/TKT-0330-dry-run.sql
-- ============================================================================

BEGIN;

-- ============================================================================
-- STEP 1: Drop changelog_view (A5 compatibility shim)
-- ============================================================================
DROP VIEW IF EXISTS changelog_view;

-- ============================================================================
-- STEP 2: Drop state_changes table (A2)
-- ============================================================================
DROP TABLE IF EXISTS state_changes;

-- ============================================================================
-- STEP 3: Drop sequences (A2)
-- ============================================================================
DROP SEQUENCE IF EXISTS state_changes_change_id_seq;
DROP SEQUENCE IF EXISTS state_tickets_number_seq;

-- ============================================================================
-- STEP 4: Drop ticket_number column from state_tickets (A2)
-- ============================================================================
-- The UNIQUE constraint is dropped automatically with the column.
ALTER TABLE state_tickets DROP COLUMN IF EXISTS ticket_number;

-- ============================================================================
-- VERIFICATION QUERIES (run after rollback to confirm)
-- ============================================================================
-- 1. Check state_changes table is gone:
--    \d state_changes
--
-- 2. Check changelog_view is gone:
--    \d changelog_view
--
-- 3. Check sequences are gone:
--    SELECT last_value FROM state_tickets_number_seq;
--    SELECT last_value FROM state_changes_change_id_seq;
--
-- 4. Check ticket_number column is gone:
--    \d state_tickets
--
-- 5. Check original changelog table is untouched:
--    SELECT COUNT(*) FROM changelog;

COMMIT;
