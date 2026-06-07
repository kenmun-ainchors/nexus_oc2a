# [AUTO-HEAL] PG write failure — auto-heal log not persisted

- **Notion ID:** `377c182953ff81e3b4f6dd73433149b6`
- **Status:** Backlog
- **Type:** US
- **Priority:** High
- **Category:** Platform
- **Sprint:** 
- **Created:** 
- **Last Edited:** 2026-06-06T15:02:00.000Z

## Notes

Auto-heal (2026-06-07 01:00 AEST): db-write.sh failed when writing state_autoheal_log. The auto-heal script ran successfully (13 of 17 checks completed) but results were not persisted to Postgres. This means the morning standup cannot query PG for the latest auto-heal results. Likely related to known tilde-path issue (TKT-0327) in db-write.sh. Investigate and fix the PG write path for auto-heal log persistence.
