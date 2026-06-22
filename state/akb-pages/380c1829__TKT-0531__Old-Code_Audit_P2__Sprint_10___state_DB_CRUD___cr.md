# [TKT-0531] Old-Code Audit P2 (Sprint 10): state DB CRUD + crons — db-ticket, db-sprint, journal, pg-to-notion

- **Notion ID:** `380c182953ff8198a443fbfbb3888b28`
- **Status:** Open
- **Type:** audit
- **Priority:** Medium
- **Category:** Technical
- **Sprint:** Sprint 10
- **Created:** 2026-06-15T07:21:00.000+10:00
- **Last Edited:** 2026-06-22T07:48:00.000Z

## Notes

Sprint 10 audit of 4 state-DB + cron scripts. Lower risk per call (short-lived, errors visible) but these are the foundation for the audit output itself. Audit last, after P0+P1 fix any patterns. Yoda-side audit using L-113 evidence-only verify. L-139 test corpus pattern applies throughout.
