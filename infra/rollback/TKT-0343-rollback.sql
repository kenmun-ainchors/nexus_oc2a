-- ============================================================================
-- TKT-0343 Rollback Script
-- Reverses A2-A3: drops unique index on state_config_baseline.tenant_id,
-- and reverts the PG row to the pre-change baseline.
--
-- WARNING: This script COMMITS on run. For dry-run, copy this file and
-- replace COMMIT; with ROLLBACK;. Never run the production script for
-- syntax checking — always use the copy+ROLLBACK method.
--
-- Script file changes (gateway-config-snapshot.sh) are reverted
-- via git revert, not by this SQL script.
--
-- Usage (dry-run only):
--   cp infra/rollback/TKT-0343-rollback.sql /tmp/TKT-0343-dry-run.sql
--   # Edit /tmp/TKT-0343-dry-run.sql: replace COMMIT; with ROLLBACK;
--   bash scripts/db-raw.sh -f /tmp/TKT-0343-dry-run.sql
-- ============================================================================

BEGIN;

-- ============================================================================
-- STEP 1: Drop unique index on tenant_id (A3)
-- ============================================================================
DROP INDEX IF EXISTS idx_config_baseline_tenant;

-- ============================================================================
-- STEP 2: Restore the pre-change baseline row (A2)
-- ============================================================================
-- This restores the stale row that existed before the snapshot script
-- started writing to PG. The data reflects the v1 shape from 2026-06-07.
UPDATE state_config_baseline
SET data = '{"pgTables": 32, "cronCount": 59, "agentCount": 14, "upgradedAt": "2026-05-29T22:00:00+10:00", "upgradedFrom": "2026.5.12", "gatewayStatus": "healthy", "openclawVersion": "2026.5.27"}'::jsonb,
    updated_at = '2026-06-07 07:55:51+10'
WHERE tenant_id = 'ainchors';

-- ============================================================================
-- VERIFICATION QUERIES (run after rollback to confirm)
-- ============================================================================
-- 1. Check unique index is gone:
--    SELECT indexname FROM pg_indexes WHERE tablename='state_config_baseline' AND indexname='idx_config_baseline_tenant';
--    Should return 0 rows.
--
-- 2. Check row is restored:
--    SELECT data FROM state_config_baseline WHERE tenant_id='ainchors';
--    Should return the v1 stale shape.
--
-- 3. Check updated_at is restored:
--    SELECT updated_at FROM state_config_baseline WHERE tenant_id='ainchors';
--    Should return 2026-06-07 07:55:51+10.

COMMIT;
