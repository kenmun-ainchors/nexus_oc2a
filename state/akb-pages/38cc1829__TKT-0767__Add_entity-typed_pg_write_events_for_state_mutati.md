# [TKT-0767] Add entity-typed pg_write_events for state mutations

- **Notion ID:** `38cc182953ff8101948ae1a65d61d869`
- **Status:** Open
- **Type:** task
- **Priority:** Medium
- **Category:** Technical
- **Sprint:** Sprint 12
- **Created:** 2026-06-27T10:24:00.000+10:00
- **Last Edited:** 2026-07-05T09:51:00.000Z

## Notes

entity_type and entity_id are NULL for all 32 pg_write_events records, breaking per-entity audit lineage. Scope: populate entity_type and entity_id in the pg-write pipeline (scripts/db-write.sh and callers) and add regression tests.
