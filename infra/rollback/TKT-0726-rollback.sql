-- ============================================================================
-- TKT-0726 Rollback Script
-- Reverts A2 schema migration and A3 PG function for agent_events.
--
-- WARNING: This script commits on run. For dry-run, copy this file and
-- replace COMMIT; with ROLLBACK;.
--
-- What this reverts:
--   1. Drops new columns from agent_events (event_id, entity_type, entity_id,
--      prev_state, new_state, hash, prev_hash)
--   2. Drops new indexes (idx_agent_events_entity, idx_agent_events_actor)
--   3. Drops the pg_write_event function
--   4. Drops the agent_events_event_id_seq sequence
--
-- What this does NOT revert:
--   - Existing event rows (data in original columns preserved)
--   - Script changes in db-ticket.sh, changelog-append.sh, db-sprint.sh
--     (those are reverted via git revert)
--   - The original agent_events columns (id, agent_id, event_type, timestamp,
--     payload, tenant_id) are untouched
--
-- Data loss boundary: Events written during the TKT-0726 window will lose
-- their hash/prev_hash/entity metadata but the original columns (id, agent_id,
-- event_type, timestamp, payload, tenant_id) are preserved.
-- ============================================================================

BEGIN;

-- 1. Drop new indexes
DROP INDEX IF EXISTS idx_agent_events_entity;
DROP INDEX IF EXISTS idx_agent_events_actor;

-- 2. Drop new columns from agent_events
ALTER TABLE agent_events DROP COLUMN IF EXISTS event_id;
ALTER TABLE agent_events DROP COLUMN IF EXISTS entity_type;
ALTER TABLE agent_events DROP COLUMN IF EXISTS entity_id;
ALTER TABLE agent_events DROP COLUMN IF EXISTS prev_state;
ALTER TABLE agent_events DROP COLUMN IF EXISTS new_state;
ALTER TABLE agent_events DROP COLUMN IF EXISTS hash;
ALTER TABLE agent_events DROP COLUMN IF EXISTS prev_hash;

-- 3. Drop the PG function
DROP FUNCTION IF EXISTS pg_write_event;

-- 4. Drop the sequence
DROP SEQUENCE IF EXISTS agent_events_event_id_seq;

COMMIT;
