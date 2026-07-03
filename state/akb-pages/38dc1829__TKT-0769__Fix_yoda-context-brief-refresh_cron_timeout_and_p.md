# [TKT-0769] Fix yoda-context-brief-refresh cron timeout and prompt weight

- **Notion ID:** `38dc182953ff81e5bceced54430ab8e2`
- **Status:** In Progress
- **Type:** task
- **Priority:** Medium
- **Category:** Technical
- **Sprint:** 
- **Created:** 2026-06-28T08:11:00.000+10:00
- **Last Edited:** 2026-06-28T08:12:00.000Z

## Notes

yoda-context-brief-refresh cron (c69615bb) times out at 120s during model-call-started. Timeout bumped from 120s to 180s at 2026-06-28 18:12 AEST. Remaining AC: observe 2 consecutive successful runs (20:00 today + 14:00 tomorrow). If still timing out, further prompt weight reduction required.
