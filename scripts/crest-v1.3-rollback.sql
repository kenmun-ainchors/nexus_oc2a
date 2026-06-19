-- CREST v1.3 Rollback DDL
-- Drops all tables created by CREST v1.3 Tier A5.
-- Run against sandbox PG first, then production if rollback needed.
-- Usage: bash scripts/db.sh -f scripts/crest-v1.3-rollback.sql

BEGIN;

-- 1. Drop routing_log (no dependencies)
DROP TABLE IF EXISTS routing_log CASCADE;

-- 2. Drop model_capabilities
DROP TABLE IF EXISTS model_capabilities CASCADE;

-- 3. Drop crest_phase_rules
DROP TABLE IF EXISTS crest_phase_rules CASCADE;

-- 4. Drop model_registry
DROP TABLE IF EXISTS model_registry CASCADE;

-- 5. Drop policy_matrices
DROP TABLE IF EXISTS policy_matrices CASCADE;

-- 6. Drop state_sub_crest
DROP TABLE IF EXISTS state_sub_crest CASCADE;

-- 7. Restore state_model_policy to pre-v1.3 state
-- (The original single-row JSONB table is untouched by v1.3;
--  new tables are separate. No restore needed for state_model_policy itself.)

COMMIT;

-- Post-rollback manual steps:
-- 1. git checkout HEAD -- state/model-policy.json
-- 2. Revert agent-skills/crest/SKILL.md to v1.2 reference
-- 3. Remove glm-5.1:cloud from globalAllowedModels if it was the only consumer
-- 4. Log CHG-rollback and alert Ken
