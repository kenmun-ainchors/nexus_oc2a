# [TKT-0720] Create entity_links edge table + backfill from markdown Linked: mentions

- **Notion ID:** `387c182953ff816ca119f7a72b4f070a`
- **Status:** Done
- **Type:** task
- **Priority:** Critical
- **Category:** Technical
- **Sprint:** Sprint 9
- **Created:** 2026-06-22T00:00:00.000+10:00
- **Last Edited:** 2026-06-22T10:27:00.000Z

## Notes

Build entity_links per CRESTv2-P1-DM §1.3. Replace grep-based Linked: with FK edges. Backfill from markdown (memory/CHANGELOG.md, docs/*.md, memory/*.md) and existing changelog table. Measure completeness (target >90% of discoverable links captured). Live writes must insert edges atomically.
