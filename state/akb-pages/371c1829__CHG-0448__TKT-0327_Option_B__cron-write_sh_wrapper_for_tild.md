# [CHG-0448] TKT-0327 Option B: cron-write.sh wrapper for tilde-path bug

- **Notion ID:** `371c182953ff813693ddebad8a8accc5`
- **Status:** Done
- **Type:** CHG
- **Priority:** 
- **Category:** 
- **Sprint:** 
- **Created:** 2026-05-31
- **Last Edited:** 2026-05-31T03:15:00.000Z

## Notes

Type: script | Source: ken-prompt | Trigger: Standup cron 3 consecutive failures, Aria ROI cron 1 failure — both ~ write failures | Changed: Created scripts/cron-write.sh. Patched 4 crons: standup blog Aria-ROI context-brief to use exec+pipe instead of write tool. | Why: Models ignore absolute-path instructions. write tool uses ~ which fails in isolated sessions. | Verified: All 4 modes tested. Cron payloads updated and verified. | Rollback: Revert each cron payload.message to previous version
