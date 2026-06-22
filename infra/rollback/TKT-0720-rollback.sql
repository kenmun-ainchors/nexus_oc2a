BEGIN;
DROP TABLE IF EXISTS entity_links CASCADE;
DROP SEQUENCE IF EXISTS entity_links_link_id_seq CASCADE;
COMMIT;

-- Script reversion (run from workspace root):
-- git checkout -- scripts/db-ticket.sh scripts/changelog-append.sh scripts/db-sprint.sh
-- Note: git handles reversion of script changes. The SQL above drops the table and sequence.
-- After git checkout, verify with: git diff --stat scripts/db-ticket.sh scripts/changelog-append.sh scripts/db-sprint.sh
