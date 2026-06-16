# [TKT-0526] Auto-heal CHECK: audit all `:cloud` model crons with timeoutSeconds < 120

- **Notion ID:** `380c182953ff81f28576dec2862b2062`
- **Status:** Done
- **Type:** task
- **Priority:** Medium
- **Category:** Technical
- **Sprint:** Sprint 8
- **Created:** 2026-06-15T04:32:00.000+10:00
- **Last Edited:** 2026-06-15T05:23:00.000Z

## Notes

L-087 root cause: yoda-context-brief-refresh (c69615bb) ran on gemma4:31b-cloud with timeoutSeconds:30 — an outlier. All comparable crons at :cloud models use 120s minimum (Forge Fallback Chain, PG-Notion Sync, Auto-Heal, Warden, TRIGGER-04/06 etc.). Cold-start + cloud latency + multi-file reads routinely exceed 30s. This TKT adds an auto-heal CHECK that scans every cron payload.model, and if it ends in :cloud AND payload.timeoutSeconds < 120, surfaces as NEEDS_KEN with the offending cron id/name/timeout/model. Prevents recurrence. Initial audit (2026-06-15): yoda-context-brief was the only outlier found, but a structural check is the right fix. Linked: CHG-0581 (the manual patch).
