-- Rollback for TKT-0721
-- Deletes changes migrated during the TKT-0721 batch

-- Note: The migration script uses a dynamic BATCH_ID: MIG-TKT-0721-YYYYMMDDHHMM.
-- Since we don't know the exact BATCH_ID at this time, we use a pattern match.

DELETE FROM entity_links 
WHERE source LIKE 'migrated-from-md:%' 
AND from_type = 'CHG' 
AND from_id IN (
    SELECT change_id FROM state_changes WHERE metadata->>'migration_batch' LIKE 'MIG-TKT-0721-%'
);

DELETE FROM state_changes 
WHERE metadata->>'migration_batch' LIKE 'MIG-TKT-0721-%';
