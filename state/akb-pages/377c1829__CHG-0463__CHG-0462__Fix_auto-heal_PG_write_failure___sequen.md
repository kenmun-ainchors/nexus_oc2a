# [CHG-0463] CHG-0462: Fix auto-heal PG write failure — sequence desync

- **Notion ID:** `377c182953ff815fa277d3607e8fa6b8`
- **Status:** Done
- **Type:** CHG
- **Priority:** 
- **Category:** 
- **Sprint:** 
- **Created:** 2026-06-07
- **Last Edited:** 2026-06-06T21:58:00.000Z

## Notes

Type: infra | Source: auto-heal | Trigger: Auto-heal CHECK #3 — PG write failure reported. Root cause: sequence state_autoheal_log_id_seq was at 30 but table max id was 41. | Changed: Reset sequence to 43 via setval(). Manually inserted missed 2026-06-06 auto-heal row. Verified all 12 state sequences now in sync. Identified gap: no sequence-health check exists in auto-heal.sh. | Why: Duplicate key violation on INSERT. Sequence had desynced, likely from restore or manual insertion bypassing DEFAULT. | Verified: All 12 sequences validated. Insert confirmed id=43. | Rollback: N/A
