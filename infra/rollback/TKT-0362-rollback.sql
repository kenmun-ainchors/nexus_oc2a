-- Rollback for TKT-0362
-- Deletes lessons and entity_links migrated during the TKT-0362 batch.

DELETE FROM entity_links
WHERE source LIKE 'migrated-from-md:MIG-TKT-0362-%'
   OR source LIKE 'reverse-link:TKT-0362:%';

DELETE FROM state_lessons
WHERE metadata->>'migration_batch' LIKE 'MIG-TKT-0362-%'
   OR lesson_id LIKE 'L-FREEFORM-%';

-- If re-running migration, you must re-run the full migration script
-- which re-creates the table if it doesn't exist. To fully drop:
-- DROP TABLE IF EXISTS public.state_lessons;
-- (commented out — only uncomment if you want to remove the entire table)
