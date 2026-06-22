# [TKT-0721] Migrate markdown CHGs into PG state_changes + link them

- **Notion ID:** `387c182953ff81fc81d4c4a8b3ae1da8`
- **Status:** Open
- **Type:** task
- **Priority:** High
- **Category:** Technical
- **Sprint:** Sprint 10
- **Created:** 2026-06-22T00:01:00.000+10:00
- **Last Edited:** 2026-06-22T07:48:00.000Z

## Notes

Migrate 1,144 markdown CHGs from memory/CHANGELOG.md (+ docs/CHANGELOG.md + archive) into PG state_changes. Use dual-write → shadow-validate → cutover → rollback-ready discipline. Link each migrated CHG to its referenced TKT/CHG/L via entity_links. Completeness metric required.
